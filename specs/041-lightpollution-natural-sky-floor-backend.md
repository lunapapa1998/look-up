# 빛공해 SQM 변환 자연광 바닥값 보정 (backend)

> Lightweight plan-f3 spec. World Atlas 2015는 **인공광만** 담기에, 어두운 지역(인공광≈0)에서 `brightness_to_sqm`이 자연 밤하늘을 안 더하고 발산해 물리적으로 불가능한 SQM(>22)을 냈다. 변환 전 자연광 바닥값을 더해 총 하늘밝기로 변환하도록 고친다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 <brain>
- modified: 2026-09-20, lead: sonnet
- refs: specs/040-light-pollution-grid-backend.md, apps/backend/app/suitability/lightpollution/convert.py, World Atlas 2015 (Falchi et al.) — "maps report artificial light only; natural sources must be added"
- risk: low

## Purpose

`brightness_to_sqm`가 인공광만 로그 변환해 어두운 셀에서 SQM을 무한대로 발산시키는 물리 오류를, 변환 전 자연 밤하늘 밝기를 더하는 방식으로 바로잡는다.

## Problem

World Atlas 2015는 인공광만 담는데 `brightness_to_sqm`은 자연광을 더하지 않고 `log10(brightness/108000000)/-0.4`만 계산한다(밝기 정확히 0일 때만 22.0 처리). 실 그리드 생성 결과 19,481셀 중 13,880개(71%)가 SQM>22(중앙값 23.7, 최대 36.5)로 나와, 대도시 외 국토 대부분이 잘못된 "Bortle 1 최적 다크스카이"로 분류된다. 다크스팟을 찾는 앱에서 이 왜곡은 레이어 신뢰도를 무너뜨린다(밤 가중치 0.30).

## Solution

`brightness_to_sqm`에서 인공광에 자연 밤하늘 밝기(≈22 SQM에 해당하는 `108_000_000 * 10**(-0.4*22)` mcd/m²)를 더한 총 밝기로 SQM을 계산한다. 인공광→0이면 정확히 22.0으로 수렴하고 결과가 22.0을 절대 넘지 않으며, 어두운 국토 셀이 현실적인 Bortle 2~4로 복원된다(대도시는 인공광 지배적이라 값 변화 무시할 수준).

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/lightpollution/convert.py` - `brightness_to_sqm`에 자연광 바닥값 상수 추가 + 총 밝기 변환. `sqm_to_bortle`/`bortle_description`은 변경 없음
- `apps/backend/tests/suitability/test_light_pollution_convert.py` - 발산 방지·상한 회귀 테스트 추가; 기존 0/음수→22.0 테스트는 유지되어야 함

### New Files

- (없음)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 자연광 바닥값 보정

변환 전 자연 밤하늘 밝기를 더해 총 하늘밝기로 SQM을 산출한다.

- [x] `convert.py`: `_NATURAL_BRIGHTNESS_MCD = 108_000_000 * 10 ** (-0.4 * _NATURAL_SKY_SQM)` 상수 추가
- [x] `brightness_to_sqm(artificial)`: `total = max(artificial, 0.0) + _NATURAL_BRIGHTNESS_MCD` 후 `log10(total / 108_000_000) / -0.4` 반환. 음수/0 분기는 이 식에 자연 흡수됨(별도 early-return 불필요, 단 기존 반환 계약 유지)
- [x] 매직넘버 `108_000_000`은 기존 코드와 동일 상수를 재사용(중복 리터럴 정리 권장하되 동작 불변)

**Phase validation**: 아래 회귀 테스트 포함 `just backend-check` green.

### Phase 2: 회귀 테스트

물리 상한과 발산 방지를 고정한다.

- [x] `brightness_to_sqm(0.0) == 22.0`, `brightness_to_sqm(-1.0) == 22.0` (기존 계약 유지 확인)
- [x] 작은 양수(예: `0.05`)에서 결과가 `< 22.0` 이고 발산하지 않음(예: `> 20.0`) 검증
- [x] 넓은 비음수 입력 범위(예: 0.0001 ~ 1e6)에서 결과가 항상 `<= 22.0 + 1e-9` 임을 검증(상한 불변식)
- [x] 밝은 도심 수준 큰 밝기에서 기존과 사실상 동일한 낮은 SQM이 나옴(자연광 바닥값이 지배적이지 않음) 검증

**Phase validation**: `just backend-check` 전부 green, 신규 상한 불변식 테스트 통과.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just backend-check
```

## Notes (agent scratchpad)

- 물리 배경: SQM 미터는 총(자연+인공) 하늘밝기를 측정. 자연 바닥 ~22 SQM. World Atlas는 인공광만 담으므로 변환 전 자연광을 더해야 실측과 일치.
- 검산: 원격지 인공광 0.05 mcd/m² → 수정 전 SQM≈22.3(Bortle 1, 오류) → 수정 후 총 0.221 → SQM≈21.7(Bortle 3, 타당).
- 이 수정 후 오프라인 생성 스크립트(`scripts/gen_light_pollution_grid.py`)로 그리드 JSON을 **재생성**해야 실데이터가 갱신됨(브레인이 별도 처리, `just check`/pytest 범위 밖).

## Amendments (post-build change history, append-only)

- (없음)
