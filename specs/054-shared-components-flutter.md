# 공용 컴포넌트: 통합 헤더, 상태 표시, 출처 표시 (3단계)

> Lightweight plan-f3 spec. 화면마다 따로 만든 헤더·오류 배너·출처 문구를 하나로 모은다. 4단계 화면 적용의 재료.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, specs/053-design-tokens-flutter.md
- risk: medium
- modified: 2026-10-29 brain — 컴포넌트 스타일 기준을 Flim(흑백 대비, 버튼 8·카드 16·pill 원형, 그림자 없음)으로 명시, 영문·숫자 라벨 컴포넌트 추가
- refs: docs/design/README.md, docs/design/flim.md, specs/058-today-observation-journey-flutter.md

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
- 스타일 기준은 Flim(`docs/design/flim.md`, 해석은 `docs/design/README.md`)과 053 토큰이다. 그림자 없음, 경계선 1px. 버튼 모서리 8, 카드 16, 칩·태그 원형, 링크 4. 채움 버튼은 바탕과 반전되는 흑백만 쓰고(낮 검정 채움, 밤 흰 채움), 컬러 채움 버튼은 만들지 않는다. 그 밖의 행동은 외곽선(ghost)·텍스트 링크로 표현한다.
- 상태·출처 보조색은 점·작은 테두리·아이콘에만 쓰고, 칩·배너의 글자는 항상 본문색(흑/백)으로 쓴다.
- 영문·숫자 라벨(eyebrow, 수치 단위)은 mono 스타일(대문자·자간 0.06em)을 쓸 수 있으나, 한글 라벨에는 대문자·넓은 자간 규칙을 적용하지 않고 Pretendard로 쓴다.
- 052의 `SampleMark`·`SampleDataNotice`는 이 spec의 `ProvenanceChip`·`StatusView` 규칙으로 통합하되 외부 API(위젯 이름·매개변수)는 유지해 058 이후 코드가 깨지지 않게 한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/main.dart` - `MaterialApp`에 `scrollBehavior: const LookUpScrollBehavior()` 등록.
- `apps/flutter/lib/widgets/sample_data_notice.dart` - 내부를 `StatusView.degraded`/`ProvenanceChip.sample` 기반으로 교체(외부 API 유지).
- `apps/flutter/lib/widgets/mode_header.dart`, `apps/flutter/lib/widgets/app_sliver_header.dart`, `apps/flutter/lib/widgets/app_header_logo.dart` - `LookUpHeader`가 재사용하거나 대체한다. 사용처가 없는 `mode_header.dart`는 새 헤더로 흡수하고, 남은 참조가 없으면 삭제해도 된다.

### New Files

- `apps/flutter/lib/widgets/common/lookup_header.dart` - 로고 + 제목 + 오른쪽 `ModeToggle`(+ 선택적 trailing 액션). Sliver 버전과 일반 버전.
- `apps/flutter/lib/widgets/common/mode_toggle.dart` - 낮/밤 2분할 세그먼트(아이콘 + 접근성 라벨), 선택된 쪽은 흑백 반전 채움, `obsModeProvider` 연결. 자동 모드가 해제되면(MANUAL) 작은 점 표시 + 툴팁 "직접 선택함 · 길게 눌러 자동으로".
- `apps/flutter/lib/widgets/common/status_view.dart` - `StatusView.loading`(정적 스켈레톤, reduce-motion 시 애니메이션 없음), `.empty`(중립 아이콘 + 한 줄 + 선택 액션, error 색 금지), `.error`(`cloud_off` + "불러오지 못했어요" + 이유 한 줄 + `FilledButton.tonal` "다시 시도"), `.degraded` 인라인 배너(`LookUpColors.warning` 톤 + "일부 정보가 지연되고 있어요 · 마지막 갱신 HH:mm" + "다시 시도").
- `apps/flutter/lib/widgets/common/provenance_chip.dart` - live(채운 점, "실시간 · HH:mm"), approx(빈 점, "추정"), sample(점선 테두리, "예시"), stale(경고 아이콘, "지연 · HH:mm 기준"). 글자는 본문색, 색은 점·테두리에만(`LookUpColors.provenance*`). 원형 칩.
- `apps/flutter/lib/widgets/common/eyebrow_label.dart` - 섹션 라벨. 영문·숫자는 mono 스타일(대문자·자간 0.06em), 한글은 Pretendard 일반 자간.
- `apps/flutter/lib/widgets/common/data_source_footer.dart` - "데이터 출처: 한국관광공사 · 기상청 · 한국천문연구원 · 국립해양조사원 · eBird / 공공누리" 한 줄(접기 가능).
- `apps/flutter/lib/widgets/common/lookup_scroll_behavior.dart` - `MaterialScrollBehavior` 확장, `dragDevices`에 touch, mouse, trackpad, stylus 포함.
- `apps/flutter/test/widgets/common/*_test.dart` - 각 위젯 테스트: 4가지 출처 상태의 텍스트·아이콘, StatusView 각 상태와 "다시 시도" 콜백, ModeToggle 탭 시 `obsModeProvider` 변경, 키보드 포커스 가능, 두 테마에서 렌더링 오류 없음.

## Phases

### Phase 1: 기반 위젯

- [ ] `LookUpScrollBehavior` 작성 및 등록
- [x] `ProvenanceChip`, `StatusView`, `DataSourceFooter` 작성과 테스트 — 054-2a(ProvenanceChip·EyebrowLabel), 054-2b(StatusView·DataSourceFooter) 완료, 사용자 시각 검증 통과. 화면 적용은 055/058

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

- 2026-10-29: 디자인 레퍼런스 확정(사용자 결정)에 따라 스타일 기준을 Flim + 053 흑백 토큰으로 명시. `eyebrow_label.dart` 추가, `SampleMark`·`SampleDataNotice` 통합 원칙(외부 API 유지) 추가. 기존 기능 요구사항(LookUpHeader, ModeToggle, StatusView, ProvenanceChip, DataSourceFooter, ScrollBehavior)은 유지.

- 2026-10-29: 단계 구분과 승인된 디자인 기준 추가(사용자 결정). 기존 요구사항은 유지하며, 아래 단계를 각각 별도 승인으로 진행한다.
  - **054-1 테마 단계 컴포넌트 스타일**(`lib/theme/app_theme.dart`, 모든 화면에 즉시 적용): ChipTheme, NavigationBarTheme, OutlinedButtonTheme, TextButtonTheme, 보조 행동용 tonal 버튼 스타일. 053에서 화면으로 확인하지 못한 카드 4곳(둘레길 식당 카드, 생태일기 카드, 코스 상세, 둘레길 상세)의 시각 검증과 밤 모드 주요 버튼 눈부심 검토 포함. 새 공용 위젯은 만들지 않는다.
  - **054-2 기반 위젯**: `ProvenanceChip`, `StatusView`, `EyebrowLabel`, `DataSourceFooter`, `LookUpScrollBehavior` 등록, `SampleDataNotice`·`SampleMark` 내부 통합(이름·매개변수 유지).
  - **054-3 헤더·모드 토글**: `LookUpHeader`, `ModeToggle`(B안 강조색 유지), 기존 헤더 흡수(이름 유지). 화면 적용은 055/058.
  - 승인된 기준:
    - 칩: 선택 안 됨 = 1px 테두리(`outline`) + 기본 글자색. 선택됨 = 흑백 반전 채움(낮 검정 배경·흰 글자 / 밤 흰 배경·검정 글자). FilterChip은 다중 선택 표시로 체크 아이콘 사용 가능, ChoiceChip은 체크 아이콘을 강제하지 않고 반전 채움과 글자 굵기로 구분.
    - 하단 탭: 활성 아이콘·라벨을 명확히 구분(채운 아이콘, 굵은 라벨, 흑백 반전 표시)하되 선택 표시 면적이 과도하지 않게.
    - 주요 행동: 흑백 반전 FilledButton 유지(053). 재시도·새로고침 등 보조 행동은 tonal(낮 옅은 회색 면 + 검정 글자 / 밤 어두운 회색 면 + 흰 글자). 화면당 흰 버튼이 과도하게 반복되지 않도록 시각 검증.
    - B안 강조색(청록·민트·앰버)은 점수, 관찰 상태, 골든타임, 새·별 등 의미 있는 정보에만 유지하고, 칩·탭의 선택 표시는 흑백 반전으로 한다.
    - 공용 컴포넌트는 페이지 바깥 좌우 여백을 넣지 않는다. 화면 좌우 여백은 055에서 `AppLayout.pageInsets`로만 관리하고, 컴포넌트는 내부 패딩과 자체 디자인만 담당한다.
    - 검증: 키보드 포커스, 선택 상태, 대비, 터치 영역(44px 이상), 320px 넘침 없음.
  - 사용처가 없는 `ModeHeader`, `CompassButton`은 삭제하지 않는다(삭제·대체는 별도 승인).

- 2026-10-30: 054-1 구현 완료와 검증 상태(사용자 확인 반영). 사용자가 직접 확인한 054-1 화면에서 디자인 오류는 발견되지 않았다.
  - 추가 결정: ChoiceChip은 체크 아이콘 숨김(테마 `showCheckmark: false`), 다중 선택 FilterChip 3곳(`observation_map_screen.dart` 레이어 칩 2곳, `observation_spot_sheet.dart` SQM 필터)만 `showCheckmark: true`로 체크 표시.
  - 회귀 수정: 앱 루트가 전환이 끝난 뒤에도 `ThemeData.lerp`를 거쳐 칩 글자색(`WidgetStateColor`)이 고정색이 되던 문제를 `sceneTheme(from, to, t)`로 수정(전환 시작·완료 시점에는 테마를 그대로 사용).
  - 전환 완료 후 칩 글자와 선택 상태: **자동 테스트 통과**.
  - 전환 도중(최대 0.8초) 화면 전체 글자 대비 저하(낮·밤 테마 색 보간으로 중간에 1:1): **알려진 이슈**, 054-1 범위 밖. `specs/060-scene-transition-fade-through-flutter.md`에서 해결 예정.
  - 생태일기 카드, 320px 실제 화면: 사용자가 직접 확인하지 않은 항목은 **미확인**(자동 테스트의 320px 넘침 없음 확인과는 별개).

- 2026-10-30: 054-2 사전 조사 후 사용자 결정. 054-2를 2a(ProvenanceChip·EyebrowLabel) → 2b(StatusView·DataSourceFooter) → 2c(SampleDataNotice·SampleMark 내부 통합) → 2d(LookUpScrollBehavior 등록)로 나누고 단계마다 별도 승인·커밋한다. 화면 적용은 055/058.
  - '참고값' 문구는 유지한다. 실시간이 아닌 값을 일괄 '추정'으로 바꾸지 않는다. ProvenanceChip 상태는 live/approx/sample/stale 네 가지이며, '참고값'을 없애려고 다섯 번째 상태를 추가하지 않는다(적합도가 참고 지표라는 설명은 별도 유지).
  - 상태 우선순위: 예시 > 지연 > 추정 > 실시간. 예시 데이터에는 '실시간'을 붙이지 않는다. 데이터에 없는 갱신 시각을 만들어 표시하지 않는다(시각은 있을 때만).
  - `SampleDataNotice` 배경은 중립 회색 유지(예시는 오류·지연과 다르므로 주황 경고 톤 금지). 위 불변 조건의 "`SampleDataNotice`를 `StatusView.degraded`로" 문구는 이 결정으로 대체한다.
  - 일부 실패(degraded)는 "일부 정보를 불러오지 못했어요"의 의미를 유지하고 단순 지연으로 표현하지 않는다. 마지막 갱신 시각이 없으면 시간을 표시하지 않는다. 오류·일부 실패의 색 구분은 054-2b에서 설계, 화면 적용은 별도 승인.
  - `DataSourceFooter`는 실제 사용되는 출처만 표시한다. 후보: 한국관광공사(관광정보·두루누비), 기상청, 한국천문연구원, 국립해양조사원, eBird, VIIRS/World Atlas(빛공해), Wikipedia. 모든 출처를 모든 화면에 고정 표시하지 않고, 실제 사용 여부와 표기 요건을 확인한다. 공공누리 유형은 검증 전까지 적지 않는다.
  - compact "예시" 태그 9px는 유지하고, 크기 조정은 055 지도 핀 디자인 검토 때 한다.
  - 개발용 갤러리 `tool/dev_preview_components.dart`(커밋 금지, 확인 후 삭제)를 8115에서 띄워 낮/밤·일반/320px·출처 4상태를 확인한다.

- 2026-10-30: **054-2a 완료.** `lib/widgets/common/provenance_chip.dart`(live/approx/sample/stale, 우선순위 예시 > 지연 > 추정 > 실시간, 시각은 있을 때만 표시, 글자는 본문색·출처색은 점·테두리·아이콘에만), `lib/widgets/common/eyebrow_label.dart`(한글은 labelMedium w600·대문자/자간 변경 없음, 영문·숫자만 있으면 `AppTheme.monoLabel` 대문자 + 원문 시맨틱 라벨)와 테스트. 기존 화면 미적용. 검증: analyze 문제 없음, 테스트 419개 통과, 웹 빌드 DEMO_FALLBACK ON/OFF 성공. **사용자 시각 검증 통과**(8115 갤러리, 낮·밤·320px, 수정 요청 없음). 054-2b·2c·2d는 미착수.

- 2026-10-30: **054-2b 구현·자동 검증(완료 판정은 사용자 시각 확인 후).** 기존 화면 미적용.
  - `lib/widgets/common/status_view.dart`: `StatusView.loading/empty/error/degraded`. loading·empty = 중립(`surfaceContainer`, 아이콘 `onSurfaceVariant`, 글자 `onSurface`), error = `errorContainer`/`onErrorContainer` + `error_outline` 아이콘, degraded = `LookUpColors.warningContainer` + `warning` 경고 아이콘, 글자 `onSurface`. 기본 문구: error '정보를 불러오지 못했어요', degraded '일부 정보를 불러오지 못했어요', loading '불러오는 중이에요'(교체 가능), empty는 화면이 문구 지정. degraded의 '마지막 갱신 HH:mm'은 시각이 주어질 때만 표시, '지연' 문구 없음(degraded ≠ stale). 재시도('다시 시도', tonal, 44px 이상)는 콜백이 있을 때만. 움직임 줄이기면 회전 표시 대신 정적 아이콘. loading/error/degraded는 화면 낭독기 live region. 그림자·바깥 여백 없음, 폭 300 미만이면 버튼이 글자 아래로.
  - `lib/widgets/common/data_source_footer.dart`: `DataSource(name, url?, attribution?)` — 출처명·링크·저작자/라이선스 고지를 별도 필드로 받음. 화면이 실제 쓰는 출처만 전달(고정 목록 없음). 중복은 공백·대소문자 정규화 후 첫 항목 유지, 빈 이름 제외, 0개면 공간 없음. 머리글(44px 이상)은 키보드 Enter/Space·화면 낭독기(button, expanded, '데이터 출처 N개')로 접기/펼치기, 접힘 상태는 이름 한 줄 미리보기. 링크는 url과 열기 콜백이 모두 있을 때만(밑줄 + 새 창 아이콘 + link 시맨틱), 아니면 일반 글자. 새 패키지(url_launcher) 없음 — 링크 열기는 화면이 콜백으로 처리.
  - 설계 대비 차이(수용): 오류 아이콘은 `cloud_off` 대신 `error_outline`, loading은 정적 스켈레톤 대신 작은 회전 표시(움직임 줄이기 시 정적 아이콘).
  - **미확인으로 남김(화면 적용 전 별도 검토):** eBird, Wikipedia, VIIRS/World Atlas, 한국관광공사(공공누리 유형), 기상청·한국천문연구원·국립해양조사원의 구체적 표기·라이선스·저작자 고지 요건과 공식 링크. 위젯에는 기본 라이선스 문구나 URL이 없다.
  - 검증: analyze 문제 없음, 테스트 463개 통과(새 44개, 낮·밤 대비·접근성·320px 포함), 웹 빌드 DEMO_FALLBACK ON/OFF 성공. 첫 검증에서 출처 바닥글 테스트 1개(낮·밤)가 테스트 작성 오류(같은 위치 재사용으로 이전 State 유지)로 실패 → 테스트만 수정 후 통과. 시각 검증(8115 갤러리)은 **미확인**.

- 2026-10-30: **054-2b 완료.** 사용자 시각 검증 통과(8115 갤러리: 낮·밤, 320px, 오류·일부 실패 색 구분, 출처 0개·1개·여러 개, 긴 출처명, 접기·펼치기 — 수정 요청 없음). 후속 확인 항목으로 유지: 출처별 공식 링크·저작자·라이선스 표기 요건(위 미확인 목록)은 화면 적용 전에 검증한다. 054-2c·2d는 미착수.
