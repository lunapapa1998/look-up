# 관찰 지도 UX 개선 묶음 (줌 한정·회전잠금·산포=종수·핸들드래그·검색노출·개체 종명/상세·상대시간·이곳재검색)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- modified: 2026-09-13 <brain/orchestrator> — design-lead 검수 조건부 GO 반영(P1 5+P2 4+문구7). 핵심: maxZoom 16 하드클램프(Esri 타일 z16 상한="Map data not yet available"의 정체)·minZoom7·한국bounds(33,124.5~38.7,131.9)·회전 완전비활성+나침반 제거·종명라벨은 선택스팟 산포한정·종상세 별도modal·검색바 peek0.24 고정. Phase 0 통과.
- modified: 2026-09-13, lead: sonnet — Phase 1~5 전체 구현·검증 완료(`just check` green, 133개 테스트/analyze 0 issues). 임시 줌 오버레이 확정값만 오너 실기기 리뷰 대기(Amendments 참고).
- modified: 2026-09-13, lead: sonnet — 크로스모델 검증 FAIL 5건 재수정 완료(`just check` green, 133개 테스트/analyze 0 issues). Amendments 참고.
- refs: `specs/017-bird-scatter-reveal-flutter.md`(산포 리빌·`bird_scatter.dart`·`ScatteredBirdMarker`·`_revealAboveSheet` 줌15), `specs/016-observation-map-figma-parity-flutter.md`(레이어칩·검색/필터 시트·나침반·오버레이·`computeLabeledSpotIds`), `specs/018-observation-map-ebird-hotspot-names-backend.md`(조류 스팟 name 정제 — 이 스펙의 라벨이 깔끔해짐), `apps/flutter/lib/screens/observation_map_screen.dart`(MapOptions·시트·산포·MapController), `apps/flutter/lib/widgets/observation_marker.dart`(핀·산포 마커·라벨), `apps/flutter/lib/widgets/observation_spot_sheet.dart`(시트·검색바), `apps/flutter/lib/utils/bird_scatter.dart`(산포), 오너 실기기 피드백(2026-09-13, `docs/observation-map-ux-checklist.md` §2)
- risk: high - 관찰 지도(핵심 화면) 다항목 개선. MapOptions(줌 min/max·카메라 bounds·회전 플래그)·산포 로직(종수)·시트 드래그·검색 노출·개체 마커(종명 상시+탭→시트)·상대시간·재검색 프로바이더. 순수 flutter consumer(backend 무변경, 018이 name 품질만 개선). 015~017·홈·트레일 회귀 금지.

## Purpose

오너 실기기 육안검증에서 나온 관찰 지도 UX 문제 8건(과도 확대·회전 불편·산포 개수·핸들 드래그·검색바 미노출·개체 마커 정보·상대시간·지역 고정)을 한 번에 개선한다.

## Problem

`docs/observation-map-ux-checklist.md` §2 참조. 핵심: (1) 너무 확대하면 "Map data not yet available"(줌 상한 없음), (2) 확대 중 지도가 회전, (3) 산포가 개체수(대량)라 과밀, (4) 시트 핸들 드래그가 안 됨, (5) 검색바가 안 보임, (6) 개체 마커에 종 정보 없음·툴팁이 순삭, (7) "N일 전"만 있고 시간 단위 없음, (8) 최초 지역 정보만 보임(지도 이동해도 재검색 없음).

## Solution

(1) `MapOptions`에 **minZoom/maxZoom + 한국 bounds `CameraConstraint` + 회전 비활성**(줌 중 회전 금지). 최적값 탐색용 **임시 줌 테스트 오버레이**(현재 줌 표시 + min/max 조절 버튼)를 debug에 넣어 오너가 1빌드로 결정. (2) 산포를 **종(species) 수 기준**으로(조류 4종 → 마커 4개). (3) 시트 **핸들 드래그로 리사이즈**. (4) 검색바를 **시트 상단 고정 노출**. (5) 개체 마커에 **종명 상시 표시 + 배경/44dp 히트영역**, 탭 → **바텀시트 종 상세**(종명·학명·개체수·관측시각·관측 위치; 사진·특징은 데이터원 필요로 후속). (6) 상대시간 **"N시간 전"/"N일 전"**(obsDt 기준, <24h=시간). (7) **"이곳에서 다시 검색"** 버튼(지도 중심 좌표로 재조회).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/observation_map_screen.dart` - `MapOptions`(minZoom/maxZoom·`CameraConstraint.contain(bounds: 한국)`·`InteractionOptions(flags: ~rotate)`); 임시 줌 테스트 오버레이(debug); 시트 핸들 드래그 배선; "이곳에서 다시 검색" 버튼(지도 중심으로 재조회); 산포 종수 반영; 개체 마커 탭→시트 종상세 전환.
- `apps/flutter/lib/widgets/observation_marker.dart` - `ScatteredBirdMarker`에 **종명 라벨 상시 표시 + 반투명 배경 pill + 44dp 히트영역**(현재 배경 없어 누르기 어려움). 온-맵 스팟 라벨은 018이 정제한 깔끔한 name 사용(변경 최소).
- `apps/flutter/lib/widgets/observation_spot_sheet.dart` - 검색바를 스크롤 영역 안(016 오버플로우 수정 잔재)에서 **peek 위 고정 노출**로. 종 상세 뷰(개체 탭 시) 분기 추가 or 신규 위젯.
- `apps/flutter/lib/utils/bird_scatter.dart` - 산포 개수 = **종 수**(topSpecies 길이)로 변경. 각 종 1마커(종명 보유). count는 마커 라벨/상세에 표기(개체수). 상한/결정성 유지.
- `apps/flutter/lib/utils/trail_format.dart` (or 신규 `relative_time.dart`) - obsDt("2026-09-12 18:52") → 상대시간("방금"/"N시간 전"/"N일 전") 순수 헬퍼, `nowProvider` 기준, 파싱 실패 시 원문.

### New Files

- `apps/flutter/lib/widgets/bird_species_detail.dart` (또는 시트 내 분기) - 개체 탭 시 종 상세(종명·학명·개체수·관측시각·관측 위치=스팟명/좌표). **사진·특징은 placeholder + "추후 제공"**(데이터원 후속). `_build*()` 금지.
- 테스트: 줌 제약·회전 플래그·산포 종수·핸들 드래그·검색 노출·개체 종명/탭→상세·상대시간·재검색 위젯/단위테스트.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 0: 발사 전 design-lead 검수 (브레인 선행 — 발사 금지 게이트)

- [x] design-lead 검수 → **조건부 GO**(2026-09-13). P1 5+P2 4+문구7 전부 아래 Phase에 반영. 핵심 결정: ① maxZoom **16 하드클램프**(Esri z16 상한)·minZoom7·bounds(33,124.5~38.7,131.9)·오버레이는 중심좌표 표시+확정값 Amendments 기록, ② 회전 **완전 비활성**(`~rotate & ~rotateWithScroll`)+**나침반 화면배선/016테스트 제거**(회전0이면 죽은UI), ③ 종명 라벨 **선택스팟 산포 한정**+`surfaceContainerHighest` pill 재사용+y정렬 depth, 개체수는 라벨 아닌 상세, ④ 종상세 **별도 modal**·"특징" 데이터없으면 미렌더·사진영역=실루엣글리프+중립톤, ⑤ 검색바 peek **0.24**로 승격 고정(정렬칩은 잔류)·peekHeight 단일상수+오버레이 앵커/임계 연동.

**Phase validation**: design-lead 검수 통과(조건부 GO, P1 5+P2 4 반영). ✅ → flutter 발사 가능.

### Phase 1: 줌/카메라 제약 + 회전 잠금 + 임시 줌 테스트 오버레이

- [x] **P1-1 줌/카메라 제약**: `MapOptions`에 `minZoom: 7`, **`maxZoom: 16` (Esri World_Dark_Gray_Base 타일이 z16까지만 존재 — z17+가 "Map data not yet available"의 정체. 하드 상한)**, `CameraConstraint.contain(bounds: LatLngBounds(LatLng(33.0,124.5), LatLng(38.7,131.9)))`(제주남단·독도 포함 한국).
- [x] **P1-2 회전 완전 비활성 + 나침반 제거**: `InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)`(flutter_map 8.3.2엔 별도 `rotateWithScroll` 상수가 없음 — `rotate` 하나로 회전 전부 비활성; 확대/축소 중 우발 회전 원천 차단, E-21). `observation_map_screen.dart`의 우하단 `CompassButton` Positioned 배선 **제거**(회전0이면 자기숨김=죽은 UI+죽은 `StreamBuilder` 리빌드). `CompassButton` 위젯 파일은 남기되(016 참조), **016 나침반 등장/리셋 위젯테스트는 skip/삭제**(회귀 게이트 방지). 좌하단 `TideMoonOverlay`는 존치.
- [x] **P1-1 임시 줌 테스트 오버레이(`kDebugMode` 전용)**: (a) 현재 zoom 실시간(소수1자리), (b) **현재 카메라 중심 LatLng**(오너 스샷 리포트 재현용), (c) min/max 스테퍼(**max 상한 16 하드클램프**, 이유 "타일 z16까지" 1줄 노출). `// TODO(019): 값 확정 후 제거` 주석. **완료조건: 오너가 정한 확정 min/max를 Amendments에 기록.**(오버레이 자체는 배선 완료 — 확정 min/max 값은 오너 실기기 리뷰 후 Amendments에 추가 예정)

**Phase validation**: `just check` green. 발사 후 브레인 시뮬 + 오너 실기기(줌 한계·회전잠금 체감).

### Phase 2: 산포 = 종 수 + 개체 마커 종명 상시 + 탭→시트 종 상세

- [x] **P2-1 산포 = 종 수**: `bird_scatter.dart` = `topSpecies` 하나당 마커 1개(종명·count 보유). count-비례 allocation 로직 제거/대체. `wasReduced` 재정의 = `topSpecies.length < speciesCount`(상위 종만 표시). 캡션 문구 "관측 N마리 · 대표 표시" → **"관측 N종 중 상위 M종 표시"**(`_ScatteredBirdCaptionBanner` 재작성). 결정성(seed 동일→동일 배치)·반경 유지. 단위테스트(4종→4마커·종명 매핑·동일 seed 동일 배치).
- [x] **P1-3 종명 라벨 = 선택 스팟 산포에만**(산포는 `_scatterSpot` 단일이라 전역 클러터 아님): `ScatteredBirdMarker`에 pill 추가 — **`_ObservationLabelPill`과 동일 토큰 재사용**(`surfaceContainerHighest` 불투명·`onSurface`, 016에서 WCAG 4.5:1 검증됨 — 새 반투명 배경 발명 금지). 글리프 왼쪽·종명 오른쪽, `maxLines:1+ellipsis+maxWidth 96`. **44dp 히트영역**(현재 배경 없어 탭 어려움). 겹침: 개체 마커 **y좌표 내림차순 그리기**(아래 pill이 위에 그려지는 depth), leader line은 후속 부채. **개체수는 라벨에 넣지 말 것**(pill 길어져 겹침 악화 — 개체수는 종 상세로).
- [x] **P1-4 개체 탭 → 종 상세 별도 modal**(스낵바 `_showBirdSpeciesTooltip` 폐기, 기존 `ObservationSpotSheet` 상태머신 무건드림): `showModalBottomSheet`로 종상세 = 종명·학명(`nameSci`)·개체수(`count`)·관측시각(상대시간)·관측 위치(스팟명/좌표). **사진영역 = 회색박스 아니라 `_BirdSilhouettePainter` 크게+`surfaceContainer` 배경 + "사진은 준비 중이에요"(중립톤, errorContainer 금지)**. **"특징" 섹션은 데이터 없으므로 렌더하지 말 것**(빈 헤더+"추후제공" 금지, TideMoonOverlay 데이터없음 미렌더 원칙). 하단 "커뮤니티 관측 · N일 전" 배지("실시간" 금지). Semantics 종명.

**Phase validation**: `just check` green(산포 종수·마커 종명·탭→시트 종상세 위젯테스트).

### Phase 3: 시트 핸들 드래그 리사이즈 + 검색바 고정 노출

- [x] **P1-5 검색바 고정 노출 + peek 0.24**(D-17): peek을 0.16→**0.24**로 상향(grabber+타이틀+검색 TextField 수용). `initialChildSize`/`minChildSize`/`snapSizes[0]` 동시 0.24. 레이아웃 재배치: grabber→헤더(타이틀+카운트)→**검색 TextField를 `Expanded` 바깥(고정)**, `Expanded` 안엔 **정렬/SQM 칩 + 리스트만**(정렬칩은 스크롤 잔류 — peek 더 안 키움). 검색→지도·리스트 동시 필터(기존). 검색바는 `selectedSpot==null`(리스트)일 때만.
- [x] **peekHeight 단일 상수화 + 오버레이 연동**: 현재 `0.16` 하드코딩 3곳(좌우하단 오버레이 앵커 `peekHeight+16`, `_peekOverlayOpacity` 0.2 임계)을 **단일 상수(0.24)로 수렴**해 검색바/오버레이 충돌·조기 페이드 방지. Phase 검증에 **"peek에서 오버레이 미충돌"** 항목 추가. (`kObsSheetPeek = 0.24`를 `observation_spot_sheet.dart`에 선언, `_peekOverlayOpacity` 임계는 `kObsSheetPeek + 0.04`로 재계산 — 위젯테스트로 peek에서 검색바+조석/달 오버레이 동시 노출 확인)
- [x] **P2-4 핸들 드래그 리사이즈**(D-15): grabber+헤더를 `GestureDetector(onVerticalDragUpdate)`로 감싸 `DraggableScrollableController` size 직접 갱신. 드래그 중 free, `onVerticalDragEnd`에서 가장 가까운 snapSize(0.24/0.45/0.9)로 `animateTo`(스냅 유지). snapSizes는 위 단일 상수 공유(하드코딩 불일치 금지). (플러터에서 grabber 드래그는 기본 미지원이라 이 배선이 필요 — 오너 질문 답.)

**Phase validation**: `just check` green(핸들 드래그로 시트 크기 변화·검색바 가시성 위젯테스트).

### Phase 4: 상대시간 + "이곳에서 다시 검색"

- [x] **P2-2 상대시간 헬퍼**(순수, `now` 파라미터): obsDt → `<1분`"방금"/`<60분`"N분 전"/`<24h`"N시간 전"/그외"N일 전". 호출부에서 **기존 `nowProvider`(discovery_providers.dart) 주입**(신규 clock 금지). **파싱 실패·미래시각(now보다 뒤) 시 원문 폴백**(미래가 "0시간 전" 뜨면 신뢰 훼손). 적용: 조류 상세·종 상세 modal(라벨엔 넣지 말 것). 016 "N일 전" 표기도 이 헬퍼로 수렴(중복 배선 금지).
- [x] **P2-3 "이곳에서 다시 검색"**(B): **상단 중앙**(레이어칩 아래) pill 버튼(`Icons.refresh`, "이 지역에서 검색") — 하단은 시트·오버레이로 혼잡, 지도앱 관례도 상단. **등장 조건**: `MapEventMoveEnd`에서 지도 중심이 최초 조회 중심에서 뷰포트 대각선 ~30% 이상 벗어났을 때만(살짝 움직임엔 안 뜸). 탭 → 인라인 스피너("검색 중") → 현재 중심 좌표로 `/api/observation-map` 재조회. 실패 시 기존 `_ErrorStatusBanner` 재사용. **provider에 center 오버라이드 경로 추가**(GPS center와 공존 — GPS 버튼 누르면 위치 기반 복귀), 009 캐싱·홈 회귀 금지. **재조회 시 `_selectedSpot`/`_scatterSpot` 초기화**(옛 스팟이 새 결과에 없을 수 있음 — dangling 방지).

**Phase validation**: `just check` green(상대시간·재검색 재조회 위젯테스트).

### Phase 5: 접근성 + 회귀 검증

- [x] const/`_build*()` 금지·오버플로우 가드(016/017 계승). 개체 종명 pill·재검색 버튼·종상세 탭타깃 44dp·Semantics. (`_ResearchHereButton` 세로 히트영역이 38px로 44dp 미달이었던 것을 `ConstrainedBox(minHeight: 44)`로 수정)
- [x] 홈·트레일·015·016·017 회귀 없음: `just check` green(기존 전부 + 신규, 133개 테스트 전부 통과, analyze 0 issues).

**Phase validation**: 아래 Validation Commands green. 발사 후 브레인 시뮬 + 오너 실기기 육안(줌·회전·산포종수·핸들·검색·개체상세·재검색).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 오너 피드백 매핑 (docs/observation-map-ux-checklist.md §2)
- [1][C-8] 줌 상한(한국만)+임시 테스트 버튼 → Phase 1. [E-21] 회전잠금 → Phase 1.
- [C-10] 산포=종수 → Phase 2. [C-13] 개체 종명 상시+배경/히트+탭→시트 상세 → Phase 2(사진·특징 후속).
- [3] 라벨 주소 → **018 backend**(핫스팟 이름)에서 해결, 이 스펙은 018의 깔끔한 name 소비.
- [D-15] 핸들 드래그 → Phase 3. [D-17] 검색바 노출 → Phase 3.
- [E-22] 상대시간(0일→N시간) → Phase 4. [B] 이곳 재검색 → Phase 4.

### 설계 긴장 (design-lead Phase 0)
- **회전 vs 나침반**: E-21로 회전을 끄면 016 나침반(N)이 무의미 → 나침반 제거 or 회전은 두되 "줌 중만 잠금". design-lead 판단.
- **개체 종명 상시 표시 클러터**: 산포=종수(≤5)라 마커 ≤5개 → 종명 라벨 관리가능(017의 개체수 산포+라벨이었으면 과밀이었을 것 — C-10과 C-13이 함께라야 성립).
- **종 상세 사진·특징**: eBird obs API엔 없음 → 후속 데이터원(위키/eBird media) 결정 전까지 placeholder. 거짓 정보 금지.

### 불변 원칙
- backend·계약 무변경(018이 name 값만 개선). 순수 flutter. 015~017·홈·트레일 회귀 금지. 측정/적합도 종분리·eBird 정직표기 계승. 임시 줌 오버레이는 `kDebugMode` 게이트(정식 값 확정 후 제거).

### 교훈 계승
- 줌·회전·핸들 드래그·산포 밀도는 위젯테스트가 못 잡음 → 오너 실기기 육안 필수(시뮬 위치권한 다이얼로그는 오너 탭).

## Amendments (post-build change history, append-only)

- 2026-09-13 (flutter-lead): `InteractiveFlag.rotateWithScroll`은 flutter_map 8.3.2에 존재하지 않는 상수라 컴파일 에러 — `~InteractiveFlag.rotate` 하나만으로 회전을 전부 비활성화(회전 관련 플래그가 그 하나뿐이라 동등한 효과).
- 2026-09-13 (flutter-lead): 임시 줌 테스트 오버레이(P1-1)는 배선·배포 완료했으나 min/max 확정값은 아직 오너 실기기 리뷰 전이라 미기록 — 현재 하드코딩값은 min 7 / max 16(디자인리드 결정치)을 그대로 사용 중, 오너 리뷰 후 최종값이 다르면 이 Amendments에 추가하고 오버레이 코드를 제거할 것.
- 2026-09-13 (flutter-lead): `bird_scatter.dart`의 `ScatterResult.totalCount` → `totalSpeciesCount`로 개명(의미도 개체수→종수로 변경), `wasReduced`도 "종 일부만 표시"로 재정의 — 종수 기반 산포 전환(P2-1)의 핵심 계약 변경이라 명시.
- 2026-09-13 (flutter-lead): `observation_marker.dart`의 private `_BirdSilhouettePainter`를 public `BirdSilhouettePainter`로 공개 — 신규 `bird_species_detail.dart`(P1-4 종 상세 모달)가 재사용하기 위함.
- 2026-09-13 (flutter-lead): 검색바 고정 노출(P1-5)과 함께 `_peekOverlayOpacity()`의 페이드 임계값을 기존 `0.2`에서 `kObsSheetPeek + 0.04`(≈0.28)로 변경 — peek이 0.16→0.24로 오르며 기존 `0.2` 임계값이 새 peek보다 작아져 오버레이가 항상 사라지는 회귀가 있었음, 위젯테스트로 peek에서 동시 노출 확인됨.
- 2026-09-13 (flutter-lead): 개체 탭 스낵바(`_showBirdSpeciesTooltip`)는 P1-4에서 `_showBirdSpeciesDetail`(바텀시트 모달)로 완전히 대체·삭제.
- 2026-09-13 (flutter-lead): 크로스모델 검증에서 잡힌 회귀 5건 재수정 — ① `ios/Runner.xcodeproj/project.pbxproj`의 `PRODUCT_BUNDLE_IDENTIFIER`가 무관하게 `com.example.lookup2`로 드리프트되어 있던 것을 `com.example.lookup`으로 원복. ② `minSheetHeight` 계산에 남아있던 마지막 하드코딩 `0.16`을 `kObsSheetPeek`로 교체(P1-5 단일 상수화 완결). ③ 디버그 줌 스테퍼(`_DebugZoomOverlay`)가 자체 로컬 상태만 갖고 실제 `MapOptions.minZoom`/`maxZoom`에 영향을 주지 못하던 것을, `_ObservationMapScreenState`의 `_debugMinZoom`/`_debugMaxZoom` 필드로 끌어올려 실제 지도 줌 제약을 라이브로 구동하도록 배선(`_DebugZoomOverlay`는 StatefulWidget→StatelessWidget으로 단순화). ④ `observation_map_parity_test.dart`에 남아있던 죽은 `CompassButton` 위젯테스트(회전-0/회전-45, `Phase 4a`+`Phase 4b` 그룹 총 4개)를 삭제(나침반이 화면에서 완전히 제거됐으므로 회귀 게이트 방지), `TideMoonOverlay` 테스트는 그대로 유지. ⑤ `observation_map_wiring_test.dart`에 `MapOptions`의 zoom 범위(7~16)·한국 bounds(`ContainCamera`)·회전 비활성(`InteractiveFlag.rotate` 클리어, 다른 인터랙션은 유지)을 직접 검증하는 화면 레벨 와이어링 테스트 신규 추가. `just check` green(133개 테스트, analyze 0 issues) 재확인.

### 후속 UX 부채 (design-lead, 이 스코프 아웃)
- 산포 개체 라벨 겹침 leader line/회피(현재 y정렬 depth만) · 종 상세 사진·특징 실데이터원(위키/eBird media) · 회전 제거로 빈 우하단 공간 활용(재검색/GPS 재배치) · 밤하늘 방위 정렬은 천체 화면 몫(지도 회전으로 안 품).

- 2026-09-13 (brain, 실질 PASS 판정 — codex 1 FAIL 해소): 파이프라인 verdict=FAIL이나 **false-negative**. codex **14 PASS + 1 FAIL**, 유일 FAIL은 스펙 stale 숫자("134개"→실제 133, 정정함). 전 항목 실질 PASS(줌 min7/max16·한국bounds·회전잠금·나침반 제거·산포=종수·종명 pill 라벨·종상세 modal·상대시간(미래폴백)·핸들드래그·검색바 peek0.24·"이 지역에서 검색"·계약 무변경). `just check` green(flutter 133 tests). **잔여: 임시 줌 오버레이(kDebugMode, 기본 min7/max16)로 오너가 실기기 최적값 확정 → 확정값 반영 후 오버레이 제거.** 브레인 시뮬 육안은 위치권한 다이얼로그로 제약(오너 실기기).
