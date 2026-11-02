# 위를 봐요 (Look Up)

> 고개를 들면 여행이 시작됩니다. 낮에는 새를, 밤에는 별을 찾아 떠나는 관찰 여행 앱.

〈위를 봐요〉는 날씨·천문·물때·빛공해 데이터와 시민과학 탐조 기록을 모아 "지금 어디서 무엇을 보기 좋은지"를 알려 주는 Flutter 앱입니다. 낮 모드에서는 새 관찰 여정을, 밤 모드에서는 별 관찰 여정을 안내합니다.

| 구분 | 주소 |
|---|---|
| 웹 데모 (GitHub Pages) | https://lunapapa1998.github.io/look-up/ |
| Android 데모 APK | 과제 제출 Google Drive 폴더에 `위를봐요_android_demo.apk`로 제출 (공개 배포하지 않음) |

## 공개 데모와 실제 데이터 환경의 차이

- **공개 웹 데모와 Android 데모 APK는 예시 데이터로 동작합니다.** 백엔드 서버가 공개 운영되고 있지 않아 API 호출이 실패하면, 앱이 "서버에 연결할 수 없어 예시 데이터를 보여드려요" 안내와 함께 `예시` 표시가 붙은 예시 데이터를 보여 줍니다. 실제 관측 정보가 아닙니다.
- **실제 공공데이터 연동**은 아래 "로컬 실행"처럼 백엔드를 직접 실행하고 API 키를 넣었을 때 동작합니다(발표 시연 영상은 이 환경에서 촬영).
- 공개 웹 데모는 첫 화면 일러스트 개선(`e9171dc`) 이전 빌드입니다. 앱 코드는 이 저장소의 `main`이 최신입니다.

## 주요 기능

- **첫 화면**: 낮·밤 일러스트, 로그인 없이 둘러보기
- **홈 · 오늘의 관찰 여정**: 오늘 조건(관찰 적합도 점수·골든타임) → 추천 장소 → 주변 코스·음식점 → 기록하기 → 참여(배지)
- **낮/밤/자동 모드 전환**: 낮은 새 관찰, 밤은 별 관찰 중심으로 화면·추천이 바뀜. 밤에는 "오늘 이 자리에서 보이는 하늘"(별자리) 표시
- **관찰 지도**: eBird 탐조 지점, 별 관측지(SQM·Bortle 추정치), 주변 음식점, 두루누비 코스 시작점. 필터·목록·정렬·핀 상세, 종 정보(위키백과)
- **발견**: 두루누비 코리아둘레길 코스, 코스별 낮·밤 적합도, 지역 식당, 코스 상세
- **낮-밤 패키지**: 예시 여행 패키지와 예약 미리보기
- **기록하기**: 새/별 관찰 기록 입력

### 미구현·제한 사항

- **예약·결제 없음**: 여행 패키지는 예시 콘텐츠이며, 예약 미리보기는 선택 내용을 전송·저장하지 않습니다.
- **로그인 미설정**: 데모 빌드에는 카카오·Google 로그인 설정이 없어 "로그인 설정을 준비 중" 안내만 나옵니다.
- **데이터가 없을 수 있는 기능**: 기록 저장·생태일기·배지 진행은 백엔드가 있어야 하며, 데모에서는 기기 임시 저장 또는 예시로 동작합니다.
- **SQM·Bortle 등급은 추정치**입니다. 실시간 측정값이 아니라 위성 자료 기반 빛공해 지도(World Atlas 2015)에서 읽은 값입니다.
- **웹 경로선 미표시**: 웹에서는 두루누비 GPX 경로선을 불러오지 못해 출발·도착 지점만 표시될 수 있습니다.

## 데이터 및 외부 API 출처

| 데이터 | 제공 | 용도 |
|---|---|---|
| 초단기 날씨 | 기상청 API허브 | 관찰 조건(하늘·습도·바람·강수) |
| 일출몰·월령 | 한국천문연구원 (공공데이터포털) | 골든타임, 달 위상, 별 관측 시간 |
| 조석(만조·간조) | 국립해양조사원 (공공데이터포털) | 갯벌 탐조 물때 |
| 두루누비 걷기길 코스 | 한국관광공사 (공공데이터포털) | 발견 탭 코스·경로 |
| 주변 음식점 | 한국관광공사 TourAPI (공공데이터포털) | 코스·관측지 주변 식당 |
| 최근 새 관찰 기록 | eBird (Cornell Lab, 시민과학) | 탐조 지점·종·마릿수 |
| 종 설명·사진 | 위키백과 | 종 정보 화면 |
| 빛공해 | World Atlas of Artificial Night Sky Brightness 2015 (VIIRS 기반, 앱 내장 격자) | SQM·Bortle 추정 |
| 지도 타일 | © OpenStreetMap contributors, Esri | 지도 |

관찰 적합도 점수·추천은 위 데이터를 바탕으로 백엔드가 계산한 값이며, 공공기관이 직접 제공하는 점수가 아닙니다.

## 저장소 구조

```
apps/flutter   Flutter 앱 (Android · iOS · Web 공용)
apps/backend   FastAPI 백엔드 (공공데이터·외부 API 연동, 점수 계산)
docs/          기획·디자인 문서, UI 목업
specs/         기능 명세
```

## 로컬 실행

### 준비물

- Flutter SDK (Dart 3.12 이상, 개발·검증은 Flutter 3.47.8)
- Python 3.12 이상 + [uv](https://docs.astral.sh/uv/) (백엔드)
- (선택) [just](https://github.com/casey/just) — 저장소 루트 `justfile`의 실행 레시피

### 1. 백엔드 (실제 데이터를 쓰려면 필요)

```bash
cp apps/backend/.env.example .env     # 저장소 루트에 .env 생성 후 각 API 키 입력
cd apps/backend
uv sync
uv run pytest -q                      # 테스트
cd ../..
just backend-dev                      # .env를 읽어 0.0.0.0:8000에서 실행
```

`.env`에는 공공데이터포털 서비스 키, 기상청 API허브 키, eBird 토큰이 필요합니다(`apps/backend/.env.example` 참고). 키는 저장소에 올리지 마세요.

### 2. 웹앱

```bash
cd apps/flutter
flutter pub get

# 로컬 백엔드에 연결해 실행
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# 백엔드 없이 예시 데이터로 실행
flutter run -d chrome --dart-define=DEMO_FALLBACK=true

# 정적 웹 빌드 (GitHub Pages용 예: --base-href /look-up/)
flutter build web --release --base-href /look-up/ --dart-define=DEMO_FALLBACK=true
```

브라우저에서 백엔드를 호출하려면 백엔드의 CORS 허용 출처에 웹앱 주소가 포함되어야 합니다.

### 3. Android 앱 실행·빌드

```bash
cd apps/flutter
flutter run -d <기기ID> --dart-define=DEMO_FALLBACK=true
flutter build apk --debug --dart-define=DEMO_FALLBACK=true
```

- Android SDK(platform 36, build-tools 36)와 JDK 17이 필요합니다.
- Firebase 설정 파일 `apps/flutter/android/app/google-services.json`은 저장소에 포함하지 않습니다. 직접 빌드하려면 본인의 Firebase 프로젝트에서 받은 파일을 그 위치에 두어야 합니다.
- 릴리스 서명 키(`android/key.properties`)도 저장소에 포함하지 않습니다. 없으면 디버그 빌드를 사용하세요.

### Android 데모 APK 설치

1. `위를봐요_android_demo.apk`를 휴대폰으로 받습니다(Android 7.0 이상).
2. 파일을 눌러 설치하고, "출처를 알 수 없는 앱" 안내가 나오면 설정에서 해당 앱의 설치를 허용합니다.
3. Play 프로텍트 경고가 나오면 [세부정보] → [무시하고 설치]를 선택합니다.
4. 앱 이름은 `lookup`으로 표시됩니다. 실행 후 「로그인 없이 둘러보기」를 누르세요.

데모 APK는 디버그 키로 서명된 테스트용이며 예시 데이터로 동작합니다.
