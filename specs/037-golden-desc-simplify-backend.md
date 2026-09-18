# 밤 골든타임 부가설명 쉬운말 순화 (C안·백엔드 문자열만)

> Lightweight plan-f3 spec. 밤 · 천체 골든타임 카드의 `description` 문구를 천문 전문용어 나열에서 일반 사용자용 쉬운 말로 순화한다. 계약(golden_hours 스키마)·시간계산 로직·낮 골든타임·점수는 전부 불변, description 문자열만 바꾼다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/035-night-golden-moon-aware-backend.md, design-lead 자문(2026-09-18)
- risk: low
- modified: 2026-09-18, lead: claude-sonnet-5

## Purpose

밤 골든타임 `description`의 "월령 X일 · 광도 Y% · 무월광 HH:MM~HH:MM" 나열식 전문용어를, 일반 사용자가 바로 이해할 쉬운 말로 바꾼다.

## Problem

현재 부가설명은 (1) `무월광 HH:MM~HH:MM`이 바로 위 `timeRange`와 **완전 중복**이고, (2) 월령·광도·무월광은 원인(전문용어)일 뿐 사용자가 알고 싶은 "그래서 별 잘 보이나"를 말해주지 않는다. design-lead 자문 결과 겉면은 결과 중심 쉬운 말로 가야 한다(C안: 문자열만 최소 변경).

## Solution

`astronomy.py` `parse()`의 description 조립 4분기를 쉬운 말로 교체한다: 용어 순화(무월광→"달빛 방해 적은", 광도→"달 밝기"), 월령 삭제, `무월광 HH:MM`·`전체 암천 HH:MM` 등 timeRange 중복 제거. golden_hours 스키마(mode/label/timeRange/description)와 시간계산·windowSource 분기·낮로직·sub_score는 무변경.

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/astronomy.py` - description 4분기 문자열만 교체 (L133 / L164-166 / L169-171 / L174 부근). 계산·분기 로직 무변경
- `apps/backend/tests/suitability/test_astronomy_provider.py` - 구 문자열(`무월광`·`광도`·`월령`·`관측 제한`·`월출몰 정보 없음`)을 assert하는 케이스를 신 문자열로 갱신
- `apps/backend/tests/suitability/test_endpoint.py` - (해당 문자열 assert가 있으면) 동일 갱신

### New Files

- (없음)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: description 4분기 문자열 교체

`parse()`의 description 조립부만 아래 표대로 교체한다. `{pct}` = illumination_pct, `{start}`/`{end}` = 창 HH:MM.

- [x] **정상(무월광 창 있음, L174)**: `{월령}·광도{pct}%·무월광 {start}~{end}` → **`달빛 방해 적은 시간대 · 달 밝기 {pct}%`**
- [x] **달 밤새 떠있음(L164-166)**: `{월령}·광도{pct}%·무월광 시간대 없음(…관측 제한)` → **`달이 밤새 떠 있어 어두운 별은 보기 어려워요 · 달 밝기 {pct}%`**
- [x] **월출몰 정보 없음(L169-171)**: `{월령}·광도{pct}%·월출몰 정보 없음·전체 암천 {start}~{end}` → **`하늘이 완전히 어두운 시간 · 달 정보 확인 중`**
- [x] **고정폴백/astm 결측(L133)**: `{월령}·광도{pct}%` → **`달 밝기 {pct}%`**

**Phase validation**: 각 분기가 신 문자열을 반환하고, `timeRange`와 중복되는 시각 표기가 description에 더 이상 없음.

### Phase 2: 테스트 문자열 갱신 + 회귀

- [x] 구 문자열 assert 케이스를 신 문자열로 갱신(4분기 전부)
- [x] `timeRange`·`mode`·`label`·sub_score·windowSource·evidence 키는 무변경임을 회귀로 확인
- [x] 낮 골든타임(tide) description 무변경 확인

**Phase validation**: `just check` 통과(신 문자열 반영, 계약/계산 회귀 없음).

## Non-Goals

- 시간계산·무월광 구간 산출·windowSource 분기 로직 변경 (035에서 완료, 순화만 함).
- 달 위상 아이콘·ⓘ툴팁·관측조건 등급(A/B안) — flutter까지 손대는 후속 별도 스펙.
- `label`("밤 · 천체 골든타임")·낮 골든타임·sub_score 변경.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 이 스펙은 다른 세션이 flutter를 활발히 수정 중인 공유 트리를 피해 격리 worktree(`feat/037-golden-desc-simplify`, base=feat/033 c42d28c)에서 빌드한다. 그래서 이 트리의 `just check` flutter는 커밋된 clean 상태라 신뢰 가능.
- 순화 근거: design-lead 자문(무월광→달빛 방해 적은, 광도→달 밝기, 월령 삭제, 중복 제거). "천문박명" 학술어는 겉면 미노출 유지(툴팁은 후속 A안).

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). C안 = description 문자열만 순화, 계약/계산/낮로직/점수 불변.
- 2026-09-18: Phase 1-2 구현 완료 (lead: claude-sonnet-5, worker: backend-engineer). 4분기 description 교체 후 `{월령}` 포매팅에만 쓰이던 `_format_age` 헬퍼가 미사용이 되어 함께 삭제(사양엔 명시 안 됐으나 죽은 코드 방지 목적, 계산/분기 로직은 무변경). `test_astronomy_provider.py` assertion 7곳 갱신. `test_endpoint.py`는 description을 assert하지 않는 목업 값이라 변경 불필요로 확인, 손대지 않음. `just check` 전체 통과(backend 164 passed/0 failed, flutter all tests passed).
