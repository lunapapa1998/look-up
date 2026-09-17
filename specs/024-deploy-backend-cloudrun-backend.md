# 백엔드 Cloud Run 배포 backend (Dockerfile + 배포 런북 + Secret Manager)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-17
- modified: 2026-09-17 <brain/orchestrator>
- refs: `apps/backend/app/main.py`(`GET /api/health`·라우터 8종), `apps/backend/pyproject.toml`(uv·python>=3.12·`uvicorn[standard]`), `apps/backend/app/suitability/config.py`(`load_dotenv`로 env 로드 — Cloud Run에선 실제 환경변수로 주입), 저장소 루트 `.env`(외부 API 키 14개), `justfile`(`backend-check`), 오너 결정(2026-09-17: Cloud Run min-instances=0·Secret Manager·예산 알림)
- risk: high - 신규 배포 인프라(Dockerfile·Cloud Run) + 시크릿 취급. **애플리케이션 코드/기존 API 계약 무변경** — 컨테이너화와 배포 문서화만 추가한다. 실제 클라우드 인증(`gcloud auth`·프로젝트·결제·`run deploy`)은 팩토리 밖 오너 대화형 단계이며, 이 스펙은 그 단계를 재현 가능한 런북으로 문서화한다.
- ⚠️ 시크릿 안전: `.env`의 실제 키 값을 Dockerfile·런북·커밋 어디에도 하드코딩 금지. 런북은 **키 이름**만 참조하고 값은 Secret Manager/배포 시점에 주입.

## Purpose

강화 갯벌 탐조 앱의 FastAPI 백엔드를 외부 기기(안드로이드 앱)에서 접근 가능한 공개 URL로 띄우기 위해, Google Cloud Run 배포에 필요한 컨테이너 정의와 재현 가능한 배포 런북을 추가한다.

## Problem

1. 백엔드가 `localhost:8000`에서만 돌아 외부 기기에서 접근할 수 없다(앱 다운로드 배포의 선행 조건 미충족).
2. 저장소에 Dockerfile·배포 설정·런북이 없어 Cloud Run에 올릴 표준 산출물이 전혀 없다.
3. 외부 API 키 14개를 안전하게(평문 노출 없이) 주입하는 절차가 문서화돼 있지 않다.

## Solution

(1) `apps/backend/Dockerfile`(uv 기반 python:3.12-slim, `$PORT` 바인딩) + `.dockerignore`를 추가해 Cloud Run 표준 컨테이너로 만든다. (2) `docs/deploy/backend-cloudrun.md` 런북에 GCP 프로젝트/결제 연결 → Secret Manager에 키 14개 등록 → `gcloud run deploy`(min-instances=0) → `/api/health` 확인 → 예산 알림까지 복붙 가능한 명령으로 문서화한다. (3) `just docker-build-backend`로 이미지 빌드를 로컬 검증하고, 기존 `backend-check`(pytest)로 코드 무변경(무회귀)을 보장한다.

## Relevant Files

### Existing Files

- `apps/backend/pyproject.toml` - 무변경(참조만). 의존성·빌드백엔드(hatchling)·`app` 패키지 구조를 Dockerfile이 그대로 사용.
- `apps/backend/app/main.py` - 무변경(참조만). 컨테이너 CMD가 `app.main:app`을 uvicorn으로 서빙. `/api/health`가 배포 확인용 엔드포인트.
- `apps/backend/app/suitability/config.py` - 무변경. `load_dotenv(find_dotenv())`는 `.env`가 없으면 조용히 넘어가고 실제 프로세스 환경변수(`os.getenv`)를 읽으므로, Cloud Run에서 주입한 env가 그대로 적용됨(코드 수정 불필요). **런북이 이 파일이 읽는 키 이름 목록의 정본**.
- `justfile` - `docker-build-backend` 레시피 추가(아래 신규). 기존 `backend-check`/`check` 무변경.

### New Files

- `apps/backend/Dockerfile` - Cloud Run용 멀티스테이지(또는 단일) 이미지. python:3.12-slim + uv 설치 → `uv sync --frozen --no-dev`(uv.lock 사용) → app 복사 → `CMD` 로 `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}`. Cloud Run은 `$PORT`(기본 8080)를 주입하므로 반드시 셸 형태로 바인딩.
- `apps/backend/.dockerignore` - `.venv`, `__pycache__`, `tests`, `.env`(⚠️ 시크릿 이미지 유입 방지), `*.pyc`, `.git` 제외.
- `docs/deploy/backend-cloudrun.md` - 배포 런북(아래 Phase 2 참조). 키 값이 아닌 **키 이름 14종**만 나열.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 컨테이너화 (Dockerfile + .dockerignore + 빌드 검증)

앱 코드 무변경으로 백엔드를 Cloud Run 호환 이미지로 만든다.

- [x] `apps/backend/Dockerfile` 작성 — python:3.12-slim 베이스, uv로 `uv.lock` 고정 설치(`--frozen --no-dev`), `app` 복사, 비루트 유저 권장, `$PORT` 셸 바인딩 CMD.
- [x] `apps/backend/.dockerignore` 작성 — `.env`·`.venv`·`__pycache__`·`tests`·`.git` 등 제외.
- [x] `justfile`에 `docker-build-backend` 레시피 추가 — `cd apps/backend && docker build -t lookup-backend:local .`. **브레인이 Maintenance Exception으로 직접 추가**(backend 팀 도메인 밖이라 위임 불가했던 블로커 해소). `just --list`에 등록 확인.
- [ ] `.env` 없이 컨테이너가 기동되는지 확인(로컬 `docker run -p 8080:8080 -e PORT=8080 lookup-backend:local` 후 `curl :8080/api/health` → `{"status":"ok"}`). 외부키가 없어도 health와 앱 부팅은 성공해야 함(키 필요한 엔드포인트만 degrade). **docker 미가용 환경(이 세션)이라 오너 수동 검증 필요.**

**Phase validation**: `just docker-build-backend`가 성공하고(exit 0), 컨테이너가 `/api/health`에 200을 반환. docker가 파이프라인 샌드박스에 없으면 이 단계는 오너 세션에서 수동 검증하고 Notes에 결과를 기록(빌드 로그 요약).

### Phase 2: 배포 런북 문서화 (docs/deploy/backend-cloudrun.md)

오너가 세션에서 복붙 실행할 수 있는 재현 가능한 절차를 문서화한다. **실행은 오너, 문서화는 이 스펙.**

- [x] 사전 준비: `gcloud` 설치 확인, `gcloud auth login`, 프로젝트 생성/선택, 결제 계정 연결, 필요한 API 활성화(`run.googleapis.com`, `artifactregistry.googleapis.com`, `cloudbuild.googleapis.com`, `secretmanager.googleapis.com`).
- [x] 시크릿 등록: `.env`의 키 14종(`DATA_GO_KR_SERVICE_KEY`, `DATA_GO_KR_SERVICE_KEY_DECODED`, `DURUNUBI_BASE_URL`, `TOURAPI_BASE_URL`, `TOUR_PHOTO_BASE_URL`, `KASI_ASTRO_EVENT_BASE_URL`, `KASI_RISESET_BASE_URL`, `KASI_LUNPH_BASE_URL`, `WEATHER_PROVIDER`, `OPENWEATHERMAP_API_KEY`, `OPENWEATHERMAP_BASE_URL`, `KMA_APIHUB_KEY`, `KMA_APIHUB_BASE_URL`, `EBIRD_API_TOKEN`, `EBIRD_API_BASE_URL` — 총 15개 라인; 값 없는 base URL은 배포 대상에서 실제 사용되는 것만)을 `gcloud secrets create` + 버전 추가로 등록하는 절차. **키 값은 문서에 쓰지 말 것**(플레이스홀더만).
- [x] 배포: `gcloud run deploy lookup-backend --source apps/backend`(또는 이미지 푸시 방식) — region(권장 `asia-northeast3` 서울), `--allow-unauthenticated`(공개 API), `--min-instances=0`, `--set-secrets`로 시크릿 매핑.
- [x] 확인: 배포 후 출력된 서비스 URL로 `curl <URL>/api/health` → 200. 대표 엔드포인트 1~2개(`/api/species`, `/api/observation-map`) 스모크.
- [x] 예산 알림: Billing budget을 소액($1/$5)에 걸어 과금 발생 시 이메일 알림 받는 절차.
- [x] 앱 연동 메모: 확보한 서비스 URL을 2단계 앱 빌드에서 `--dart-define=API_BASE_URL=<URL>`로 주입한다는 안내(HTTPS이므로 안드로이드 cleartext 이슈 없음).

**Phase validation**: 런북을 처음 읽는 사람이 값만 채우면 배포를 완주할 수 있을 만큼 명령이 구체적(복붙 가능). 시크릿 실값이 문서·커밋에 없음.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just backend-check
just docker-build-backend
```

> 주의: `docker-build-backend`는 파이프라인 환경에 docker가 있을 때만 exit 0 가능. docker 미가용 시 lead는 `backend-check`만 파이프라인 검증으로 돌리고, `docker-build-backend`는 Phase 1 Notes에 수동 검증 결과(빌드 성공 로그 요약)를 남긴다.

## Notes (agent scratchpad)

- 앱 코드는 이미 Cloud Run 친화적: `config.py`가 `os.getenv`로 읽어 env 주입만으로 동작, `/api/health` 존재. 컨테이너화+문서화가 이 스펙의 실체이고 로직 변경은 없어야 한다.
- 외부키가 하나도 없어도 컨테이너 부팅과 `/api/health`는 성공해야 한다(키 필요 엔드포인트만 degrade). 부팅 시점에 키를 강제로 검증해 죽는 코드가 있으면 Notes에 보고(스펙 밖 이슈).
- `gcloud run deploy --source`는 buildpacks 대신 저장소의 Dockerfile을 자동 감지해 사용하므로 Dockerfile이 정본 빌드 경로.
- **Phase 1 (backend-engineer, member-build apps/backend) 완료**: `apps/backend/Dockerfile`(python:3.12-slim, `uv sync --frozen --no-dev` 레이어 캐싱, `app` 복사, `appuser` 비루트 유저, `CMD uv run uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}` 셸 폼)와 `apps/backend/.dockerignore`(`.venv .env __pycache__ *.pyc .git tests .pytest_cache`) 신규 생성, `app/`·`tests/`·`pyproject.toml`·`uv.lock` 무변경 확인. `just check`로 `backend-check`(154 passed, 12 skipped) 회귀 없음 확인.
- **도메인 화이트리스트 블로커(오너 조치 필요)**: backend 팀(`factory/teams/backend.yaml`)의 `domains`는 `apps/backend`, `specs` 두 개뿐이다. `factory/delegate.sh`는 `<domain>` 인자를 이 목록과 정확히 일치시키는 화이트리스트 체크를 강제하므로, 저장소 루트 `justfile`(`docker-build-backend` 레시피 추가)과 `docs/deploy/backend-cloudrun.md`(런북 신규 파일)는 이 backend 팀 lead가 member-build로 위임할 수 없다. lead 자신도 쓰기 가능 경로가 `specs/`뿐이라 직접 작성 불가(하드룰 1). 두 가지 선택지: (a) 오너/오케스트레이터 브레인이 `justfile`/`docs/`는 factory 유지보수 예외(CLAUDE.md Maintenance Exception)로 직접 작성하거나, (b) `backend.yaml`의 `domains`에 `justfile`(단일 파일 도메인)과 `docs/deploy`를 추가해 백엔드 팀이 위임 가능하게 한다. Phase 1의 마지막 체크박스(`.env` 없이 컨테이너 기동 확인)도 이 세션에 docker CLI 접근이 없어 오너 수동 검증이 필요하다.

## Amendments (post-build change history, append-only)

- 2026-09-17: 스펙 최초 작성(brain).
- 2026-09-17: backend-lead 실행 — Phase 1 중 Dockerfile/.dockerignore만 완료([x]), 나머지(justfile 레시피, docs/deploy 런북 전체)는 backend 팀 도메인 화이트리스트(`apps/backend`,`specs`)가 저장소 루트 `justfile`/`docs/`를 포함하지 않아 [F]로 표시하고 오너에게 에스컬레이션(Notes 참조). docker 미가용으로 컨테이너 기동 확인도 [ ] 보류.
- 2026-09-17: 재시도(2회차) — `just docker-build-backend` 검증이 동일하게 `error: justfile does not contain recipe` 로 실패(exit 1). `factory/delegate.sh:22-25`를 직접 확인해 화이트리스트 미스매치가 하드 차단(`domain not in team whitelist`)임을 재확인. 동일 원인의 반복 실패이므로 member 재위임을 하지 않고 즉시 오너 에스컬레이션(coordination-core 규칙 5: 같은 스펙이 두 번 실패하면 패치 대신 에스컬레이션). backend-lead가 위임/직접 작성 가능한 파일은 이미 모두 완료된 상태(Dockerfile, .dockerignore) — 이 스펙은 backend 팀 단독으로는 더 이상 전진 불가.

## Metadata (append-only)

- modified: 2026-09-17, lead: claude-sonnet-5
- 2026-09-17: brain(오케스트레이터) — 도메인 블로커를 Maintenance Exception으로 해소. `justfile`에 `docker-build-backend` 레시피 직접 추가, `docs/deploy/backend-cloudrun.md` 런북 직접 작성(값 노출 없이 `.env`→Secret Manager 파이프 방식, 15키 전부 Secret Manager, min-instances=0, 서울 리전, 예산 알림 포함). Dockerfile 수정: `uv sync`에 `--no-install-project`, CMD에 `uv run --no-sync` 추가(프로젝트 미복사 시점 빌드 실패·런타임 재sync 방지). `backend-check` 154 passed 무회귀. 남은 항목: `.env` 없는 컨테이너 기동 확인([ ])은 docker 미가용으로 오너 수동 검증. 실제 `gcloud` 배포는 오너 대화형 단계.
