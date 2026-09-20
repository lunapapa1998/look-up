# 홈 좁은 폭 0.5px 오버플로 수정 (리베이스 마무리)

> Lightweight plan-f3 spec. main 리베이스 후 남은 유일한 실패 수정.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-21
- modified: 2026-09-21 brain
- refs: specs/046-night-sky-inline-values-flutter.md, specs/048-tonight-sky-targets-flutter.md
- risk: low
- modified: 2026-09-21, lead: claude sonnet

## Purpose

홈 화면이 좁은 폭에서 RenderFlex 0.5px 오버플로를 내는 것을 없앤다.

## Problem

`test/screens/home_discovery_screen_test.dart`의 "does not overflow at narrow surface widths"가 `A RenderFlex overflowed by 0.500 pixels on the right`로 실패한다. 빛공해 인라인 값(SQM·Bortle) 추가(046) 또는 "오늘 밤 하늘"/별밝기 행이 좁은 폭에서 미세하게 넘친다.

## Solution

오버플로를 내는 Row를 `Flexible`/`Wrap`/`Expanded`로 감싸거나 간격을 조정해 좁은 폭에서 넘치지 않게 한다. 표시 내용·정보는 유지.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - 좁은 폭에서 넘치는 Row 식별(별밝기 인라인 `SQM · Bortle · 추정치` 행 또는 "오늘 밤 하늘"/기타 행) → `Flexible`/`Wrap`/`overflow: ellipsis`/간격 축소로 0px 이하로. 레이아웃 회귀 없게.
- `apps/flutter/test/screens/home_discovery_screen_test.dart` - 기존 "narrow surface widths" 테스트를 통과시키는 게 목표(테스트 임계값 완화가 아니라 실제 오버플로 제거).

### New Files

- (없음)

## Phases

### Phase 1: 오버플로 제거

- [x] 좁은 폭에서 넘치는 Row를 Flexible/Wrap 등으로 수정 (내용 유지)
- [x] `home_discovery_screen_test`의 narrow-width 테스트 통과 확인

**Phase validation**: `just flutter-check` 통과 (전체 green).

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 리베이스로 main(4탭/UI 정리/region picker)과 통합된 상태. 이 오버플로만 남은 유일 실패.
- 테스트 임계값을 늘려서 통과시키지 말 것 — 실제 위젯 오버플로를 없애야 함.

## Amendments (post-build change history, append-only)

- 실제 오버플로 원인은 spec 문서가 짐작한 SQM/Bortle 인라인 행이 아니라, `HomeDiscoveryScreen`의 `SliverAppBar` title Row였다: `const Spacer()`와 위치칩을 감싸던 `Flexible`이 나란히 flex:1을 공유(50/50 분할)하던 구조가 서브픽셀 반올림으로 0.5px 오버플로를 유발. `Spacer()` + `Flexible(chip)`을 단일 `Expanded(child: Align(alignment: Alignment.centerRight, child: chip))`로 교체해 leftover-width 계산을 1개 Expanded로 단순화해 해결.
- 겸사겸사 `_NightSkySection`의 SQM/Bortle Row(night 모드, `mainAxisSize: MainAxisSize.min` + 감싸이지 않은 Text)도 동일 계열의 잠재 오버플로 위험이 있어 `Flexible` + `maxLines:1` + `overflow: ellipsis`로 방어적으로 함께 수정(이 스펙의 실패 테스트가 직접 겨냥한 대상은 아니었으나 안전상 동시 처리).
- 진단 과정에서 테스트 파일에 임시로 넣었던 예외 상세출력(`FlutterError.onError` 오버라이드 등) 3회 시도는 실제로는 커밋되지 않았음(멤버가 DONE을 보고했지만 파일에 반영되지 않은 false-completion 3건 관찰) — 이후 probe 커밋으로 파이프라인 정상 동작을 재확인하고 우회.
