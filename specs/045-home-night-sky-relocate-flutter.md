# 홈 밤하늘 밝기 표시 재배치 (점수 하단 / 밤 전용 + 낮 한 줄)

> Lightweight plan-f3 spec. design-lead 자문 확정안. spec 042/044에 이은 배치 조정.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/042-light-pollution-plain-language-flutter.md, specs/044-home-light-pollution-plain-language-flutter.md, specs/039-moon-section-flutter.md
- risk: medium

## Purpose

홈 화면에서 밤하늘 밝기(별 스케일) 표시를 적합도 점수 카드 헤더에서 떼어내, 밤 모드에선 점수 카드 바로 아래 독립 블록으로, 낮 모드에선 카드 아래 경량 한 줄로 재배치한다.

## Problem

현재 밤하늘 밝기(`NightSkyTag`)가 적합도 점수 게이지와 같은 카드 헤더에 붙어 있어, 종합 점수(합성)와 측정 지표(밤하늘 밝기)의 성격·위계가 한 행에서 충돌한다. 또 관측 판단의 핵심 근거인 밤하늘 밝기가 점수 결론과 시각적으로 묶여 있지 않다.

## Solution

적합도 카드 헤더 trailing의 `NightSkyTag`를 제거하고, 밤 모드에선 점수 카드 바로 아래(골든아워 위)에 별 스케일 블록을 독립 배치(순서: 점수 → 별밝기 → 골든아워 → 오늘의 달), 낮 모드에선 카드 아래 "오늘 밤 · <라벨>" 경량 한 줄로 상시 노출한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - (1) 적합도 카드 헤더 trailing의 `NightSkyTag`+`ConstrainedBox(maxWidth:170)` 제거(≈L382-403), 회수 여백은 라벨 확장. (2) 밤 모드: 점수 카드 바로 아래 별밝기 독립 블록 추가(`currentMode == ObsMode.night` + status 유효 시). (3) 낮 모드: 카드 아래 "오늘 밤 · <쉬운 라벨>" 경량 한 줄. (4) stagger 모션 슬롯 편입.
- `apps/flutter/lib/widgets/night_sky_tag.dart` / `night_sky_scale.dart` - 별 스케일/쉬운 라벨 표현 재사용. 밤 블록·낮 한 줄에 맞는 표현 확인(별 스케일이지 원문 SQM이 아니어야 함).
- `apps/flutter/test/` - 홈 위젯 테스트: 밤 모드 순서(점수→별밝기→골든아워→달), 낮 모드 한 줄 노출, 카드 헤더에서 별 제거, approx/hasNoData 처리 검증.

### New Files

- (필요 시) `apps/flutter/lib/widgets/night_sky_section.dart` - 밤 모드 독립 블록 위젯(`_TodayMoonSection`과 동일 컨테이너 스타일). 홈 화면 내 private 위젯으로 둬도 무방.

## Phases

### Phase 1: 카드 헤더에서 제거 + 밤 모드 블록

- [x] 적합도 카드 헤더 trailing의 `NightSkyTag`/`ConstrainedBox` 제거, 카드는 게이지+라벨만
- [x] 밤 모드: 점수 카드 바로 아래(골든아워 위) 별밝기 독립 블록 배치. 헤더 없이 점수에 밀착("점수의 부속 근거"). 컨테이너 스타일 `_TodayMoonSection`과 일관(surfaceContainerLow α0.9, radius 8, 좌측 아이콘 슬롯 `Icons.auto_awesome` + 본문 + 우측 값/ⓘ)
- [x] 별 스케일 + 쉬운 라벨(mapNightSky) 표현. SQM·Bortle는 ⓘ 탭 바텀시트로만(현재 측정값 표시 포함). isApprox→별 opacity 0.6 + "추정치". hasNoData→별 숨기고 "밤하늘 밝기 정보 없음"
- [x] 최종 밤 순서: 점수 → 별밝기 → 골든아워 → 오늘의 달

**Phase validation**: 위젯 테스트로 밤 모드 순서·별 제거·상태 처리 확인.

### Phase 2: 낮 모드 한 줄 + 모션

- [x] 낮 모드: 카드 아래 "오늘 밤 · <쉬운 라벨>" + 미니 별 스케일 + ⓘ 경량 한 줄 상시 노출("오늘 밤" 시제 앵커 필수)
- [x] 낮↔밤 수동 전환 시 별밝기 블록/한 줄을 기존 `_StaggerReveal` 리듬에 편입(점수 다음, 골든아워 앞 슬롯). auto·reduce-motion은 즉시 settle
- [x] 카드 폭/전폭 오버플로 없음

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- design-lead 확정: "이동(move), 복제 아님". 밤 배치는 (달 아래가 아니라) 점수 바로 하단 — 근거는 결론 옆, 첫 화면 노출 확보, 위계 정순(점수=결론 / 별밝기=핵심 근거 / 달=시간가변 방해요소는 골든아워 계열).
- 별 스케일 표현이 이미 042/044로 들어갔는지 확인하고, 원문 SQM이 남아있다면 이 스펙에서 별 스케일로 통일.
- 후속(스코프 밖): 지도 핀·스팟 시트의 원문 SQM 라벨 표현 불일치는 별도 스펙.

## Amendments (post-build change history, append-only)

- 2026-09-20: 재보완 라운드 — 크로스모델 검증 FAIL 2건 수정. (1) ⓘ 바텀시트가 설명문만 보이고 실측값이 없던 문제: `showNightSkyInfoSheet`에 `NightSky` 인자를 추가해 현재 SQM/Bortle 값을 시트 하단에 표시(`night_sky_tag.dart`), `NightSkyInfoButton`에 `nightSky` 필드 추가. (2) 위젯 테스트 커버리지 누락(달 순서, 낮 "오늘 밤" 한 줄, approx/no-data 상태): `home_discovery_screen_test.dart`에 4개 테스트 추가, `FakeSuitabilityApi`에 `nightSkyStatusOverride` 파라미터 추가(approx/none 상태 테스트용). `just check` 236개 테스트 전부 통과 확인.

- modified: 2026-09-20, lead: sonnet
