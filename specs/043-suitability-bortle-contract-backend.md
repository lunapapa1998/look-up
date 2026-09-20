# suitability 응답에 bortleClass·nightSkyStatus 노출 (계약 확장)

> Lightweight plan-f3 spec. flutter 홈 카드가 밤하늘 밝기를 쉬운 언어로 표시하려면 필요한 계약 확장.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/042-light-pollution-plain-language-flutter.md, specs/040-light-pollution-grid-backend.md
- risk: medium

## Purpose

flutter 홈 화면이 빛공해 데이터를 별 스케일/쉬운 라벨(spec 042의 `mapNightSky`)로 표시할 수 있도록, suitability 응답에 `bortleClass`와 빛공해 신뢰도 status를 노출한다.

## Problem

`SuitabilityResponse`는 `sqmValue`/`skyClass`만 내보내고 `bortleClass`와 빛공해 `status`(approx/stub/none)를 포함하지 않는다. flutter `mapNightSky(bortleClass, status)`는 이 두 값이 있어야 동작하는데, 홈이 쓰는 `SuitabilityIndex`엔 없어 홈 카드만 여전히 원문 `SQM` 텍스트를 렌더한다.

## Solution

`SuitabilityResponse`에 `bortleClass: int`와 `nightSkyStatus: str`를 추가한다. 두 값 모두 이미 `LightPollutionProvider`가 계산해 `readings["lightPollution"]`의 evidence(`bortleClass`)와 `.status`에 갖고 있으므로, 모델 필드 추가 + 서비스 통과만 하면 된다(순수 additive, 하위호환).

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/models.py` - `SuitabilityResponse`에 `bortleClass: int`, `nightSkyStatus: str` 필드 추가.
- `apps/backend/app/suitability/service.py` - `light_pollution_evidence.get("bortleClass")`와 `readings["lightPollution"].status`를 응답에 통과. evidence에 값이 없을 때의 안전한 기본값(bortleClass 누락 시 sqm에서 유도하거나 9, status 누락 시 'none').
- `apps/backend/tests/suitability/` - 응답 스키마/값 테스트 확장.

### New Files

- (없음)

## Phases

### Phase 1: 계약 확장

- [x] `SuitabilityResponse`에 `bortleClass: int` + `nightSkyStatus: str` 추가
- [x] `service.py`에서 evidence의 `bortleClass`, 리딩의 `status`를 응답에 통과 (누락 시 안전 기본값)
- [x] 기존 응답 소비 테스트가 깨지지 않는지 확인(additive)
- [x] 신규 필드 값 검증 테스트: fallback 경로(evidence에 bortleClass 없을 때 `sqm_to_bortle` 유도)와 passthrough 경로(evidence에 명시적 `bortleClass` 있을 때 그대로 통과) 둘 다 커버

**Phase validation**: `just backend-check` 통과 + 신규 필드 테스트 통과.

## Validation Commands

```sh
just backend-check
```

## Notes (agent scratchpad)

- 값 출처: `LightPollutionProvider.fetch`가 evidence에 `bortleClass`, `sqmValue`, `skyClass`, `method`를 넣고 `LayerReading.status`에 approx/stub를 둠. "데이터 없음"(none)은 현재 provider가 항상 값을 반환하므로 미발생이나, 계약상 status 문자열을 그대로 노출해 flutter가 방어적으로 처리할 수 있게 한다.
- 후속(별건 flutter): `SuitabilityIndex`에 `bortleClass`/status 추가 후 `home_discovery_screen`의 원문 SQM 렌더를 `NightSkyTag`/`mapNightSky`로 교체 (spec 042 마무리).

## Amendments (post-build change history, append-only)

- 2026-09-20: 신규 필드 검증 테스트는 스펙에 적힌 "강화 실그리드 좌표" 대신 FakeProvider 기반 두 케이스(fallback: evidence에 bortleClass 없음 → `sqm_to_bortle(sqmValue)` 유도, passthrough: evidence에 명시적 bortleClass → 그대로 통과)로 구현. 기존 테스트 스위트가 실그리드 좌표 대신 FakeProvider 패턴을 일관되게 쓰고 있어 동일 패턴을 따름. `just check` 통과(backend 213 passed, flutter 전체 통과)로 검증.
- modified: 2026-09-20, lead: claude-sonnet-5
