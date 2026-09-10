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

## 목업 비교 분석 + 기상청 API 허브 채택 (2026-09-08)

- **목업 2종 비판 비교** — `docs/ui-mockups`(Stitch 원본) vs `docs/ui-mockups-2-claude-design`(Claude 디자인). 결론: 세트1은 데이터 신뢰(텔레메트리 밀도)·지도(실제 지도+GPX+핀+바텀시트)가 강점이나 **데스크톱 와이드라 PRD의 390px 모바일 미충족** + 이미지 의존. 세트2는 **390px 모바일 정본**·듀얼모드/적색필터 표현·접근성이 강점이나 **지도 화면이 동심원 다이어그램으로 빈약**.
- **통합 목업 방향(구두 스펙, 미저장)** — 세트2를 폼팩터/디자인 정본으로, 세트1의 ①지도 화면 ②모노스페이스 텔레메트리 ③환경데이터 상세(점진적 공개) ④개인화 카피를 이식. 적색필터 전역 승격·이미지 폴백·상태(로딩/빈/에러) 정의. (사용자가 문서화 원하면 `specs/004-...` 이전 번호 주의 — 004는 적합도 엔진 예약됨)
- **비교 페이지 산출:** [`docs/comparison-set1-vs-set2.html`](docs/comparison-set1-vs-set2.html) — 두 세트를 화면별로 나란히 iframe 크롭한 정적 비교 뷰(홈 낮/밤·지도·기록·배지 5행). 로컬서버 또는 직접 열기.
- **기상청 경로 변경·채택:** data.go.kr 단기예보(공용키) 대신 **기상청 API 허브(`apihub.kma.go.kr`) 동네예보 격자자료** 채택. 자체 인증키 `KMA_APIHUB_KEY`(별도) 발급·`.env` 저장 완료. 엔드포인트 4종 전부 실측 검증 통과(실황 실데이터 확인).
  - 오퍼레이션: `nph-dfs_odam_grd`(실황) / `nph-dfs_vsrt_grd`(초단기예보) / `nph-dfs_shrt_grd`(단기예보) / `nph-dfs_xy_lonlat`(격자↔위경도 양방향).
  - **설계 유의:** ① 격자 API는 **전국 격자 전체 반환** → 위경도→격자(nx,ny) 변환 후 해당 셀만 추출(+캐싱) 필요. ② 좌표변환 API 제공으로 램버트 변환 직접 구현 불필요. ③ **시정(25km+)·대기시상은 여전히 공백** — 별도 근사(위성영상/ASOS) 필요. ④ 통합 코드 부재로 아직 `WEATHER_PROVIDER=openweathermap` 유지, KMA 어댑터 완성 시 `kma`로 스위치.
  - data.go.kr 단기예보 활용신청은 **불필요**로 정리(`docs/api-keys-status.md` 갱신).

## 적합도 점수 엔진 완성 (2026-09-08) ✅ — 공모전 핵심 조각

- **005 backend** 실질 완성. `specs/005-suitability-engine-backend.md`. `GET /api/suitability?lat&lng&mode` → 0~100 융합 점수 + 골든타임 + 텔레메트리 + 레이어별 breakdown. 계약 publish: `apps/backend/.team/member.md` §8.
- **3레이어 실연동 확인(브레인이 실 API 직접 호출)**: 기상 = **기상청 API 허브(KMA) 초단기예보 격자** live, 천체 = **KASI 출몰/월령** live, 빛공해 = VIIRS approx. 조석·생물·수요 = `status:"stub"` 정직 표기. 실패 시 graceful degrade(재정규화+`degraded:true`).
- **빌드 2회 모두 verdict FAIL이었으나 스펙 결함 아님** — 팀(backend-engineer)에 Bash/네트워크 권한이 없어 (a)라이브 캡처·(b)justfile 리시피·(c)실연동 디버깅을 구조적으로 못함. 오프라인 파이프라인은 매번 green(68 passed)이었고, **실 API로만 드러나는 결함**을 브레인이 실연동 검증으로 전부 확정·수정:
  - data.go.kr 서비스키 **이중 인코딩**(unquote/DECODED 키 필요), KASI 파서 추정 전면 오류(오퍼레이션 경로·`_type≠dataType`·필드 `aste`≠`astronomicalTwilightEnd`·공백 패딩·lunph는 solYear/Month/Day).
  - 사용자 지시로 **기상 OWM→기상청(KMA) 전환**. KMA 격자 좌표/인덱싱 파싱 버그(콤마 미제거, "1라인=1행" 오가정 → 실측 flatten `(ny-1)*149+(nx-1)`), 실황(odam)엔 SKY 없음 → 초단기예보(vsrt)로 전환. **시정 카드는 KMA 지표(SKY·REH·WSD·PTY)로 교체**(KMA 격자에 visibility 없음).
- **교훈**: 추정 스키마는 실패한다 → 외부 API는 라이브 캡처 선행. 크로스모델 verify(codex)는 오프라인 결함만, **실연동 결함은 브레인의 `just suitability-live`가 잡는다**. 부검: 스펙 005 Amendments.
- 계약 변경: telemetry `kind` `visibility`→`sky`/`humidity`/`precip`. flutter consumer 배선 시 kind→IconData 매핑 갱신 필요.

## flutter consumer 배선 완성 (2026-09-08) ✅ — 홈 화면 실 API 연동

- **006 flutter** PASS, 커밋 `c5fc4a7`, attempts=2, 크로스모델 verify(codex) 통과. `specs/006-suitability-consumer-flutter.md`. 하드코딩 mock `discoveryProvider`(동기 `Provider`)를 `GET /api/suitability?lat&lng&mode`를 호출하는 `AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>`로 전환. `just flutter-check` green(26 tests, 신규 `suitability_wiring_test` 5케이스 포함).
- **손댄 것**: 신규 `lib/api/suitability_api.dart`(`SuitabilityApi` 추상 + `HttpSuitabilityApi` + `FakeSuitabilityApi`, 001/002 패턴 미러), `lib/models/discovery.dart`(`fromJson` 팩토리 4종 + `TelemetryReading.icon`→`kind`(String) 교체 + `ObsMode.toQueryValue`/`obsModeFromApiValue`), `lib/config.dart`(`defaultObservationLat/Lng` 고정 상수, GPS 전까지 강화 갯벌 37.5921/126.3984), `lib/state/discovery_providers.dart`(`DiscoveryNotifier`가 `obsModeProvider` watch → mode 변경 시 재조회), `lib/screens/home_discovery_screen.dart`(`AsyncValue.when` data/loading/error 3분기 + degraded 배너 + kind→IconData 매핑). `hotspotsProvider`는 무변경(mock 유지).
- **브레인 실배선 검증(실 backend + .env 실키 직접 호출)**: uvicorn 기동 → `GET /api/suitability` day/night 실호출. day score=75·night score=63·degraded=false(KMA+KASI live), 응답 필드명(`score`/`label`/`sqmValue`/`skyClass`/`degraded`/`goldenHours[]`/`telemetry[]{kind,label,value}`)·타입(int/float→num.toDouble/bool)·telemetry kind 5종(`sky`/`humidity`/`wind`/`precip`/`tide`)이 flutter `DiscoveryOverview.fromJson`·kind 매핑과 전부 정합 확인. 계약 소비 배선 완결.
- 교훈: 순수 consumer 조각은 backend 무변경 + flutter 레인 갇힘이라 팀 권한 이슈 없이 깔끔히 PASS(005의 팀 권한 꼬리와 대조).

## GPS 사용자 위치 연동 완성 (2026-09-08) ✅ — 실 위치 기반 적합도

- **007 flutter** PASS(빌드 2회: #1 `bd17e35` 배선, #2 `730ffce` UI 마감 Amendment). `specs/007-gps-location-flutter.md`. 고정 상수 좌표 → 실 GPS 위치 기반 적합도 조회 + 역지오코딩 지명 라벨. `just check` green.
- **손댄 것**: 신규 `lib/services/location_service.dart`(`ObservationLocation` 모델 + `LocationService` 추상 + `GeolocatorLocationService`(모든 실패 경로 폴백 흡수, raise 금지) + `FakeLocationService`; `assemblePlaceName` 순수 함수=중복 제거+최대 2요소), `pubspec.yaml`(`geolocator`/`geocoding` 추가), `ios/Runner/Info.plist`(`NSLocationWhenInUseUsageDescription`), `discovery_providers.dart`(`locationServiceProvider`+`locationProvider` AsyncNotifier, `DiscoveryNotifier`가 `locationProvider.future` 좌표로 조회), `home_discovery_screen.dart`(상단 라벨 동적화, 지명 `Flexible`+`maxLines:1`+`ellipsis`). 신규 `test/location_wiring_test.dart`. 폴백 좌표=기존 강화 상수 재사용.
- **브레인 실검증(iOS 시뮬레이터, `xcrun simctl location booted set` 좌표 주입 + `privacy grant location-always`)**: 서울시청 37.5665/126.9780 주입 → 점수 75→**79**·SQM 18.52→**19.54**·습도 85%→**50%**·풍속 2.0W→**1.0 E**로 좌표 기반 재조회 확인 + 지명 역지오코딩 표시. **빌드 #1은 오프라인 위젯테스트가 못 잡는 UI 마감 결함 2건을 브레인 실검증이 확정**(스펙 007 Amendments): (A) 지명이 목업 짧은 라벨보다 길어 헤더 오버플로우("RIGHT OVERFLOWED BY 51"), (B) 한국 역지오코딩에서 `administrativeArea`==`locality`("서울특별시" 중복) → "서울특별시·서울특별시·태평로1가". 빌드 #2로 (A) Flexible+ellipsis, (B) assemblePlaceName 중복제거+2요소 축약 → 재검증 시 오버플로우 로그 0건·중복 제거 확인.
- **교훈**: 006/005와 동일 — 크로스모델 verify(codex)는 오프라인 결함만, **실기기에서만 드러나는 UI/실배선 결함은 브레인의 시뮬레이터 육안 검증이 잡는다**. GPS/역지오코딩은 실 좌표 주입 없이 위젯테스트만으로는 불충분.
- **알려진 잔여(UX, 낮은 우선순위)**: 상단 지명 칩이 목업 고정폭이라 긴 지명은 "서울…"로 잘림(오버플로우는 없음). 전체 지명 노출 원하면 칩 폭 확장 or 탭→지역 선택 UI 후속 필요.

## 조석(tide) 레이어 실연동 완성 (2026-09-08) ✅ — 낮 골든타임 실데이터화

- **008 backend** PASS, 커밋 `c8c4474`, attempts=2, codex verify 통과. `specs/008-tide-live-backend.md`. tide provider stub→live(KHOA 조석예보 고저조). `just check` green.
- **API**: `GET https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService`(data.go.kr, **기존 `DATA_GO_KR_SERVICE_KEY` 재사용** — 새 키 불필요, KASI와 동일). 파라미터 `obsCode`(필수, 예 DT_0001), `date`류는 무시(항상 오늘). **XML 응답**(json 미지원). item: `obsvtrNm`/`lat`/`lot`/`predcDt`/`predcTdlvVl`(cm)/`extrSe`(**극값 순번 1~4 — 고조/저조 구분 아님! 조위값 대소로 판정**).
- **손댄 것**: `providers/tide.py` live 재작성(최근접 관측소→API→XML 파싱→낮 만조 골든타임/텔레메트리, 예외 흡수 stub 폴백), 신규 `providers/tide_stations.py`(전국 조석관측소 37개 정적표+haversine 최근접), `config.py` `get_tide_config()`(키 unquote 재사용), 실 캡처 XML 픽스처.
- **브레인 실검증(uvicorn end-to-end)**: 강화 갯벌 day → tide `status:live`, 낮 골든타임 "12:56-14:56 · **만조 14:56**"(구 stub "14:00-17:30 / 만조 16:15 (스텁)" 대체). 부산 day → "04:29-06:29 · 만조 06:29", 실 API 직접 대조(06:29=108cm 극값)와 정합. **위치별로 관측소·만조 시각 달라짐 확인.**
- **잔여(로직 튜닝, 낮은 우선순위)**: 낮 만조 선택 기준이 "낮 시간대 첫/특정 고조"라, 부산처럼 정오~오후 고조가 없는 날은 이른 아침(06:29)을 고름 → 그날 최고 고조(저녁 18:49 125cm)와 다름. 탐조 실용성 위해 "주간 관측 가능 시간대 최고 고조" 등으로 튜닝 여지.
- 계약 §8 형태 불변(tide status stub→live만) → flutter(006/007) 재배선 불필요. **적합도 4레이어 중 3레이어(기상 KMA·천체 KASI·조석 KHOA) live + 빛공해 approx** 달성(생물·수요만 향후).

## 토글 캐싱 + 낮/밤 모드 헤더 재설계 (2026-09-09) ✅ — 디자인 리드 도입

- **009 flutter** PASS(`3bea65d`, attempts=1). 낮↔밤 토글 시 매번 재조회+로딩바 뜨던 문제 → `discoveryProvider`를 `AsyncNotifierProvider.family(ObsMode)` + `ref.keepAlive()`로 전환. mode별 캐시 유지, 토글은 즉시 전환(재호출·로딩 없음), 위치 변경 시만 무효화. `suitability_wiring_test`에 "토글 시 mode별 1회만 호출" 캐싱 검증 추가.
- **디자인/UX 리드 신설** `.claude/agents/design-lead.md`(`e71f10b`/별도 커밋). 20년+ 경력 UX 디렉터 페르소나 — **목업 맹종 아닌 UX 원리·HIG/Material 준수 기반 비판적 개입**, 산출물=판단/설계/비평(코드 X, 구현손은 flutter 팀). UI/UX 조각의 앞단(설계)+뒷단(검수)에 개입. **워크플로우 확립: UI 조각은 design-lead 자문 선행 → 스펙화 → 발사 전 design-lead 스펙 검수 → flutter 구현 → 실기기 비평.** 실제로 010 스펙 검수에서 "세그먼트 제거 라인 사실오류(적합도 카드 삭제 위험)"를 발사 전 차단함(검수 가치 입증).
- **010 flutter** PASS(빌드 3회: 골격 `d868d82`(attempts=2, verify가 접근성 테스트 보강 요구) → 브레인 실검증 status bar 겹침 발견 → SafeArea 수정 `e71f10b`(attempts=1)). `specs/010-mode-header-skeleton-flutter.md`. **낮/밤 스위치 재설계 골격**: 세그먼트 pill 폐기 → 상단 **모드 헤더**(해☼낮/달☾밤 토글 + AUTO/MANUAL 배지), `SingleChildScrollView`→`CustomScrollView`+`SliverAppBar(pinned)` **collapsing pinned header**(스크롤 시 얇은 토글 바만 고정), `obsModeProvider`→`{mode, source}` 확장, **로컬 시각 기반 자동 초기판정**(source=auto), 수동 전환 시 영구 유지(source=manual, MANUAL 배지 탭→자동복귀 + 첫 전환 1회 힌트). 인사말/텔레메트리 라벨 본문 이동. `nowProvider`(테스트 결정성). 골격 전환은 150ms crossfade 통일.
- **오너 확정 UX 정책**: 낮/밤은 자주 전환하는 장면전환급 스위치(배경/색 테마 전환은 011 확정 요구). 자동/수동 = 최초 시각 자동, 수동 시 **영구 유지**(자동복귀 없음, 배지 탭이 유일 탈출구).
- **브레인 실검증**: 펼침 상단 status bar 겹침 → SafeArea 수정으로 해결 확인. 접힘(collapse) 상태는 시뮬레이터 자동 스크롤 불가로 육안 확인 보류(같은 SafeArea 처리라 해결 추정).
- **교훈**: 오프라인 위젯테스트는 접근성·status bar 겹침을 못 잡음 → 브레인 시뮬레이터 육안검증 필수(007/010 반복 확인). UX 결정은 목업 준수가 아니라 원리/트레이드오프로 — design-lead가 그 역할.
- **011 flutter** PASS(`4e6efcc`, attempts=2; `just check` green=58 test). `specs/011-scene-transition-flutter.md`(risk medium). 010 골격 위 **비주얼/모션 레이어**. Phase 0: **design-lead 모션 원문 3차 재발사로 수령 성공**(앞선 2회 스톨) — 낮=풀라이트(방향 B) 오너 확정, **브레인 초안 눈부심 항목이 역효과였음을 design-lead가 정정**(easeInOutCubic은 t=0.5 밝기 급상승=밤→낮 화이트 플래시 → **2-스테이지 front-load 밝기 램프** `NightToDayGlareCurve`). Phase 1: `app_theme.dart` **낮/밤 2팔레트**(`nightColorScheme()`=현재값 동결/`dayColorScheme()` 신규/`themeFor(ObsMode)`/`ColorScheme.lerp`, `dark()`/`darkColorScheme()` 완전 제거). Phase 2: `main.dart` `ConsumerStatefulWidget`+AnimationController로 **애니메이션 테마 전환**(자동800/수동560/밤→낮640/reduce≤150·밤→낮≤250, 연타 안전), 순수함수는 `lib/theme/scene_transition.dart` 분리. Phase 3: `mode_header.dart` 해↔달 **morph**(240ms 활성 글리프만 opacity+scale+rotation, 접힘±12°/펼침±18°), `home_discovery_screen.dart` 콘텐츠 stagger(**수동 한정**, +80/40ms·6px slide-up, 제자리 transition=teardown 금지), haptic=수동 개시 selectionClick 1회. **크로스모델 검증 FAIL 3건 잡음**(hotspot 디밍/AnimatedSwitcher 유실, 펼침 morph scale 오적용, 테스트 무변경 과장 표기) → 수정 후 재green.
  - **⚠️ 병렬 발사 사고(교훈)**: 이전 세션 잔여 build가 이미 백그라운드로 돌던 중 브레인이 재발사 → 같은 `apps/flutter` 도메인 2 run 병렬(규칙 4 충돌 위험). 결과는 PASS 수렴·코드 정상이나 **커밋 2개**(`4e6efcc`=구현, `e763928`=lead.md expertise 1줄). **교훈: build 발사 전 `just runs`/실행 프로세스 확인 필수.**
  - **🟡 브레인 시뮬레이터 육안검증 부분 완료(2026-09-09)**: iPhone 17 Pro 시뮬레이터 실행 → **낮(라이트) 팔레트 실렌더 확인**(이 조각 최대 리스크 = 목업에도 없던 신규 라이트 테마가 실제로 뜸: 밝은 회색/화이트 배경·다크 텍스트·틸/골드 accent, 모드 헤더 해=낮 활성 fill+굵기/달=밤/AUTO 배지 정상, 오후 시각 자동판정 source=auto). **밤 토글·전환 모션·밤→낮 눈부심·morph·haptic·reduce-motion은 미검증** — 이 머신에 UI 탭 수단 전무(idb·cliclick 미설치, System Events 자동화 미인가)라 화면 탭 구동 불가 + 위치 권한 다이얼로그가 반복 출현(simctl privacy grant/revoke가 in-flight 프롬프트를 못 닫음). **밤 팔레트는 현재값 동결(003~010에서 이미 검증)이고 전환 타이밍·reduce-motion·연타는 scene_transition_test 6건 green이라 회귀 리스크 낮음**. 잔여=밤→낮 눈부심 완화 "체감"만 오너/실기기 확인 필요.

## 트레일·노포 backend 카탈로그 실연동 완성 (2026-09-10) ✅ — 트레일 탭 데이터 기반

- **012 backend** PASS(`4507086`, 3차 재발사 attempts=1, codex verify 통과). `specs/012-trails-heritage-backend.md`(risk high). 트레일·노포 탭이 물 신규 계약 `GET /api/trails?lat&lng`. `just check` green(95 passed, 7 skipped).
- **design-lead IA 자문(2회) 선행**: 트레일·노포 = "선(하루 동선/코스)" 탭(관찰 지도="점"). 오너가 붙여준 **지도 중심 목업은 폐기**(관찰지도 90% 중복=IA 붕괴), 레포 04 리스트/리포트 골격 기준·게이미피케이션 제거. 랜딩=코스 카탈로그→상세 push, 노포=코스 종점 waypoint. **스펙 검수 GO 사인오프**(비용 편차=featured만 풀 적합도/리스트는 SQM 수용) + flutter 후속 UX 요건 4개(측정태그 vs 점수게이지 분리, featured 정렬근거 라벨 등)를 스펙에 상속 기록.
- **오너 결정**: 데이터=실데이터부터(backend 먼저) / 근처=sigun 권역 매칭(courseList에 위경도 필터 없음) / 노포=근처 음식점 리스트만(영업시간 로직 후속) / Figma 불필요.
- **브레인 라이브 캡처 그라운드 트루스(008 교훈, 스펙 임베드)**: 두루누비 `B551011/Durunubi/courseList`(기존 data.go.kr 키 재사용, brdDiv=DNWW, crsIdx/crsKorNm/sigun/crsDstnc km/crsTotlRqrmHour 분/crsLevel/gpxpath), **gpxpath GPX 파일 첫/끝 trackpoint=시작/종점 좌표**(전국 DNWW 142코스, 시군 매칭 최대 12·강화 2), TourAPI `KorService2/locationBasedList2` contentTypeId=39(title/addr1/dist/mapx/mapy). 픽스처 3종 실캡처 임베드(멤버 네트워크 없음 대비).
- **손댄 것**: 신규 `app/trails/`(models·durunubi·tourapi·service), `routers/trails.py`+main 등록, `config.get_trails_config()`, `.env.example`(DURUNUBI/TOURAPI base_url), `.team/member.md` 신규 계약 절, tests(파서/서비스/엔드포인트/live 스모크). 랭킹=종점 SQM 내림차순+tie-break(거리→crsIdx), `CANDIDATE_LIMIT=15`(GPX fetch 상한), featured 1개만 풀 낮/밤 적합도(SuitabilityService 재사용).
- **⚠️ 3발사 이력(교훈)**: 1차 FAIL=Phase 3 멤버 Edit 권한거부(requires-approval) 반복으로 미착수(환경 문제). 2차 FAIL=**codex verify 실결함 1건**(GPX가 top-K slice 전에 매칭 전부 fetch → 스펙 "GPX top-K 제한" 위반). 브레인 판정=**스펙 자기모순**(종점 SQM 랭킹은 GPX 선행 불가피). 규칙5대로 오너 에스컬레이트 → 스펙 정정+`CANDIDATE_LIMIT` 상한 추가 → 3차 PASS. **브레인 end-to-end 실검증(uvicorn, 강화 37.5921/126.3984)**: region=인천 강화군, 2코스, featured=서해랑길 101(SQM 20.15·day67/night64 live·노포3 강화어부네꽃게탕 등), 비-featured=DMZ평화의길 1(SQM16.0·null) — 실데이터·featured-only·tie-break 정상.
- **잔여(후속 flutter consumer 조각이 상속)**: design-lead UX 요건 4개(nightSky 측정태그 vs suitability 점수게이지 분리·status 가시화, featured 정렬근거 라벨 "밤하늘 가장 어두운", featured만 점수인 게 열등해 보이지 않게, SQM 동일소스 단일진실). 기능 후속: 코스별 풀 적합도(캐싱 선행), 노포 영업시간, 좌표 근접 랭킹, 조석 골든타임 waypoint, GPX 폴리라인 썸네일.

## 트레일·노포 flutter consumer 완성 (2026-09-10) ✅ — 트레일 탭 실화면

- **013 flutter** 구현 완료·`just check` green(**66 tests** = 기존 58 + 트레일 8, analyze 무경고, 홈 004~011 회귀 없음). 커밋 `b1de369`. `specs/013-trails-heritage-flutter.md`(risk medium). `PlaceholderScreen('트레일·노포')` → 카탈로그 랜딩 + featured 리치 카드 + 코스 상세(노포 waypoint) 실화면.
- **design-lead 자문+검수 선행**(워크플로우 준수): 화면 설계 자문 → 스펙화 → 발사 전 스펙 검수(조건부 GO, P1 4건+P2 2건+스코프 좁히기 반영) → 발사. 핵심 규율: **nightSky(측정 태그 톤·게이지 금지·SQM/Bortle/skyClass/approx) ↔ suitability(원형 게이지 톤) 종 분리**, **featured=발췌/리스트=전체 비열등 위계**(공유 서브위젯 구조로 강제), 정렬근거 캡션 단일진실("밤하늘이 가장 어두운 순서예요"), 낮/밤 **accent-only 강조(위치 고정 낮=좌/밤=우, 현재 모드만 glow+bold)**, live→'실시간' 태그, 대비 4.5:1 폴백(tertiary<4.5:1→onSurface).
- **손댄 것**: 신규 `models/trails.dart`(nullable suitability 안전 파싱), `api/trails_api.dart`(abstract/Http/Fake), `screens/{trails_catalog,course_detail}_screen.dart`, `widgets/{night_sky_tag,course_card,heritage_eats_list}.dart`, `utils/trail_format.dart`, `test/trails_wiring_test.dart`(8케이스). 수정 `app_shell.dart`(index2 교체)/`discovery_providers.dart`(trailsProvider 위치 watch)/`score_gauge.dart`(progressColor 파라미터).
- **⚠️ 3발사 이력(교훈=파이프라인 false-negative)**: 1·2차 FAIL=**lead claude 세션이 "API Error: Connection closed mid-response"로 조기 사망**(스폰은 됨, `lead.ok:false`). 1차에 코드 대부분 디스크 반영·`just check` green이었으나 테스트/검증 미완. 오너 승인 하 3차 재발사 → lead 완주(`lead.ok:true`), 잔여 완성(테스트 8 + live 태그 + Phase 5) + **codex 크로스검증 4건 수정**(Bortle 렌더/featured 배지 문구 통일/메타 카드 레이아웃/테스트 border assert). **그러나 verdict는 여전히 FAIL** — codex 4건 수정 후 verify2 재검증 미기록으로 verdict가 FAIL로 굳은 **false-negative**. **브레인이 직접 `just check`(green 66) + 4건 수정 코드 리딩으로 실질 PASS 확정 후 커밋.** 교훈: 파이프라인 verdict를 맹신 말고 `lead.ok`/`validation`/`just check`/실코드로 교차 확인(011 계승, 이번은 API 드롭發 false-FAIL 신규 유형).
- **✅ 브레인 시뮬레이터 육안검증 완료 + 오버플로우 버그 발견·수정**: iPhone 17 Pro에 backend(uvicorn, 강화 실데이터)+flutter run으로 실렌더 확인. **탭 수단 없어**(idb·cliclick 미설치) 트레일 탭 도달은 `_selectedIndex` 임시 2 변경→스크린샷→revert로 우회 검증. **카탈로그 실렌더 확인**: region "인천 강화군"·정렬근거 캡션·featured 서해랑길101(듀얼 게이지 67금/66청+낮 glow·실시간 태그·노포 프리뷰)·nightSky 측정태그 vs 게이지 시각 분리·DMZ 리스트 카드(게이지 없음)·홈 회귀 없음 전부 육안 확인. **⚠️ 오버플로우 버그 1건 발견**: featured nightSky 태그가 긴 skyClass("양호한 다크스카이")에서 우측 36px 넘침 — **오프라인 위젯테스트가 못 잡음(66 tests가 버그 있는 채로 green)**, 시뮬레이터 육안만이 잡음(007/010/011 교훈 재확인). **수정**: `night_sky_tag.dart` `Row(min)`→`Wrap`(긴 skyClass 다음 줄 흐름, ellipsis 없이 전 필드 가시), 커밋 `d8441fe`, 재검증으로 해소 확인. 상세 push·낮밤 토글 accent 이동은 오너 직접 탭 확인 권장(회귀 리스크 낮음).
- **잔여(후속 부채)**: GPX 폴리라인 지도 썸네일, 노포 상세 push·지도 핀, 코스별 풀 적합도(featured 외), 노포 영업시간, 좌표 근접 랭킹, 모드 전환 stagger(카탈로그 리스트 구조), 정렬/필터 UI, 즐겨찾기, 위치 칩 tap→권역 재선택.

## 관찰 지도 = 앱 핵심으로 확정 + 계획 수립 (2026-09-10) — 다음 큰 조각

- **오너 재정의**: 앱의 핵심 = "유저 현재 위치·설정 지역 주변에서 무엇을(새·별) 관찰할 수 있나"를 **지도로** 보여주는 것. Figma 정본 `node 1-2104`("생태 & 다크스카이 관찰 지도", `https://www.figma.com/design/VIF8Yc0dC2Qq86GOFZkJUA/lookup?node-id=1-2104`). 이건 **관찰 지도 탭(index1, 현재 빈 PlaceholderScreen)**의 정본이며, "목업 지도가 사라졌다"의 답 = 애초에 이 탭 몫이었고 미구현 상태였음(트레일 탭과 별개, design-lead "점 vs 선" IA 일치).
- **오너 결정 3개**: (1) 조류 데이터=**eBird API**(위경도 최근관측 `/data/obs/geo/recent`, 무료 토큰 필요 — ⚠️ `.env`에 아직 없음, 오너가 ebird.org/api/keygen에서 발급해야 backend 라이브 연동 가능), (2) 지도=**flutter_map + OSM 다크타일**(무료·키 불필요), (3) 순서=**design-lead 자문(완료) → backend 관찰레이어 계약 → flutter 지도 consumer**.
- **design-lead 자문 결론(2026-09-10)**: (A) map-first + **3-스냅 드래그 바텀시트**(Figma의 "지도 520px 고정+아래 시트 페이지 스크롤"은 **틀림** → 지도 full-bleed, 시트는 오버레이 peek12%/half45%/full90%). (B) 레이어=점(조류/별/노포 핀)·선(트레일)·면(히트맵/Bortle)을 섞지 말 것 → MVP는 **점 핀 3종 + 탭→시트만**, 면(히트맵·Bortle색면)·3D·나침반·오프라인캐시·다중지역·지도텔레메트리·낮모드 라이트타일 전부 **후속**. (C) **측정값(핀=SQM/최근관측) vs 적합도(시트 상세에서만 ScoreGauge+status)** 013 종분리 계승 — 핀에 적합도 점수 박지 말 것. (D) **eBird 정직표기**: "실시간 출현" 금지 → "최근 관측·N일 전"+핀 신선도 색(≤24h 선명/1~7일 반투명/>7일 흐림), 상태=`community`/`approx`(절대 `live` 아님). (E) 지역 드롭다운=데이터 쿼리 bbox / GPS=카메라 이동만.
- **탭 IA 오너 결정**: 트레일 탭 **존치**(점≠선, 흡수 반대 — 대신 지도↔트레일 딥링크 후속). 탭 순서 **현행 유지**(지도 index1 그대로, 재편 안 함).
- **backend 계약 최소 요건(design-lead→브레인)**: 스팟 목록 by 지역 bbox(id/종류 bird|star|heritage/좌표/이름/측정값), 조류=eBird 프록시(종명·개체수·`obsDt` 필수·상태 community/approx), 스팟 상세 적합도=홈/트레일 동일 suitability 스키마(시트에서만), 측정값/적합도 응답 필드 분리(013 계승), degraded 플래그.
- **다음 액션**: `specs/014-observation-map-backend.md`(관찰레이어 계약, 팀=backend) 작성 → 발사. **⚠️ 선결: eBird API 토큰** — 없으면 브레인 라이브캡처 그라운드트루스(008/012 패턴) 불가, 픽스처만으로 진행하거나 토큰 확보 후 진행.

## 낮-밤 패키지 탭(index3) 정체 정의 (2026-09-10) — 기록만, 구현은 후속

- **정의**: "**1박 2일 낮→밤 체류형 관광 상품(예약 커머스) 탭**". PRD §Screen 4·비즈니스 모델 + 목업 `docs/ui-mockups/05-day-night-packages.html` 근거. 지역 소멸 방지 체류형 큐레이션 = 낮 탐조(생태해설사)+노포 식음 바우처+밤 천체관측(적색 손전등·망원경)+교통(KTX/전기셔틀)+장비 대여+**예약·1인 가격**. 예: 강원 인제 DMZ 두루미&곰배령 128,000원, 전남 신안 흑산도 갯벌&은하수 145,000원.
- **성격**: 홈(오늘 판단)·트레일(코스 랭킹)·지도(공간 탐색)와 **겹치지 않는 유일한 커머스 레이어**(예약·결제·상품). design-lead "중복 위험"은 표면(낮/밤)만 본 것 — 실제 태스크(1박2일 상품 예약)는 고유.
- **오너 결정**: 정체는 명확 → 탭 존치(빈 목적 없는 탭 아님). **단 지금 구현 안 함** — 실상품·제휴·결제/예약 백엔드 필요한 비즈니스 조각이라 실콘텐츠 준비 후 후속. 지금은 관찰 지도(핵심)가 우선.

## 관찰 지도 backend 계약 완성 (2026-09-10) ✅ — GET /api/observation-map 라이브 검증

- **014 backend** 구현·`backend-check` green(111 passed/8 skipped). 커밋 `6215339`. `specs/014-observation-map-backend.md`(risk high). 신규 `GET /api/observation-map?lat&lng` = 조류(eBird)+별(SQM)+노포 스팟 목록.
- **eBird 라이브 연동**: 토큰 `.env` 저장(gitignore). `sppLocale=ko` 한국어 종명. `/data/obs/geo/recent` → locId(관측지) 집계로 조류 스팟. **정직 표기**: status=`community`(절대 live 아님)+`obsDt` 필수.
- **재사용(신규 최소화)**: 별 SQM=`LightPollutionProvider`, 노포=`trails/tourapi`, 스팟 적합도=기존 `GET /api/suitability`(신규 없음). 측정값/적합도 응답 필드 분리(013 계승, `score` 필드 없음).
- **브레인 uvicorn end-to-end 라이브 검증(강화 37.5921/126.3984)**: HTTP 200, region 인천 강화군, degraded=false, **18 스팟(조류 14 + 별 1 + 노포 3)**. 조류 실데이터=영종도 송산만 갯벌 36종·알락꼬리마도요 280, 여차리 갯벌/물꽝, 초지리 들판 황로 14 등. 별=강화 천문인마을 SQM 16.81 Bortle 8 approx. 노포=꽃게와낙지 1363m 등. `score` 필드 없음 확인.
- **⚠️ 파이프라인 verdict=FAIL = false-negative**(3번째 사례): `lead.ok:true`·`validation:true`·codex **14 PASS + 1 FAIL(브레인 라이브검증 미수행)** — 유일 FAIL이 스펙 설계상 브레인 몫이라 lead가 규칙5로 에스컬레이션, 브레인이 검증 완료로 해소. verify2 미기록으로 verdict FAIL 굳음. [[factory-verdict-false-negative]] 재확인.

## 관찰 지도 flutter consumer 완성 (2026-09-10) ✅ — 커밋 d7fdc16 (실질 PASS, 잔여=오너 시뮬 육안)

- **015 flutter** 구현·`just check` green(flutter test 75/75, analyze 무경고). 커밋 `d7fdc16`. `specs/015-observation-map-flutter.md`(risk high). app_shell index1 placeholder→`ObservationMapScreen`.
- **신규 의존성**: `flutter_map 8.3.2`+`latlong2 0.10.1`, CARTO dark_matter 무키 다크타일. **낮모드 저알파 오버레이**(design-lead P1-1: full-bleed 다크지도가 앱 낮/밤 장면전환 정체성과 충돌 → `colorScheme.surface` 0.12~0.18 오버레이로 정합, positron 스왑은 후속). 발사 전 justfile `flutter-check`에 `flutter pub get` 선행 추가(유지보수)+pub 캐시 워밍으로 신규패키지 취득 de-risk.
- **핵심 규율 계승(013)**: 측정값↔적합도 종분리(핀/리스트=측정값, 시트 상세에서만 기존 `/api/suitability` 2차 호출+구분선 분리), eBird 정직표기(한국어 "커뮤니티 관측" 배지+"N일 전" 날짜파싱 폴백, "실시간" 금지). 핀 3종 **색+형태 이중 인코딩**(P1-2, WCAG 1.4.1, `flutter_dash` 금지), **위치 권한거부 폴백**(P1-3, 강화 기본좌표+배너+재시도), 3-스냅 시트(0.16/0.45/0.9), 레이어칩 필터, 상태 4종.
- **design-lead 발사 전 검수=조건부 GO**(P1 3+P2 5 전부 반영). [[lookup-design-lead-workflow]] 관문 준수.
- **⚠️ 파이프라인 verdict=FAIL = false-negative(4번째)**: codex 검증 **23항목 중 22 PASS**(nullable 파싱·카메라 fit·측정/적합도 구분선·정직문구·상태·위치폴백·오버플로우·접근성 전부 PASS), 유일 FAIL은 "`_build*` 코드베이스 전체 0건" 체크박스 문구의 **스코프 오독**(신규 6파일 0건 확인, 지적된 `mode_header`/`course_card`/`trails_catalog`는 기존 파일=회귀금지로 무변경). 브레인 grep+`just check` 재실행으로 실질 PASS 확정. **크로스모델 가치 발현**: lead가 런 중 실 결함 2건(단일스팟 zero-area bounds 크래시·테스트 State 재사용) 자체 수정. [[factory-verdict-false-negative]]/[[factory-crossmodel-verify-value]].
- **잔여**: 오너 시뮬/실기기 육안검증(다크타일 렌더·핀 위치·3-스냅 드래그·측정vs적합도 시각분리·오버플로우 — 이 머신 idb/cliclick 없어 지도 탭까지 탭 도달 불가, 013 오버플로우 선례상 필수). 앱은 홈 index0 시작 → 관찰지도 index1은 탭 필요.

## 다음 세션 시작점 (후속 조각)

**다음 = 오너 육안검증 후 후속 조각 선택.** 관찰 지도(015) 실질 완료 → 후속 UX 부채(지도 탭 모드토글 진입점·positron 낮타일 스왑·클러스터링) 또는 아래 B/C/D 중 오너 선택.

**완료분**: 013 트레일 flutter(`b1de369`/`d8441fe`), 014 관찰지도 backend(`6215339`), **015 관찰지도 flutter(`d7fdc16`, green+실질PASS, 잔여=오너 육안)**. **낮-밤 패키지 탭**=1박2일 예약 커머스로 정의만 기록(구현 후속).

~~**012 트레일 backend PASS** → 다음=flutter consumer 조각~~ (013으로 완료).

**그 외 후보 — B/C/D 중 오너 선택.**

**후보 B — 핫스팟 랭킹(backend→flutter)**: `hotspotsProvider`(현재 mock)를 물릴 backend 조각. TourAPI(위치기반관광) 장소 레이어 + 적합도 랭킹 엔드포인트(예: `GET /api/hotspots?lat&lng&mode`) 신설 → publish 후 flutter 배선. 팀=`backend`(publisher) → `flutter`(consumer) 순차. GPS(007) 완성으로 실 위치 기반 핫스팟이 자연스러운 다음 수순.

**후보 C — 레이어 breakdown UI**: 계약 `layers[]`(key/weight/subScore/status)를 홈 또는 상세에 시각화(레이어별 기여도·live/approx/stub 배지). 006에서 파싱은 안 하고 통과 — 필요 시 모델에 `layers` 추가부터. 팀=`flutter`.

**후보 D — 위치 UX 마감**: 지명 칩 탭 → 지역 수동 선택/검색, 위치 새로고침 버튼, 긴 지명 전체 표시. 007 잔여 UX. 팀=`flutter`.

**(backend 심화 후속)**: 낮 만조 선택 로직 튜닝(008 잔여), 성능(현재 KMA 격자 5요청×340KB 다운로드 → 배치/캐싱 최적화 + 조석 관측소 조회 캐싱), OWM 잔재 정리(`OPENWEATHERMAP_*` env·문서). ~~KHOA 조석 실연동~~ → 008에서 완료.

기타 예약분: (b) 인증·멀티유저, (c) 에코 도보 큐레이션(두루누비·위치기반관광 API), (d) SQLite 영속화.

### 미해결 유지보수 (낮은 우선순위)
- **`just factory-sync` 검토** — 로컬 core가 factory-template보다 뒤처졌을 수 있음(팀 이름 해석 등). 다음 세션에서 `--dry-run`으로 드리프트 확인 후 판단.

## 크레딧 감각

- medium 스펙 1개 ≈ claude 2~4콜(리드+멤버) + codex 1~2콜(검증) + agy 1콜(정찰), 5~10분. 발사 전 예상 콜 수 고지.
- 긴 런은 백그라운드로 발사 후 결과 JSON 파싱해 보고.

## 참고 (본사 세션에서 한 작업)

이 준비(부트스트랩·스펙·justfile)는 `pi-agent-expert` 세션에서 두뇌 역할로 수행했다. 관련 메모리는 본사 memory에 있음(`lookup-app-project`, `factory-repo-lineage-and-sync`). 앞으로 lookup 프로덕트 작업은 **이 폴더에서 세션을 열어** 진행한다.
