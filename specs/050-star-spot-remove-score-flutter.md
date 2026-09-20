# 별 스팟 시트 하단 적합도 점수 게이지 제거

> Lightweight plan-f3 spec. 오너 지시.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-21
- modified: 2026-09-21 brain
- modified: 2026-09-21, lead: flutter
- modified: 2026-09-21, lead: flutter
- refs: specs/049-star-spot-sheet-starlight-flutter.md
- risk: low

## Purpose

별 스팟(강화 천문인마을) 상세 시트 하단의 0~100 적합도 점수 게이지(`SuitabilityBlock`/`ScoreGauge`)를 제거한다.

## Problem

049로 시트 상단에 별밝기·천체 골든타임·오늘 밤 별자리가 들어오면서, 시트 맨 아래의 일반 적합도 점수 게이지는 별 관측 맥락에서 불필요·중복으로 판단된다.

## Solution

`star_spot_detail.dart`에서 하단 `SuitabilityBlock`(및 그 앞 Divider)을 제거한다. 다른 스팟 종류(탐조/문화유산/트레일) 시트는 변경하지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/spot_detail/star_spot_detail.dart` - 하단 `SuitabilityBlock`과 직전 `Divider` 제거. 상단(이름 → 별밝기 → 골든타임 → 오늘 밤 별자리)은 유지.
- `apps/flutter/test/` - star 스팟 시트 테스트에서 `SuitabilityBlock`/`ScoreGauge` 존재 단언이 있으면 제거로 갱신.

### New Files

- (없음)

## Phases

### Phase 1: 제거

- [x] `star_spot_detail.dart`에서 `SuitabilityBlock` + 직전 `Divider` 제거 (import도 미사용 시 정리)
- [x] 관련 위젯 테스트 갱신 (점수 게이지 부재 단언)

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 범위: 별(star) 스팟 시트만. bird/heritage/trail 스팟 시트의 `SuitabilityBlock`은 유지.
- `SuitabilityBlock`/`ScoreGauge` 위젯 자체는 다른 스팟에서 쓰이므로 삭제하지 말 것 — star 시트에서 사용만 제거.

## Amendments (post-build change history, append-only)

- 2026-09-21: Cross-model verifier FAIL fix-up. Two gaps from the first attempt were closed: (1) added a `star spot detail does not render the suitability score gauge` test in `star_spot_detail_test.dart` asserting `find.byType(ScoreGauge)`/`find.byType(SuitabilityBlock)` both `findsNothing`; (2) corrected the stale `SuitabilityBlock` doc comment in `observation_spot_detail.dart` that still claimed it was shared by `BirdSpotDetail` and `StarSpotDetail` — now says it is used by `BirdSpotDetail` and other non-heritage spot kinds. `just check` reverified green (analyzer clean, 253 flutter tests pass, backend tests pass).
