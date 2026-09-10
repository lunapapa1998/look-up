# 트레일·노포 flutter consumer (코스 카탈로그 리스트 + featured 리치 카드 + 코스 상세 노포 waypoint)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-10
- modified: 2026-09-10 <brain/orchestrator>
- modified: 2026-09-10 <brain/orchestrator> — design-lead 스펙 검수 조건부 GO 반영(P1 4건+P2 2건+스코프 좁히기). Phase 0 통과, 발사 준비 완료.
- refs: `specs/012-trails-heritage-backend.md`(계약 publisher·§14/§221 UX 요건), `apps/backend/.team/member.md` §20(`GET /api/trails` 계약 publish), `apps/flutter/lib/api/suitability_api.dart`(API 클라이언트 abstract/Http/Fake 관례), `apps/flutter/lib/state/discovery_providers.dart`(`locationProvider`·`AsyncNotifierProvider.family` 관례), `apps/flutter/lib/widgets/score_gauge.dart`(점수 게이지), `apps/flutter/lib/screens/home_discovery_screen.dart`(카드/텔레메트리/degraded 배너 톤), `apps/flutter/lib/theme/app_theme.dart`(낮/밤 2팔레트 `themeFor(ObsMode)`), `apps/flutter/lib/screens/app_shell.dart`(탭 index 2 placeholder), design-lead 화면 설계 자문(2026-09-10, 아래 §design-lead 설계 요지)
- risk: medium - 순수 flutter consumer 조각. 신규 화면 2개(카탈로그 랜딩 + 코스 상세) + 공통 위젯 + 모델/API/프로바이더 배선. backend·계약 무변경(012가 이미 라이브 검증한 `GET /api/trails`를 소비). 홈(004~011) 회귀 금지.
- modified: 2026-09-10, lead: sonnet — 재발사분 잔여 완성(Amendments 참조): `test/trails_wiring_test.dart` 신규(8 케이스) + `CourseSuitability.status=='live'` 시각 태그 추가(§E approx/live 병기 갭 보완) + Phase 5 전체 체크. `just check` green(66 tests, analyze 무경고).
- modified: 2026-09-10, lead: sonnet — 크로스모델(codex) 검증 FAIL 4건 수술적 수정(Amendments 참조). `just check` green(66 tests, analyze 무경고).

## Purpose

오너가 원한 "트레일·노포 탭"의 눈에 보이는 부분을 완성한다 — 012 backend가 라이브 검증한 `GET /api/trails` 계약을 소비해, 현재 빈 `PlaceholderScreen('트레일·노포')`를 **코스 카탈로그 리스트 + featured 리치 카드 + 코스 상세(노포 waypoint)** 실화면으로 교체한다.

## Problem

1. 트레일·노포 탭(`app_shell.dart:23`)이 `PlaceholderScreen(icon: Icons.hiking)` 빈 껍데기 상태다 — backend 계약은 준비됐는데 소비하는 화면이 없다.
2. flutter 앱에 트레일 도메인 모델·API 클라이언트·프로바이더가 전무하다(홈의 suitability 계열만 존재).

## Solution

(1) 012 계약 기준으로 트레일 도메인 모델(`TrailsResponse`/`TrailCourse`/`NightSky`/`HeritageEat`/`CourseSuitability`) + `TrailsApi`(abstract/Http/Fake) + `trailsProvider`(위치 watch)를 배선하고, (2) design-lead 설계대로 **카탈로그 랜딩 화면**(region 헤더 + featured 리치 카드 + "이 권역의 다른 코스" 리스트 + 상태 4종)과 **코스 상세 화면**(메타·종점 밤하늘·featured 듀얼 게이지·종점 노포 top3)을 신규 구현해 placeholder를 교체한다. 핵심 시각 규율은 **nightSky(측정 태그 톤, 게이지 금지) ↔ suitability(원형 게이지 톤)의 종(種) 분리**와 **featured=발췌/리스트=전체의 비열등 위계**다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/app_shell.dart` - `_tabs` index 2의 `PlaceholderScreen(icon: Icons.hiking, title: '트레일·노포')`를 신규 `TrailsCatalogScreen()`으로 교체. 나머지 탭·NavigationBar·index 배선 무변경.
- `apps/flutter/lib/widgets/score_gauge.dart` - **`progressColor` 선택 파라미터 추가**(현재 `colorScheme.secondary` 하드코딩). 낮 적합도=`tertiary`/밤 적합도=`secondary`로 게이지 arc 색을 구분해야 함(design-lead C-4). 기본값은 현행 유지(홈 회귀 없음). 중앙 숫자 텍스트 색도 progressColor 연동 검토(색맹 대비 위해 숫자 텍스트는 필수 유지).
- `apps/flutter/lib/state/discovery_providers.dart` - 여기에 `trailsApiProvider`/`trailsProvider`를 추가하거나(홈 프로바이더와 동거) 신규 `trails_providers.dart`로 분리(빌더 판단). `locationProvider`(기존)를 watch해 lat/lng 획득 — 홈 `DiscoveryNotifier`와 동일 패턴. `obsModeProvider`(기존)를 watch해 낮/밤 강조 축 결정. 009 family 캐싱·홈 배선 회귀 금지.

### New Files

- `apps/flutter/lib/models/trails.dart` - 012 §14 계약 기준 도메인 모델(plain 클래스 + `fromJson` 팩토리, `models/discovery.dart` 관례 그대로): `Coordinate(lat,lng)`, `NightSky(sqmValue:double, bortleClass:int, skyClass:String, status:String)`, `HeritageEat(name, addr, distanceM:int, lat, lng, contentId)`, `CourseSuitability(score:int, label, status)`, `TrailCourse(crsIdx, name, sigun, distanceKm:double, durationMin:int, level:int, cycle, gpxUrl, start:Coordinate, end:Coordinate, nightSky:NightSky, heritageEats:List<HeritageEat>, daySuitability:CourseSuitability?, nightSuitability:CourseSuitability?)`, `TrailsResponse(region, degraded:bool, courses:List<TrailCourse>)`. `daySuitability`/`nightSuitability`는 **nullable**(featured만 non-null — null 안전 파싱 필수).
- `apps/flutter/lib/api/trails_api.dart` - `suitability_api.dart` 관례 복제: `TrailsApiException`(재사용 또는 공용화 판단), `abstract class TrailsApi { Future<TrailsResponse> fetchTrails({required double lat, required double lng}); }`, `HttpTrailsApi`(`GET {baseUrl}/api/trails?lat&lng`, `_checkStatus` 200, `TrailsResponse.fromJson`), `FakeTrailsApi`(테스트용 결정적 데이터 — featured 1 + 비-featured 2, degraded 토글, shouldThrow 토글, onFetch 콜백). mode 쿼리 없음(계약은 lat/lng만).
- `apps/flutter/lib/screens/trails_catalog_screen.dart` - 랜딩(§A). `ConsumerWidget`, `trailsProvider` watch → `AsyncValue.when(loading/error/data)`. data 내부에서 degraded·empty 분기. 단일 `CustomScrollView`/`ListView`.
- `apps/flutter/lib/screens/course_detail_screen.dart` - 코스 상세(§B). `TrailCourse`를 생성자로 받는 화면(추가 fetch 없음 — 랜딩이 이미 가진 객체를 push). `Scaffold`+`AppBar(코스명)`.
- `apps/flutter/lib/widgets/night_sky_tag.dart` - nightSky **측정 태그 톤** 공용 위젯(featured/리스트/상세 공통, §C). SQM·Bortle·skyClass·approx 태그를 칩/모노스페이스로. **게이지·프로그레스·0~100 스케일 암시 절대 금지.** tertiary 계열. 상세용 대형 변형(size 파라미터 등)도 이 위젯이 커버 or 별도 분기.
- `apps/flutter/lib/widgets/course_card.dart` - featured/리스트 공통 카드. `CourseCard(course, featured: bool, onTap)`. **구조 강제(design-lead P1-1)**: featured/리스트는 **같은 위젯 트리를 공유**하고 `featured` 플래그로 **추가 슬롯만 append**한다 — name/meta/nightSky를 그리는 서브위젯(예 `_CourseCardCore`)을 두 경로가 공유하고, featured일 때만 그 아래에 테두리(1px secondary)+듀얼 게이지+노포 프리뷰를 덧붙인다. **리스트 전용 축소 렌더 경로를 별도로 만들지 말 것**(타이포/배경 동등성이 분기 남발로 깨지는 것을 원천 차단). 배경색은 양쪽 동일(surfaceContainer) — 위계는 테두리·추가 슬롯으로만.
- `apps/flutter/lib/widgets/heritage_eats_list.dart` - (상세용) 종점 노포 top3 read-only 리스트(name/distanceM 포맷/addr ellipsis). tap 불가.
- `apps/flutter/test/trails_wiring_test.dart` - `FakeTrailsApi` 주입 위젯테스트: (1) featured 카드가 듀얼 게이지·노포 프리뷰·테두리를 렌더, (2) 비-featured 리스트 카드는 게이지 없음(null 안전)·nightSky 태그는 있음, (3) degraded=true→`errorContainer` 배너+다시 시도, (4) courses 0 & degraded=false→중립 empty 상태이며 **`errorContainer` 토큰이 쓰이지 않았음을 negative assert**(색 오용을 오프라인에서도 잡음), (5) loading→진행표시, (6) error(throw)→다시 시도 버튼, (7) 카드 tap→상세 push(노포 top3·종점 밤하늘 렌더, featured면 듀얼 게이지·비-featured면 "수록 기준" 안내), (8) nightSky 수치가 리스트/featured/상세에서 동일 값(단일 진실). (오프라인 한계 — 색감/모드 강조/stagger 체감은 브레인 시뮬레이터 육안.)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 0: 발사 전 design-lead 스펙 검수 (브레인 선행 — flutter 발사 금지 게이트)

design-lead 화면 설계 자문은 수령 완료(§design-lead 설계 요지). 이 스펙이 자문을 정확히 옮겼는지 **발사 전 design-lead 스펙 검수 1회**(memory `lookup-design-lead-workflow`)를 거친 뒤 Phase 1 착수. 검수에서 잡힌 사항은 스펙에 반영·기록.

- [x] design-lead 스펙 검수 → **조건부 GO**(2026-09-10). P1 4건(featured 비열등 공유 서브위젯 구조·empty/degraded/error 색 토큰 못박기+negative assert·NightSkyTag 대비 4.5:1 하한+폴백·정렬근거 캡션 시간부사 제거) + P2 2건(단일 탭 타깃·비-featured 게이지 섹션 미렌더) + 스코프 좁히기(모드 stagger 미적용) **전부 스펙에 반영 완료** → GO.

**Phase validation**: design-lead 검수 통과(조건부 GO, P1/P2 반영 완료). ✅ → flutter 팀 발사 가능.

### Phase 1: 모델 + API 클라이언트 + 프로바이더 배선 (data layer, UI 없음)

- [x] `models/trails.dart` 신규(012 §14 계약, nullable suitability 안전 파싱).
- [x] `api/trails_api.dart` 신규(abstract/Http/Fake, `GET /api/trails?lat&lng`).
- [x] `trailsApiProvider`+`trailsProvider`(위치 watch, 홈 `DiscoveryNotifier` 패턴) 배선. 홈 프로바이더·009 캐싱 회귀 없음.

**Phase validation**: `just check` green(analyze 무경고 + 기존 test green, 신규 모델/파싱 단위테스트 통과).

### Phase 2: 공통 위젯 (NightSkyTag 측정태그 / CourseCard / HeritageEatsList / score_gauge progressColor)

- [x] `score_gauge.dart`에 `progressColor` 선택 파라미터 추가(기본값 현행 secondary — 홈 회귀 없음).
- [x] `night_sky_tag.dart`(측정 태그 톤, 게이지 금지, tertiary, approx/live 텍스트+색 병기).
- [x] `course_card.dart`(featured/리스트 공통, `featured: bool` 분기 — 테두리/듀얼게이지/노포프리뷰 토글, name·meta·nightSky는 동등). `heritage_eats_list.dart`(상세용 read-only).
- [x] `distanceM`→"320m", `durationMin`→"3시간 40분", `level`→"쉬움/보통/어려움"(+dot) 사람이 읽는 포맷 헬퍼(스크린리더 대비, §E-6).

**Phase validation**: `just check` green + 위젯 단위 렌더 테스트.

### Phase 3: 카탈로그 랜딩 화면 + app_shell 배선 + 상태 4종

- [x] `trails_catalog_screen.dart`: region 헤더(권역 칩, 정적 라벨) + 정렬근거 캡션(**"밤하늘이 가장 어두운 순서예요"** — 시간부사 "오늘" 제거, design-lead P1-4: 정적 approx SQM에 "오늘"이 라이브를 암시하면 데이터 정직 원칙과 마찰. 정렬규칙만 서술; featured 카드 밖) + featured 리치 카드(courses[0]) + "이 권역의 다른 코스 · N개" 리스트(courses[1..]) + tap→상세 push.
- [x] 상태 4종 + **토큰 못박기(design-lead P1-2)**: loading(진행표시), data, **error/degraded=true = `errorContainer` 배경 + `onErrorContainer` 텍스트 + `Icons.warning_amber_rounded`**(홈 degraded 톤 상속), error에 다시 시도 버튼(=provider invalidate), **empty(courses 0 & degraded=false) = `surfaceContainer` 배경 + `onSurfaceVariant` 텍스트 + 중립 아이콘(`Icons.explore_off`류)** — empty에 error 색(`errorContainer`/빨강) 절대 금지(§A-5). 세 상태가 색으로 구분되어야 함.
- [x] `app_shell.dart` index 2 placeholder→`TrailsCatalogScreen()` 교체(다른 탭 무변경).

**Phase validation**: `just check` green + 랜딩 위젯테스트(featured/리스트/degraded/empty/loading/error).

### Phase 4: 코스 상세 화면 (push)

- [x] `course_detail_screen.dart`: 코스명·권역·(featured면)정렬근거 배지 헤더(가짜 GPX 지도 히어로 금지 — §B-1), 메타 카드(거리/시간/난이도/순환), 종점 밤하늘 조건(NightSkyTag 대형, 측정 톤), (featured만)낮·밤 듀얼 게이지(size~96), 종점 노포 top3(HeritageEatsList, read-only).
- [x] **비-featured 처리 못박기(design-lead P2-6)**: 비-featured 코스는 **게이지 섹션 자체를 렌더하지 않고**(빈 게이지 자리=회색 원 금지, "결핍"으로 읽힘), 대신 종점 밤하늘 블록 아래에 **1줄 안내 캡션**(`onSurfaceVariant` 중립 톤, 예 "이 코스는 밤하늘 조건 기준으로 수록되었어요") — negative/결핍 프레이밍 금지.
- [x] 랜딩 카드 tap→이 화면 push(추가 fetch 없이 `TrailCourse` 전달). back 정상.

**Phase validation**: `just check` green + 상세 push 위젯테스트(노포 렌더·featured/비-featured 분기).

### Phase 5: 낮/밤 강조 + 접근성 + 통합 검증

- [x] 낮/밤 모드 강조(§D): 게이지 좌우 스왑 금지(위치 항상성) — 현재 모드 쪽 게이지 accent 강조(glow/label bold)만. featured/리스트 정렬은 모드 무관 SQM 고정. **모드 전환 stagger는 이번 조각 미적용**(design-lead 스코프 권고: 카탈로그는 리스트라 홈의 4그룹 stagger 구조가 안 맞음 → 후속 부채로 분리). 011 장면전환 테마 전환(전역)은 자동 상속되므로 **홈 회귀 없음만 확인**. `course_card.dart`/`course_detail_screen.dart`의 게이지 `Row`가 `Consumer`로 `obsModeProvider`를 watch — day는 항상 좌, night는 항상 우 고정, 현재 모드 쪽만 glow+bold.
- [x] 접근성(§E): 카드 tap 44pt(`ConstrainedBox(minHeight: 44)`), 게이지 색 단독 금지(중앙 숫자+라벨 병기 — 기존), **approx/live 색+텍스트 병기**(nightSky의 `'(약)'`은 기존 구현, 이번에 `CourseSuitability.status=='live'`용 `'실시간'` 텍스트 태그를 `course_card.dart`+`course_detail_screen.dart` 양쪽 게이지 옆에 신규 추가— 게이지 accent 색과 동일 색 재사용), monospace 수치 ≥12sp(`night_sky_tag.dart`), semantic 라벨(featured="대표 코스, {name}, 밤하늘 가장 어두움"), 원시 단위 사람 포맷(`trail_format.dart`).
- [x] **대비 하한 못박기(design-lead P1-3)**: `NightSkyTag`의 tertiary 텍스트는 `_contrastRatio` 헬퍼로 실측 대비를 계산해 4.5:1 미달 시 `onSurface`로 폴백(`night_sky_tag.dart:35-40`) — 구현 확인됨.
- [x] 홈(004~011) 회귀 없음: `just check` green — 58개 기존 테스트(009 캐싱·010 collapse·011 장면전환·003 에러문구 포함) 전부 그대로 통과 + 신규 `trails_wiring_test.dart` 8개 추가로 총 66개 통과, analyze 무경고.

**Phase validation**: 아래 Validation Commands 통과 확인(`just check` green, 66 tests). 발사 후 브레인 시뮬레이터 육안검증(색감·모드 강조·nightSky vs 게이지 시각 분리 실렌더·상세 push·노포).

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: 트레일 모델/API/프로바이더 배선, 카탈로그 랜딩(region 헤더+featured 카드+리스트+상태 4종), 코스 상세(메타+종점 밤하늘+featured 듀얼 게이지+종점 노포 top3), nightSky↔suitability 시각 종 분리, featured 비열등 위계, 낮/밤 accent 강조, 접근성.
- **제외(후속 부채, design-lead §E)**: GPX 폴리라인 지도 썸네일/렌더(가짜 지도 이미지도 금지), 노포 상세 push·지도 핀 연동·전화/길찾기(read-only 리스트까지만), 예약·바우처·할인·탄소·기금·백년가게 배지(계약에 없음, stub 금지), 24시간 타임라인·스튜어드 스팟·게이미피케이션·관찰기록(IA 배제 확정), 자유 인터랙티브 지도(지도 탭 위임), 정렬/필터 UI(SQM 단일 정렬 고정), 즐겨찾기/저장, 위치 칩 tap→권역 재선택.

### backend 계약 (012 §14, 라이브 검증됨 — 소비 기준)
```
GET /api/trails?lat&lng → TrailsResponse
{ region, degraded, courses[최대5, 종점 SQM 높은 순]:
  { crsIdx, name, sigun, distanceKm, durationMin, level(1..3), cycle, gpxUrl,
    start{lat,lng}, end{lat,lng},
    nightSky{sqmValue, bortleClass, skyClass, status("approx")},
    heritageEats[top3]{name, addr, distanceM, lat, lng, contentId},
    daySuitability{score,label,status}|null,     // featured(1위)만 non-null
    nightSuitability{score,label,status}|null } }
```
- featured=랭킹 1위(courses[0])만 day/nightSuitability 채워짐, 나머지 null.
- 라이브 예(강화): region "인천 강화군", featured=서해랑길 101(SQM 20.15 approx, day 67/night 64 live, 노포 3), 비-featured=DMZ평화의길 1(SQM 16.0, 적합도 null).

### design-lead 설계 요지 (2026-09-10 자문 — 이 스펙이 따르는 근거)
- **랜딩** = region 헤더 + featured 리치 카드 1장 + "이 권역의 다른 코스" 리스트, 단일 스크롤. featured는 "리스트에서 뽑아 올린 발췌"로 읽히게(열등/특권 위계 금지).
- **정렬근거**(요건2)는 featured 카드 **밖** 캡션("밤하늘이 가장 어두운 순서예요" — "오늘" 등 시간부사 배제, P1-4)으로 — 카드 안 배지는 "코스 속성"으로 오독됨(정렬 규칙이지 코스 속성 아님). 카드 안엔 보조 pill 하나만(선택).
- **nightSky↔suitability 종 분리**(요건1, §C 표): nightSky=측정 태그(칩/monospace 수치, **게이지·0~100 스케일 암시 금지**, tertiary/앰버, approx 태그), suitability=원형 ScoreGauge(낮=tertiary/밤=secondary arc, live 태그). **같은 행에 나란히 두지 말고 구분선으로 분리.** approx/live 태그는 대응 값 바로 옆.
- **featured 카드 위계**(위→아래): 정렬근거 pill(보조) → 코스명 → 메타행(거리·시간·난이도·순환) → 구분선 → nightSky 측정 블록 → 구분선 → 낮/밤 듀얼 게이지(coures duality 대표 증명, size~72) → 종점 노포 프리뷰 1줄(상세 유도) → 카드 tap=상세 push(별도 CTA 불필요). **카드 전체가 단일 탭 타깃(InkWell 1개), 내부에 개별 탭 요소 없음**(노포 프리뷰도 tap 불가 — 노포 상세 push는 제외 목록) (design-lead P2-5).
- **리스트 카드**(요건3): name·meta·nightSky는 featured와 **완전 동등**(같은 타이포 크기·같은 NightSkyTag). 차이는 테두리+듀얼게이지+노포프리뷰 유무뿐. suitability 슬롯은 아예 렌더 안 함(negative 문구 금지). 섹션 라벨 "이 권역의 다른 코스"가 발췌/전체 프레이밍.
- **상세**: 가짜 GPX 지도 히어로 금지(기대 조작) → 코스명+권역부터. 메타 카드 → 종점 밤하늘(NightSkyTag 대형, "종점 관측지 밤하늘") → (featured만)듀얼 게이지 size~96/비-featured는 "밤하늘 조건 기준으로 수록" 안내(결핍 아닌 수록기준) → "관측을 마치고 들를 수 있는 곳" 종점 노포 top3(read-only, distanceM 포맷·addr ellipsis).
- **낮/밤**(요건 대비 제약: 코스별 풀 적합도는 featured만): 모드는 **재정렬 아닌 accent 강조·서사만**. 게이지 위치 고정(낮=좌/밤=우), 현재 모드 쪽 게이지에 glow·label bold만(위치 항상성). featured/리스트 SQM 정렬은 모드 무관 고정(요건4 단일 진실). 모드 전환 stagger는 이번 조각 미적용(후속 부채) — 전역 테마 전환만 자동 상속.
- **단일 진실**(요건4): featured 종점 SQM 수치는 리스트·featured·상세에서 동일 숫자·동일 소스·동일 NightSkyTag 렌더.

### flutter 팀 인수인계 (design-lead)
- 신규 위젯 `NightSkyTag`(측정 톤, featured/리스트/상세 공통 재사용), `CourseCard(featured:bool)`, `HeritageEatsList`, 포맷 헬퍼.
- `score_gauge.dart`에 progressColor 파라미터 추가(낮=tertiary/밤=secondary).
- 모드 전환 stagger: 이번 조각 **미적용**(카탈로그 리스트 구조에 홈 4그룹 stagger 부적합 → 후속 부채). 전역 테마 전환(011)만 자동 상속, 홈 회귀 없음만 확인.
- 상태 4+2종: loading/data/error(다시 시도)/degraded(error 톤 배너) + empty(courses 0 & degraded=false는 중립 톤).

### 불변 원칙
- **backend·계약 무변경.** 순수 flutter consumer. 012 `GET /api/trails`를 그대로 소비(모델은 계약과 정합). 홈(004~011) 회귀 금지(009 family 캐싱·010 collapse·011 장면전환·007 오버플로우·003 에러/loading/degraded 문구). `score_gauge` progressColor 기본값=현행(홈 회귀 없음). `obsMode`/`location` 프로바이더는 기존 것 재사용.

### 교훈 계승 (005~012)
- 외부 API 없음(계약 소비만) → 크로스모델 verify(codex)가 오프라인 결함 커버. **단 색감·nightSky vs 게이지 시각 분리 체감·모드 강조·상세 push·노포 렌더는 오프라인 위젯테스트가 못 잡음 → 브레인 시뮬레이터 육안검증 필수**(007/010/011 반복 확인).
- nullable suitability 파싱 방어 필수(featured만 non-null — null 역참조가 가장 흔한 크래시 후보).

## Amendments (post-build change history, append-only)

- 2026-09-10 (brain): 1차 발사 verdict=FAIL, 단 실사유 = **flutter-lead 프로세스 스폰 실패**(`lead.ok:false`, `sessionId:null`, attempts=2 모두 lead 스폰 단계에서 실패 — "previous lead spawn failed — waiting 90s"). **코드 결함 아님** — 011/012에서 반복 관찰된 transient 스폰/권한 인프라 문제 계열. **브레인 직접 검증(`just check`) 결과 green(58 테스트 전부 통과, analyze 무경고, 홈 회귀 없음).** 이미 디스크에 반영된 산출물: `models/trails.dart`(nullable suitability 파싱 정확), `api/trails_api.dart`, `widgets/{night_sky_tag,course_card,heritage_eats_list}.dart`, `screens/{trails_catalog,course_detail}_screen.dart`, `utils/trail_format.dart`, `app_shell.dart`/`discovery_providers.dart`/`score_gauge.dart` 수정. `night_sky_tag.dart`는 P1-3 대비 폴백(tertiary<4.5:1→onSurface)까지 구현 확인. **잔여(재발사 lead가 완성)**: (1) `test/trails_wiring_test.dart` 신규(§New Files 8개 케이스 — 현재 미생성, 테스트 수 58 그대로), (2) Phase 3 empty vs degraded 색 토큰 negative assert 검증, (3) Phase 5 접근성(semantic 라벨·44pt)·낮/밤 accent 강조 확인, (4) codex 크로스검증. Phase 1/2는 파일·`just check`로 완료 확인됨([x] 유지). 재발사는 이미 있는 파일을 재작성 말고 **잔여만 완성** + 전체 재검증.

- 2026-09-10 (brain, 재발사): 잔여 항목 완성. (1) 접근성 갭 발견 — §E "approx/live 색+텍스트 병기" 중 approx(nightSky `'(약)'`)만 구현돼 있었고 live(`CourseSuitability.status`)는 시각 표시가 전무 → `course_card.dart`(`_buildFeaturedExtras`)와 `course_detail_screen.dart`(`_SuitabilitySection`) 양쪽 게이지 라벨 옆에 `daySuitability.status=='live'`/`nightSuitability.status=='live'` 조건부 `'실시간'` 텍스트(게이지 accent 색 재사용) 추가. (2) `test/trails_wiring_test.dart` 신규 — 8케이스 전부(§New Files 명세대로): data/non-featured/degraded/empty(negative assert 포함)/loading/error/navigation(featured·non-featured 분기)/단일 진실(SQM 카탈로그·상세 동일값). `find.descendant(of: find.byType(CourseDetailScreen), ...)`로 push 후에도 마운트 유지되는 카탈로그 화면과의 중복 매치를 스코프 처리. (3) Phase 3/5 전 항목 재검증 후 [x] 처리 — 44pt 탭 타깃(`ConstrainedBox(minHeight:44)`)·semantic 라벨(featured)·대비 폴백(`_contrastRatio`)·모드 accent(`Consumer`+`obsModeProvider` watch, 좌우 고정)는 이미 디스크에 구현되어 있었음을 코드 리딩으로 확인. `just check` green: 66 tests(기존 58 + 신규 8), analyze 무경고, 홈 회귀 없음. (4) codex 크로스검증은 팀 YAML의 `verifier: codex` 파이프라인 단계가 이 lead 세션 종료 후 자동 수행 — lead가 별도로 수동 호출하지 않음.

- 2026-09-10 (brain, 3차 크로스검증 수정): codex 크로스모델 검증에서 FAIL 4건 발견 → 전부 flutter-engineer에게 수술적으로 재위임하여 수정 완료. (1) `night_sky_tag.dart` — `NightSky.bortleClass`(int, 기존 모델 필드지만 미사용)를 렌더링하지 않고 있었음 → SQM Text와 skyClass Text 사이에 `'Bortle ${bortleClass}'` Text 신규 삽입(동일 gap 패턴·monoStyle·onSurfaceVariant 색). (2) `course_detail_screen.dart` `_FeaturedBadge` — 텍스트가 "밤하늘 관측 최적 코스"(코스 속성으로 오독됨, design-lead P1-4 위반)였던 것을 카탈로그 정렬근거 캡션과 동일한 문장 "밤하늘이 가장 어두운 순서예요"로 통일(단일 진실). (3) 같은 파일 `_MetaRow` — 거리/시간/난이도/순환을 "·" 구분 plain Text 한 줄로만 렌더하던 것을 스펙의 "메타 카드" 요건에 맞게 `Card` + 4개 `_MetaItem`(라벨+값 분리) 레이아웃으로 재구성. (4) `test/trails_wiring_test.dart` 첫 테스트가 featured 카드의 테두리(border) 커버리지를 주장하면서 실제 assert가 없었음 → `find.descendant`로 featured `CourseCard` 내부 `Card`를 찾아 `RoundedRectangleBorder.side.width > 0` assert 추가. 4건 모두 member 수정 후 lead가 diff 직접 확인 + `just check` 재실행으로 green 검증(66 tests, analyze 무경고, 기존 assert 무변경).
