# 관찰 지도 통합 바텀시트 상세 (핀 종류별 컴포넌트 + 조류 종상세(위키) + 탐방로 리치, 모달/alert 폐기)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- refs: `specs/020-species-wiki-rich-trails-backend.md`(소비할 `GET /api/species`·`GET /api/trails/detail`), `specs/019-...ux-refinements-flutter.md`(현 시트·산포·종상세 modal), `specs/016-...figma-parity-flutter.md`(트레일 폴리라인·tooltip/alert), `apps/flutter/lib/widgets/observation_spot_sheet.dart`·`observation_spot_detail.dart`·`bird_species_detail.dart`·`observation_marker.dart`, `apps/flutter/lib/screens/observation_map_screen.dart`, Figma node `62-35`(종 상세 목업 — 단 아래 §정직 스코프대로 실데이터만), 오너 피드백(2026-09-13, `docs/observation-map-ux-checklist.md`)
- risk: high - 관찰지도 상세 인터랙션 아키텍처 재편(모달·alert 제거→통합 시트). 핀 종류별 상세 컴포넌트 + 조류 종상세 인-시트(위키) + 탐방로 리치 상세. 신규 backend(020) 2계약 소비 + API/프로바이더. 015~019·홈·트레일탭(013) 회귀 금지.
- ⚠️ design-lead 검수: 오너 지시로 이번 조각 **생략**(설계 판단은 브레인이 §설계 결정에 명시).

## Purpose

핀 종류(조류/별/노포/탐방로)마다 **같은 바텀시트 안에서** 종류별 상세 컴포넌트를 띄우도록 통합하고(모달·alert 폐기), 조류는 종 탭 시 Wikipedia 종 상세를, 탐방로는 두루누비 리치 상세를 인-시트로 보여준다.

## Problem

1. 상세 인터랙션이 파편화: 스팟 탭→시트 상세(019), 개체 새 탭→**모달**(019), 탐방로 탭→**alert**(016). 오너: 전부 기존 바텀시트 내용 교체로 통일하라.
2. 조류 종 상세에 사진·특징이 없고(placeholder), 탐방로 상세는 거리 정도만.

## Solution

바텀시트를 **뷰 상태 머신**(list ↔ spotDetail ↔ speciesDetail)으로 재편해, (1) 스팟 탭 → 종류별 컴포넌트(`BirdSpotDetail`/`StarSpotDetail`/`HeritageSpotDetail`/`TrailSpotDetail`)를 시트에 렌더, (2) 조류 개체/종 탭 → 시트가 `SpeciesDetail`(020 `/api/species` 위키 사진·설명)로 전환(뒤로가기로 스팟 상세 복귀), (3) 탐방로 폴리라인/trailhead 탭 → 시트가 `TrailSpotDetail`(020 `/api/trails/detail` 리치)로 전환(**alert 제거**). 없는 데이터는 정직 placeholder.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/observation_spot_sheet.dart` - 시트를 **뷰 상태(enum: list/spotDetail/speciesDetail)** 로 재편. `selectedSpot`/`selectedSpecies` + back 스택. 핀 종류별 상세 컴포넌트 스위칭.
- `apps/flutter/lib/widgets/observation_spot_detail.dart` - kind 분기를 **종류별 컴포넌트로 분해**(아래 New Files). 측정/적합도 종분리 유지.
- `apps/flutter/lib/widgets/bird_species_detail.dart` - 019 modal용 → **인-시트 `SpeciesDetail`로 전환**(위키 사진·설명 소비). modal 호출부 제거.
- `apps/flutter/lib/screens/observation_map_screen.dart` - 개체 새 탭→modal(`showModalBottomSheet`) 제거하고 **시트 상태 전환**으로. 탐방로 폴리라인/trailhead 탭→alert 제거하고 **탐방로 스팟 선택→시트 TrailSpotDetail**. 트레일을 시트가 다룰 수 있게 선택 대상 확장(ObservationSpot 외 TrailCourse).
- `apps/flutter/lib/api/trails_api.dart` - `fetchTrailDetail(crsIdx)` 추가(`GET /api/trails/detail`). Fake 포함.
- `apps/flutter/lib/state/discovery_providers.dart` - `speciesInfoProvider(sci,ko)`(FutureProvider.family, `/api/species`) + `trailDetailProvider(crsIdx)`(FutureProvider.family, `/api/trails/detail`). 로딩/에러 상태.

### New Files

- `apps/flutter/lib/api/species_api.dart` - `SpeciesApi`(abstract/Http/Fake), `GET /api/species?sci&ko` → `SpeciesInfo(nameKo,nameSci,summary?,thumbnailUrl?,wikiUrl?,source)`.
- `apps/flutter/lib/models/species.dart`, `models/trail_detail.dart` - 020 계약 DTO(nullable 안전 파싱).
- `apps/flutter/lib/widgets/spot_detail/bird_spot_detail.dart` - 조류 스팟 상세(종 목록 → 종 탭 시 SpeciesDetail 전환). 커뮤니티 관측·상대시간(019) 계승.
- `apps/flutter/lib/widgets/spot_detail/star_spot_detail.dart` - 별(SQM·Bortle·다크스카이 등급 + 적합도, 019 로직 이관).
- `apps/flutter/lib/widgets/spot_detail/heritage_spot_detail.dart` - 노포(이름·주소·거리).
- `apps/flutter/lib/widgets/spot_detail/trail_spot_detail.dart` - **탐방로 리치**: 거리·소요시간·난이도·순환(계약) + 종점 밤하늘 + 종점 노포 + 낮/밤 적합도 + **두루누비 상세(설명·테마·편의시설·화장실·교통·시점종점명·고도·대표이미지, 020)**. 없는 필드 미렌더.
- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - 위키 종 상세(사진 or 실루엣 placeholder + 요약 + 위키 링크 + 개체수·관측시각·관측위치). **정직 스코프**(§).
- 테스트: 시트 상태전환(list↔spotDetail↔speciesDetail)·종류별 컴포넌트 렌더·위키/트레일상세 fake 소비·모달/alert 부재 negative assert·정직 placeholder.

## Phases

### Phase 1: 시트 상태 머신 + 종류별 스팟 상세 컴포넌트 (기존 데이터)
- [ ] 시트 뷰 상태(enum list/spotDetail/speciesDetail) + back. `observation_spot_detail.dart` kind 분기를 `spot_detail/{bird,star,heritage,trail}_spot_detail.dart`로 분해(기존 측정/적합도·종분리 로직 이관, 회귀 없음).
- [ ] 탐방로를 시트 상세로: 폴리라인/trailhead 탭 → **alert 제거**, `TrailSpotDetail`(우선 기존 `/api/trails` 필드: 거리·시간·난이도·순환·밤하늘·노포·적합도) 렌더.

**Phase validation**: `just check` green(상태전환·종류별 렌더·alert 제거 negative assert).

### Phase 2: 조류 종 상세 인-시트 (위키, 020 `/api/species`)
- [ ] `species_api.dart`+`models/species.dart`+`speciesInfoProvider`. `bird_spot_detail.dart` 종 목록 → 종/개체 탭 시 시트가 `species_detail.dart`로 전환. **019 modal(`showModalBottomSheet`) 제거**.
- [ ] `species_detail.dart`: 위키 사진(없으면 실루엣+"사진 준비 중" 중립톤) + 요약 + 위키 링크 + 개체수·상대시각·관측위치. 커뮤니티 관측 배지. back→스팟 상세.

**Phase validation**: `just check` green(종상세 전환·위키 fake·placeholder·modal 부재 negative assert).

### Phase 3: 탐방로 리치 상세 (두루누비, 020 `/api/trails/detail`)
- [ ] `models/trail_detail.dart`+`trailDetailProvider`+`trails_api.fetchTrailDetail`. `trail_spot_detail.dart`에 두루누비 상세(설명·테마·편의시설·화장실·교통·시점종점명·고도·이미지) on-demand 로드·렌더. 없는 필드 미렌더, 로딩/에러 상태.

**Phase validation**: `just check` green(트레일상세 fake 소비·부분필드·로딩/에러).

### Phase 4: 접근성 + 회귀 검증
- [ ] const/`_build*()` 금지·오버플로우 가드·44dp·Semantics(019/016 계승). 측정/적합도 종분리·eBird 정직표기·shortSpotName(020 이후엔 이름 이미 깔끔) 유지.
- [ ] 홈·트레일탭(013)·015~019 회귀 없음: `just check` green.

**Phase validation**: 아래 Validation Commands. 발사 후 브레인 시뮬 + 오너 실기기(핀 종류별 시트 상세·종상세·탐방로 리치, 모달/alert 없음).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 설계 결정 (design-lead 생략 — 브레인 판단)
- **정직 스코프(Figma 62-35 vs 실데이터)**: Figma 종상세는 울음소리 AI·출현예측%·성조/유조·안전관찰거리·리워드 배지·IUCN/천연기념물 등 **데이터원 없는 가공 UI**가 다수 → **만들지 않음**(가짜 데이터 금지, 앱 정직성 원칙). 실제 채울 것: 위키 사진·요약·링크 + eBird 개체수·관측시각·관측위치 + 커뮤니티 관측 배지. Figma의 밀도·연출 톤은 참고하되 내용은 실데이터만.
- **측정/적합도 종분리(013/015 계승)**: 스팟 상세의 측정값과 적합도 게이지는 구분선 분리 유지. 종 상세·탐방로 상세도 측정 위주, 적합도는 해당 좌표 `/api/suitability`만.
- **통합 시트 상태 머신**: 모달·alert 전부 폐기(오너). back 스택으로 list↔spotDetail↔speciesDetail. 시트 크기 스냅(019 kObsSheetPeek)·핸들드래그 유지.
- **탐방로 = 관찰지도의 리치 상세**지만 트레일 탭(013) 카탈로그 복제는 아님(016 P1-3 계승) — 상세 하단에 "트레일 탭에서 코스 전체 보기" 딥링크 가능(후속).

### 소비 계약 (020)
- `GET /api/species?sci&ko` → `{nameKo,nameSci,summary?,thumbnailUrl?,wikiUrl?,source}`(결과없음=null필드).
- `GET /api/trails/detail?crsIdx` → 코스 리치(설명·테마·편의시설·화장실·교통·시점종점명·고도·이미지, 부분 null 가능).

### 불변 원칙
- backend 무변경(020 소비만). 015~019·홈·트레일탭 회귀 금지. 정직표기(없는 데이터 placeholder·미렌더). 신규 위젯 별도 클래스(`_build*()` 금지).

### 교훈 계승
- 위키 이미지·탐방로 상세·시트 전환 체감은 오프라인 위젯테스트가 못 잡음 → 오너 실기기 육안(시뮬 위치권한 탭 필요).
- 외부(위키/두루누비) 실패 방어: 로딩/에러/placeholder, 크래시 금지.

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
