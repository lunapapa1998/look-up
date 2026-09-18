# Figma 트레일·노포 탭 구현

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- refs: specs/013-trails-heritage-flutter.md; https://www.figma.com/design/VIF8Yc0dC2Qq86GOFZkJUA/lookup?node-id=1-1044
- risk: medium - Flutter catalog UI and interactions; existing API contracts preserved.

## Purpose

사용자가 지정한 Figma 트레일·노포 화면을 기존 앱의 세 번째 탭에 구현한다.

## Problem

탭은 연결되어 있지만 현재 화면은 기본 목록이다. 디자인의 생태 트레일 소개, 코스 시각화, 권역 선택과 노포 큐레이션 영역이 없다.

## Solution

기존 trailsProvider와 TrailCourse, HeritageEat를 사용해 시안의 구조를 Flutter로 구현한다. 헤더, 권역 필터, 지도 미리보기와 메타정보, 낮·밤 관측 요약, 경유지 및 주변 노포, GPX 액션을 구성하며 현재 상세 이동과 데이터 상태를 유지한다. API가 제공하지 않는 포인트·탄소 실적·제휴 할인·숙소·종별 관측·시간대 리포트는 사실처럼 만들지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/trails_catalog_screen.dart` - catalog composition and filters
- `apps/flutter/lib/widgets/course_card.dart` - design-aligned course presentation
- `apps/flutter/lib/screens/course_detail_screen.dart` - existing navigation target
- `apps/flutter/lib/screens/app_shell.dart` - existing third tab; preserve shell
- `apps/flutter/lib/theme/app_theme.dart` - existing day/night tokens
- `apps/flutter/lib/api/gpx_api.dart` - reuse existing GPX capability if applicable
- `apps/flutter/test/trails_wiring_test.dart` - adapt meaningful tests to new UI

### New Files

- `apps/flutter/lib/widgets/trails/` - focused catalog widgets as needed
- `apps/flutter/test/widgets/trails_catalog_figma_test.dart` - filter, empty/error and navigation regression coverage
- `apps/flutter/assets/trails/` - downloaded Figma assets if needed; no expiring URLs in committed UI

## Phases

### Phase 1: Design and current capabilities

- [x] Read figma-design-to-code skill before get_design_context; target file VIF8Yc0dC2Qq86GOFZkJUA node 1:1044, include skillNames.
- [x] Review existing theme, shell header, course/detail widgets, GPX and heritage APIs; avoid modifying unrelated in-flight edits.
- [x] Match reference screenshot. Orchestrator retrieved context successfully: navy #08122D background; mint #42E1BE accent; low surface #111A36 and cards #151E3A; horizontal region pills; large featured card with map top fading into name; compact four-column metadata; warm day and mint night panels; numbered route stops; local partner cards; wide mint GPX CTA.

**Phase validation**: implementation plan matches real model capabilities and reference.

### Phase 2: Implementation

- [x] Show eyebrow DURUNUBI × ECO-OBSERVATORY, title 두루누비 코리아둘레길 / 생태 관찰 트레일, description 낮에는 숲과 바다의 새소리를 걷고, 밤에는 별빛 아래 쉬어가는 저탄소 도보길. Reuse shell branding/header patterns rather than duplicating bottom navigation.
- [x] Implement scrollable 권역 filters from available course sigun data with 전체 권역 reset and honest empty state; do not imply nationwide data exists when backend is regional.
- [x] Render featured course using real name, distance, duration, difficulty, start/end map preview and nightSky. Use real start/end coordinates with existing flutter_map if feasible; no fabricated route polyline or hardcoded Figma course name.
- [x] Show day/night suitability when present without null assertions; distinguish non-live status. Use screenshot-inspired compact information panels instead of oversized generic gauge-only layouts.
- [x] Show real start/end and available nearby heritage stops; nearby 노포 section uses actual HeritageEat name/address/distance, dedupes by contentId, has coherent detail/map navigation. No invented partner certifications or discounts.
- [x] Provide working GPX action only when usable gpxUrl exists using project's capabilities; empty/missing URL must have honest state. Do not label offline map download as supported unless implemented.
- [x] Preserve loading, error/retry, partial-data banner/retry, empty state, course detail navigation and day/night themes. Support 320px screens and enlarged text, safe area and >=44px touch targets.
- [x] Any bitmap displayed from Figma must be downloaded exact asset bytes and registered in pubspec; only clearly matching existing glyphs may replace exported icons. Prefer data-backed maps instead of static illustrative map.

**Phase validation**: screen follows reference structure, interactions function, no fake live facts and no overflow.

### Phase 3: Verification

- [x] Test region filter/reset, null suitability, unique nearby heritage, GPX missing/available behavior, detail navigation, loading/error/empty/degraded and narrow-screen overflow.
- [x] Run Flutter analysis and tests; visually inspect a rendered screen (screenshot or golden) against Figma and report concrete evidence.
- [x] Keep unrelated user edits intact and report validation plus limitations. Direct implementation requested; no factory checkpoint created.

**Phase validation**: just flutter-check succeeds and visual evidence reviewed.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

There are pre-existing changes in apps/flutter/.team/member.md, species_detail.dart and observation_spot_sheet_detail_test.dart, plus backend and specs 033. Do not stage, overwrite, or revert these. Scope is Flutter only; backend contracts need no changes. User explicitly requested implementing this tab; proceed without another plan-approval question.

## Amendments (post-build change history, append-only)

- 2026-09-18: Initial design-derived scope.

- 2026-09-18: User explicitly requested direct implementation rather than Flutter team execution. Stopped the idle factory-flutter session started in this conversation and implemented directly.
- 2026-09-18: Implemented catalog intro, data-backed region filters, course map/metadata/day-night panels, endpoint stops, deduplicated heritage cards, and GPX route/map screen with retry. No backend contract changes.
- 2026-09-18: `just flutter-check` passed: analysis clean and 175 tests passed. Targeted coverage includes filter/reset, missing suitability, heritage deduplication/navigation, actual GPX polyline data, missing GPX, retry and 320px / 1.6x text in both themes.
- 2026-09-18: Generated and visually inspected `/private/tmp/lookup-trails-night.png` and `/private/tmp/lookup-trails-day.png` with Korean font. Widget render uses fixture data and blocks network map tiles; live tile loading and device GPX network access are not verified. Web preview build was skipped because this project has no web platform configured.
- 2026-09-18: GPX CTA deliberately says 지도 보기; offline map/file download is not implemented. API lacks point ledger, carbon totals, accommodation/photos/discounts and species/time-window reports, so these illustrative Figma facts are omitted.
- 2026-09-18: iPhone 17 Pro simulator debug build and launch succeeded against local backend at http://127.0.0.1:8000. Actual course, suitability and restaurant response display confirmed; live GPX route opening not yet checked on simulator.
- 2026-09-18: Documented actual data sources and limitations in `docs/trails-data-status.md` at user request. Backend region is fixed to Ganghwa despite accepting location coordinates; SQM/Bortle are coordinate-generated placeholders, suitability mixes real inputs with those placeholders, and nearby-food results do not establish heritage certification. Existing UI wording still needs follow-up; no additional behavior changes in this documentation step. User authorized a direct Git commit of the trails implementation and this documentation.
