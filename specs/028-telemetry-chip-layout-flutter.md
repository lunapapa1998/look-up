# 텔레메트리 칩 레이아웃 변경 — 아이콘 상단·좌측 정렬 (flutter)

> Lightweight plan-f3 spec. 홈 카드 텔레메트리 pill 칩(독립 칩 유지)의 내부 배치를 Figma 19-3382에 맞춰 아이콘을 상단 줄로 올리고 전체 좌측 정렬한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/025-home-suitability-card-redesign-flutter.md, specs/026-home-mode-switcher-relocate-flutter.md, Figma node 19-3382
- risk: low

## Purpose

텔레메트리 칩의 아이콘을 좌측(세로 중앙)에서 라벨과 같은 상단 줄로 옮기고 값 줄을 칩 좌측 끝에 정렬해, Figma 정본(19-3382)의 세로 레이아웃과 일치시킨다.

## Problem

현재(025) 칩은 `Row[아이콘, Column[라벨, 값]]` 구조라 아이콘이 왼쪽에서 두 줄을 가로지르고 값이 아이콘 폭만큼 들여쓰기된다. Figma는 아이콘+라벨을 상단 한 줄에, 값을 그 아래 칩 좌측 끝에 두는 세로 배치다.

## Solution

칩 내부를 `Column(crossAxisAlignment: start)[ Row[아이콘, 라벨], 값 ]`으로 바꾼다. 독립 pill 칩·Wrap 배치·다크 테마 색은 현행 유지(Figma의 라이트 배경/색은 채택하지 않음, 레이아웃만).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - 텔레메트리 칩 빌드 부분(025에서 `Wrap` + 각 칩 `Container > Row[Icon, SizedBox, Column[label,value]]`). 칩 내부를 세로 배치로 교체.

### New Files

- 없음.

## Phases

### Phase 1: 칩 내부 세로 배치

- [ ] 각 칩 `Container`(surfaceContainerHigh, radius 8~12, padding ~10, minHeight 44 유지)의 child를 `Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: min)`로 변경.
- [ ] Column 1행: `Row(mainAxisSize: min)[ Icon(_iconForTelemetryKind, size ~14, color onSurfaceVariant/outline), SizedBox(width 6), Text(label, onSurfaceVariant 12px) ]`.
- [ ] Column 2행(gap 4): `Text(value, onSurface bold ~14px)` — 칩 좌측 끝에서 시작(아이콘 들여쓰기 없음).
- [ ] 색은 앱 다크 테마 토큰 유지: 라벨 `onSurfaceVariant`, 값 `onSurface`. Figma의 라이트 hex(#EBF0EE/#554336/#0F172A)는 쓰지 않는다.
- [ ] 독립 칩 + `Wrap`(spacing/runSpacing 8) 배치 유지. 3칩 한 줄, 4개+ 2줄 폴백 유지.

**Phase validation**: 각 칩이 아이콘+라벨(상단) / 값(하단) 2줄, 좌측 정렬로 렌더. 스크린샷으로 Figma 19-3382 배치와 대조.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **선행 의존**: spec 026과 동일 파일(`home_discovery_screen.dart`) → 병렬 금지. 026 완료·커밋 후 착수.
- 텔레메트리 값은 앱 데이터 모델상 단일 문자열(`TelemetryReading.value`, 예 "2.1 m/s (NW)")이라 Figma처럼 값/단위를 두 폰트로 분리하지 않고 한 `Text`로 둔다.
- 텔레메트리는 독립 칩 유지 결정(design-lead 발견성 권고) — 단일 바로 바꾸지 않는다.

## Amendments (post-build change history, append-only)

- (없음)
