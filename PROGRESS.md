# PROGRESS — 위를 봐요(Look Up)

> 이 리포의 세션 인수인계 진입점. 새 세션은 여기부터 읽는다.
> 이 리포는 factory 소비 레포다 (본사: `~/dev/pi-agent-expert`, 템플릿: `~/dev/factory-template`).
> 두뇌 규칙은 `CLAUDE.md` / 절차는 `factory/brain.md`.

## 이 앱은 뭔가

**"위를 봐요(Look Up)"** — 2026 관광 데이터 활용 공모전 제안서 기반 앱.
원 제안서: `~/Downloads/2026_관광데이터_공모전_제안서.pdf`.

새(낮·탐조)와 별(밤·천체관측)을 매개로 지역의 낮과 밤을 재발견하는 저탄소 로컬 관광 플랫폼("수직적 여행"). 공모전 핵심 차별성은 기상·천문·조석·빛공해 등 공공 OpenAPI를 융합한 **0~100 적합도 점수 엔진**.

- **스택:** backend = FastAPI(계약 publisher) / flutter = Riverpod(consumer). 풀스택 확정.
- **팀:** `backend`, `flutter` (init.sh로 부트스트랩, `factory/teams/*.yaml`).

### 기획·디자인 문서 (2026-09-08 추가, 커밋 `29569b9`)

- **PRD:** [`docs/PRD-look-up.md`](docs/PRD-look-up.md) — v1.0. 화면 9종·5-레이어 데이터 모델·비즈니스 모델·로드맵. 후속 조각 '적합도 점수 엔진'은 PRD 3장(5-레이어 → 0~100)을 근거로 스펙화.
- **UI 목업:** [`docs/ui-mockups/`](docs/ui-mockups/README.md) — 화면 9종 HTML 스냅샷 + `logo.svg` + 디자인 토큰 요약. **정본은 Figma** (`VIF8Yc0dC2Qq86GOFZkJUA`). Flutter ThemeData 시드는 README의 토큰(secondary `#42e1be`, tertiary `#f5bc7e`, bg `#08122d`)을 정본으로.

### API 키 발급 착수 (2026-09-08, 커밋 `2344011`)

적합도 점수 엔진(후속 조각 3-a)용 OpenAPI 키 확보 시작. 현황·발급처 체크리스트: [`docs/api-keys-status.md`](docs/api-keys-status.md). **키 값은 gitignore된 `.env`에만** 저장(커밋 금지, 개발 노출분은 운영 전 재발급 권장).

- **발급 완료:** data.go.kr 공통 서비스키 1개(두루누비·TourAPI 4.0·관광사진·KASI 천문현상/출몰시각/월령 공용) + OpenWeatherMap(임시).
- **날씨는 임시로 OpenWeatherMap** 사용(`WEATHER_PROVIDER=openweathermap`). 최종은 기상청 단기예보로 교체 예정(`kma`로 스위치). OWM은 visibility 10km 캡이라 "시정 25km+" 판정 불가 — 공모전 가점(국내 공공데이터) 겸 최종 교체 필요.
- **추가 발급 대기:** (data.go.kr 활용신청만) 기상청 단기예보·생태관광정보·관광빅데이터 / (별도 키) 바다누리 해양조석·eBird / (후속 협의) KOBIS·국립생태원.
- **키 불필요:** 빛공해는 VIIRS 위성광 근사, 탄소계수는 정적표 내장.

## MVP 커팅 (2026-09-07)

전체 5기능(실시간 생태 가이드 / 에코 도보 큐레이션 / 디지털 생태 일기 / 낮-밤 패키지 / 그린 마일리지) 중 **외부 API 의존이 가장 낮은 '디지털 생태 일기 CRUD'** 부터.

- `specs/001-ecolog-backend.md` — FastAPI 스캐폴딩(Phase 0) + 관찰 기록 CRUD + 배지 도출, in-memory 저장소. **계약 publisher.** risk: medium. Validation: `just backend-check`.
- `specs/002-ecolog-flutter.md` — Flutter 스캐폴딩 + 목록/작성/배지 3화면, Riverpod, 001 계약(`apps/backend/.team/member.md`) consume. risk: medium. Validation: `just flutter-check`.

**후속 조각 예약** (각 스펙 Notes 참조): 적합도 점수 엔진(실제 OpenAPI 융합), 인증·멀티유저, 에코 도보 큐레이션(두루누비·위치기반관광 API), SQLite 영속화, '수직적 여행' 브랜딩 디자인 패스.

## 지금까지 한 것

- `~/dev/factory-template/init.sh ~/dev/lookup backend flutter` 로 부트스트랩 (커밋 `df732ca`)
- justfile `check` TODO → `backend-check`(uv pytest)·`flutter-check`(flutter analyze+test) + 빈 레인 skip + `check-teams` 배선 (커밋 `a9a439c`). 현재 `just check` = exit 0
- 스펙 001·002 작성, `check-specs` 통과 (커밋 `953374d`)

## MVP 조각 1 (디지털 생태 일기) 완성 (2026-09-07) ✅✅

- **001 backend** PASS, 커밋 `218efc5`. FastAPI CRUD + 배지, pytest 32건. 계약 published: `apps/backend/.team/member.md`.
  - 빌드 #1 검증 FAIL(codex): PATCH `observedAt:null`이 응답 스키마(non-null 필수)와 모순. 사용자 결정 "422 거부" → Amendment 명문화 후 재발사 PASS. required-non-null 3필드(speciesType·speciesName·observedAt)는 PATCH 명시적 null 불가.
- **flutter 스캐폴딩** (A안, 두뇌 선심기) 커밋 `0431c52`.
- **002 flutter** PASS, 커밋 `0f9aa3a`. Riverpod + 3화면(목록·작성폼·배지그리드) + API 클라이언트(HTTP/Fake) + 위젯테스트. flutter test 15건.
  - 빌드 #1 FAIL=claude 세션 한도(용량, 스펙 아님) → 리셋 후 재개. 빌드 #2 품질 FAIL 2건(배지 name 영어→한국어 계약 미러 위반, diary 카드 사진 썸네일 누락) → 스펙 002 Amendment로 못 박고 재발사 PASS.
- `just check` 전체 green: backend pytest 32 + flutter analyze 무경고 + flutter test 15.
- **크로스모델 검증(claude 빌드 ↔ codex 검증)이 실제 결함 3건을 전부 잡음** — 셋 다 `validation:true`(테스트 통과)였으나 verify가 FAIL. 상세 부검: [`docs/verification-postmortem-mvp1.md`](docs/verification-postmortem-mvp1.md).

## 브랜딩 디자인 패스 완성 (2026-09-08) ✅

- **003 flutter** PASS, 커밋 `39e02b5`, attempts=2. 목업(정본 Figma) 토큰 → `lib/theme/app_theme.dart`(딥네이비 다크 ColorScheme + Space Grotesk/Inter/JetBrains Mono google_fonts 3종 매핑) 정본화 후 기존 3화면 리스킨 + 영어→한글 카피. 동작·API 계약 불변(비주얼/카피 전용). `specs/003-lookup-branding-flutter.md`.
- **크로스모델 검증(codex)이 또 실제 결함 2건을 잡음**(validation:true였으나 verify FAIL): (1) JetBrains Mono가 TextTheme에 실제 매핑 안 됨(배지 카운트 무스타일), (2) 에러 상태가 raw 예외(영문) 노출 → 고정 한글 문구로 교체. 스펙 003 Amendments에 기록. MVP1 부검(3건) 패턴과 일관 — 크로스모델 verify의 가치 재확인.
- species 색 매핑: 새(bird)=골드 tertiary(낮) / 별(star)=틸 secondary(밤).

## 다음 세션 시작점 (후속 조각)

**다음 조각 확정: (a) 적합도 점수 엔진** (공모전 핵심 차별성, backend 계약 publisher). 사용자와 2026-09-08 세션에서 003 다음 작업으로 확정. 근거: API 키 발급 진행 중(data.go.kr 공용키 + OWM 임시), 홈/발견 화면의 적합도 카드(목업 01/02)가 이 계약의 소비처. PRD 3장(5-레이어 → 0~100)을 스펙 근거로 `specs/004-suitability-engine-backend.md` 작성 예정. **주의**: OWM은 visibility 10km 캡이라 "시정 25km+" 판정 불가 → 최종 기상청 단기예보 교체 필요(스펙에 provider 스위치 여지 명시).

기타 예약분: (b) 인증·멀티유저, (c) 에코 도보 큐레이션(두루누비·위치기반관광 API), (d) SQLite 영속화. UI 후속: 하단 탭 IA·홈/발견 셸(적합도 엔진 계약 확정 후).

### 미해결 유지보수 (낮은 우선순위)
- **`just factory-sync` 검토** — 로컬 core가 factory-template보다 뒤처졌을 수 있음(팀 이름 해석 등). 다음 세션에서 `--dry-run`으로 드리프트 확인 후 판단.

## 크레딧 감각

- medium 스펙 1개 ≈ claude 2~4콜(리드+멤버) + codex 1~2콜(검증) + agy 1콜(정찰), 5~10분. 발사 전 예상 콜 수 고지.
- 긴 런은 백그라운드로 발사 후 결과 JSON 파싱해 보고.

## 참고 (본사 세션에서 한 작업)

이 준비(부트스트랩·스펙·justfile)는 `pi-agent-expert` 세션에서 두뇌 역할로 수행했다. 관련 메모리는 본사 memory에 있음(`lookup-app-project`, `factory-repo-lineage-and-sync`). 앞으로 lookup 프로덕트 작업은 **이 폴더에서 세션을 열어** 진행한다.
