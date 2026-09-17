# 백엔드 Cloud Run 배포 런북

> lookup(위를 봐요) FastAPI 백엔드를 Google Cloud Run에 배포하는 재현 가능한 절차.
> 관련 스펙: `specs/024-deploy-backend-cloudrun-backend.md`. 컨테이너 정의: `apps/backend/Dockerfile`.
>
> ⚠️ **시크릿 안전 원칙**: API 키 값을 이 문서·명령 히스토리·커밋 어디에도 평문으로 남기지 않는다.
> 아래 절차는 값을 직접 타이핑하지 않고 로컬 `.env`에서 Secret Manager로 **파이프**한다.
> `.env`는 `.dockerignore`·`.gitignore` 대상이라 이미지·저장소에 들어가지 않는다.

배포는 GCP 계정 인증이 필요해 오너가 세션에서 직접 실행한다(`gcloud`). 각 블록은 위→아래 순서로 복붙한다.

---

## 0. 사전 준비

```sh
# gcloud CLI 설치 확인 (없으면 https://cloud.google.com/sdk/docs/install)
gcloud --version

# 로그인 (브라우저 인증)
gcloud auth login
```

변수 설정 — `PROJECT_ID`는 전 세계 유일해야 한다(예: `lookup-<본인>-<숫자>`).

```sh
export PROJECT_ID="lookup-feel-$(date +%s)"   # 원하는 값으로 교체 가능
export REGION="asia-northeast3"                # 서울 리전
export SERVICE="lookup-backend"
```

프로젝트 생성 → 선택 → 결제 계정 연결 → 필요한 API 활성화.

```sh
gcloud projects create "$PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# 결제 계정 ID 확인 후 연결 (BILLING_ACCOUNT_ID는 아래 목록에서 복사)
gcloud billing accounts list
gcloud billing projects link "$PROJECT_ID" --billing-account="<BILLING_ACCOUNT_ID>"

# 배포에 필요한 API 활성화
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```

---

## 1. Secret Manager에 키 등록 (값은 로컬 .env에서 파이프)

저장소 루트에서 실행한다(`.env`가 있는 위치). 아래 루프는 `.env`의 각 키를 동일 이름의 시크릿으로 만들고, 값을 stdin으로 흘려보내 **터미널에 값이 노출되지 않는다.** 이미 있으면 새 버전만 추가한다.

```sh
cd /path/to/lookup   # .env 가 있는 저장소 루트

while IFS= read -r line; do
  case "$line" in \#*|"") continue;; esac        # 주석·빈 줄 건너뜀
  key="${line%%=*}"
  val="${line#*=}"
  [ -z "$val" ] && continue                       # 빈 값 스킵
  if gcloud secrets describe "$key" >/dev/null 2>&1; then
    printf '%s' "$val" | gcloud secrets versions add "$key" --data-file=-
  else
    printf '%s' "$val" | gcloud secrets create "$key" --replication-policy=automatic --data-file=-
  fi
  echo "registered secret: $key"
done < .env
```

Cloud Run 런타임 서비스 계정에 시크릿 접근 권한 부여.

```sh
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for key in $(grep -vE '^\s*#|^\s*$' .env | cut -d= -f1); do
  gcloud secrets add-iam-policy-binding "$key" \
    --member="serviceAccount:${RUNTIME_SA}" \
    --role="roles/secretmanager.secretAccessor" >/dev/null
done
echo "granted secretAccessor to $RUNTIME_SA"
```

---

## 2. 배포

`--source apps/backend` 는 Cloud Build로 `apps/backend/Dockerfile`을 자동 감지해 이미지를 빌드·배포한다. `--set-secrets`로 15개 키를 **참조로만** 주입한다(평문 아님).

```sh
# .env 키 목록으로 --set-secrets 인자 생성 (ENV=SECRET:latest 형식)
SECRET_FLAGS="$(grep -vE '^\s*#|^\s*$' .env | cut -d= -f1 \
  | awk '{printf "%s%s=%s:latest", (NR>1?",":""), $1, $1}')"

gcloud run deploy "$SERVICE" \
  --source apps/backend \
  --region "$REGION" \
  --allow-unauthenticated \
  --min-instances=0 \
  --port=8080 \
  --set-secrets="$SECRET_FLAGS"
```

배포가 끝나면 서비스 URL이 출력된다. 변수로 잡아둔다.

```sh
export SERVICE_URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo "$SERVICE_URL"
```

---

## 3. 배포 확인 (스모크)

```sh
curl -s "$SERVICE_URL/api/health"                       # → {"status":"ok"}
curl -s "$SERVICE_URL/api/species?lat=37.5921&lng=126.3984" | head -c 400
curl -s "$SERVICE_URL/api/observation-map?lat=37.5921&lng=126.3984" | head -c 400
```

`/api/health`가 200이면 배포 성공. 외부 API 의존 엔드포인트는 시크릿이 올바르면 정상, 특정 키 누락 시 해당 엔드포인트만 degrade된다.

> 첫 요청은 콜드 스타트(수백 ms~수 초)로 느릴 수 있다(min-instances=0). 상시 응답이 필요해지면
> `gcloud run services update "$SERVICE" --region "$REGION" --min-instances=1` (월 소액 고정비 발생).

---

## 4. 예산 알림 (과금 조기 경보)

트래픽이 튀어 과금이 시작되면 즉시 알 수 있도록 소액 예산 알림을 건다.

```sh
BILLING_ACCOUNT_ID="$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingAccountName)' | sed 's#.*/##')"

gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="lookup-backend budget" \
  --budget-amount=5USD \
  --threshold-rule=percent=0.2 \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=1.0
```

> `gcloud billing budgets` 가 없다면 `gcloud components install alpha` 후 `gcloud alpha billing budgets create ...`,
> 또는 콘솔 Billing → Budgets & alerts 에서 동일하게 설정한다.

---

## 5. 앱 연동 (2단계 준비)

확보한 `$SERVICE_URL`(HTTPS)을 Flutter 앱 빌드 시 주입한다. HTTPS라 안드로이드 cleartext 예외 설정이 불필요하다.

```sh
flutter build apk --release --dart-define=API_BASE_URL="$SERVICE_URL"
```

자세한 앱 빌드·배포는 2단계 스펙(`specs/025-...-flutter.md`, 예정)에서 다룬다. 번들ID는 `com.feel.lookup`.

---

## 재배포 (코드 변경 후)

```sh
gcloud run deploy "$SERVICE" --source apps/backend --region "$REGION"
```

시크릿을 바꿨을 때만 `.env` 갱신 후 §1 루프를 다시 돌려 새 버전을 추가하면 `:latest` 참조가 자동 반영된다(재배포 필요).
