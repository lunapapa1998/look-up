# 홈 밤하늘 밝기에 SQM·Bortle 인라인 노출 + "(전문가용 측정값)" 제거

> Lightweight plan-f3 spec. 오너 직접 지시. spec 045에 이은 표현 조정.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/045-home-night-sky-relocate-flutter.md, specs/042-light-pollution-plain-language-flutter.md
- risk: low
- modified: 2026-09-20, lead: claude-sonnet-5
- modified: 2026-09-20, lead: claude-sonnet-5 (badge adjacency fix, cycle 2)

## Purpose

홈 화면 밤하늘 밝기 표시에도 스팟 상세(강화 천문인마을)처럼 SQM·Bortle 값을 인라인으로 노출하고, "(전문가용 측정값)" 문구를 앱 전역에서 제거한다.

## Problem

스팟 상세(`NightSkyTag large:true`)는 `SQM X · Bortle N (전문가용 측정값)`을 인라인 노출하지만, 홈의 밤 블록/낮 한 줄은 별 스케일 + ⓘ만 있고 SQM·Bortle 값이 인라인에 없다. 또 "(전문가용 측정값)" 문구는 불필요하다는 오너 판단이다.

## Solution

홈 밤 블록과 낮 한 줄에 `SQM X · Bortle N` 인라인 텍스트를 추가하고(스팟 상세와 동일 포맷), `night_sky_tag.dart`의 "(전문가용 측정값)" 접미 문구를 제거한다. 그리고 "추정치" 뱃지를 (기존 기대카피 행이 아니라) SQM·Bortle 값 옆으로 이동한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/night_sky_tag.dart` - L216의 `SQM {sqm} · Bortle {n} (전문가용 측정값)`에서 ` (전문가용 측정값)` 제거 → `SQM {sqm} · Bortle {n}`. (스팟 상세 large 모드)
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 밤 블록(≈L1321~)과 낮 한 줄(≈L1410~)에 `SQM {sqm} · Bortle {n}` 인라인 텍스트 추가. `hasNoData`면 이 줄 숨김. 포맷은 night_sky_tag와 동일(`sqmValue.toStringAsFixed(2)`).
- `apps/flutter/test/` - 관련 위젯 테스트: 홈 밤 블록/낮 한 줄에 SQM·Bortle 노출 확인, "(전문가용 측정값)" 문구 부재 확인.

### New Files

- (없음)

## Phases

### Phase 1: 문구 제거 + 인라인 노출

- [x] `night_sky_tag.dart` L216에서 ` (전문가용 측정값)` 제거
- [x] 홈 밤 블록에 `SQM X · Bortle N` 인라인 추가 (hasNoData면 숨김)
- [x] 홈 낮 한 줄에 `SQM X · Bortle N` 노출 (컴팩트 유지, hasNoData면 숨김)
- [x] "추정치" 뱃지를 SQM·Bortle 값 옆으로 이동 (스팟 상세 + 홈 밤 블록/낮 한 줄 모두 일관). isApprox일 때만 노출
- [x] 위젯 테스트 갱신/추가 (인라인 값 노출 + 문구 부재 + 추정치 뱃지 위치)

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- ⓘ 바텀시트(`showNightSkyInfoSheet`)의 "현재 측정값" 줄은 그대로 유지(중복 아님 — 설명 맥락).
- "(전문가용 측정값)" 문구는 현재 코드에서 night_sky_tag.dart L216 한 곳에만 존재. 다른 곳에 없는지 grep 재확인.
- 1차 검증 FAIL: `_NightSkyDayLine`(home_discovery_screen.dart)에서 "추정치" 뱃지가 SQM/Bortle 텍스트 옆이 아니라 별 아이콘 Row 끝에 붙어 있어 인접성 요건 위반. `Text.rich`(WidgetSpan으로 뱃지 임베드)로 교체해 인접하게 수정, 별 Row의 중복 뱃지 제거. 신규 위젯 테스트로 TextSpan 트리 구조 검증. `just check` 재실행 — flutter analyze 0 issues, 237개 테스트 전체 통과 확인.

## Amendments (post-build change history, append-only)

- 2026-09-20: 1차 크로스모델 검증 FAIL(day-line 뱃지 비인접) → `_NightSkyDayLine`을 `Text.rich`로 재구성해 수정, 인접성 검증 위젯 테스트 추가. `just check` green으로 재검증 완료.
