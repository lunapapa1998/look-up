# 별 스팟 시트에 천체 골든타임 + 관측 가능한 별자리 추가

> Lightweight plan-f3 spec. 오너 지시. spec 048의 starlight 소비를 스팟 시트로 확장.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-21
- modified: 2026-09-21 brain
- refs: specs/048-tonight-sky-targets-flutter.md, specs/040-starlight-forecast-backend.md
- risk: medium

## Purpose

관측 지도에서 별 스팟(강화 천문인마을)을 탭했을 때 나오는 상세 시트에, 그 위치의 천체 골든타임과 오늘 밤 관측 가능한 별자리 목록을 추가한다.

## Problem

`star_spot_detail.dart`는 현재 [이름 → NightSkyTag(SQM/별밝기) → SuitabilityBlock]만 보여준다. starlight 예보 엔진이 그 스팟 좌표로 골든타임(일몰/박명 종료=관측 시작)과 보이는 별자리 목록을 계산할 수 있는데 시트에 노출되지 않는다.

## Solution

스팟 좌표(lat/lng)로 조회하는 family starlight provider를 추가하고, 별 스팟 상세 시트에 "천체 골든타임" 블록(예보 문장 + 일몰/관측 시작 시각)과 "오늘 밤 보이는 별자리" 목록(spec 048의 `tonight_sky_section` 재사용)을 추가한다. 순수 flutter 작업(백엔드 계약·모델 기존).

## Relevant Files

### Existing Files

- `apps/flutter/lib/state/discovery_providers.dart` - 좌표 기반 family starlight provider 추가(`FutureProvider.family<StarlightForecast, ({double lat, double lng})>` 형태). 기존 홈용 provider가 있으면 그것을 family로 일반화하거나 병행.
- `apps/flutter/lib/widgets/spot_detail/star_spot_detail.dart` - NightSkyTag 아래에 (1) "천체 골든타임" 블록: `forecast.summary`(예보 문장) + `sunset`/`astronomicalTwilightEnd`(일몰·관측 시작 시각) 표시, (2) "오늘 밤 보이는 별자리" 섹션: `forecast.allVisibleTargets`를 `tonight_sky_section` 위젯으로 렌더. 그 아래 기존 Divider + SuitabilityBlock 유지.
- `apps/flutter/lib/widgets/tonight_sky_section.dart` - 재사용(무편집 우선). 스팟 시트 문맥에 맞게 파라미터화가 필요하면 최소 보강.
- `apps/flutter/lib/models/starlight_forecast.dart` - 기존 필드(summary/sunset/astronomicalTwilightEnd/allVisibleTargets) 사용, 무편집 우선.
- `apps/flutter/test/` - 스팟 시트 렌더 테스트(골든타임 블록 + 별자리 목록), 로딩/degraded/빈 목록 처리, FakeStarlightApi 재사용.

### New Files

- (필요 시) `apps/flutter/lib/widgets/spot_detail/star_golden_time.dart` - 골든타임 블록 위젯. star_spot_detail 내 private로 둬도 무방.

## Phases

### Phase 1: 좌표 기반 provider

- [x] 스팟 좌표로 starlight 예보를 가져오는 family provider 추가(로딩/에러 처리)
- [ ] provider 단위 테스트(또는 Fake로 위젯 테스트에서 커버) — Phase 2 위젯 테스트로 커버 예정

**Phase validation**: 관련 테스트 통과.

### Phase 2: 스팟 시트 UI

- [x] 별 스팟 상세에 "천체 골든타임" 블록: 예보 문장(summary) + 일몰/관측 시작(박명 종료) 시각. 컴팩트, 기존 시트 톤 일관
- [x] "오늘 밤 보이는 별자리" 섹션: `allVisibleTargets`를 `tonight_sky_section`으로 렌더(상위 N + 더보기, 타입 아이콘 + 방위/고도 일상어 + 관측유형). 방위각/target_type raw 금지
- [x] 로딩 스켈레톤, degraded 시 "추정치" 표기, 빈 목록 empty 문구 (빈 목록/추정치는 `TonightSkySection` 기존 처리 재사용)
- [x] 기존 NightSkyTag(large) + SuitabilityBlock 유지, 순서: 이름 → 별밝기(NightSkyTag) → 천체 골든타임 → 오늘 밤 보이는 별자리 → SuitabilityBlock
- [x] 위젯 테스트 갱신/추가

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- starlight 모델은 이미 spec 048에서 summary/sunset/astronomicalTwilightEnd/allVisibleTargets 파싱함 → 백엔드/모델 변경 불필요.
- 강화 천문인마을 좌표(37.7378, 126.4708)로 조회 시 카시오페이아/북두칠성/베가 등 실계산 별자리가 나옴(시각 의존).
- 위계 중복 방지: NightSkyTag=장소 어둡기(SQM/별밝기), 골든타임=언제, 별자리 목록=무엇을 어느 방향. 각 별자리 행에 SQM 반복 금지.
- Figma 참고(별자리 설명 UI): node 19-2169 / 성운 핫스팟 UI: node 1-185 — 정합은 후속 리파인 가능.

## Amendments (post-build change history, append-only)

- 2026-09-21: 크로스모델 검증 FAIL(loading/empty 미커버) 재위임 후 수정. loading 테스트가 즉시-resolve하는 fake API 때문에 실제로는 로딩 상태를 포착하지 못하고 있었음(`tester.pump()` 1회 만에 Future가 이미 resolve됨) → Completer 기반 `_PendingStarlightApi`로 재작성해 진짜 미해결 상태를 검증하도록 수정. empty-list 테스트(`_emptyForecast` 헬퍼)도 함께 추가. `just check` green 확인(4개 테스트 전부 통과).

- modified: 2026-09-21, lead: claude-sonnet-5
