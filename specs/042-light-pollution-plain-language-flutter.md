# 빛공해(밤하늘 밝기) 일반인용 쉬운 언어 표시

> Lightweight plan-f3 spec. 표현/카피 개선 스펙. design-lead 자문 기반.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 brain
- refs: specs/040-light-pollution-grid-backend.md, specs/041-lightpollution-natural-sky-floor-backend.md, apps/flutter/lib/widgets/night_sky_tag.dart
- risk: medium

## Purpose

홈/지도/상세에 노출되는 밤하늘 밝기 데이터를 천문 전문용어(SQM·Bortle·Class) 대신 일반 사용자가 즉시 이해하는 쉬운 언어로 바꾼다.

## Problem

현재 `NightSkyTag`는 `SQM 20.30 · Bortle 6 · Class 6 보통 도심 근교 · (약)`처럼 전문용어를 그대로 노출해, 일반 사용자가 "여기서 별이 잘 보이는지" 판단할 수 없다. 특히 "보통 도심 근교"는 좋고 나쁨의 방향성이 없고(강화 지역 대부분이 이 라벨), "(약)"은 지시 대상이 없어 오독된다.

## Solution

1차 정보를 "별 5칸 스케일 + 쉬운 라벨 + 기대 관측물"로 바꾸고, SQM·Bortle 전문값은 progressive disclosure(ⓘ 탭/상세)로 강등한다. 신뢰도 표기는 `(약)`→`추정치`로 바꾸고, 데이터 없음 상태를 명시적으로 처리한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/night_sky_tag.dart` - 주 대상. 컴팩트(`large:false`)/상세(`large:true`) 레이아웃 재구성, 별 스케일·라벨·기대카피·추정치·ⓘ 추가.
- `apps/flutter/lib/models/trails.dart` - `NightSky` 모델. `status`를 데이터 없음('none'/nullable) 수용하도록 방어적 조정.
- `apps/flutter/lib/models/discovery.dart` - `sqmValue`/`skyClass` 소비처 확인 및 정합.
- `apps/flutter/lib/models/starlight_forecast.dart` - 동일 필드 소비처 정합.
- `apps/flutter/lib/widgets/course_card.dart` - 홈 카드에서 태그 배치 확인(레이아웃 회귀 방지).

### New Files

- `apps/flutter/lib/widgets/night_sky_scale.dart` (선택) - Bortle→5단계(별 개수/라벨/기대카피/색) 매핑 유틸. 위젯 내부 private로 둬도 무방.

## Phases

### Phase 1: 매핑 로직

Bortle 등급(1~9)과 status를 사용자 표현으로 변환하는 순수 함수/테이블을 만든다.

- [x] Bortle→5단계 매핑: 1~2 `별이 쏟아져요`(✦✦✦✦✦), 3~4 `별이 잘 보여요`(✦✦✦✦✧), 5~6 `별이 조금 보여요`(✦✦✦✧✧), 7~8 `별이 흐릿해요`(✦✦✧✧✧), 9 `도시 불빛이 강해요`(✦✧✧✧✧)
- [x] 각 단계 기대 관측물 카피 매핑(은하수 앵커): `은하수까지 선명해요`/`맑으면 은하수도 보여요`/`밝은 별과 별자리 위주로 보여요`/`아주 밝은 별만 보여요`/`별 관측은 어려워요`
- [x] status 3분기: `approx`→`isApprox` 플래그(별 opacity는 Phase 2에서 적용), `none`/빈 문자열→`hasNoData` + `정보 없음`, 그 외(`live` 포함)→정상 케이스
- [x] `NightSky.status`를 nullable(`String?`)로 변경, `fromJson`의 `?? 'live'` 폴백 제거 — 누락된 status가 정상 데이터로 위장되지 않도록 수정 (`trails.dart`)
- [x] 순수 매핑 함수 단위 테스트 (경계값 1~9, 클램핑, approx/none/live)

**Phase validation**: 매핑 단위 테스트 통과 (경계값 Bortle 2/3/4/5/6/7/8/9 및 status 3종).

### Phase 2: NightSkyTag 재구성

- [x] 컴팩트(`large:false`): 별 5칸 Row(채운/빈, 리뷰 ★과 구별되는 `Icons.auto_awesome` 사용) + 쉬운 라벨 1행 / 기대카피 + 추정치 배지 1행. SQM·Bortle 숫자 숨김.
- [x] 상세(`large:true`): 위 + 하단 회색 소형 텍스트로 `SQM 20.30 · Bortle 6 (전문가용 측정값)` 노출.
- [x] ⓘ(또는 태그 탭) → 바텀시트/툴팁으로 SQM·Bortle 뜻 설명 및 추정치 출처 설명. 터치 타깃 44×44 이상.
- [x] 게이지/진행바 은유 금지 유지(기존 주석 의도). 별 아이콘은 방향성만.
- [x] 색 스케일: 청록(좋음)→그레이→앰버(주의), 레드 금지. 기존 `_contrastRatio ≥ 4.5` 폴백을 별 색에도 적용.
- [x] 접근성: semanticsLabel에 별 개수·라벨·신뢰도 음성 노출(색+아이콘+텍스트 3중 인코딩), 장식용 별 아이콘은 `ExcludeSemantics`로 중복 낭독 방지.

- [x] approx 상태의 별 opacity 적용 — 채워진 별에 `isApprox` 기반 투명도(0.6/1.0) 차등 적용 (`night_sky_tag.dart`)
- [x] 컴팩트 레이아웃 행 재배치 — `추정치` 배지를 라벨 행에서 기대카피 행으로 이동해 "라벨 1행 / 기대카피+추정치 배지 1행" 구조로 정정 (`night_sky_tag.dart`)
- [x] 위젯 테스트 커버리지 확장 — 5개 Bortle 티어 라벨, 별 아이콘 5개 개수, 시맨틱스 라벨(추정치 포함), approx/live 알파값 비교 테스트 추가 (`night_sky_tag_test.dart`, 기존 5개 → 총 13개)

**Phase validation**: 위젯 테스트로 5단계 라벨/별개수/추정치·정보없음 상태/상세 숫자 노출 렌더 확인 — `night_sky_tag_test.dart` 신규 통과. `just check` 226/226 통과, analyze 0 issues (기존 218 + 신규 8).

### Phase 3: 소비처 정합 & 회귀

- [x] 홈 course_card, 스팟/코스 상세(`NightSkyTag` 사용처)에서 태그 레이아웃 오버플로 없음 확인 — `just check` 전체 그린(218/218 통과, analyze 0 issues). 카드 높이 증가로 테스트 뷰포트 밖 탭 이슈 발생 → `trails_wiring_test.dart` 테스트 서피스 확대로 해결(위젯 자체는 무변경).
- [ ] 기존 `skyClass` 문자열 직접 렌더하던 곳 통일 — **부분 완료**: `NightSkyTag` 소비처(course_card, trail/star spot detail, course_detail_screen)는 전부 통일됨. `home_discovery_screen.dart:397,414`가 `SuitabilityIndex.sqmValue`/`skyClass`(discovery.dart)를 여전히 원문 렌더 중이나, 이 모델에는 `bortleClass`가 없어 `mapNightSky`를 적용할 수 없음 — 백엔드 계약에 `bortleClass` 추가가 선행되어야 하는 별도 후속 스펙 필요. `observation_marker.dart`/`observation_spot_sheet.dart`의 지도 핀 `SQM {값}` 한 줄 라벨은 스펙 Relevant Files에 없고 극도로 좁은 지도 픽셀 예산 제약이 있어 이번 범위에서 제외.

**Phase validation**: `just flutter-check` 통과 (전체 grün 확인, 위 미해결 항목은 범위 밖으로 별도 기록).

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- design-lead 자문 요약: 수치가 아니라 "여기서 뭐가 보이는지"로. 별 5칸 스케일 1순위(게이지 배제 근거=night_sky_tag.dart L15-18 주석). "보통 도심 근교"·"광해 심각"·"(약)" 전면 교체.
- 데이터 없음(status null) 케이스가 현재 코드에 없음 — 프론트는 방어적으로 처리하되, 백엔드 계약에 "데이터 없음" 명시값 추가는 별도 backend 스펙으로 분리(후속).
- 카피 문구는 확정본이 아니라 1차안 — 오너 리뷰로 조정 가능.

## Amendments (post-build change history, append-only)

- 2026-09-20: 크로스모델 검증(FAIL) 후 재작업 — (1) `NightSky.status`가 non-nullable + `fromJson`이 누락값을 `'live'`로 폴백해 데이터 없음을 정상 데이터처럼 위장하던 버그 수정, (2) `isApprox` 상태에서 채워진 별 아이콘이 정상 데이터와 동일한 불투명도로 렌더되던 것을 opacity 0.6으로 차등, (3) 컴팩트 레이아웃에서 `추정치` 배지가 라벨 행에 붙어있던 것을 기대카피 행으로 이동, (4) `night_sky_tag_test.dart`에 5단계 티어 라벨/아이콘 개수/시맨틱스/opacity 비교 테스트 8건 추가. `home_discovery_screen.dart`/`observation_marker.dart`/`observation_spot_sheet.dart`의 raw SQM 노출은 기존 Amendments대로 계속 범위 밖(백엔드 `bortleClass` 계약 확장 선행 필요).

- 2026-09-20: `home_discovery_screen.dart`의 `SuitabilityIndex.sqmValue`/`skyClass` 원문 렌더는 이번 스펙 범위에서 미해결로 남김 — `SuitabilityIndex`(discovery.dart)에 `bortleClass` 필드가 없어 `mapNightSky` 매핑 불가. 백엔드 계약 확장(SuitabilityIndex에 bortleClass 추가) 후 별도 후속 flutter 스펙으로 처리 필요.
- 2026-09-20: `observation_marker.dart`/`observation_spot_sheet.dart`의 지도 핀 `SQM {값}` 한 줄 라벨은 Relevant Files에 없었고 지도 픽셀 예산이 극히 좁아 이번 범위에서 제외. 필요 시 별도 스펙에서 검토.
- 2026-09-20: Phase 2/3 검증 중 `NightSkyTag` 컴팩트 레이아웃이 별 행 + 라벨 행 + 기대카피 행(3줄)으로 늘어나며 `course_card.dart`의 카드 높이가 커져, `trails_wiring_test.dart`의 기존 800×600 기본 테스트 서피스에서 featured 카드 탭이 뷰포트 밖으로 밀려 hit-test 실패가 발생함 — 위젯은 무변경, 테스트 헬퍼 `_pumpTrails`에 800×1400 서피스 오버라이드(+teardown) 추가로 해결.
- modified: 2026-09-20, lead: claude sonnet
- modified: 2026-09-20, lead: claude sonnet 5 (재작업)
