# 홈 밤 블록 라벨 "별밝기" → "오늘 밤"

> Lightweight plan-f3 spec. 오너 직접 지시. 카피 통일.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/045-home-night-sky-relocate-flutter.md
- risk: low

## Purpose

홈 밤 모드 별밝기 블록의 프리픽스를 "별밝기"에서 "오늘 밤"으로 바꿔 낮 한 줄("오늘 밤 · ...")과 문구를 통일한다.

## Problem

밤 블록은 `'별밝기 · ${label}'`, 낮 한 줄은 `'오늘 밤 · ${label}'`로 프리픽스가 불일치한다.

## Solution

밤 블록 프리픽스를 "오늘 밤"으로 변경한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - 밤 블록(≈L1356) `'별밝기 · ${display.label}'` → `'오늘 밤 · ${display.label}'`.
- `apps/flutter/test/` - 관련 위젯 테스트에서 "별밝기" 단언이 있으면 "오늘 밤"으로 갱신.

### New Files

- (없음)

## Phases

### Phase 1: 라벨 변경

- [x] 밤 블록 프리픽스 "별밝기" → "오늘 밤"
- [x] 테스트 단언 갱신(있으면)

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 낮 한 줄은 이미 "오늘 밤 · ..."이라 밤/낮 통일됨. hasNoData 문구("... 밤하늘 밝기 정보 없음")도 프리픽스 일관되게 유지.

## Amendments (post-build change history, append-only)

- (none yet)
- modified: 2026-09-20, lead: flutter-lead(claude)
