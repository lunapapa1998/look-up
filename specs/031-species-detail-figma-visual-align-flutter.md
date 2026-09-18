# 종 상세(SpeciesDetail) Figma 62-35 비주얼 정합 — 오버레이 히어로 → 미디어 카드 (flutter)

> Lightweight plan-f3 spec. 029가 도입한 풀블리드 오버레이 히어로를 Figma 62-35 정본 구조(사진=둥근 미디어 카드, 종명·학명·보전배지는 사진 위쪽 일반 콘텐츠)로 정합한다. 실데이터 섹션 구성은 유지하고, 가짜 데이터 섹션은 계속 제외한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/029-species-detail-figma-hero-flutter.md, Figma node 62-35 (VIF8Yc0dC2Qq86GOFZkJUA), specs/021-observation-map-unified-sheet-detail-flutter.md
- risk: medium

## Purpose

관측 지도 종 상세(`SpeciesDetail`)의 비주얼을 Figma 62-35 정본에 맞춘다 — 029가 Figma를 오독해 만든 풀블리드 오버레이 히어로를, 실제 62-35 구조인 "둥근 미디어 카드 안 사진 + 헤더(배지·종명·학명) 위쪽 배치"로 되돌린다.

## Problem

029는 62-35의 사진 영역을 "풀블리드 히어로(사진 위 그래디언트 스크림에 종명·학명·배지 오버레이)"로 구현했으나, **실제 Figma 62-35의 사진은 풀블리드가 아니라 둥근 "Media Card" 안에 담긴 사진**이고, 보전배지·종명·학명은 사진 **위쪽에 일반 콘텐츠(좌측 20px 정렬)** 로 배치된다. 즉 현재 구현은 오너가 준 Figma 정본과 레이아웃 위계가 다르다.

## Solution

`_SpeciesHero`(풀블리드 오버레이 Stack)를 걷어내고, 62-35 순서 그대로 재편한다: (1) 보전배지 행 → (2) 종명(대제목)+학명(이탤릭) → (3) 사진 미디어 카드(둥근 radius·그림자, 하단 "출처: Wikipedia" 캡션 오버레이) → (4) 관측 카드(기존) → (5) 오늘의 물때(기존) → (6) 위키 설명(기존). 가짜 섹션(음성 파형/AI, Match%, 성조·유조 분해, 안전거리, 출현예측%, 장비·에티켓, 리워드 배지, GPX/KOBIS, 관심종 버튼)은 계속 넣지 않는다. Figma는 이번 스코프에서 **비주얼 정본**으로 취급한다(오너 결정 — 029의 "목업≠정본" 판단을 이 조각에 한해 정정).

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - 주 대상. `_SpeciesHero`(풀블리드 오버레이) 제거, `_SpeciesMediaCard`(둥근 카드 안 사진+캡션 오버레이) 신설, `build`의 `ListView` children 순서를 62-35 정본(배지→종명/학명→사진카드→관측카드→물때→위키)으로 재배열. 뒤로가기 버튼(`obsmap_detail_back_button` key)은 시트 헤더/사진 카드 위 좌상단에 유지.
- `apps/flutter/lib/widgets/spot_detail/conservation_badges.dart` - 배지 재사용. 사진 위가 아니라 사진 위쪽(헤더 영역)에 배치되도록 호출 위치만 이동. 중립톤 유지(밤 적색필터 충돌 금지).
- `apps/flutter/lib/widgets/spot_detail/today_tides_section.dart` - 오늘의 물때 재사용(`found==true`만). 변경 없음.
- `apps/flutter/lib/models/species.dart` - `thumbnailUrl`(사진), `conservation`(배지·보호종 안내) 참조. 변경 없음.
- `apps/flutter/test/` - 종 상세 관련 위젯 테스트(사진/이름/배지 finder). 히어로→미디어카드 구조 변경에 맞춰 assertion 갱신.

### New Files

- 없음(모두 `species_detail.dart` 내 private 위젯으로).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 헤더(배지 → 종명/학명)를 사진 위쪽 일반 콘텐츠로

62-35의 상단 위계(배지 → 제목 → 학명)를 사진 위쪽에 좌측 20px 정렬 콘텐츠로 배치한다.

- [x] `ConservationBadges`를 사진보다 **위**, 종명보다 위에 배치(62-35 `Status Badges: Conservation Hierarchy`, y=60). 배지 없거나(비보호종) 로딩 중이면 배지 행은 자리만 접어 레이아웃 점프 방지.
- [x] 종명(`selection.nameKo`)을 대제목(`textTheme.headlineSmall`/`titleLarge` 급, w700), 그 아래 학명(`selection.nameSci`)을 이탤릭·`onSurfaceVariant`로(62-35 `Species Title & Scientific Notation`, y=110). 좌측 정렬, 수평 패딩 16~20px.
- [x] **관심종 북마크 버튼은 넣지 않는다**(62-35에는 있으나 미구축 액션 — 죽은 버튼 금지).
- [x] 뒤로가기 버튼(`obsmap_detail_back_button` key)은 유지하되 위치는 시트 헤더(그래버 옆) 또는 사진 카드 위 좌상단 반투명 원형. 터치타깃 44pt.

**Phase validation**: 배지·종명·학명이 사진 위쪽에 62-35 순서대로 읽힌다. 비보호종에서 배지 자리로 인한 점프 없음. 뒤로가기 동작·key 회귀 없음.

### Phase 2: 풀블리드 히어로 → 미디어 카드 사진

`_SpeciesHero`(오버레이 Stack)를 제거하고 62-35 `Media Card` 스타일로 재작성한다.

- [x] 사진을 좌우 꽉 채우는 풀블리드가 아니라 **수평 패딩(16px) 안의 둥근 미디어 카드**(radius ~16, `surfaceContainer` 배경, 은은한 그림자)로. 사진 높이 176~200 고정(로딩/에러/placeholder 공통 슬롯 → 점프 방지). 이미지 `BoxFit.cover`, `Alignment.topCenter`(새 머리 보존).
- [x] 카드 하단에 **"출처: Wikipedia" 캡션 오버레이**(초소형, 중립 흑색 반투명 배경, WCAG AA 대비). 62-35의 "현장 디지스코프"·"Match 99.4%"는 **가짜라 넣지 않는다**.
- [x] `thumbnailUrl` null/로드 실패 → 카드 안 `_SpeciesPhotoPlaceholder` 폴백(카드 높이 유지, 캡션 없음). 로드 실패 상태 추적은 029의 `StatefulWidget`+`_imageLoadFailed` 회귀 방지 로직을 그대로 계승.
- [x] **금지**: 음성 파형/AI 재생 HUD(62-35 `Bird Sound AI ...`)는 가짜 — 넣지 않는다.
- [x] 밤 모드 적색필터 충돌 방지: 카드/캡션 스크림은 중립 흑색 알파만(청록/유채색 금지).

**Phase validation**: 사진이 둥근 카드 안에 뜨고 하단에 "출처: Wikipedia"만 오버레이된다. 풀블리드 오버레이·Match%·파형 어디에도 없음. null 폴백·로드 실패 스크림 회귀 없음. 실제 종 5~6개로 잘림/대비 스크린샷 확인.

### Phase 3: 관측 카드·물때·위키 유지 + 회귀

실데이터 섹션(관측 카드/물때/위키)은 구성 유지, 사진 카드 아래로 순서만 정합한다.

- [x] `_ObservationCard`(개체수/시각/위치 + 커뮤니티 배지 + 조건부 보호종 안내) 현행 유지. 62-35의 성조·유조 분해·안전 관찰 거리는 **가짜라 계속 미추가**.
- [x] `TodayTidesSection`(`found==true`만) 현행 유지. 62-35의 출현예측%는 가짜라 미추가(물때 시각만 실데이터).
- [x] `_WikiSummaryText`(더보기)+위키 링크 버튼 현행 유지(사진 카드/관측 카드 아래로 이동, 순서상 맨 마지막).
- [x] 종 상세 관련 위젯 테스트를 히어로→미디어카드 구조에 맞춰 갱신(사진/이름/배지 finder). `just check` 통과.

**Phase validation**: `just check` 그린. 관측/물때/위키 회귀 없음. 가짜 필드 어디에도 없음.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just check
```

## Notes (agent scratchpad)

- **정본 근거**: Figma 62-35 실측 구조(get_metadata) — 사진은 `Media Card: Field Digiscoping Photo`(62:107, 카드 radius+shadow, 사진 334×176 + 하단 캡션 오버레이)이지 풀블리드 아님. 배지(62:83)·종명/학명(62:95)은 사진(62:107)보다 위. 029가 이 위계를 오독했음(오너 지적 반영).
- **실데이터/가짜 경계**(029 판단 계승): 실데이터=사진(위키 썸네일)·보전배지·종명/학명·관측(개체수/시각/위치)·물때·위키. 가짜(미구현)=음성 파형/AI·Match%·성조유조 분해·안전거리·출현예측%·장비에티켓·리워드 배지·GPX·KOBIS·관심종.
- **Figma 정본 취급 범위**: 이번 조각은 오너 결정으로 Figma를 **비주얼 정본**으로 둔다(레이아웃 위계·카드 스타일·순서). 단 가짜 데이터 섹션은 계속 제외 — "Figma 그대로"가 "가짜 UI까지 복원"을 뜻하지 않음.
- **029 산출물 계승**: `_imageLoadFailed` 로드 실패 추적(codex가 잡았던 회귀), 중립톤 스크림(밤 적색필터), 뒤로가기 key·44pt는 그대로 유지하며 컨테이너만 카드로 교체.

## Amendments (post-build change history, append-only)

- 2026-09-18 (flutter-lead): 위키 요약 블록의 위치를 스펙 순서대로 맨 마지막(관측카드→물때→위키)으로 옮기며, 기존 `species_detail.dart`의 원래 자식 순서(위키→관측카드→물때)가 62-35 정본과 어긋나 있던 것도 함께 바로잡음(스펙 Solution 문구에 이미 명시돼 있었으나 원 파일은 미정합 상태였음).
- 2026-09-18 (flutter-lead): Phase 3 테스트 갱신은 신규 회귀 테스트 추가로 처리 — 기존 테스트는 `_SpeciesHero` private 구조를 직접 참조하지 않아 구조 변경 후에도 그대로 통과했으나, "배지→종명→사진" 수직 위계를 실제로 검증하는 테스트가 없었으므로 `observation_spot_sheet_detail_test.dart`의 IUCN 배지 테스트에 `getTopLeft` dy 비교(배지<이름<사진) + 썸네일 null일 때 위키 캡션 미노출 assertion을 추가. 최초 구현에서 `find.text('저어새')`가 스코프 없이 두 위젯(헤더 텍스트 + 시트 하위 다른 화면에 남아있던 텍스트)에 매칭돼 `getTopLeft` 모호성 오류가 났고, `find.descendant(of: find.byType(SpeciesDetail), ...)`로 스코프를 좁혀 재수정함.

- modified: 2026-09-18, lead: claude-sonnet-5
