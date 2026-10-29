# 오늘의 관찰 여정: 발견 → 가이드 → 여행 → 기록 → 참여

> Lightweight plan-f3 spec. 이미 있는 화면과 API를 하나의 흐름으로 잇는다. 백엔드·API·인증·데이터 모델은 바꾸지 않는다. 배치·반응형·토큰 적용은 055 범위다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, specs/053-design-tokens-flutter.md, specs/054-shared-components-flutter.md, specs/055-screens-redesign-responsive-flutter.md, docs/PRD-look-up.md
- risk: medium
- order: 053 → 054 → **058 Phase 1~5** → 055 → 056 (사용자 확정, 각 단계 별도 승인)

## Purpose

〈위를 봐요〉의 핵심 차별화(공공데이터 기반 자연관찰 가이드 + 참여형 생태여행)를 '오늘의 관찰 여정' 한 흐름으로 보여준다. 이용자가 관찰 장소와 일정을 직접 조사하지 않아도 오늘의 조건 → 추천 장소 → 주변 여행 → 기록 → 참여로 안내받게 한다.

## Problem

발견·가이드·여행·기록 단계에 쓸 부품은 실제 API로 동작하지만 서로 이어져 있지 않다. 생태일기·작성·배지 화면은 앱에서 들어갈 길이 없고, 다른 화면에서 특정 관찰 장소를 열거나 기록 폼을 미리 채울 방법이 없다. 화면 곳곳에 관찰 결과나 종 출현을 단정하는 문구가 있고(예: 점수와 무관한 "완벽한 하루예요", 날씨를 반영하지 않은 "은하수까지 선명해요"), 공공데이터와 시민과학 데이터(eBird)가 구분되지 않는다.

## Solution

탭 이동·장소 지정·폼 미리 채우기 같은 연결 기반을 만들고, 기존 응답만으로 추천 장소와 "지금/다음 관찰 시간"을 계산한다. 홈에 5단계 '오늘의 관찰 여정' 카드를 넣어 각 단계에서 기존 화면으로 이동하게 하고, 기록·참여 진입과 시범 미션을 연결한다. 단정 문구를 고치고 데이터 출처를 구분해 표시한다.

## 불변 조건

- **백엔드(`apps/backend`), API 클라이언트(`lib/api/*_api.dart`)의 인터페이스·요청, 인증(`lib/auth/*`), 데이터 모델(`lib/models/*`)의 구조를 바꾸지 않는다.** 미리 채우기는 화면 생성자의 선택 매개변수로만 처리한다. `models/stay_package.dart`는 예시 문구(문자열)만 고칠 수 있다.
- 사용자 승인 없이 백엔드 변경이 필요한 기능(숙박·관광지·축제 조회, 사용자별 기록, 미션 저장, 지도 `region` 전달 등)은 이 spec에 넣지 않는다.
- 데이터 출처 구분: 기상청·한국천문연구원·국립해양조사원·한국관광공사(두루누비 포함)는 **공공데이터**, eBird는 **시민과학 데이터**, 빛공해 격자는 **참고 데이터(World Atlas 2015)**로 표기한다. 적합도는 **참고 지표**로 표기한다.
- 종 출현이나 관측 결과를 확정적으로 표현하지 않는다. 예: "볼 수 있어요" 대신 "최근 14일 시민과학 데이터(eBird) 기준 N종 기록", 조건은 "관찰 조건이 좋아요 · 참고 지표".
- 실제 기능이 없는 미션은 **시범**, 실제 상품이 아닌 패키지는 **예시**로 표시한다.
- 052의 샘플 대체 동작(`DEMO_FALLBACK`)과 `예시` 표시를 유지한다. 플래그가 꺼진 기본 빌드에서 기존 테스트가 회귀하지 않아야 한다.
- 화면 배치 개편·반응형·토큰 적용은 하지 않는다(055 범위). 홈에는 여정 카드를 **삽입**만 한다.
- 시연 위치는 기존 고정 좌표(강화)다. 여정 화면에 "시연 지역: 강화" 같은 기준을 숨기지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/app_shell.dart` - 탭 index를 Riverpod 상태로 올려 다른 화면에서 탭 전환 가능하게 함(Phase 1).
- `apps/flutter/lib/screens/observation_map_screen.dart` - 선택 매개변수 `initialSpotId`로 해당 장소가 열린 채 시작(Phase 1).
- `apps/flutter/lib/screens/observation_form_screen.dart` - 선택 매개변수 `initialSpeciesType`, `initialSpeciesName`, `initialLat`, `initialLng`로 새 기록 미리 채우기(Phase 1). 저장 후 SnackBar "기록했어요" + 액션 "생태일기 보기" → `DiaryListScreen`(Phase 4, 055에서 이동).
- `apps/flutter/lib/widgets/observation_spot_detail.dart` - 쓰이지 않는 `SuitabilityBlock`(장소별 적합도, 기존 `/api/suitability`를 장소 좌표로 호출)을 다시 연결, '참고 지표' 표기(Phase 2).
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 여정 카드 삽입(Phase 3). 점수와 무관한 고정 인사말을 점수 구간별 문구로 교체(Phase 5, 055에서 이동).
- `apps/flutter/lib/widgets/spot_detail/species_detail.dart`, `bird_spot_detail.dart`, `star_spot_detail.dart` - '기록하기' 버튼 → 미리 채운 작성 폼(Phase 4).
- `apps/flutter/lib/screens/diary_list_screen.dart`, `apps/flutter/lib/screens/badges_screen.dart` - 진입 경로 연결(Phase 4, 055에서 이동).
- `apps/flutter/lib/screens/packages_catalog_screen.dart`, `apps/flutter/lib/widgets/packages/package_card.dart` - '여정 연계 체류 상품(예시)' 안내, 카드에 `예시` 표시, 하단 고정 "서비스 준비 중" 바 정리(Phase 5, 055에서 이동).
- `apps/flutter/lib/widgets/night_sky_scale.dart`, `apps/flutter/lib/widgets/tonight_sky_section.dart`, `apps/flutter/lib/widgets/observation_marker.dart`, `apps/flutter/lib/models/stay_package.dart`(문구만) - 단정 문구 수정, 지도 핀 라벨에 관찰 날짜 표시(Phase 5).

### New Files

- `apps/flutter/lib/state/journey_providers.dart` - 탭 상태, 여정 단계 상태(Phase 1~3).
- `apps/flutter/lib/utils/journey_recommender.dart` - 추천 장소 계산(낮: 새 관찰 장소의 기록 종 수·최근성, 밤: 별 장소 SQM)과 추천 이유 문구(Phase 2).
- `apps/flutter/lib/utils/golden_window.dart` - `GoldenHour.timeRange` 해석, "지금/다음 관찰 시간" 계산(Phase 2).
- `apps/flutter/lib/widgets/journey/journey_card.dart` (+ 단계 위젯) - 홈 여정 카드(Phase 3).
- `apps/flutter/lib/widgets/journey/mission_card.dart` - 배지 진행도를 '이번 주 관찰 1건 기록하기' 같은 **시범** 미션으로 표시. 미션 정의는 앱 안에만 둔다(Phase 4).
- `apps/flutter/lib/utils/nearby_travel.dart` - 선택한 장소와 이미 받은 둘레길 코스·종점 음식점 사이의 거리 계산. "코스 종점 기준 거리"로 표기(Phase 5).
- `apps/flutter/test/...` - 각 Phase의 단위·위젯 테스트(아래 Phase 참고).

## Phases

### Phase 1: 연결 기반

탭 전환, 지도 장소 지정, 기록 폼 미리 채우기를 화면 매개변수와 상태로 만든다.

- [ ] 탭 index를 Riverpod 상태로 올림(`app_shell.dart`, `journey_providers.dart`)
- [ ] `ObservationMapScreen(initialSpotId)` 선택 매개변수
- [ ] `ObservationFormScreen` 미리 채우기 선택 매개변수(기존 수정 모드 `existing` 동작 유지)
- [ ] 테스트: 탭 전환, 지정 장소가 열린 채 시작, 폼 미리 채우기 후 새 기록(POST) 동작, 수정 모드 회귀 없음

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 가이드 로직

기존 응답만으로 추천 장소와 관찰 시간을 계산한다. 화면 스타일은 바꾸지 않는다.

- [ ] `journey_recommender.dart`: 낮/밤 추천과 이유 문구("최근 14일 시민과학 데이터(eBird) 기준 N종 기록" 등)
- [ ] `golden_window.dart`: 지금/다음 골든타임 계산
- [ ] 장소 상세에 `SuitabilityBlock` 재연결, '참고 지표' 표기
- [ ] 테스트: 낮/밤, 데이터 없음, 샘플 데이터 경우의 단위 테스트, 장소 적합도 블록 위젯 테스트

**Phase validation**: `just flutter-check` 통과.

### Phase 3: 홈 '오늘의 관찰 여정' 카드

① 오늘 조건(적합도 · 참고 지표, 지금/다음 골든타임) → ② 추천 장소(이유 표시) → ③ 주변 코스·음식점 → ④ 기록하기 → ⑤ 오늘의 참여(시범).

- [ ] `journey_card.dart` 작성, 홈에 삽입(배치 개편 없음)
- [ ] 각 단계 탭 시 기존 화면·탭으로 이동(지도 장소 열기, 둘레길 탭·코스 상세, 미리 채운 폼, 배지)
- [ ] 샘플 모드에서 `예시` 표시 유지
- [ ] 테스트: 단계별 이동, 360/1280px 넘침 없음

**Phase validation**: `just flutter-check` 통과 + 로컬 웹(DEMO_FALLBACK on/off)에서 사용자 확인.

### Phase 4: 기록·참여 연결

- [ ] 종·새 장소·별 장소 상세의 '기록하기' → 미리 채운 폼
- [ ] 저장 후 "생태일기 보기" → `DiaryListScreen`, 배지 화면 진입 연결
- [ ] `mission_card.dart`: 배지 진행도 기반 **시범** 미션 표시(서버 저장·계정 연결이 없음을 문구에 반영)
- [ ] 테스트: 기록하기 → 미리 채움 → 저장 → 일기 보기 흐름, `시범` 표시, 샘플 모드 기기 임시 저장 안내

**Phase validation**: `just flutter-check` 통과.

### Phase 5: 여행 연결과 문구·출처 정리

- [ ] `nearby_travel.dart`: 장소 주변 코스·음식점 묶음("코스 종점 기준 거리")
- [ ] 패키지 '여정 연계 체류 상품(예시)' 안내와 `예시` 표시
- [ ] 단정 문구 수정: 홈 인사말(점수 구간별), `night_sky_scale.dart`, `tonight_sky_section.dart`, 지도 핀 라벨(관찰 날짜), 패키지 예시 문구
- [ ] 데이터 출처 표기: 공공데이터 / 시민과학 데이터(eBird) / 참고 데이터 구분
- [ ] 테스트: 단정 표현이 없음, '참고 지표'·'시민과학 데이터' 표기, 근처 코스 거리 계산

**Phase validation**: `just flutter-check` 통과 + 로컬 웹에서 여정 전체를 사용자가 확인.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 각 Phase는 범위 보고 → 사용자 승인 → 구현 → lead 검증 → 결과 보고 → 커밋 승인 순서로 진행한다.
- 실행 경로: Windows 세션 내 3계층(flutter-lead → flutter-engineer), 검증은 `flutter pub get && flutter analyze && flutter test`(= `just flutter-check`).
- 쓰이지 않는 `hotspotsProvider` mock(`state/discovery_providers.dart`, 단정 문구 포함)의 삭제 여부는 기존 코드 삭제에 해당하므로 Phase 5 시작 전에 사용자에게 따로 확인한다.
- 적합도 엔진의 한계(물때 점수 낮 85/밤 70 고정, 낮 천문 점수 75 고정, 일출·일몰 미반영)는 백엔드 범위라 이 spec에서 고치지 않는다. 화면에서는 '참고 지표'로만 표기한다.
- 백엔드 변경이 필요한 확장(숙박 32·관광지 12·축제 15, 사용자별 기록·uid·영구 저장, 미션 저장, 지도 지역 전달, 일출·일몰 기반 낮 골든아워, 물때 점수 실데이터화, Cloud Run 복구·CORS)은 별도 승인 안건이다.

## Amendments (post-build change history, append-only)

- 2026-10-29: 신설. spec 055에서 홈 '관찰 기록하기'·생태일기·배지 진입, 점수 구간별 인사말, 패키지 예시 안내를 이 spec으로 이동(사용자 승인).
- 2026-10-29: 디자인 레퍼런스 확정(`docs/design/README.md`). 이 spec의 새 UI(여정 카드, 미션 카드, 출처 표기, 예시·시범 표시)는 054 공용 컴포넌트와 053 흑백 토큰(Flim 기준)을 사용한다. 새 색·그림자·모서리 값을 직접 만들지 않는다. 기능 범위는 변경 없음.
