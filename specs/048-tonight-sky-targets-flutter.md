# 홈 "오늘 밤 하늘" — 위치별 보이는 별자리/성운 목록

> Lightweight plan-f3 spec. design-lead 자문 확정안. starlight all_visible_targets 소비(백엔드 계약 기존).

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/040-starlight-forecast-backend.md, specs/045-home-night-sky-relocate-flutter.md
- risk: medium

## Purpose

홈(발견/큐레이션) 밤 모드에, 이 위치에서 오늘 밤 보이는 별자리/성운/은하수 목록을 독립 "오늘 밤 하늘" 서브섹션으로 노출한다.

## Problem

백엔드 `starlight` 예보는 관측자 위경도·시각 기반으로 `all_visible_targets`(보이는 대상 전체, score순 정렬)를 계산해 반환하지만, Flutter는 이를 파싱/렌더하지 않는다(모델이 목록 미파싱, starlight가 어떤 provider에도 미배선). 사용자는 "지금 여기서 무엇이 어느 방향에 보이는지" 알 수 없다.

## Solution

`StarlightForecast` 모델에 `allVisibleTargets` 파싱을 추가하고, 밤 모드 전용 starlight provider를 배선한 뒤, 홈 핫스팟 섹션 바로 위에 독립 "오늘 밤 하늘" 컴팩트 리스트(상위 3 + 더보기)를 렌더한다. 순수 flutter 작업(백엔드 계약 기존).

## Relevant Files

### Existing Files

- `apps/flutter/lib/models/starlight_forecast.dart` - `StarlightForecast`에 `List<StarlightTarget> allVisibleTargets` 파싱 추가(`all_visible_targets`). `StarlightTarget`엔 이미 constellation/direction/targetType 등 있음, altitude/observation_mode 필드 확인·보강.
- `apps/flutter/lib/state/discovery_providers.dart` - 밤 모드 전용 starlight forecast provider 배선(현재 위치 lat/lng로 `StarlightApi` 호출). 낮 모드에선 호출/watch 안 함.
- `apps/flutter/lib/api/starlight_api.dart` - 필요 시 응답 파싱 정합.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 밤 모드에서 핫스팟 섹션(≈L761) 바로 위에 "오늘 밤 하늘" 독립 서브섹션 추가. 오버라인 `TONIGHT'S SKY` + 헤딩 "오늘 이 자리에서 보이는 하늘". 컴팩트 행(골든아워/오늘의 달과 동일 컨테이너 스타일). stagger reveal 편입.
- `apps/flutter/test/` - 모델 파싱 테스트, 밤 모드 목록 렌더/낮 모드 숨김/상위 3+더보기/빈 목록 empty 문구 테스트.

### New Files

- (필요 시) `apps/flutter/lib/widgets/tonight_sky_section.dart` - "오늘 밤 하늘" 서브섹션 위젯. 홈 내 private로 둬도 무방.

## Phases

### Phase 1: 모델 + provider 배선

- [x] `StarlightForecast`에 `allVisibleTargets` 파싱(`all_visible_targets` → `List<StarlightTarget>`), altitude_deg/observation_mode 등 필드 정합
- [x] 밤 모드 전용 starlight provider(현재 lat/lng) 배선, 낮 모드 미호출
- [x] 모델 파싱 단위 테스트

**Phase validation**: 모델/파싱 테스트 통과.

### Phase 2: "오늘 밤 하늘" 서브섹션 UI

- [x] 밤 모드에서 핫스팟 섹션 바로 위에 독립 서브섹션 렌더(오버라인+헤딩)
- [x] 컴팩트 리스트: 상위 3개(백엔드 score순 그대로) + "N개 더 보기" 펼침. 카드 아님, 골든아워/오늘의 달 컨테이너 스타일 재사용
- [x] 각 행: 타입 아이콘(은하수/별자리/성단/별 4종) + 이름 + 방위·고도 일상어("남동쪽 하늘, 머리 위 가까이") + 관측유형 pill(맨눈/쌍안경/망원경). 방위각·target_type raw 금지. 설명은 행 탭 시 인라인 펼침
- [x] 고도 3구간 번역(지평선 근처 / 중간 높이 / 머리 위 가까이)
- [x] 낮 모드 숨김. 빈 목록: "오늘 밤은 또렷이 보이는 대상이 적어요" empty 문구. approx/stub 시 "추정치" 표기
- [x] 접근성 semanticsLabel(이름+방위/고도+관측유형 합성), stagger reveal 편입(핫스팟과 슬롯 안 겹치게)

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 백엔드 `all_visible_targets`는 service.py에서 score순(best 먼저) 정렬됨 → 상위 3개 그대로 사용.
- 정보 위계(중복 방지): 별밝기 블록="얼마나 어둡나(장소 조건)", 오늘 밤 하늘 목록="무엇을 어느 방향에서(대상 선택지)". 각 행에 SQM/별 개수 반복 금지.
- best 1개는 목록 최상단에 자연히 위치. v1은 행 탭=인라인 펼침(대상 상세 화면 없음).
- 카탈로그 9개 고정 전제(홈 인라인 적합). 향후 대량 확장 시 검색/필터 별도 화면 재검토.

## Amendments (post-build change history, append-only)

- 2026-09-21: 1차 시도(cross-model verifier) FAIL 3건을 수정: (1) 오버라인 카피 `TONIGHT SKY`→`TONIGHT'S SKY`, 헤딩 카피 오타 수정, 빈 목록 문구 수정(`tonight_sky_section.dart`, 대응 테스트 동기화), (2) `_StaggerReveal` 슬롯 겹침 수정 — `_staggerTotalDuration` 420ms→620ms, 핫스팟 슬롯 startMs 200→400(오늘 밤 하늘 슬롯 180ms와 겹치지 않게 분리), (3) 밤 모드 렌더/낮 모드 숨김/provider 호출 억제를 검증하는 `HomeDiscoveryScreen` 위젯 테스트 3건 추가(`home_discovery_screen_test.dart`, `FakeStarlightApi` 도입). `just check` 재실행으로 backend 213 passed/12 skipped, flutter analyze 이슈 0건, flutter test 249건 전부 통과 확인.

- modified: 2026-09-21, lead: flutter-lead (claude)
