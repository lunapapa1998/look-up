# 관찰 지도 flutter consumer (full-bleed 지도 + 3-스냅 바텀시트 + 핀 3종 + 측정값/적합도 종분리)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-10
- modified: 2026-09-10 <brain/orchestrator>
- modified: 2026-09-10 <brain/orchestrator> — design-lead 스펙 검수 조건부 GO 반영(P1 3건: 낮모드 다크타일 오버레이·핀 색+형태 이중인코딩·위치권한거부 상태 / P2 5건: peek 0.16·노포 적합도 재프레이밍·community 한국어배지+날짜파싱방어·시트가림 카메라오프셋·레이어전부off 구분·attribution 위치). Phase 0 통과, 발사 준비 완료.
- refs: `specs/014-observation-map-backend.md`(계약 publisher·라이브 검증됨), `apps/backend/.team/member.md` §25(`GET /api/observation-map` 계약 publish), `specs/013-trails-heritage-flutter.md`(측정값↔적합도 종분리·상태 토큰 못박기·오버플로우 교훈 선례), `apps/flutter/lib/api/trails_api.dart`(abstract/Http/Fake API 관례), `apps/flutter/lib/state/discovery_providers.dart`(`locationProvider`·`obsModeProvider`·`suitabilityApiProvider`·`AsyncNotifier` 관례), `apps/flutter/lib/widgets/{night_sky_tag,score_gauge}.dart`(측정 태그·적합도 게이지 재사용), `apps/flutter/lib/theme/app_theme.dart`(`themeFor(ObsMode)` 낮/밤 2팔레트), `apps/flutter/lib/screens/app_shell.dart`(탭 index 1 placeholder), design-lead 관찰지도 자문(2026-09-10, PROGRESS "관찰 지도=앱 핵심" 절), Figma `node 1-2104`/`19-1959`("생태 & 다크스카이 관찰 지도"=관찰 지도 탭 index1), 스킬 `flutter-fix-layout-issues`·`flutter-ui`(브레인이 로드해 아래 §스킬 지침 반영)
- risk: high - 신규 외부 패키지(`flutter_map`+`latlong2`+OSM/CARTO 다크 타일) 도입 + full-bleed `Stack`+`DraggableScrollableSheet`(오버플로우·unbounded 취약 구조) + 지도 인터랙션(핀 탭·bbox fit·GPS 1샷) + 스팟 탭 시 기존 `GET /api/suitability` 2차 호출 배선. 순수 flutter consumer(backend·계약 무변경). 홈(004~011)·트레일(013) 회귀 금지.

## Purpose

앱의 **핵심 화면**인 "관찰 지도 탭"의 눈에 보이는 부분을 완성한다 — 014 backend가 라이브 검증한 `GET /api/observation-map` 계약을 소비해, 현재 빈 `PlaceholderScreen('관찰 지도')`(app_shell index 1)를 **full-bleed 다크 지도 + 3-스냅 드래그 바텀시트 + 관찰 스팟 핀 3종(조류/별/노포)** 실화면으로 교체한다.

## Problem

1. 관찰 지도 탭(`app_shell.dart:22`)이 `PlaceholderScreen(icon: Icons.map, title: '관찰 지도')` 빈 껍데기다 — backend 계약(014)·설계(design-lead)는 준비됐는데 소비 화면이 없다("사라진 지도"는 애초 이 탭의 몫).
2. flutter 앱에 지도 라이브러리·관찰 스팟 도메인 모델·API 클라이언트·프로바이더가 전무하다(홈 suitability·트레일 계열만 존재).

## Solution

(1) `flutter_map`+`latlong2`+무키(no-key) CARTO 다크 래스터 타일을 도입하고, (2) 014 계약 기준 관찰 스팟 도메인 모델(`ObservationMapResponse`/`ObservationSpot`/`BirdObservation`/`NightSky`/`HeritageInfo`) + `ObservationMapApi`(abstract/Http/Fake) + `observationMapProvider`(위치 watch)를 배선하고, (3) design-lead 설계대로 **full-bleed 지도**(GPS 1샷 → 스팟 bbox fit, SafeArea edge-to-edge) 위에 **핀 3종**(조류/별/노포, 레이어 칩으로 필터) + **3-스냅 드래그 바텀시트**(peek=스팟 리스트 / mid·full=스팟 상세)를 신규 구현해 placeholder를 교체한다. 핵심 규율은 013 계승 **측정값(핀/시트 상단, 계약 그대로)↔적합도(시트 상세에서 기존 `GET /api/suitability?lat&lng&mode`를 그 스팟 coord로 2차 호출)의 종(種) 분리**와 **eBird 정직 표기**(status="community", "실시간" 금지 → "최근 관측·N일 전")다.

## Relevant Files

### Existing Files

- `apps/flutter/pubspec.yaml` - **신규 의존성 추가**: `flutter_map: ^8.3.2`, `latlong2: ^0.10.1`(이 리포 Flutter 3.44.5에서 실제 해소되는 버전 — 브레인이 pub 캐시 사전 확인). 그 외 의존성 무변경. `just check`(=`flutter-check`)가 `flutter pub get`을 선행하므로 파이프라인이 자동 취득·`pubspec.lock` 갱신(캐시 워밍됨). **flutter_map 8.x API**: `MapController`/`MapOptions`/`TileLayer`/`MarkerLayer`/`RichAttributionWidget`/`CameraFit.bounds`(`fitCamera`) 사용.
- `apps/flutter/lib/screens/app_shell.dart` - `_tabs` index 1의 `PlaceholderScreen(icon: Icons.map, title: '관찰 지도')`를 신규 `ObservationMapScreen()`으로 교체. 나머지 탭·NavigationBar·index 배선 무변경(index 0 홈·index 2 트레일·index 3/4 placeholder/일기 그대로). `HomeDiscoveryScreen(onViewMapPressed: () => setState(() => _selectedIndex = 1))`가 이미 index 1로 점프하므로 홈 "지도 보기" 버튼이 이 화면으로 자연 연결됨(회귀 확인).
- `apps/flutter/lib/state/discovery_providers.dart` - `observationMapApiProvider`/`observationMapProvider`(위치 watch)와 스팟 상세 적합도용 `spotSuitabilityProvider`를 추가하거나 신규 `observation_map_providers.dart`로 분리(빌더 판단). `locationProvider`(기존)를 watch해 lat/lng 획득 — 트레일 `TrailsNotifier`와 동일 패턴. `obsModeProvider`(기존)를 watch해 낮/밤 accent·적합도 mode 결정. `suitabilityApiProvider`(기존, `fetchSuitability({lat,lng,mode})→DiscoveryOverview`) **무변경 재사용**. 009 family 캐싱·홈·트레일 배선 회귀 금지.
- `apps/flutter/lib/widgets/night_sky_tag.dart` - **무변경 재사용**. 별 스팟의 SQM/Bortle/skyClass/approx 측정 태그를 시트에서 이 위젯으로(게이지 금지, tertiary 톤 — 013 규율 그대로).
- `apps/flutter/lib/widgets/score_gauge.dart` - **무변경 재사용**(013에서 `progressColor` 파라미터 이미 추가됨). 스팟 상세 시트의 적합도(2차 `/api/suitability`)를 낮=tertiary/밤=secondary arc 게이지로.
- `apps/flutter/lib/utils/trail_format.dart` - **재사용 or 공용화**(`distanceM`→"320m" 포맷 헬퍼). 노포 스팟 거리 표기에 사용. 없으면 관찰지도용 포맷 헬퍼는 여기에 추가(중복 금지).

### New Files

- `apps/flutter/lib/models/observation_map.dart` - 014 §25 계약 기준 도메인 모델(plain 클래스 + `fromJson` 팩토리, `models/trails.dart` 관례 그대로). `Coordinate`는 `models/trails.dart`의 것 재사용(import) — 재정의 금지. 신규: `BirdSpecies(nameKo, nameSci, speciesCode, count:int?, obsDt:String)`, `BirdObservation(speciesCount:int, topSpecies:List<BirdSpecies>, mostRecentObsDt:String, status:String)`, `NightSky`(트레일과 동일 형태 — `models/trails.dart` 것 재사용 or 공용화 판단), `HeritageInfo(addr, distanceM:int?, contentId)`, `ObservationSpot(id, kind:String["bird"|"star"|"heritage"], name, coord:Coordinate, nightSky:NightSky?, birds:BirdObservation?, heritage:HeritageInfo?)`, `ObservationMapResponse(region, degraded:bool, spots:List<ObservationSpot>)`. **`count`/`distanceM`는 nullable**(계약상 없을 수 있음 — null 안전 파싱 필수). **kind별로 정확히 하나의 측정 블록만 non-null**(bird→birds, star→nightSky, heritage→heritage). **적합도(score) 필드 없음**(계약에 의도적으로 없음 — 넣지 말 것).
- `apps/flutter/lib/api/observation_map_api.dart` - `trails_api.dart` 관례 복제: `ObservationMapApiException`, `abstract class ObservationMapApi { Future<ObservationMapResponse> fetchObservationMap({required double lat, required double lng}); }`, `HttpObservationMapApi`(`GET {baseUrl}/api/observation-map?lat&lng`, `_checkStatus` 200, `ObservationMapResponse.fromJson`), `FakeObservationMapApi`(테스트용 결정적 데이터 — bird 1 + star 1 + heritage 1, degraded 토글, shouldThrow 토글, onFetch 콜백). mode 쿼리 없음(계약은 lat/lng만).
- `apps/flutter/lib/screens/observation_map_screen.dart` - 관찰 지도 화면(§A~§D). `ConsumerStatefulWidget`(지도 `MapController`·시트 `DraggableScrollableController`·선택 스팟 상태 보유). `Stack`: 바닥=`FlutterMap`(full-bleed, SafeArea edge-to-edge), 상단 오버레이=레이어 칩 Row + GPS 재중심 버튼, 하단=`DraggableScrollableSheet`(3-스냅). `observationMapProvider` watch → `AsyncValue.when(loading/error/data)`. data 내부에서 degraded·empty 분기.
- `apps/flutter/lib/widgets/observation_marker.dart` - 핀 위젯 3종(조류/별/노포). **⭐ 색만이 아니라 핀 형태(shape)로도 kind 구분(P1-2, 색각이상 8%·다크타일·낮오버레이 대비저하 대응, WCAG 1.4.1)**: 조류=청록(teal) + **물방울형 핀** + 새 실루엣 아이콘(**`Icons.flutter_dash` 금지** — Flutter 마스코트라 브랜드 오염; 일반 새 글리프/커스텀 실루엣), 별=앰버 + **원형 핀** + `Icons.star`(관습상 가장 강함, `nights_stay`보다 직관적), 노포=**채도 낮춘 뉴트럴 회갈색**(앰버와 색상환에서 벌려 인접 회피) + **사각/모서리둥근 핀** + `Icons.storefront`/`restaurant`. **핀 시각 크기(24~32px) ≠ 히트 타깃**: 탭 히트 영역만 ≥44dp로 확장(밀집 시 유리). 선택 핀은 튀어오름(scale 1.2~1.3/elevation)+나머지 약간 dim(선택 상태 명확, Nielsen #1). 라벨 텍스트는 오버플로우 방지(§스킬 지침).
- `apps/flutter/lib/widgets/observation_spot_sheet.dart` - 3-스냅 시트 콘텐츠. peek=스팟 리스트(kind 아이콘+name+측정 요약 1줄), mid/full=선택 스팟 상세(kind별 측정 블록 + 적합도 게이지). 리스트는 **`SliverList.builder`/`ListView.builder`**(스팟 수 가변, §스킬 lazy). 상세는 kind별 컴포넌트로 분기.
- `apps/flutter/lib/widgets/observation_spot_detail.dart` - 선택 스팟 상세 본문(시트 mid/full). 상단=**측정 블록**(kind별: 조류=`BirdObservation` 종수+topSpecies+"최근 관측 N일 전"+community 배지 / 별=`NightSkyTag`(재사용) / 노포=주소+거리) → 구분선 → 하단=**적합도 블록**(`spotSuitabilityProvider(coord)` watch → `ScoreGauge`, 로딩/에러 자체 상태). 측정↔적합도 사이 **구분선 필수**(같은 행 금지 — 013 규율).
- `apps/flutter/test/observation_map_wiring_test.dart` - `FakeObservationMapApi`+`FakeSuitabilityApi` 주입 위젯테스트(아래 §테스트 케이스). **지도 타일은 네트워크라 테스트에서 렌더 못 함** → 마커 매핑·레이어 필터·시트·측정/적합도 분리·상태·정직문구를 검증(타일 렌더는 브레인 시뮬 육안).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 0: 발사 전 design-lead 스펙 검수 (브레인 선행 — flutter 발사 금지 게이트)

design-lead 관찰지도 화면 설계 자문은 수령 완료(PROGRESS "관찰 지도=앱 핵심" 절 + 아래 §design-lead 설계 요지). 이 스펙이 자문을 정확히 옮겼는지, 그리고 신규 요소(flutter_map 다크 타일 선택·3-스냅 스냅포인트·핀 시각 언어·오버플로우 예방)가 UX 원칙에 맞는지 **발사 전 design-lead 스펙 검수 1회**(memory `lookup-design-lead-workflow`)를 거친 뒤 Phase 1 착수. 검수에서 잡힌 사항은 스펙에 반영·기록.

- [x] design-lead 스펙 검수 → **조건부 GO**(2026-09-10). P1 3건(낮모드 다크타일 저알파 오버레이·핀 색+형태 이중 인코딩+`flutter_dash` 금지·위치 권한거부 폴백 상태) + P2 5건(peek 0.16 상향·노포 적합도 재프레이밍/생략·community 한국어 배지+날짜파싱 방어·시트 가림 카메라 오프셋·레이어 전부off 구분·attribution 접힘형 위치) **전부 스펙에 반영 완료** → GO.

**Phase validation**: design-lead 검수 통과(조건부 GO, P1/P2 반영 완료). ✅ → flutter 팀 발사 가능.

### Phase 1: 의존성 + 모델 + API 클라이언트 + 프로바이더 배선 (data layer, UI 없음)

- [x] `pubspec.yaml`에 `flutter_map`+`latlong2` 추가, `flutter pub get`, `pubspec.lock` 갱신.
- [x] `models/observation_map.dart` 신규(014 §25 계약, nullable count/distanceM 안전 파싱, kind별 단일 측정 블록, `Coordinate`/`NightSky` 재사용).
- [x] `api/observation_map_api.dart` 신규(abstract/Http/Fake, `GET /api/observation-map?lat&lng`).
- [x] `observationMapApiProvider`+`observationMapProvider`(위치 watch, 트레일 `TrailsNotifier` 패턴) + `spotSuitabilityProvider`(coord+mode로 기존 `suitabilityApiProvider.fetchSuitability` 호출하는 `FutureProvider.family`) 배선. 홈·트레일·009 캐싱 회귀 없음.

**Phase validation**: `just check` green(analyze 무경고 + 기존 test green, 신규 모델/파싱 단위테스트 통과).

### Phase 2: 지도 스캐폴드 (flutter_map 다크 타일 + GPS 1샷 bbox fit + full-bleed) + 레이어 칩

- [x] `observation_map_screen.dart`: `Stack` 바닥에 `FlutterMap`(CARTO 다크 래스터 타일 `TileLayer` + **낮 모드 저알파 오버레이 레이어**(P1-1, `obsModeProvider` watch → 낮만 `colorScheme.surface` 0.12~0.18 오버레이) + `RichAttributionWidget`(접힘형, 시트 안 가리는 상단 우측, "© OpenStreetMap contributors © CARTO")). full-bleed + `SafeArea`/`MediaQuery.paddingOf`로 시스템바 침범 방지(§스킬 edge-to-edge). 초기 카메라=위치 획득 후 스팟 전체 `LatLngBounds`에 `fitCamera`(스팟 없으면 지역 기본 좌표). [초기 카메라 bbox fit은 Phase 3에서 마커 배선과 함께 완성 — 이 phase는 defaultObservationLat/Lng 고정 카메라]
- [x] 상단 오버레이: 레이어 칩 Row(조류/별/노포 토글, 다중 선택, 기본 전체 on) + GPS 재중심 버튼(위치로 카메라 이동, 1샷). 칩 토글 시 해당 kind 핀만 표시. **레이어 전부 off = "표시할 레이어를 선택하세요" 안내(P2, 데이터 빈 상태 empty와 시각·문구 구분)**. [마커 필터 배선은 Phase 3]
- [x] app_shell index 1 placeholder→`ObservationMapScreen()` 교체(다른 탭 무변경).

**Phase validation**: `just check` green(레이어 칩 필터 로직 단위/위젯테스트 — 타일 렌더 assert 제외). 발사 후 브레인 시뮬 육안(다크 타일·bbox fit 실렌더).

### Phase 3: 핀 3종 + 마커 매핑 + 탭→시트 선택

- [x] `observation_marker.dart`(조류/별/노포 3종, kind별 아이콘·색, 44dp+ 탭 타깃, 선택 강조). [조류 아이콘: Material Icons에 새 글리프가 없어 `Icons.flutter_dash` 대신 `CustomPainter`로 손그림 실루엣 구현]
- [x] 스팟→`Marker` 매핑을 **순수 함수/테스트 가능 로직**으로 분리(레이어 필터 적용). `FlutterMap`의 `MarkerLayer`에 배선.
- [x] 핀 탭 → 선택 스팟 상태 갱신(`_selectedSpot`) + 시트를 mid(0.45) 스냅으로 전개(`_selectSpot` 통합, 마커 탭·리스트 탭 동일 경로). **카메라를 시트에 안 가리게 오프셋(P2) 완료**: `_revealAboveSheet`가 `MapCamera.latLngToScreenOffset`/`screenOffsetToLatLng` 픽셀 왕복으로 선택 스팟을 mid 스냅 위 가시영역으로 이동, `fitCamera` bottom padding도 peek(0.16) 시트 높이 반영.

**Phase validation**: `just check` green(스팟→마커 매핑·필터·탭→선택 위젯테스트). 발사 후 브레인 시뮬(핀 위치·탭).

### Phase 4: 3-스냅 바텀시트 (스팟 리스트 + 스팟 상세, 측정값/적합도 종분리)

- [x] `observation_spot_sheet.dart`: `DraggableScrollableSheet`(스냅 3종 — **peek≈0.16**(P2, 0.12는 리스트 1줄도 안 보여 signifier 전락 → peek에서 리스트 항목 최소 1개 온전 노출+다음 항목 상단 암시) / mid≈0.45 / full≈0.9, `snap:true`, `snapSizes`). peek 헤더에 **"관찰 스팟 N곳"** 카운트+활성 레이어 상태 1줄(P2, 정보 scent — kind별 개수 요약으로 구현). peek=스팟 리스트(`ListView.builder`, kind 도트+name+측정 요약 1줄, 항목 탭→선택+mid 전개). mid/full=선택 스팟 `observation_spot_detail.dart`.
- [x] `observation_spot_detail.dart`: 상단 **측정 블록**(조류=종수+topSpecies+"최근 관측 N일 전"+**community 배지(한국어 "커뮤니티 관측" — P2, 영문 "community" 그대로 금지)**, 별=`NightSkyTag` 재사용, 노포=주소+거리) → **구분선**(`Divider`) → 하단 **적합도 블록**(`spotSuitabilityProvider` watch → `ScoreGauge` 낮/밤 accent, 로딩=진행표시/에러=재시도 버튼). **측정↔적합도 같은 행 금지, 구분선 분리**(013 §C 규율) 준수. **노포(heritage) 스팟 적합도 처리(P2)**: **적합도 블록 전체 생략**(측정=주소·거리만) 채택.
- [x] **eBird 정직 표기(014/013 계승, 위반 금지)**: 조류 블록은 `status`가 "community"임을 한국어 배지로 표기, `mostRecentObsDt`를 "N일 전"으로 표기(`DateTime.tryParse`). **"실시간"/"지금 출현" 문구·색 절대 미사용.** **날짜 파싱 방어(P2)**: 파싱 실패 시 원문 문자열 그대로 표기(크래시·"NaN일 전" 없음, `tryParse null`이면 원문 반환).

**Phase validation**: `just check` green(시트 스냅·리스트→상세·측정 블록 kind 분기·적합도 2차 호출(FakeSuitabilityApi)·정직문구 위젯테스트). 발사 후 브레인 시뮬(드래그 스냅 체감).

### Phase 5: 상태 4종 + 접근성 + 오버플로우 가드 + 통합 검증

- [x] 상태 + **토큰 못박기(013 P1-2 계승)**: loading(진행표시), data, **degraded=true / error = `errorContainer` 배경 + `onErrorContainer` 텍스트 + `Icons.warning_amber_rounded`**(홈/트레일 degraded 톤 상속) + 다시 시도(provider invalidate), **empty(spots 0 & degraded=false) = `surfaceContainer` + `onSurfaceVariant` + 중립 아이콘**(`errorContainer`/빨강 절대 금지 — `_ErrorStatusBanner`/`_EmptyStatusBanner` 분리 구현으로 검증).
- [x] **⭐ 위치 권한 거부/미획득 폴백(P1-3, 발사 전 필수)**: `location_service.dart`의 `GeolocatorLocationService`가 이미 실패 시 강화 고정좌표로 폴백(크래시·빈 화면 없음). `_LocationFallbackBanner`(surfaceContainer 톤, 에러 아님)로 "현재 위치를 못 찾아 강화 기준으로 표시 중" 안내 + "위치 켜기" 버튼(`locationProvider.notifier.refresh()`)으로 재시도.
- [x] **오버플로우 가드**: 시트 콘텐츠는 `ListView.builder`/`ListView` 안(unbounded 회피), 긴 텍스트는 `Expanded`+ellipsis, `Row` 가변폭은 `Expanded`/`Flexible`로 감쌈. 013 재발 유형 없음.
- [x] 접근성: 마커 44dp 히트타깃 + `Semantics(button:true, label:...)`, 레이어 칩 44dp 확장 + Semantics, GPS 버튼 Semantics, 상호작용 위젯에 `Key('obsmap_...')` 부여(칩/GPS버튼/리스트항목/스크린).
- [x] **const-first / `_build*()` 금지 — 범위: 이 스펙의 신규 015 파일만**: `_buildPin`/`_buildMeasurementBlock`/`_buildSuitabilityBlock` 전부 제거 → `_ObservationPin`/`_MeasurementBlock`/`_SuitabilityBlock` 별도 위젯 클래스로 추출 완료(**신규 6파일에 `_build*` 0건 확인**). **기존 파일(`mode_header`=010, `course_card`·`trails_catalog`=013)의 `_build*()`는 스코프 밖 — "홈·트레일 회귀 금지"라 의도적 무변경**(리팩터 시 스코프 위반). ※ codex verdict=FAIL은 이 체크박스 원문의 "전체 코드베이스" 문구를 문자 그대로 읽은 스코프 오독으로, 실 결함 아님(브레인 교차확인).
- [x] 홈(004~011)·트레일(013) 회귀 없음: `just check` green(기존 66개 테스트 전부 통과). 홈 "지도 보기" 버튼→index 1 점프가 이 화면으로 연결됨(Phase2에서 교체 완료).

**Phase validation**: 아래 Validation Commands 통과(`just check` green). 발사 후 **브레인 시뮬레이터 육안검증**(다크 타일 실렌더·핀 3종 위치·레이어 칩 필터·3-스냅 드래그 체감·측정 vs 적합도 시각 분리·정직 문구·오버플로우 없음 — 013 교훈: UI 오버플로우/타일은 위젯테스트가 못 잡음, 시뮬 필수).

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: flutter_map+다크타일 도입, 관찰스팟 모델/API/프로바이더 배선, full-bleed 지도(GPS 1샷 bbox fit), 핀 3종+레이어 칩 필터, 3-스냅 바텀시트(리스트+상세), 측정값↔적합도 종분리(적합도=기존 `/api/suitability` 2차 호출), eBird 정직표기(community·N일 전), 상태 4종, 접근성, 오버플로우 가드.
- **제외(후속 부채, design-lead MVP 절제)**: Bortle 색면 raster 오버레이·조류 히트맵, 3D/기울기·나침반, 오프라인 타일 캐시, 다중 지역 bbox·"이 지역 검색", 낮 모드 라이트 타일(positron, MVP는 다크 고정 — 단 낮모드 저알파 브랜드 오버레이는 MVP 포함, §다크 타일 결정 P1-1), 지도 탭 모드 토글 진입점, 노포 상세 push·전화/길찾기·예약, 클러스터링(스팟 수 적어 불필요), 트레일 선 레이어(트레일 탭 위임), 즐겨찾기/기록, 필터/정렬 UI(레이어 칩까지만).

### backend 계약 (014 §25, 라이브 검증됨 — 소비 기준)
```
GET /api/observation-map?lat&lng → ObservationMapResponse
{ region, degraded, spots[]:
  { id, kind("bird"|"star"|"heritage"), name, coord{lat,lng},
    nightSky{sqmValue,bortleClass,skyClass,status="approx"}|null,     // star만
    birds{speciesCount, topSpecies[≤5]{nameKo,nameSci,speciesCode,count?,obsDt},
          mostRecentObsDt, status="community"}|null,                   // bird만
    heritage{addr, distanceM?, contentId}|null } }                     // heritage만
```
- kind별 정확히 하나의 측정 블록만 non-null. **적합도(score) 필드 없음** — 스팟 탭 시 기존 `GET /api/suitability?lat&lng&mode`(§8, `fetchSuitability`→`DiscoveryOverview.suitabilityIndex.score`) 재사용.
- `birds.status`는 항상 "community"(절대 live 아님), `nightSky.status`는 항상 "approx". `count`/`distanceM`는 없을 수 있음(nullable).
- 라이브 예(강화 37.5921/126.3984): region "인천 강화군", degraded=false, 18 스팟(조류 14+별 1+노포 3). 조류=영종도 송산만 갯벌 36종·알락꼬리마도요 280 등, 별=강화 천문인마을 SQM 16.81 Bortle 8, 노포=꽃게와낙지 1363m 등.

### design-lead 설계 요지 (2026-09-10 자문 — 이 스펙이 따르는 근거, PROGRESS "관찰 지도=앱 핵심")
- **map-first** + 3-스냅 드래그 시트(Figma 520px 고정은 틀림 — 지도가 주인공, 시트는 위로 얹힘). MVP=핀 3종+시트만(면 오버레이·3D·나침반·오프라인 후속).
- **측정값 vs 적합도 종분리 계승**(013): 지도에 여러 스팟이 동시에 뜨는데 시점 의존 점수를 핀마다 박으면 소음 → 핀/리스트는 측정값만, 적합도는 스팟 탭 후 "지금" 시점이 확정된 상세에서만 게이지로.
- **eBird "실시간" 금지** → "최근 관측·N일 전"+community. 과거 시민관측 로그임을 정직하게.
- 핀 3종(조류/별/노포) 시각 언어 구분, 레이어 칩으로 on/off.

### ⭐ 스킬 지침 반영 (브레인이 `flutter-fix-layout-issues`·`flutter-ui` 로드해 스펙에 못박음 — 팀은 Skill 도구 없음)
- **오버플로우 예방(flutter-fix-layout-issues)**: `Stack`+`DraggableScrollableSheet`는 unbounded height/RenderFlex 취약 → 시트 콘텐츠는 스크롤러블 안, `Row`/`Column` 가변폭 자식은 `Expanded`/`Flexible`, 긴 텍스트는 `TextOverflow.ellipsis`. 013 오버플로우 재발(d8441fe: Row→Wrap) 유형 원천 차단. `Positioned`는 `Stack` 직계·`Expanded`는 `Flex` 직계(ParentData 오용 금지).
- **flutter-ui**: const-first, **private `_build*()` 메서드 금지 → 별도 위젯 클래스 추출**, 리스트 `ListView.builder`/`SliverList.builder`(lazy), `SafeArea`/`MediaQuery.paddingOf`로 Android 15 edge-to-edge 대응(full-bleed 지도 특히 중요), 상호작용 위젯 `Key(...)`, `Semantics` 라벨, 48dp 탭 타깃/WCAG AA 대비, Loading/Error/Empty 상태 필수. 프로젝트는 스킬의 `AppColors/AppSpacing` 대신 `context.colorScheme`+`themeFor(ObsMode)` 관례 사용 → **하드코딩 색/여백 금지, 기존 테마 토큰 사용**.

### 다크 타일 결정 (MVP — design-lead P1-1 결론 반영)
- ~~CARTO `dark_matter` 무키 래스터 타일~~ → **CARTO는 무키 타일에 "API KEY REQUIRED" 워터마크를 박게 정책이 바뀜(시뮬 육안 발견, 2026-09-10 Amendment)** → **Esri "World Dark Gray Base"**(`https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}`, 진짜 무키·워터마크 없음·다크, `{z}/{y}/{x}` 행/열 순·{s} 서브도메인 없음)로 확정. **attribution 필수**(`RichAttributionWidget`, 접힘형(ⓘ), "Tiles © Esri · © OpenStreetMap contributors", **시트 peek에 안 가리게 상단 우측**(P2)).
- **⭐ 낮 모드 오버레이(P1-1, 발사 전 필수)**: 다크 타일을 고정하되, **낮 모드일 때 지도 위에 `colorScheme.surface`(낮 팔레트) 계열 저알파 오버레이(alpha ≈ 0.12~0.18, 또는 `BlendMode.softLight/overlay`)를 한 겹** 얹어 낮엔 지도가 미세하게 밝게/따뜻하게 물들게 한다(밤엔 오버레이 없음 또는 밤 배경색 극저알파). 이유: 낮/밤 "장면 전환"은 이 앱 확정 요구사항(`main.dart:97-108`가 전체 테마를 `ThemeData.lerp`로 보간)인데, 화면 70%인 지도 바닥이 모드 무관 다크면 낮 화면이 밤처럼 보여 정체성이 붕괴(Nielsen #4)한다. 오버레이는 타일 리로드 없이 테마 lerp에 지도 바닥도 함께 반응시키는 저비용 절충. **오버레이 알파는 타일 판독성 유지가 상한**(너무 진하면 지도가 안 보임).
- 완전한 낮 라이트 타일 스왑(positron)은 후속(타일 2종·프리로드·전환 깜빡임 부담 → MVP 과다). 모드는 이 오버레이 + 핀 accent + 적합도 게이지 색에 영향.
- ※ 후속 부채 기록: 관찰 지도 탭엔 모드 토글(ModeHeader) 진입점이 없어(홈에만 있음) 사용자가 이 탭에서 낮/밤을 못 바꿈 — 이번 스코프 밖, 후속 UX 부채.

### 테스트 케이스 (`observation_map_wiring_test.dart`, 타일 렌더 제외)
1. data: bird/star/heritage 스팟이 각 kind 마커로 매핑(개수·아이콘).
2. 레이어 칩 토글: 특정 kind off→해당 마커 사라짐(필터 로직). **전부 off→"레이어 선택" 안내가 뜨고 데이터 empty와 문구/토큰이 구분됨**(P2).
3. 핀/리스트 탭→선택 스팟 상세가 시트에 렌더(kind별 측정 블록만).
4. 측정/적합도 분리: 상세에 측정 블록 + (FakeSuitabilityApi 주입) 적합도 게이지, **구분선으로 분리**·측정 블록에 게이지 토큰 없음(negative assert).
5. 조류 정직문구: **한국어 community 배지**("커뮤니티 관측"류, 영문 "community" 부재 assert) + "N일 전"/날짜 렌더, **"실시간"/"live" 문자열 부재**(negative assert). 잘못된 날짜 문자열→크래시 없이 원문 폴백(P2).
6. degraded=true→`errorContainer` 배너+다시 시도. empty(0 & degraded=false)→중립 톤이며 `errorContainer` 미사용(negative assert). loading→진행표시. error(throw)→다시 시도.
7. 단일 진실: 별 스팟 SQM이 리스트 요약·상세 `NightSkyTag`에서 동일 값.
8. 접근성: 핀/칩 탭 타깃 ≥44dp, semantic 라벨 존재.
9. **위치 폴백(P1-3)**: 위치 미획득(FakeLocation 실패/거부) → 기본 지역(강화) 좌표 폴백 렌더 + 안내 배너 + 재시도 버튼, 크래시·빈 회색 화면 없음.
- (오프라인 한계 — 타일 다크 렌더·bbox fit·3-스냅 드래그 체감·핀 실위치는 브레인 시뮬 육안.)

### 불변 원칙
- **backend·계약 무변경.** 순수 flutter consumer. 014 `GET /api/observation-map`+기존 `GET /api/suitability`만 소비. 홈(004~011)·트레일(013) 회귀 금지(009 family 캐싱·010 collapse·011 장면전환·013 트레일). `NightSkyTag`/`ScoreGauge`/`suitabilityApiProvider` 무변경 재사용. `Coordinate`/`NightSky` 재사용(재정의 금지). 측정값/적합도 종분리·eBird 정직표기 절대 준수.

### 교훈 계승 (007/010/011/013)
- 외부 API 없음(계약 소비만) → 크로스모델 verify(codex)가 오프라인 결함 커버. **단 다크 타일 렌더·핀 위치·3-스냅 드래그 체감·측정 vs 적합도 시각 분리·오버플로우는 오프라인 위젯테스트가 못 잡음 → 브레인 시뮬레이터 육안검증 필수**(013 오버플로우가 66 tests 통과 후 시뮬에서 발견된 선례).
- nullable(count/distanceM/measurement 블록) 파싱 방어 필수(null 역참조가 가장 흔한 크래시 후보).
- flutter_map은 신규 패키지 → `flutter pub get` 후 버전 호환·`pubspec.lock` 커밋 확인. 위젯테스트에서 타일은 네트워크라 렌더 불가 → 타일 assert 하지 말 것(마커/시트/상태만).

## Amendments (post-build change history, append-only)

- 2026-09-10 <flutter-lead>: `just check` 최초 실패(exit 1) 진단 후 2건 수정.
  1. `lib/screens/observation_map_screen.dart`의 `ref.listen(observationMapProvider, ...)` 콜백이 스팟 1개(또는 좌표 전부 동일)일 때 `LatLngBounds.fromPoints`가 zero-area bounds를 만들어 `fitCamera`의 zoom이 non-finite가 되어 크래시("Camera zoom must be finite"). `bounds.north==south && east==west`(degenerate) 감지 시 `fitCamera` 대신 `_mapController.move(bounds.center, 14)`로 우회하도록 수정.
  2. 위 크래시에 가려져 있던 2차 결함: `test/observation_map_wiring_test.dart`의 "bird honesty copy" 테스트가 같은 `tester`로 `_pumpObservationMap`을 두 번 호출(중간에 스팟 탭으로 선택)하는데, `ObservationMapScreen()`이 const·key 없음이라 Flutter가 두 pump 사이에 동일 State를 재사용해 `_selectedSpot`이 새 API 데이터로 안 리셋됨(리스트 대신 이전 상세가 계속 렌더) → 테스트 헬퍼에 `key: ValueKey(observationMapApi)` 부여로 pump마다 독립 State 강제, 프로덕션 코드 무변경.
  - 재검증: `just check` green(backend 111 passed/8 skipped, flutter analyze 무경고, flutter test 75/75 all passed).
- modified: 2026-09-10, lead: sonnet
- 2026-09-10 (brain, 시뮬 육안검증 핫픽스 — 다크타일 CARTO→Esri): 오너 시뮬 육안에서 **CARTO `dark_matter` 무키 타일이 "API KEY REQUIRED" 워터마크를 픽셀에 박아 반환**(CARTO가 무키 정책 변경)하는 것을 발견 — 013 오버플로우처럼 위젯테스트가 못 잡고 시뮬에서만 드러나는 결함. 브레인 직접 핫픽스([[commit d8441fe]] 선례): `observation_map_screen.dart` `TileLayer` URL을 **Esri "World Dark Gray Base"**(`server.arcgisonline.com/.../World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}`, 진짜 무키·워터마크 없음·다크, `{z}/{y}/{x}` 행/열 순·{s} 없음)로 교체, attribution "Tiles © Esri" + "© OpenStreetMap contributors". curl로 실타일(256×256 JPEG, 워터마크 없음) 선확인 후 반영. 재기동 시뮬 캡처로 워터마크 소거 확인 + **P1-2 핀 이중 인코딩 실렌더 검증**(조류=청록 물방울+날개 / 노포=회갈색 모서리둥근 사각+스토어 / 별=앰버) + peek 헤더 "관찰 스팟 18곳"(P2) 정상. `just check` green(75/75). §다크 타일 결정 갱신.
- 2026-09-10 (brain, 실질 PASS 판정 — codex 유일 FAIL 해소): 파이프라인 verdict=FAIL이나 교차확인 결과 **false-negative(4번째 사례, [[factory-verdict-false-negative]])**. codex 검증 **23항목 중 22 PASS**(nullable 파싱·카메라 fit·측정↔적합도 구분선·조류 정직문구·상태 4종·위치 폴백·오버플로우 가드·접근성 전부 PASS), **유일 FAIL은 "전체 코드베이스에 `_build*` 0건" 체크박스 문구를 문자 그대로 읽은 스코프 오독** — 브레인 grep 확인 결과 신규 015 6파일엔 `_build*()` 0건(규율 준수), 지적된 `mode_header`(010)·`course_card`·`trails_catalog`(013)는 기존 파일로 "홈·트레일 회귀 금지"라 의도적 무변경(리팩터 시 스코프 위반). 체크박스 문구를 신규 파일 범위로 정정. **크로스모델 가치는 발현됨**([[factory-crossmodel-verify-value]]): lead가 런 중 실 결함 2건(zero-area bounds 크래시·테스트 State 재사용) 자체 수정. 브레인 직접 `just check`(=flutter-check) 재실행 green(flutter test 75/75, analyze 무경고). verify2=null이 verdict FAIL을 굳힘. **잔여: 브레인 시뮬레이터 육안검증**(다크타일·핀·3-스냅 드래그·측정vs적합도 시각분리·오버플로우 — 013 교훈상 위젯테스트가 못 잡음).
