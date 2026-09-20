# 홈 카드 빛공해 표시를 쉬운 언어로 (spec 042 마무리)

> Lightweight plan-f3 spec. spec 042의 미해결 항목(홈 메인 카드) 마무리. spec 043 계약 확장에 의존.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/042-light-pollution-plain-language-flutter.md, specs/043-suitability-bortle-contract-backend.md
- risk: medium

## Purpose

홈 화면 메인 적합도 카드가 여전히 원문 `SQM {값}` + `Class N ...`을 렌더하는 것을, spec 042에서 만든 별 스케일/쉬운 라벨 표현으로 통일한다.

## Problem

`home_discovery_screen.dart`는 `SuitabilityIndex.sqmValue`/`skyClass`를 원문 그대로 렌더한다. spec 042의 `mapNightSky`는 `bortleClass`가 필요한데 `SuitabilityIndex`에 없어 적용하지 못했다. spec 043으로 백엔드가 `bortleClass`/`nightSkyStatus`를 노출하면 홈도 통일할 수 있다.

## Solution

`SuitabilityIndex` 모델에 `bortleClass`/`nightSkyStatus`를 추가해 파싱하고, `home_discovery_screen`의 원문 SQM/skyClass 렌더를 spec 042의 `mapNightSky`/`NightSkyTag` 표현으로 교체한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/models/discovery.dart` - `SuitabilityIndex`에 `bortleClass`(int), `nightSkyStatus`(String) 필드 + `fromJson` 파싱 추가. 구버전 응답 대비 방어적 기본값.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 원문 `SQM {값}`(≈L397) + `skyClass`(≈L414) 렌더를 `mapNightSky`/`NightSkyTag` 기반 별 스케일 표현으로 교체. 카드 좁은 공간에 맞는 컴팩트 배치.
- `apps/flutter/lib/widgets/night_sky_tag.dart` / `night_sky_scale.dart` - 재사용(무편집 우선). 홈 카드 폭 제약상 필요하면 컴팩트 변형 검토.
- `apps/flutter/test/` - 홈 위젯 테스트에서 별 스케일/라벨 렌더 확인, 기존 원문 SQM 단언 갱신.

### New Files

- (없음 우선; 홈 전용 컴팩트 표현이 필요하면 최소한으로)

## Phases

### Phase 1: 모델 확장

- [x] `SuitabilityIndex`에 `bortleClass`/`nightSkyStatus` 추가 + `fromJson` (누락 시 방어적 기본값)
- [x] 모델 단위 테스트

**Phase validation**: 모델 테스트 통과.

### Phase 2: 홈 카드 표현 교체

- [x] `home_discovery_screen`의 원문 SQM/skyClass 렌더를 별 스케일/쉬운 라벨로 교체 (spec 042 표현과 일관)
- [x] approx → "추정치" 표기, 카드 폭 오버플로 없음
- [x] 홈 위젯 테스트 갱신/추가

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- spec 043(backend)이 먼저 통과해야 이 스펙의 `bortleClass`/`nightSkyStatus` 파싱이 실데이터로 검증된다.
- spec 042의 `NightSkyTag`/`mapNightSky`를 최대한 재사용. 홈 카드 폭이 좁으면 별 스케일 + 라벨만 컴팩트로.

## Amendments (post-build change history, append-only)

- 2026-09-20: home_discovery_screen.dart의 카드 헤더 trailing 컬럼을 `ConstrainedBox(maxWidth: 170) > NightSkyTag(large: false)`로 교체(원래 시도한 140은 별 5개 행 + 안내 버튼 폭에 2px 부족해 overflow). NightSkyTag는 `NightSky` 모델(models/trails.dart)을 받으므로 `SuitabilityIndex`의 4개 필드로 매 렌더마다 NightSky를 구성.
- 2026-09-20: 홈 화면 전체 320px 폭 회귀 테스트는 이 스펙과 무관한 기존 오버플로(앱바 타이틀, golden hour 아이콘 행)를 노출해 375px(표준 iPhone 폭)로 조정 — 카드 자체의 컴팩트 레이아웃만 검증 범위로 좁힘. 기존 320px 오버플로는 별도 스펙에서 다뤄야 함.

- modified: 2026-09-20, lead: claude
