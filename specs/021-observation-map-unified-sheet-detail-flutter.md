# 관찰 지도 통합 바텀시트 상세 (핀 종류별 컴포넌트 + 조류 종상세(위키) + 탐방로 리치, 모달/alert 폐기)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- refs: `specs/020-species-wiki-rich-trails-backend.md`(소비할 `GET /api/species`·`GET /api/trails/detail`), `specs/019-...ux-refinements-flutter.md`(현 시트·산포·종상세 modal), `specs/016-...figma-parity-flutter.md`(트레일 폴리라인·tooltip/alert), `apps/flutter/lib/widgets/observation_spot_sheet.dart`·`observation_spot_detail.dart`·`bird_species_detail.dart`·`observation_marker.dart`, `apps/flutter/lib/screens/observation_map_screen.dart`, Figma node `62-35`(종 상세 목업 — 단 아래 §정직 스코프대로 실데이터만), 오너 피드백(2026-09-13, `docs/observation-map-ux-checklist.md`)
- risk: high - 관찰지도 상세 인터랙션 아키텍처 재편(모달·alert 제거→통합 시트). 핀 종류별 상세 컴포넌트 + 조류 종상세 인-시트(위키) + 탐방로 리치 상세. 신규 backend(020) 2계약 소비 + API/프로바이더. 015~019·홈·트레일탭(013) 회귀 금지.
- ⚠️ design-lead 검수: 오너 지시로 이번 조각 **생략**(설계 판단은 브레인이 §설계 결정에 명시).
- modified: 2026-09-13, lead: claude-sonnet-5
- modified: 2026-09-13, lead: claude-sonnet-5 (재검증 런 — dead-code 삭제 완료, 크로스모델 FAIL 해소)

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
- `apps/flutter/lib/widgets/spot_detail/trail_spot_detail.dart` - **탐방로 리치**: 거리·소요시간·난이도·순환(계약) + 종점 밤하늘 + 종점 노포 + 낮/밤 적합도 + **두루누비 상세(020 실계약: `description`·`themeId`·`startName`·`endName`·`travelerInfo`(교통편 원문, HTML `<br>` 포함)·`tourInfo`(주변관광 원문)·`elevationProfile`[{positionRatio,elevationM}])**. ⚠️ 편의시설·화장실·대표이미지는 두루누비 API에 필드 자체가 없어 020에서 제외됨 — 렌더하지 말 것. `travelerInfo`/`tourInfo`는 `<br>` 포함 HTML 텍스트라 개행 정규화 후 표시. 없는 필드 미렌더.
- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - 위키 종 상세(사진 or 실루엣 placeholder + 요약 + 위키 링크 + 개체수·관측시각·관측위치). **정직 스코프**(§).
- 테스트: 시트 상태전환(list↔spotDetail↔speciesDetail)·종류별 컴포넌트 렌더·위키/트레일상세 fake 소비·모달/alert 부재 negative assert·정직 placeholder.

## Phases

### Phase 1: 시트 상태 머신 + 종류별 스팟 상세 컴포넌트 (기존 데이터)
- [x] 시트 뷰 상태(list/spotDetail, back 포함) + back. `observation_spot_detail.dart` kind 분기를 `spot_detail/{bird,star,heritage,trail}_spot_detail.dart`로 분해(기존 측정/적합도·종분리 로직 이관, 회귀 없음). (speciesDetail 3번째 뷰는 Phase 2에서 실제 소비자와 함께 추가 — Amendments 참조)
- [x] 탐방로를 시트 상세로: 폴리라인/trailhead 탭 → **alert 제거**, `TrailSpotDetail`(우선 기존 `/api/trails` 필드: 거리·시간·난이도·순환·밤하늘·노포·적합도) 렌더.

**Phase validation**: `just check` green(상태전환·종류별 렌더·alert 제거 negative assert).

### Phase 2: 조류 종 상세 인-시트 (위키, 020 `/api/species`)
- [x] `species_api.dart`+`models/species.dart`+`speciesInfoProvider`. `bird_spot_detail.dart` 종 목록 → 종/개체 탭 시 시트가 `species_detail.dart`로 전환. **019 modal(`showModalBottomSheet`) 제거**.
- [x] `species_detail.dart`: 위키 사진(없으면 아이콘+"사진 준비 중" 중립톤 — 손그림 실루엣 페인터 대신 표준 Icon으로 단순화) + 요약 + 위키 링크(텍스트, url_launcher 미도입) + 개체수·상대시각·관측위치. 커뮤니티 관측 배지. back→스팟 상세(3단 스택: list↔spotDetail↔speciesDetail 확인됨).

**Phase validation**: `just check` green(종상세 전환·위키 fake·placeholder·modal 부재 negative assert).

### Phase 3: 탐방로 리치 상세 (두루누비, 020 `/api/trails/detail`)
- [x] `TrailDetailResponse`/`ElevationPoint`(`models/trails.dart`에 추가, 별도 파일 아님)+`trailDetailProvider`+`trails_api.fetchTrailDetail`. `trail_spot_detail.dart`(ConsumerWidget 전환)에 두루누비 상세 on-demand 로드·렌더: description/travelerInfo/tourInfo(HTML `<br>` 개행 정규화)+표고 최소/최대 요약. **themeId·startName·endName은 의도적으로 미렌더**(브레인 판단, 아래 Amendments) — 편의시설/화장실/이미지는 020 자체에 필드 없음. 없는 필드 미렌더, found=false/전체 null이면 중립 안내, 로딩/에러 상태 별도.

**Phase validation**: `just check` green(트레일상세 fake 소비·부분필드·로딩/에러).

### Phase 4: 접근성 + 회귀 검증
- [x] const/`_build*()` 금지·오버플로우 가드·44dp·Semantics(019/016 계승). 측정/적합도 종분리·eBird 정직표기·shortSpotName 유지 — 감사 중 2건 발견·수정(스팟/코스/종 이름 타이틀 Text에 maxLines/overflow 누락 5곳, `species_detail.dart` 좌표 줄에서 `shortSpotName` 누락).
- [x] 홈·트레일탭(013)·015~019 회귀 없음: `just check` green(백엔드 133 passed·10 skipped, flutter 154 passed, analyze 0 issues) — 브레인이 각 단계마다 직접 실행 확인.

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
- `GET /api/trails/detail?crsIdx` → 코스 리치(`description`·`themeId`·`startName`·`endName`·`travelerInfo`(교통)·`tourInfo`(주변관광)·`elevationProfile`[{positionRatio,elevationM}]·`found`·`degraded`, 부분 null 가능). 편의시설·화장실·대표이미지는 020에서 제외(두루누비 API에 없음).

### 불변 원칙
- backend 무변경(020 소비만). 015~019·홈·트레일탭 회귀 금지. 정직표기(없는 데이터 placeholder·미렌더). 신규 위젯 별도 클래스(`_build*()` 금지).

### 교훈 계승
- 위키 이미지·탐방로 상세·시트 전환 체감은 오프라인 위젯테스트가 못 잡음 → 오너 실기기 육안(시뮬 위치권한 탭 필요).
- 외부(위키/두루누비) 실패 방어: 로딩/에러/placeholder, 크래시 금지.

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
- 2026-09-13, lead: 시트 뷰 상태는 스펙 문구대로 처음부터 3값 enum을 만들지 않고, Phase 1에서 list/spotDetail 2단만 구현(소비자 없는 speciesDetail은 미완성 배선이라 판단), Phase 2에서 실제 소비자(species_api/species_detail)와 함께 3단(list↔spotDetail↔speciesDetail)으로 확장 — 최종 동작은 스펙 요구사항과 동일(3단 back 스택 테스트로 검증됨), 구현 순서만 다름.
- 2026-09-13, lead: `species_detail.dart`의 "사진 없음" placeholder는 `bird_species_detail.dart`의 손그림 `BirdSilhouettePainter`를 재사용하지 않고 표준 `Icon`으로 단순화(정직 placeholder라는 목적은 동일, 코드 이관보다 간결함 우선). 위키 링크(`wikiUrl`)는 `url_launcher` 패키지를 새로 추가하지 않고 `SelectableText`로만 노출(탭하면 브라우저로 여는 기능은 이번 스코프 밖) — 오너 확인 시 후속 스펙으로 추가 가능.
- 2026-09-13, lead: 탐방로 리치 상세에서 `themeId`·`startName`·`endName`은 브레인 판단으로 렌더 대상에서 제외(`startName`/`endName`은 이미 화면에 보이는 코스명·종점 정보와 중복, `themeId`는 사용자에게 의미 없는 내부 식별자) — `description`/`travelerInfo`/`tourInfo`/표고 최소·최대 요약만 렌더. `elevationProfile`은 `positionRatio`가 실거리(km) 비례가 아니라는 020 계약의 경고에 따라 그래프/거리축을 만들지 않고 최소·최대 표고 값 요약으로만 정직하게 표시.
- 2026-09-13, lead: **후속 정리 필요** — `apps/flutter/lib/widgets/bird_species_detail.dart`는 Phase 2에서 완전히 대체되어 코드베이스 어디에서도 참조되지 않는 죽은 파일이 되었으나(정적 grep으로 확인 완료), 이 헤드리스 런에서는 `git rm` 등 파일 삭제 동작이 승인 게이트에 막혀(대화형 세션의 사용자 승인 필요) 삭제하지 못했다. 다음 대화형 세션에서 `git rm apps/flutter/lib/widgets/bird_species_detail.dart` 실행 필요(삭제해도 `just check`엔 영향 없음 — 이미 아무도 import하지 않음).
- 2026-09-13, lead: 크로스모델 검증 FAIL(`bird_species_detail.dart`가 구모달 구현·구키 그대로 잔존) 재확인 결과, 원인은 claude 어댑터 멤버의 도구 권한이 `Read,Grep,Glob,Edit,Write`뿐이라 파일 삭제(Bash/`rm`/`git rm`) 자체가 불가능했던 구조적 제약이었음(위 Amendment의 "승인 게이트" 추정은 부정확 — 실제로는 tool grant에 Bash가 아예 없음). apps/flutter는 디렉토리 도메인이라 `codex` 어댑터 멤버(workspace-write 샌드박스, 셸 접근 가능)로 재위임해 파일 삭제 완료. `git rm` 스테이징 자체는 codex 샌드박스의 인덱스 권한 문제로 실패했으나 워킹트리 삭제는 반영됨(`git status`로 `D apps/flutter/lib/widgets/bird_species_detail.dart` 확인). 잔여 grep 히트는 `test/widgets/observation_spot_sheet_detail_test.dart`의 서술용 문자열(`'no BirdSpeciesDetail-style modal key ever appears...'`)뿐으로 코드 참조 아님. 브레인이 직접 `just check` 재실행해 backend 133 passed/10 skipped, flutter analyze 0 issues, flutter test 154 passed 확인 완료(회귀 없음).
- 2026-09-13 (**브레인 검증 — codex 지적 back-stack 결함 1건 수정**): 크로스모델 verify(codex)가 10항목 중 9 PASS, 유일 FAIL로 **시트 back 스택 붕괴 실 결함**을 지적. 재현 경로 확정: (1) 조류 스팟 탭→scatter marker 표시(`_scatterSpot` 세팅), (2) 개체 탭→SpeciesDetail, (3) back→spot detail 복귀(정상), (4) back→list 복귀 **그러나 `_handleSheetBack`이 `_revertScatter()`를 안 불러 scatter marker가 지도에 잔존**, (5) 잔존 marker 탭→`_selectSpecies`(`_selectedSpot`=null인데 SpeciesDetail 열림), (6) back→`_selectedSpecies`만 clear→부모 spot detail이 없어 곧장 list로 감(back 계층 붕괴). **근본 수정**: `_handleSheetBack`을 재구조화해 species→spotDetail 복귀는 scatter 유지(spot detail이 개체를 계속 표시해야 하므로 정상), spotDetail/trail→list 복귀 시에만 `_revertScatter()` 호출해 scatter를 정리(`observation_map_screen.dart:133`). 이로써 list 복귀 후 잔존 marker 자체가 사라져 결함 경로가 원천 차단됨. `just check` green(backend 133, flutter 154 passed, analyze 0). 회귀 테스트는 scatter가 `flutter_map` 카메라/marker 렌더에 의존해 오프라인 위젯테스트로 재현이 어려워(스펙 §교훈 계승대로) 근본 수정 + 오너 실기기 육안에 위임.
