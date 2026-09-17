# 홈 텔레메트리 섹션 좌측 정렬·전폭 정합 (flutter)

> Lightweight plan-f3 spec. 홈 적합도 카드의 텔레메트리 칩 섹션을 상단 골든타임 카드와 같은 좌측 라인·같은 너비로 정렬한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/025-home-suitability-card-redesign-flutter.md, specs/028-telemetry-chip-layout-flutter.md
- risk: low
- modified: 2026-09-18, lead: claude

## Purpose

텔레메트리 칩 섹션(하늘상태·습도·풍속·강수·조위)이 위 낮/밤 골든타임 카드와 동일한 좌측 시작선·전폭을 갖도록 정렬해 시각적 정합을 맞춘다.

## Problem

적합도 카드의 데이터 `Column`(`home_discovery_screen.dart:246`)에 `crossAxisAlignment`가 없어 기본값 `center`다. 골든타임 카드는 내부 `Row`+`Expanded`로 전폭이라 안 밀리지만, 텔레메트리 `Wrap`은 내용 폭이 전폭보다 좁을 때(값이 짧은 경우) 가운데로 밀려 들여쓰기처럼 보이고 골든 카드와 시작선이 어긋난다.

## Solution

카드 데이터 `Column`을 `crossAxisAlignment: CrossAxisAlignment.start`로 바꿔 텔레메트리 `Wrap`이 항상 좌측(골든 카드와 동일 라인)에서 시작하게 하고, 필요 시 `Wrap`을 `SizedBox(width: double.infinity)`로 감싸 전폭 스팬을 보장한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - 적합도 카드 `data: (overview) => Column(...)`(line 246 부근)에 `crossAxisAlignment: CrossAxisAlignment.start` 추가. 텔레메트리 `_StaggerReveal > Wrap`(line 506 부근)이 전폭 좌측 정렬되게.

### New Files

- 없음.

## Phases

### Phase 1: 카드 Column 좌측 정렬

- [x] `home_discovery_screen.dart:246`의 `data: (overview) => Column(`에 `crossAxisAlignment: CrossAxisAlignment.start` 추가.
- [x] 텔레메트리 `Wrap`이 좌측 정렬·전폭이 되도록 필요 시 `SizedBox(width: double.infinity, child: Wrap(...))`로 감싼다(Wrap 기본 정렬 start 유지).
- [x] 회귀 확인: 스코어 헤더(Row 전폭)·골든타임 카드(전폭)·degraded 배너(width:infinity)는 좌측 정렬 전환 후에도 동일하게 보여야 한다. loading/error 상태 무영향.

**Phase validation**: 텔레메트리 첫 칩(하늘상태)의 좌측 edge가 골든타임 카드 좌측 edge와 정확히 일치하고, 칩 섹션이 전폭을 사용한다. 스크린샷으로 낮/밤 모드 모두 확인.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 근본 원인은 Column 기본 center 정렬. 골든 카드는 Expanded로 전폭이라 영향 없었고 Wrap만 좁을 때 센터링돼 들여쓰기처럼 보였다.
- 텔레메트리는 독립 pill 칩·아이콘 상단(028) 유지. 칩 자체 구조는 건드리지 않고 정렬만.
- 선행 의존: 같은 파일이라 다른 flutter 잡과 병렬 금지. 이 스펙 완료 후 029(종상세) 착수.

## Amendments (post-build change history, append-only)

- 2026-09-18: flutter-engineer는 팀 Bash 권한이 `flutter` 실행을 차단해 정적 편집만 수행하고 검증을 위임했음. lead가 직접 `just check`로 `flutter analyze`(무결점) 및 `flutter test`(166/166 통과, `home_discovery_screen_test.dart` 포함)를 확인해 완료 처리함.
