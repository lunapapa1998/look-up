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

- [x] `LookUpScrollBehavior` 작성 및 등록 — 054-2d 완료(B-1: 전역 등록 대신 가로 목록 4곳에만 적용), 사용자 브라우저 확인 통과
- [x] `ProvenanceChip`, `StatusView`, `DataSourceFooter` 작성과 테스트 — 054-2a(ProvenanceChip·EyebrowLabel), 054-2b(StatusView·DataSourceFooter) 완료, 사용자 시각 검증 통과. 화면 적용은 055/058

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 헤더와 모드 토글

- [~] `ModeToggle`, `LookUpHeader` 작성과 테스트 — ModeToggle(054-3a) 완료(사용자 디자인 승인). LookUpHeader(054-3b) 미착수
- [x] `SampleDataNotice` 내부 교체 — 054-2c 완료, 사용자 시각 검증 통과

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

- 2026-10-30: **054-2c 구현·자동 검증(완료 판정은 사용자 시각 확인 후).** `lib/widgets/sample_data_notice.dart` 내부만 변경, 화면 파일·기존 테스트 무수정.
  - `SampleMark`: 이름·생성자·import 경로 유지. 표시는 `ProvenanceChip.sample(compact:)`로 재사용(원형, 점선 테두리, 본문색 글자, compact 9px 유지). 화면 낭독기는 이전과 같은 비컨테이너 라벨 '예시 데이터'로 감싸 카드·행의 설명에 합쳐 읽히는 동작을 유지(칩 자체의 별도 노드는 제외). 크기는 변경 전과 동일(측정: 일반 39×17, compact 27×13). 지도 핀의 `ExcludeSemantics` 그대로.
  - 중복 점선 테두리 구현 제거 — `provenance_chip.dart`에만 남음.
  - `SampleDataNotice`: 키·문구·표시 조건(해당 출처가 예시일 때만, 아니면 크기 0)·재시도 콜백·중립 회색 배경 유지. '다시 시도'를 `FilledButton.tonal`(터치 영역 44px 이상)로 변경, 버튼이 배너 오른쪽 둥근 끝에 붙지 않도록 오른쪽 안쪽 여백 `AppSpacing.xs` 추가. 웹에서는 버튼 터치 영역 때문에 배너가 약간 높아질 수 있음.
  - 검증: analyze 문제 없음, 테스트 479개 통과(기존 테스트 무수정 통과 — sample_data_notice_test 7, demo_fallback_wiring_test 2, observation_map_wiring_test 11 포함; 새 16개: 실제↔예시 전환, 재시도, 낮·밤 대비, 화면 낭독기 합침, 320px). 첫 검증에서 새 높이 테스트 2개가 공식 계산 오류로 실패 → 측정값 기준으로 테스트만 수정. 웹 빌드 DEMO_FALLBACK ON/OFF 성공(8080/8081 갱신). 시각 검증은 **미확인**.

- 2026-10-30: **054-2c 완료.** 사용자 시각 검증 통과(8080 DEMO_FALLBACK ON: 예시 배너·태그 표시, 8081 OFF: 예시 표시 없음 — 디자인·레이아웃 문제 없음). 054-2d·054-3은 미착수. 참고: 확인 시점에 운영 백엔드(Cloud Run)가 HTTP 500을 반환해 8080은 예시 데이터로 대체됨 — 백엔드는 이 spec 범위 밖이며 별도 후속 점검.

- 2026-10-30: **054-2d 방식 변경(사용자 결정 B-1)과 구현·자동 검증(완료 판정은 사용자 브라우저 확인 후).**
  - 결정: `MaterialApp.scrollBehavior` 전역 등록은 하지 않는다(위 불변 조건·Phase 1의 "등록" 문구를 대체). 전역 등록은 세로 페이지·지도 시트·입력란까지 마우스 드래그로 바꾸므로, 마우스 드래그가 필요한 가로 목록에만 지역 적용한다.
  - 화면 파일 수정 금지 규칙의 **예외(이 단계 한정, 사용자 승인)**: 아래 4곳에서 기존 가로 `SingleChildScrollView`를 `ScrollConfiguration(behavior: const LookUpScrollBehavior())`로 감싸는 줄과 import만 추가(배치·디자인·데이터 로직·키·콜백 무변경, 들여쓰기 재정렬만 발생).
    - `observation_map_screen.dart` 지도 레이어 칩, `packages_catalog_screen.dart` 패키지 분류 필터, `trails_catalog_screen.dart` 트레일 지역 필터, `observation_spot_sheet.dart` 지도 시트 정렬·SQM 필터(시트 자체와 검색창은 감싸지 않음).
  - `lib/widgets/common/lookup_scroll_behavior.dart`: `MaterialScrollBehavior`에 마우스만 드래그 장치로 추가. 터치·스타일러스·트랙패드, Shift+휠(가로), 스크롤바는 상속 그대로. `main.dart`·테마 무변경.
  - 자동 검증: analyze 문제 없음, 테스트 487개 통과(새 8개: 마우스 드래그로 가로 스크롤·드래그 시 칩 오선택 없음, 감싸지 않은 목록은 마우스로 안 움직임(기본 동작), 짧은 클릭 1회 선택, 터치 드래그, Shift+휠, 세로 목록·입력란으로 동작이 번지지 않음). 네 화면의 기존 테스트 100개 무수정 통과. 웹 빌드 DEMO_FALLBACK ON/OFF 성공(8080/8081 갱신).
  - **수동 검증 대기(실제 브라우저):** 실제 마우스로 네 가로 목록 끌기·짧은 클릭 선택·끌고 놓을 때 오선택 없음, 지도 이동과 지도 시트 마우스 동작이 이전과 같음, 시트 검색창 마우스 텍스트 선택, 실제 트랙패드 두 손가락 가로 스크롤·물리 휠 Shift+휠, 데스크톱 웹 스크롤바 모양, 모바일 터치.
  - 백엔드 HTTP 500/503(Cloud Run 플랫폼 단계 추정, 원인 미확정)과 CORS 미설정은 서로 별개의 후속 점검 항목. GCP 접근 권한 준비 전까지 진단 보류, GCP 설정·배포·결제·IAM·백엔드 코드는 변경하지 않음.

- 2026-10-30: **054-2d 완료.** 사용자가 실제 브라우저(8080, 마우스)에서 네 가로 목록 동작을 확인했고 발견된 문제 없음. 실제 트랙패드 두 손가락 스크롤·물리 휠 Shift+휠의 개별 확인과 모바일 실기기(터치) 검증은 **하지 않았으며 미확인**으로 남긴다(자동 테스트의 합성 이벤트 검증만 있음). 054-2(a~d) 전체 완료. 054-3은 미착수.

- 2026-10-30: **054-3 분할과 054-3a(ModeToggle) 결정·구현·자동 검증(완료 판정은 사용자 시각 확인 후).** 054-3a(ModeToggle) → 054-3b(LookUpHeader) 순서로 각각 별도 승인. 화면 적용은 055/058.
  - 결정(사용자): 위 New Files의 `mode_toggle.dart` 설명 중 "선택된 쪽은 흑백 반전 채움", "MANUAL이면 작은 점", "길게 눌러 자동으로" 툴팁은 아래로 **대체**한다.
    - 선택 색은 B안 강조색과 기존 홈 버튼 의미를 유지: 낮 선택 = `tertiary`(글자 `onTertiary`), 밤 선택 = `secondary`(글자 `onSecondary`). 선택은 색만이 아니라 채움·굵기(w700)·시맨틱(selected)으로도 구분.
    - 버튼은 아이콘 + 짧은 글자 '낮'/'밤'. 각 44px 이상, 평면(그림자 없음), 320px 넘침 없음.
    - 낮/밤(관찰 모드)과 자동/직접(선택 방식)을 구분: 낮/밤은 기존 `setManual`, 별도의 명시적 '자동' 버튼이 기존 `resetToAuto()`를 호출(실제 모드는 provider의 시간 정책이 결정, 새 상태 저장 없음). 길게 누르기는 넣지 않음.
  - `lib/widgets/common/mode_toggle.dart`: 순수 표현형 `ModeToggle(mode, source, onModeSelected, onAutoSelected)` + provider 어댑터 `ObsModeToggle`. 토글 자체에는 햅틱 없음(앱 루트가 수락된 직접 전환당 1회). '자동' 버튼은 자동 상태면 흑백 반전 채움 + 시맨틱 selected·'자동 모드 켜짐', 직접 선택 상태면 외곽선 + '자동 모드로 돌아가기'. 낮/밤 버튼은 selected·상호 배타 그룹('관찰 모드') 시맨틱과 '자동으로 선택됨/직접 선택됨' 힌트. 키보드 Tab·Enter·Space, 포커스 링은 2px `onSurface` + 안쪽 1px `surface`(강조색·반전 채움 위에서도 보이도록).
  - 기존 홈 버튼·AppSliverHeader·AppHeaderLogo·ModeHeader·CompassButton·화면·main.dart·테마·provider 무변경. 060 페이드 스루·입력 차단 그대로.
  - 자동 검증: analyze 문제 없음, 테스트 511개 통과(새 24개). 실제 앱 루트(MyApp) 연동 테스트 포함: 밤 탭 → 커튼 전환·햅틱 1회, 같은 모드 재탭 → 전환·햅틱 없음, 커튼 0.5 이상일 때 탭 차단 후 정상 복구, '자동'(같은 모드면 무변화, 다른 모드면 자동 전환·햅틱 없음). 첫 검증에서 테스트용 MaterialApp의 기본 테마 애니메이션 때문에 움직임 줄이기 테스트 2개 실패 → 테스트 하네스만 수정. 웹 빌드 DEMO_FALLBACK ON/OFF 성공.
  - 미확인(수동): 실제 화면 낭독기(TalkBack·VoiceOver·NVDA) 낭독, 실제 브라우저 Tab 포커스 링·hover 모양, 실기기 햅틱, 8115 갤러리 시각 확인. 포커스 링은 AA 기준 충족, 강조색·반전 채움 위에서는 안쪽 1px 선이 주로 보여 AAA(2.4.13)는 미충족.

- 2026-10-30: **054-3a ModeToggle 최종 색상 결정(사용자 시각 검토 후).** 결정 정리:
  - 바로 위 항목의 "낮 선택 = `tertiary` / 밤 선택 = `secondary`" 결정은 **대체**한다.
  - 중간에 검토된 낮 `#9CA3F5` / 밤 `#FFC107` 조합은 **최종안이 아니다**.
  - **최종:** 낮 선택 = 퍼플 그레이 `#9CA3F5`(RGB 156,163,245), 밤 선택 = 소프트 앰버 `#F4C247`(RGB 244,194,71). 낮 테마·밤 테마 모두 같은 값을 쓴다. 배경은 낮 `#FFFFFF`, 밤 `#141414` 유지.
  - **적용 범위는 ModeToggle 전용.** `LookUpColors`에 전용 토큰 `modeDayAccent`/`onModeDayAccent`/`modeNightAccent`/`onModeNightAccent` 추가(테마 파일 최소 수정, 사용자 승인). 전역 `colorScheme.secondary`/`tertiary`와 기존 데이터 강조색(점수·골든타임·출처·상태 표시)의 의미와 값은 그대로 유지.
  - 대비(계산값): 선택 글자·아이콘은 `#141414` — `#9CA3F5` 위 약 7.9:1, `#F4C247` 위 약 11.1:1(흰 글자는 약 2.3 / 1.7로 미달). 채움색과 낮 배경(#FFFFFF)의 대비는 약 2.3 / 1.7로 비텍스트 3:1에 못 미치므로, 지정 색은 바꾸지 않고 선택된 버튼에 1px `#141414` 테두리를 둔다(흰 바탕 대비 약 18:1, 채움 대비 7.9 이상). 밤 배경(#141414)에서는 채움 대비 약 7.9 / 11.1. 포커스 링 안쪽 선은 1px → 2px(`surface`)로 키워 강조색 위에서도 보이게 함.
  - 그 밖의 054-3a 동작(API, setManual/resetToAuto, '자동' 버튼, 키보드, 시맨틱, 44px, 320px, 움직임 줄이기, 햅틱 없음, 060 연동)은 변경 없음. 사용자 시각 확인 전까지 054-3a는 완료 처리하지 않는다.
  - 최종 색상 적용 후 자동 검증: analyze 문제 없음, 테스트 516개 통과(기존 511 + 새 5: 강조 토큰 값 낮·밤 동일, 선택 테두리·포커스 링 대비, 토글 안에서 secondary/tertiary 미사용 등), 웹 빌드 DEMO_FALLBACK ON/OFF 성공, 8115 갤러리 갱신. 첫 실행에서 포커스 링 테스트 2개가 실패 — 포커스가 다른 버튼에서 옮겨 올 때 링이 한 프레임 뒤에 그려지는 것을 테스트가 너무 일찍 확인한 탓(제품 문제 아님) → 테스트에 프레임 1회 추가. 시각 확인(밤 배경에서 두 강조색의 어울림 등)은 **미확인**.

- 2026-10-30: **054-3a ModeToggle 최종 디자인(사용자 승인).** 바로 위 항목의 "선택된 버튼에 1px `#141414` 테두리" 보완은 **제거**한다(사용자 결정).
  - 선택 버튼: 색 채움 중심의 평면 디자인 — 낮 `#9CA3F5` / 밤 `#F4C247` 채움, 글자·아이콘 `#141414` w700, 검은 외곽선·그림자·그라데이션 없음. 비선택 버튼의 중립 외곽선(묶음 1px `outline`과 구분선)은 유지. 자동 버튼(자동 = 흑백 반전 채움, 직접 = 외곽선) 유지. 크기·모서리·간격·아이콘·문구 유지.
  - 선택 상태 구분: 채움, 굵은 글자(w700 대 w500), 화면 낭독기 '선택됨'(selected) + '자동으로 선택됨/직접 선택됨' 안내.
  - 대비 결과: 선택 글자·아이콘 대 채움 약 7.9:1(낮 강조) / 11.1:1(밤 강조) — 4.5:1 충족. 채움 대 밤 배경(#141414) 약 7.9 / 11.1 — 3:1 충족. 포커스 링: 바깥 2px `onSurface`와 바탕 대비 약 18.4, 강조 채움 위에서는 낮 테마의 바깥 선(#141414) 약 7.9 / 11.1, 밤 테마의 안쪽 선(#141414) 약 7.9 / 11.1로 두 테마 모두 식별 가능.
  - **남은 접근성 제한(숨기지 않음):** 낮 배경(#FFFFFF)에서 선택 채움 대 바탕 대비는 약 2.3:1(#9CA3F5) / 1.7:1(#F4C247)로 비텍스트 3:1(WCAG 1.4.11)에 **미달**한다. 승인된 색은 바꾸지 않고 검은 테두리도 다시 넣지 않는다. 다른 보완(예: 선택 표시 아이콘, 얇은 하단 표시선 등)은 임의 적용하지 않고 사용자 결정 사항으로 남긴다.
  - 사용자 최종 시각 확인 전까지 054-3a 완료 처리하지 않는다.

- 2026-10-30: **054-3a 완료(사용자 최종 디자인 승인).**
  - 최종: 낮 선택 `#9CA3F5`, 밤 선택 `#F4C247`(ModeToggle 전용 `LookUpColors` 토큰, 전역 `secondary`/`tertiary` 무변경), 선택 글자·아이콘 `#141414` w700, 선택 버튼 검은 테두리 없음, 자동 버튼(흑백 반전 채움/외곽선)과 기존 흑백 테마 유지.
  - 접근성 보완안은 사용자 선택 **3번(현재 디자인 유지)** — 체크 아이콘·검은 밑줄 추가하지 않음.
  - 자동 검증: analyze 문제 없음, 테스트 516개 통과, 웹 빌드 DEMO_FALLBACK ON/OFF 성공. 키보드(Tab·Enter·Space), 시맨틱(선택됨·자동/직접), 44px, 320px, 움직임 줄이기, 실제 MyApp 060 연동(햅틱 1회·같은 모드 무변화·커튼 중 입력 차단) 포함.
  - **접근성 기준 미충족 항목(완전 충족 아님):** 낮 테마에서 선택 채움 대 흰 배경 대비 약 2.3:1(`#9CA3F5`) / 1.7:1(`#F4C247`)로 WCAG 1.4.11 비텍스트 3:1 기준에 **미달**. 현재는 굵은 글자와 화면 낭독기 '선택됨'으로 보조한다.
  - **후속 접근성 개선 과제(열림):** 낮 테마 ModeToggle 선택 표시의 비텍스트 대비 3:1 확보 방안 재검토(색 변경 없이 가능한 표시 방식 등) — 화면 적용(055/058) 전 또는 별도 접근성 단계에서 사용자 결정.
  - 미확인(완료로 표시하지 않음): 실제 화면 낭독기(TalkBack·VoiceOver·NVDA) 낭독, 실기기 햅틱, 실제 브라우저 포커스 링 모양.

- 2026-10-30: **054-3b LookUpHeader 구현·검증(사용자 시각 확인 전, 완료 아님).** `lib/widgets/common/lookup_header.dart`: `LookUpHeader`(일반)·`LookUpSliverHeader`(`SliverFloatingHeader`, 스크롤 시 숨김·위로 올리면 재등장·스냅, 상태 표시줄 여백 없음 = 기존 primary:false와 동일). provider 비의존, `title`('위를 봐요', titleMedium)·`subtitle`('LOOK UP', 장식 — 화면 낭독기 제외)·`modeToggle` 슬롯·`actions`. 로고는 `AppHeaderLogo(excludeFromSemantics: true)`, 제목은 머리글 시맨틱. 토글이 있으면 폭 480 이상이면서 실제 측정한 내용 폭이 맞을 때만 한 줄, 아니면 두 줄(1줄 로고+제목+액션, 2줄 토글). 토글이 없으면 한 줄. 평면 배경, 그림자·바깥 여백 없음. 기존 AppSliverHeader·AppHeaderLogo·ModeHeader·CompassButton·화면 무변경. 검증: analyze 문제 없음, 새 테스트 24개(320/375/480/600/1024 × 글자 배율 1.0/1.3/2.0 넘침 없음, 줄 전환, 말줄임, 머리글·중복 낭독 없음, Tab 순서, Sliver 숨김/복귀). 첫 검증에서 테스트 작성 오류로 6개 실패 → 테스트만 수정. 사용자 지시(속도 우선)로 이번 단계의 전체 테스트·웹 빌드 재실행은 화면 통합 후 한 번에 진행. **054-3b 구현·자동 검증 완료로 기록(사용자 커밋 승인). 실제 화면 시각 확인은 미완료.**
