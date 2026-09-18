# Figma 낮-밤 패키지 탭 직접 구현

## Metadata

- created: 2026-09-18
- modified: 2026-09-18 Codex
- refs: https://www.figma.com/design/VIF8Yc0dC2Qq86GOFZkJUA/lookup?node-id=1-672; docs/packages-data-status.md
- risk: medium - fourth-tab UI, local preview state and asset registration
- branch: feat/figma-screen-1-672

## Purpose

사용자가 지정한 1박 2일 낮-밤 패키지 시안을 네 번째 앱 탭에 구현한다. 사용자 지시에 따라 팩토리를 사용하지 않고 작업 전에 새 브랜치를 생성했다.

## Problem

현재 네 번째 탭은 임시 화면이다. 패키지·운영사·예약 API가 없어 시안 내용의 실판매·실시간 여부를 확인할 수 없다.

## Solution

예시 패키지 모델을 기반으로 카드·유형 필터·타임라인·장비·환경 안내를 구현했다. 가격·혜택·지표는 예시로 표시하고 날짜·인원별 금액을 확인하는 로컬 예약 미리보기를 제공한다. 실제 예약·결제·상담 접수·잔여 좌석은 연결하지 않았다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/app_shell.dart` - fourth-tab destination
- `apps/flutter/pubspec.yaml` - Figma assets
- `apps/flutter/test/screens/app_shell_test.dart` - tab connection regression

### New Files

- `apps/flutter/lib/models/stay_package.dart` - typed examples
- `apps/flutter/lib/screens/packages_catalog_screen.dart` - catalog/filter/help
- `apps/flutter/lib/screens/package_booking_preview_screen.dart` - date/people/local preview
- `apps/flutter/lib/widgets/packages/package_card.dart` - card/timeline
- `apps/flutter/lib/widgets/packages/package_extras.dart` - kit/impact sections
- `apps/flutter/assets/packages/` - downloaded original Figma asset bytes
- `apps/flutter/test/screens/packages_catalog_screen_test.dart` - interactions/layout
- `docs/packages-data-status.md` - example-data boundaries and validation

## Phases

### Phase 1: Design and implementation

- [x] Create a dedicated branch before changes; preserve unrelated modifications.
- [x] Read figma-design-to-code skill and get design context for node 1:672.
- [x] Reuse day/night theme, layout tokens and app shell; store Figma images locally.
- [x] Implement filter/reset/empty state, both cards, timelines, equipment and impact panels.
- [x] Clearly label all unverified prices, indicators, itinerary and benefits as examples; replace live booking/seat/chat claims with honest preview/help actions.
- [x] Provide local date/person selection and sample price summary without transmission or reservation storage.

**Phase validation**: static analysis clean; real fourth-tab navigation and simulator display verified.

### Phase 2: Verification

- [x] Package and shell tests pass, including 320px/1.6x text and both color schemes.
- [x] Render and visually review original asset images in both themes.
- [x] Build and launch the current app in iPhone 17 Pro simulator.
- [x] Run whole Flutter validation; isolate and document the unrelated failing observation-card test rather than modifying parallel work.

**Phase validation**: package coverage passes. Entire suite is not green: 189 pass and 1 unrelated failure, reproduced without package integration changes.

## Validation Commands

```sh
just flutter-check
```

## Notes

Full-suite failure: `apps/flutter/test/widgets/observation_spot_sheet_detail_test.dart:493` expects `커뮤니티 관측` under SpeciesDetail. Same failure reproduced in `/private/tmp/lookup-packages-baseline` after excluding this task's app-shell/pubspec integration changes. This task does not modify SpeciesDetail, relative-time helpers, tides, team member notes or spec 036. Temporary rendering test/PNGs are under `/private/tmp`; they are not production entrypoints.

## Amendments

- 2026-09-18: Implemented and verified directly on a new branch. No factory run, merge, push or commit requested for this task.
- 2026-09-18: User subsequently requested integration into the existing development branch. Commit only package-related files, then merge `feat/figma-screen-1-672` into its original parent development branch `feat/033-night-golden-moon-aware`, preserving parallel unstaged edits. Do not push.
