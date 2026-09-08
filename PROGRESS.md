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

## 다음 세션 시작점 (후속 조각)

**후보 A(유력) — 011 낮/밤 장면 전환 연출(flutter)**: 010 골격 위에 비주얼/모션. 해/달 **morph 토글** + 낮/밤 전환 시 **배경 crossfade(600ms easeInOutCubic)·accent 색 lerp·콘텐츠 stagger·haptic**, 자동 전환은 조용히(800ms)·수동은 강하게, `reduce-motion` 250ms 폴백. design-lead 자문 원문(장면 전환 연출 스펙)이 그라운드. 오너 "최종앱 필수" 확정 요구. **발사 전 design-lead 검수 워크플로우 적용.**

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
