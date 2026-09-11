# 조류 스팟 탭 → 확대 + 개체 산포 리빌 (관측지 핀을 개별 새 마커로 펼치기)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-11
- modified: 2026-09-11 <brain/orchestrator>
- modified: 2026-09-11 <brain/orchestrator> — design-lead 검수 조건부 GO 반영(P1 6: 확대=줌15·`_revealAboveSheet` 재사용/카메라 점프 · 산포 중 라벨 억제(`computeLabeledSpotIds` 인자) · 각 종 최소1개+비례+축소 시만 "대표 표시" 캡션 · 단일 실루엣/색통일/핀과 형태위계 구분 · 리버트 줌<13+stagger fade-scale-in · 개체 탭=종명 툴팁(시트 금지)/44dp. P2 5→후속). Phase 0 통과, 발사 준비.
- refs: `specs/016-observation-map-figma-parity-flutter.md`(관찰지도 확장·핀/시트/라벨·`buildObservationMarkers`·`_selectSpot`/`_revealAboveSheet` 카메라 이동), `specs/015-observation-map-flutter.md`(측정/적합도 종분리·`ObservationSpot.birds.topSpecies`), `apps/flutter/lib/screens/observation_map_screen.dart`(`MapController`·선택 상태·MarkerLayer), `apps/flutter/lib/widgets/observation_marker.dart`(핀 위젯·`buildObservationMarkers`), `apps/flutter/lib/models/observation_map.dart`(`BirdObservation.topSpecies[{nameKo,count}]`), 오너 요청(2026-09-11, 스크린샷 2장: "새가 그냥 써있잖아. 개별 새 모양이 각각 있었으면. 장소 이름 누르면 확대되며 랜덤으로 새들이 지도에 찍히게")
- risk: medium - 순수 flutter 인터랙션 추가(backend·계약 무변경). 조류 스팟 탭 시 카메라 확대 + 그 스팟의 개체를 좌표 주변 랜덤 산포 마커로 렌더. 기존 선택/시트/라벨 배선 회귀 금지(016).

## Purpose

관찰 지도에서 조류 관측지 핀이 "장소"만 찍고 종은 시트에 텍스트로만 나오는 걸, **장소를 탭하면 그 지점으로 확대되며 관측된 새들이 개별 새 마커로 지도에 흩뿌려지는** 리빌 인터랙션으로 바꿔 "새를 관찰한다"는 앱의 정체성을 지도에서 직접 보여준다.

## Problem

1. 조류 스팟 탭 시 종 정보는 **시트 텍스트 목록**("Pileated Woodpecker · 2마리")으로만 보이고, 지도에는 개별 새가 없다 — 오너가 원한 "새 모양이 각각 지도에 찍히는" 그림과 다르다.
2. eBird는 개체별 GPS가 아니라 **관측지(locId)별 집계**만 주므로 실제 새 좌표를 찍을 수 없다 → 대안 필요.

## Solution

조류 스팟(핀 또는 시트 리스트)을 탭하면 (1) 카메라가 그 스팟 좌표로 **확대 이동**하고, (2) 그 스팟 `birds.topSpecies`의 개체수만큼 **좌표 주변에 결정적(seed=spot.id) 랜덤 산포된 새 마커**를 렌더한다. 각 마커는 새 실루엣 아이콘(종별 구분)이고, 다른 스팟 선택·줌아웃·시트 닫기 시 산포가 걷히고 관측지 핀으로 복귀한다. 개체수는 `topSpecies.count` 합(가시 상한으로 바운딩)이며, 이는 **측정 데이터(관측 개체수) 시각화**다(적합도 아님 — 종분리 유지).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/observation_map_screen.dart` - 조류 스팟 선택 시 카메라 확대(`_selectSpot`에 zoom-in 추가 or 신규 분기) + 산포 마커 레이어 추가(`MarkerLayer` 또는 별도 레이어). 선택 해제/줌아웃/시트 닫기 시 산포 제거. 기존 `_revealAboveSheet`·라벨·016 배선 회귀 금지.
- `apps/flutter/lib/widgets/observation_marker.dart` - 새 개체 마커(신규 위젯 or 확장). 관측지 핀(`ObservationMarker`)과 구분되는 **개체 새 마커**(작은 새 실루엣). `_build*()` 금지(별도 위젯 클래스).
- `apps/flutter/lib/models/observation_map.dart` - **무변경 재사용**. `BirdObservation.topSpecies[{nameKo, nameSci, count}]`에서 개체 산포 목록 생성.

### New Files

- `apps/flutter/lib/utils/bird_scatter.dart` - **순수 함수**: `List<ScatteredBird> scatterBirds({required Coordinate center, required List<BirdSpecies> topSpecies, required String seed, int maxIndividuals = 25, double radiusMeters = 400})`. 종별 count만큼 개체를 만들되 합이 `maxIndividuals` 초과 시 비례 축소, `seed`(spot.id) 기반 결정적 난수로 center 주변 반경 내 좌표 산포(같은 스팟은 항상 같은 배치). `ScatteredBird(coord, nameKo, speciesCode)`. 네트워크·State 없음(단위테스트 가능).
- `apps/flutter/test/bird_scatter_test.dart` - `scatterBirds` 단위테스트(개체수=count 합 or 상한, 결정적 재현성(같은 seed→같은 좌표), 반경 내, count=null 방어) + 위젯테스트(조류 스팟 탭→산포 마커 렌더·비조류 탭→산포 없음·다른 선택/해제 시 산포 제거).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 0: 발사 전 design-lead 검수 (브레인 선행 — flutter 발사 금지 게이트)

오너 인터랙션 요청을 design-lead가 UX로 다듬는다(오너 방향=산포 리빌은 고정, 실행만).

- [x] design-lead 검수 → **조건부 GO**(2026-09-11). P1 6건을 아래 Phase 1~4에 확정 반영(확대 정의·라벨 억제·정직 축소·마커 시각·리빌 모션·개체 탭 툴팁). P2 5건은 §후속 부채. **핵심 지적: 016의 `_selectSpot`/`_revealAboveSheet`는 줌을 안 바꾸고 pan만 하며(줌 유지), 확대(z15) 시 `computeLabeledSpotIds` 줌 임계(11)를 넘어 주변 핀 라벨이 폭발 → 산포와 겹쳐 과밀. 확대 로직과 라벨 억제를 함께 짜야 함.**

**Phase validation**: design-lead 검수 통과(조건부 GO, P1 6 반영). ✅ → flutter 발사 가능.

### Phase 1: 산포 순수 로직 (bird_scatter.dart)

- [x] `bird_scatter.dart`: `scatterBirds`(결정적 seed 산포, 반경 내, null 방어). **P1-3 정직한 축소**: 상한 25, 합>25면 축소하되 **각 종 최소 1개 보장 후 잔여를 비례 배분**(280+2+1 → 알락꼬리마도요가 25 다 먹고 희귀종 0 되는 것 금지 — "어떤 종이 있었나"가 탐조 핵심). count=null이면 1로 취급. **축소 발생 여부(`wasReduced`)와 실제 총합을 반환**해 캡션에 사용. 반환 리스트 순서는 결정적(stagger 인덱스로 재사용, P1-5).
- [x] `bird_scatter_test.dart` 단위테스트: 개체수(합≤25), **결정성(같은 seed→같은 좌표·같은 순서)**, 반경 내, null 방어, **P1-3 케이스(280/2/1 → 각 종 ≥1, 합≤25, wasReduced=true)**, 상한 이하(6마리 → wasReduced=false, 산포=실제).

**Phase validation**: `just check` green(순수 로직 테스트 통과). ✅ 확인(2026-09-11, lead): analyze 0 issues, 113→119 tests(신규 6개 전부 통과).

### Phase 2: 개체 새 마커 위젯 + 산포 렌더

- [x] **P1-4 개체 새 마커 = 단일 실루엣·색 통일**(종별 실루엣/색 구분 안 함 — 12~16px에서 마도요/딱따구리 구분은 비현실적이고 "이 픽셀=이 종"은 거짓 정밀도). 기존 `_BirdSilhouettePainter`(단일 실루엣) 재사용. **관측지 핀과 형태 위계로 구분**: 핀=청록 물방울(teardrop box, 좌표 앵커) / 개체=**teardrop 없는 밝은 실루엣 글리프 14~16px**(가벼운 "흩뿌려진 존재"). 다크타일 대비 위해 실루엣에 얇은 그림자(alpha 0.4 black blur 2) 1겹. 별도 위젯 클래스(`_build*()` 금지). → `ScatteredBirdMarker`(observation_marker.dart), `markerBoxSize=44`, 탭/Semantics 없음(Phase 4에서 추가).
- [x] 조류 스팟 선택 시 `scatterBirds` 결과를 `MarkerLayer`로 렌더(비조류 스팟은 산포 없음). **축소 발생 시(`wasReduced`)만 "관측 N마리 · 대표 표시" 캡션**(선택 스팟 라벨 or 좌하단; 상한 이하면 캡션 없음 — 산포=실제라 이미 정직). 시트 헤더 정확 수치("280마리")는 016대로 유지. → `observation_map_screen.dart` build()에 `scatterResult` 파생값 + `_ScatteredBirdCaptionBanner`(totalCount 기반) 추가.

**Phase validation**: `just check` green(산포 마커 렌더·조류만 위젯테스트). ✅ 확인(2026-09-11, lead): analyze 0 issues, 119→122 tests(신규 3개 전부 통과 — bird-001 25개 렌더/캡션 없음, star-001 0개, 300마리 축소 시 캡션 1회).

### Phase 3: 확대 리빌 + 리버트 배선

- [x] **P1-1 확대 정의**: 조류 스팟 탭 → 카메라 **줌 15**로 이동. **기존 `_revealAboveSheet`의 pan(시트 위로 shift) 로직을 재사용**하되 `camera.zoom` 대신 목표 줌 15를 넘기는 최소 변경(새 pan 알고리즘 재발명 금지 = 016 회귀 방지). **카메라는 애니메이션 없이 `move`로 점프**(신규 패키지 금지) — "리빌 연출"은 카메라가 아니라 개체 마커 등장 애니메이션이 담당. → `_revealAboveSheet(spot, {targetZoom})`, 픽셀 오프셋 계산은 무변경, 마지막 `move` 호출만 변경.
- [x] **P1-2 산포 중 라벨 억제**(과밀 근본 차단): 산포 활성 중엔 **선택 스팟 1개만 라벨, 주변 미선택 핀 라벨은 zoom 무관 억제**. `computeLabeledSpotIds`에 `scatterActive` 인자 추가 → true면 zoom 값과 무관하게 "선택만 라벨" 경로(순수 함수 유지, 테스트 가능). 확대(z15)가 임계 11을 넘겨 주변 라벨이 켜지는 것을 막음. → `scatterActive` 파라미터(기본 false, 기존 동작 무변경) + `buildObservationMarkers`/화면 호출부까지 배선.
- [x] **P1-5 리빌/리버트 모션·트리거**: 등장 = **stagger fade+scale-in**(center 가까운 개체부터, 개체별 20~30ms 간격, 각 200ms fade 0→1 + scale 0.6→1.0 easeOut, 총 ≤~1초 = "장소에서 새가 퍼져나감"). stagger 순서 = `scatterBirds` 반환 순서(결정적). 리버트 = **일괄 150ms fade-out**(역 stagger 안 함). **리버트 트리거 3개: (a) 다른 스팟 탭, (b) `mapEventStream` camera.zoom < 13, (c) 시트가 mid-snap 이상 확장**(016 `_peekOverlayOpacity` 임계 재사용). 빈 지도 탭 선택해제는 016에 없으니 신설 금지(후속). 상태 누수 없음. → `_scatterSpot`/`_scatterVisible` 상태 + `_activateScatter`/`_revertScatter`(idempotent)/`_handleScatterMapEvent`/`_handleScatterSheetSize` + `_StaggeredBirdEntrance`(index*25ms 지연 fade+scale) + 마커별 `ValueKey(spotId_i)`로 스팟 전환 시 리빌 재생.

**Phase validation**: `just check` green(탭→확대+산포, 해제→복귀 위젯테스트). ✅ 확인(2026-09-11, lead): analyze 0 issues, 123 tests(신규 1개, bird-001 선택 후 heritage-001로 전환 시 산포 완전 해제 — star-001은 줌15 이후 뷰포트 밖으로 컬링되어 탭 불가라 근접한 heritage-001로 교체, 2회 재위임 끝에 통과).

### Phase 4: 접근성 + 오버플로우 가드 + 통합 검증

- [ ] **P1-6 개체 마커 탭 = 종명 툴팁**(시트 상세 금지 — 개체는 대표 표현이라 "이 1마리" 상세는 거짓 정밀도이고 시트는 관측지 상세로 점유됨). 탭 → 짧은 종명 툴팁(개체 위 말풍선 or 하단 스낵바 톤, 축소 시 "관측 N마리 · 대표 표시" 병기). **탭 타깃 44dp**(투명 히트박스로 14~16px 글리프 감싸기, 016 `pinBoxSize` 패턴). Semantics 라벨=종명 필수.
- [ ] 오버플로우/const/`_build*()` 금지(016 계승). 산포 마커가 라벨/오버레이/시트와 시각 충돌 없음.
- [ ] 홈·트레일·015·016 회귀 없음: `just check` green(기존 전부 + 신규).

**Phase validation**: 아래 Validation Commands green. 발사 후 브레인 시뮬 육안(탭→확대→새 산포 실렌더, 위젯테스트가 못 잡는 산포 밀도·모션·아이콘).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: 조류 스팟 탭 시 카메라 확대 + 개체 산포 새 마커(결정적 랜덤), 리빌/리버트, 개체수 상한·반경 바운딩, 종별 구분(design-lead), 순수 산포 로직. **flutter consumer(backend 무변경)**.
- **제외(후속)**: 실제 개체 GPS(eBird 미제공), 새 종별 사진/도감 연동, 산포 새의 이동 애니메이션(정적 배치까지), 별/노포의 유사 산포(조류만).

### 데이터 재사용 (backend 무변경)
- `ObservationSpot.birds.topSpecies[{nameKo, nameSci, speciesCode, count}]` + `speciesCount`. 개체 산포 수 = topSpecies count 합(가시), 상한 초과 시 비례 축소. count=null이면 1로 취급 or 제외(빌더/디자인 판단).
- 라이브 예: Phoenix Lake = Pileated Woodpecker 2 + American Kestrel 2 + Northern Flicker 1 + White-breasted Nuthatch 1 = 6개체 산포. 강화 영종도 송산만 = 알락꼬리마도요 280 등(→ 상한 25로 바운딩).

### 설계 긴장 (design-lead Phase 0)
- **측정/적합도 종분리 유지**: 산포는 관측 개체수(측정) 시각화. 적합도 아님.
- **과밀 방지**: 알락꼬리마도요 280 같은 대량은 상한(예 25)으로 바운딩 — 실제 수는 시트 텍스트에 그대로("280마리"), 지도 산포는 대표 표현임을 UX로 정직하게(라벨/캡션).
- **결정성**: seed=spot.id로 재빌드·재선택 시 같은 배치(새가 매번 순간이동하면 안 됨).

### 비조류 스팟 확대 비대칭 (design-lead P2-3, 의도된 설계)
- 조류 스팟만 z15 확대+산포, 별/노포는 016대로 pan만(줌 유지). 탭 거동이 종류별로 달라지지만 **의도**: 조류=개체 리빌이 앱 정체성, 별/노포=점 데이터라 확대 실익 없음. 혼란되면 후속에서 통일 검토.

### 후속 UX 부채 (design-lead P2, 이번 스코프 밖)
- P2-1 산포 반경을 개체수 비례(sqrt 스케일 250~450m, 밀도 균질) · P2-2 최소 개체 간격(포아송 디스크/rejection sampling, 겹침 방지 — 25 상한이면 순수 랜덤도 대개 견딤) · P2-4 산포 중 미선택 핀 dim(opacity 0.4, 라벨 억제로 충분하나 여유 시) · P2-5 밤 모드 적색필터에서 흰 실루엣 판독 시뮬 육안 확인.

### 불변 원칙
- backend·계약 무변경. 순수 flutter. 015/016/홈/트레일 회귀 금지. 측정/적합도 종분리·eBird 정직표기 계승. Esri 다크타일·라벨(016) 유지. **신규 패키지 금지**(카메라 애니메이션 패키지 도입 안 함 — P1-1).

### 교훈 계승 (013/015/016)
- 산포 밀도·모션·아이콘·확대 체감은 오프라인 위젯테스트가 못 잡음 → 브레인 시뮬 육안 필수(단 시뮬 위치권한 다이얼로그는 오너 탭 필요 — 자동화 도구 없음).

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
