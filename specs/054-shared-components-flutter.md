# 공용 컴포넌트: 통합 헤더, 상태 표시, 출처 표시 (3단계)

> Lightweight plan-f3 spec. 화면마다 따로 만든 헤더·오류 배너·출처 문구를 하나로 모은다. 4단계 화면 적용의 재료.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, specs/053-design-tokens-flutter.md
- risk: medium

## Purpose

모든 화면이 같은 헤더, 같은 로딩·빈 화면·오류·지연 표시, 같은 데이터 출처 표시를 쓰도록 공용 위젯을 만든다.

## Problem

헤더가 세 종류이고, 오류 배너가 두 벌("다시 불러오기"/"다시 시도")이며, 출처 표기 어휘가 다섯 가지(`실시간`/`참고값`/`추정치`/`예시`/`시안`)로 흩어져 있다. 낮/밤 모드는 홈에서만 바꿀 수 있고, 홈의 모드 토글은 `GestureDetector`라 웹에서 hover·focus·키보드 조작이 안 된다. Flutter 웹 기본 스크롤 동작은 마우스 드래그를 막아 가로 칩 목록을 마우스로 넘길 수 없다.

## Solution

`LookUpHeader`, `ModeToggle`, `StatusView`, `ProvenanceChip`, `DataSourceFooter`, 앱 전역 `LookUpScrollBehavior`를 만들고 테스트한다. 2단계 토큰만 사용한다. 1단계의 `SampleDataNotice`는 `ProvenanceChip`/`StatusView`를 쓰도록 바꾼다.

## 불변 조건

- 출처 어휘는 `실시간`, `추정`, `예시`, `지연` 네 가지로 고정한다.
- 출처 상태는 색만으로 구분하지 않는다. 모양(채운 점/빈 점/점선 테두리/경고 아이콘)과 텍스트를 함께 쓴다.
- 이 spec에서는 기존 화면에 새 위젯을 넣지 않는다(4단계 범위). 예외: `SampleDataNotice` 내부 구현 교체, 앱 전역 ScrollBehavior 등록.
- 인터랙티브 요소는 InkWell/Material 버튼 기반으로 만들어 hover, focus, 키보드, 최소 터치 영역 44×44를 보장한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/main.dart` - `MaterialApp`에 `scrollBehavior: const LookUpScrollBehavior()` 등록.
- `apps/flutter/lib/widgets/sample_data_notice.dart` - 내부를 `StatusView.degraded`/`ProvenanceChip.sample` 기반으로 교체(외부 API 유지).
- `apps/flutter/lib/widgets/mode_header.dart`, `apps/flutter/lib/widgets/app_sliver_header.dart`, `apps/flutter/lib/widgets/app_header_logo.dart` - `LookUpHeader`가 재사용하거나 대체한다. 사용처가 없는 `mode_header.dart`는 새 헤더로 흡수하고, 남은 참조가 없으면 삭제해도 된다.

### New Files

- `apps/flutter/lib/widgets/common/lookup_header.dart` - 로고 + 제목 + 오른쪽 `ModeToggle`(+ 선택적 trailing 액션). Sliver 버전과 일반 버전.
- `apps/flutter/lib/widgets/common/mode_toggle.dart` - 낮/밤 2분할 `SegmentedButton` 스타일(아이콘 + 접근성 라벨), `obsModeProvider` 연결. 자동 모드가 해제되면(MANUAL) 작은 점 표시 + 툴팁 "직접 선택함 · 길게 눌러 자동으로".
- `apps/flutter/lib/widgets/common/status_view.dart` - `StatusView.loading`(정적 스켈레톤, reduce-motion 시 애니메이션 없음), `.empty`(중립 아이콘 + 한 줄 + 선택 액션, error 색 금지), `.error`(`cloud_off` + "불러오지 못했어요" + 이유 한 줄 + `FilledButton.tonal` "다시 시도"), `.degraded` 인라인 배너(`LookUpColors.warning` 톤 + "일부 정보가 지연되고 있어요 · 마지막 갱신 HH:mm" + "다시 시도").
- `apps/flutter/lib/widgets/common/provenance_chip.dart` - live(채운 점, "실시간 · HH:mm"), approx(빈 점, "추정"), sample(점선 테두리, "예시"), stale(경고 아이콘, "지연 · HH:mm 기준").
- `apps/flutter/lib/widgets/common/data_source_footer.dart` - "데이터 출처: 한국관광공사 · 기상청 · 한국천문연구원 · 국립해양조사원 · eBird / 공공누리" 한 줄(접기 가능).
- `apps/flutter/lib/widgets/common/lookup_scroll_behavior.dart` - `MaterialScrollBehavior` 확장, `dragDevices`에 touch, mouse, trackpad, stylus 포함.
- `apps/flutter/test/widgets/common/*_test.dart` - 각 위젯 테스트: 4가지 출처 상태의 텍스트·아이콘, StatusView 각 상태와 "다시 시도" 콜백, ModeToggle 탭 시 `obsModeProvider` 변경, 키보드 포커스 가능, 두 테마에서 렌더링 오류 없음.

## Phases

### Phase 1: 기반 위젯

- [ ] `LookUpScrollBehavior` 작성 및 등록
- [ ] `ProvenanceChip`, `StatusView`, `DataSourceFooter` 작성과 테스트

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 헤더와 모드 토글

- [ ] `ModeToggle`, `LookUpHeader` 작성과 테스트
- [ ] `SampleDataNotice` 내부 교체

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

## Amendments (post-build change history, append-only)

