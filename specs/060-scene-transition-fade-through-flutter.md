# 낮/밤 장면 전환: 색 보간에서 페이드 스루로

> Lightweight plan-f3 spec. 011에서 만든 낮/밤 테마 색 보간(lerp)을 어두운 커튼으로 잠깐 가리고 넘어가는 페이드 스루로 바꾼다. 054-1과 분리된 별도 작업이다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-30
- modified: 2026-10-30 brain — 초안(설계 검토 승인 후 문서만 작성, 구현 미승인)
- modified: 2026-10-30 brain — 사용자 검토 반영: 입력 차단과 재토글 구분, Phase 2 대상 표, 대비 기준 구분, Phase 1 알려진 한계, 개발용 미리보기 구분
- refs: specs/011-scene-transition-flutter.md, specs/053-design-tokens-flutter.md, specs/054-shared-components-flutter.md, docs/design/README.md
- risk: medium - 순수 flutter. 앱 루트(`main.dart`)의 전환 방식 교체 + (Phase 2) 화면 5개 파일의 모드 읽기 교체. backend·API·인증·데이터 모델 무변경. 전역 화면에 영향을 주므로 단계별 승인과 미리보기 확인을 거친다.

## 확정된 결정 (2026-10-30 사용자)

1. B안 페이드 스루 채택.
2. 커튼 색 #141414.
3. 전반부 비율 50%를 초기 기준값으로 둔다(미리보기 후 조정 가능).
4. 움직임 줄이기 설정에서는 커튼 없이 즉시 전환.
5. Phase 2(콘텐츠 동기화)는 보류. Phase 1 미리보기 후 별도 결정.
6. 개발 전용 느린 재생 미리보기 파일 사용 승인(커밋 제외, 검증 후 삭제).

## Purpose

낮/밤을 바꾸는 동안 글자가 배경과 같은 색이 되어 읽을 수 없는 순간을 없앤다. 화면은 언제나 "완전한 낮" 또는 "완전한 밤" 테마로만 그린다.

## Problem

053 B안의 낮(흰 바탕/#141414 글자)과 밤(#141414 바탕/흰 글자) 테마는 서로 정반대라서, `main.dart`가 두 테마를 `ThemeData.lerp`로 섞으면 t≈0.5에서 모든 글자와 배경이 #8A8A8A로 같아진다(대비 1:1). t 0.3~0.7 구간은 앱 전체가 3:1 미만이다. 칩 테마만 즉시 바꾸거나 상태별로 보간해도 교차 지점은 남으므로, 색 보간 방식으로는 해결할 수 없다(054-1 검토에서 확인).

## Solution

테마 색은 더 이상 섞지 않는다. 화면 전체에 #141414 커튼을 겹쳐 전반부에 어둡게 덮고, 완전히 덮인 순간에 목표 테마로 교체한 뒤 후반부에 커튼을 걷는다. 움직임 줄이기 설정에서는 커튼 없이 즉시 교체한다. (Phase 2, 보류) 화면 콘텐츠도 같은 순간에 바뀌도록 "지금 화면에 그려진 모드" provider를 둔다.

## 불변 조건

- `MaterialApp.theme`에는 `AppTheme.themeFor(ObsMode.day)` 또는 `AppTheme.themeFor(ObsMode.night)` **둘 중 하나만** 들어간다. `ThemeData.lerp`는 앱 경로에서 쓰지 않는다.
- 테마 교체는 커튼 불투명도가 1(완전히 덮임)일 때만 일어난다. 움직임 줄이기 설정은 예외(즉시 교체, 커튼 없음).
- 커튼 색은 `#141414` 하나로 고정한다(낮→밤, 밤→낮 모두). 흰 화면이 번쩍이는 순간을 만들지 않는다.
- 전환 중에도 `MaterialApp`, `Navigator`, 각 화면의 `State`는 다시 만들지 않는다. 스크롤 위치, 칩 선택, 열린 시트, 하단 탭, 화면 이동 기록은 그대로다.
- 커튼은 접근성 트리에 나타나지 않는다. 커튼 때문에 포커스가 이동하거나 사라지지 않는다.
- 전환이 끝나면(또는 취소되면) 커튼은 반드시 불투명도 0이고 입력을 막지 않는다.
- 데이터 로딩 흐름(`discoveryProvider`, `spotSuitabilityProvider`, API 호출), 인증, 모델은 바꾸지 않는다. Phase 2도 "어느 모드를 읽는가"만 바꾼다.
- 054-1의 칩·탭·버튼 테마, FilterChip 체크(지도 3곳), ChoiceChip 체크 숨김, B안 강조색은 그대로 둔다.
- 낮·밤 패키지 상품 설명과 오타는 이 spec 범위가 아니다.

## 설계

### 1. 타임라인 (기본: 전반 50% / 후반 50%)

| 진행 | 화면에 적용된 테마 | 커튼 불투명도 | 곡선 |
|---|---|---|---|
| 0 → 0.5 | 이전 테마 그대로 | 0 → 1 | 밤으로: easeInOutCubic / 낮으로: easeInCubic(제안값, 미리보기 후 확정) |
| 0.5 | **이 순간 목표 테마로 교체**(보이지 않음) | 1 | — |
| 0.5 → 1 | 목표 테마 | 1 → 0 | 밤으로: easeInOutCubic / 낮으로: `NightToDayGlareCurve`(앞부분은 빠르게 60%까지, 이후 천천히 밝아짐 — 눈부심 완화) |

- 전체 시간은 기존 값을 그대로 쓴다: 자동 800ms, 수동 낮으로 640ms / 밤으로 560ms. 커튼이 완전히 덮인 상태는 한 프레임 수준이다(따로 머무르지 않음).
- 전반부 비율은 상수 하나(`kCurtainRiseFraction = 0.5`)로 둔다. 미리보기에서 "새 화면이 늦게 나온다"고 느끼면 0.35~0.4로 조정할 수 있다(조정은 사용자 확인 후).
- 커튼은 `ColoredBox(color: Color(0xFF141414).withValues(alpha: o))`로 그린다. `Opacity` 위젯 대신 색의 알파를 써서 웹에서 별도 합성 레이어(saveLayer)를 만들지 않는다.
- 햅틱: 수동 전환 요청 1건마다 1회(현행 `shouldHapticOnTransition` 유지). 자동 전환은 햅틱 없음.

### 2. 구조

- `main.dart`의 `MaterialApp`은 `theme: _displayedTheme`(낮/밤 둘 중 하나)와 `builder:`를 쓴다. `builder`는 `Stack[child(Navigator), SceneCurtain]`을 돌려준다. `child`는 그대로 전달되므로 Navigator와 그 아래 상태가 유지된다.
- 커튼이 `Navigator` 위에 있으므로 바텀시트, 다이얼로그, 스낵바까지 함께 덮는다.
- `AnimatedBuilder`는 `MaterialApp` 전체가 아니라 **커튼만** 다시 그린다. `MaterialApp`은 테마가 바뀌는 순간(교체 1회)에만 다시 빌드한다. 지금처럼 매 프레임 전체 테마를 새로 만들지 않으므로 전환 중 프레임 부담이 줄어든다.
- `scene_transition.dart`에 다음을 둔다(단독 테스트 가능):
  - `curtainOpacity({required double t, required ObsMode to})` — 위 표의 불투명도.
  - `bool hasSwapped(double t)` — t가 교체 지점을 지났는지.
  - `SceneCurtain` 위젯 — `ExcludeSemantics` + 포인터 흡수(o ≥ 0.5일 때만) + `ColoredBox`. `o == 0`이면 `SizedBox.shrink()`.
  - `SceneInputGuard` 위젯 — Navigator 바로 위 `Shortcuts`. o ≥ 0.5일 때만 실행·이동 키를 소비(3-1). 포커스는 건드리지 않음.
- `sceneTheme`(054-1에서 추가한 보간 도우미)는 더 이상 쓰이지 않으므로 이 spec에서 제거한다(아래 "054-1과의 관계").

### 3. 입력 차단과 재토글 (서로 다른 규칙)

**두 규칙은 독립적이다.** 입력 차단은 "사용자 입력(포인터·키보드)이 화면에 닿는가"만 정하고, 재토글 처리는 "모드 상태(`obsModeProvider`)가 바뀌었을 때 전환을 어떻게 이어가는가"만 정한다. 전환 로직은 입력이 아니라 **provider 상태 변화만** 듣는다.

#### 3-1. 사용자 입력 차단 (포인터·키보드)

| 커튼 불투명도 o | 포인터(터치·마우스·트랙패드) | 키보드 | 비고 |
|---|---|---|---|
| o = 0 (전환 없음·완료 후) | 정상 | 정상 | 커튼 위젯 없음 |
| 0 < o < 0.5 | **정상 전달** | **정상** | 화면이 아직 보이는 구간. 모드 버튼을 누르면 provider가 바뀌고 3-2 규칙을 따른다 |
| o ≥ 0.5 ("가려진 구간") | **차단(흡수, 버려짐)** | **차단(버려짐)** | 버튼이 거의 보이지 않는 구간. 보이지 않는 버튼·링크·탭이 실행되는 것을 막는다. 버려진 입력은 나중에 다시 실행되지 않는다(대기열 없음) |

- 한 번의 전환에서 o ≥ 0.5인 시간은 곡선 계산상 약 0.15~0.4초다(밤으로 수동 약 0.28초, 낮으로 수동 약 0.16초, 자동 최대 약 0.4초). 정확한 값은 Phase 1 테스트에서 측정해 Notes에 기록한다.
- 포인터 차단은 커튼 위젯 안에서만 이뤄지고, 아래 화면의 `IgnorePointer`·`AbsorbPointer` 상태를 바꾸지 않는다(화면 상태 무변경).

**키보드 차단 방식**
- `MaterialApp.builder`에서 Navigator(child) 바로 위에 `Shortcuts` 한 겹을 둔다. 가려진 구간에서만 실행·이동 키를 `DoNothingAndStopPropagationIntent`로 바꿔 키 이벤트를 소비한다. 앱 루트 기본 단축키(Enter/Space → 실행)보다 먼저 처리되므로 일반 버튼·링크·탭·칩의 키보드 실행이 일어나지 않는다.
  - 대상 키: Enter, Space, NumpadEnter(실행), Tab, Shift+Tab, 방향키(포커스 이동), Escape(시트·다이얼로그 닫기).
  - 앱 안에는 현재 자체 `Shortcuts`·`onKeyEvent` 처리가 없다(2026-10-30 확인). 구현 시 다시 확인한다.
  - 글자 입력란의 문자 입력은 막지 않는다(실행 동작이 아님). 현재 전환이 일어나는 화면에서 글자 입력 중 모드를 바꾸는 경로는 없다.
- **포커스를 빼앗지 않는다.** `ExcludeFocus`, `FocusScope` 교체, `unfocus()`를 쓰지 않는다. 포커스된 요소는 가려진 구간 내내 그대로 포커스를 유지하고, 포커스 이동 키도 막으므로 위치가 바뀌지 않는다. 커튼 자체는 포커스를 받지 않는다(`Focus` 없음, `canRequestFocus` 대상 아님).
- **정상 복구:** o가 0.5 아래로 내려가는 즉시(그리고 완료 시) `Shortcuts` 차단이 풀리고 포인터 흡수도 사라진다. 그 뒤의 첫 키 입력·탭부터 정상 동작한다. 전환이 중간에 취소돼도 같은 조건(o < 0.5)으로 풀린다. `dispose` 시 차단 상태가 남지 않는다.

**모드 상태 변경은 입력 차단과 별개로 처리**
- 차단은 "사용자 입력"만 막는다. `obsModeProvider` 상태 변화(가려지기 전에 눌린 버튼, `resetToAuto`, 코드 호출)는 가려진 구간에도 언제나 받아들이고 3-2·3-3 규칙으로 최종 모드에 수렴한다.
- 따라서 차단 때문에 마지막 모드 요청이 사라지는 일은 없다. 사라지는 것은 "가려진 동안 새로 들어온 사용자 입력"뿐이다.

#### 3-2. 재토글 처리 (provider 상태 변화 기준)

provider 상태를 바꾸는 경로는 세 가지이며 **모두 같은 규칙**으로 처리한다. 커튼 불투명도와 상관없이 항상 받아들인다.
- 사용자 탭·키보드 실행(o < 0.5일 때만 도달), 화면 낭독기 실행 동작(4-3)
- `resetToAuto()`(홈 "자동으로" 복귀) — 시간 기준 모드로 바뀌면 자동 전환(800ms, 햅틱 없음)
- 그 밖에 코드가 `setManual`/`resetToAuto`를 부르는 경우(예: 테스트). 현재 `ObsModeController`에는 시간 경과로 스스로 바뀌는 타이머가 없다(빌드 시 1회 계산).

상태: 표시 모드 D(지금 화면에 그려진 테마), 목표 모드 T, 커튼 불투명도 o, 전환 세대 번호 g.

| 상황 | 동작 |
|---|---|
| 새 모드 = 현재 목표 T (같은 값 재선택) | provider가 같은 모드를 다시 내보내도 무시(현행처럼 `next.mode == 목표`면 return) |
| 전반부(D=이전, 커튼 올라가는 중)에 **D와 같은 모드로 되돌림** | 교체하지 않는다. 커튼만 현재 o에서 0으로 내린다(남은 비율만큼의 시간). D 그대로 |
| 후반부(D=새 모드, 커튼 내려가는 중)에 **이전 모드로 되돌림** | 새 전환: 커튼을 현재 o에서 1로 다시 올리고, 덮이는 순간 교체 후 걷는다 |
| 커튼을 내리며 취소하는 중에 다시 D가 아닌 모드 선택 | 새 전환: 현재 o에서 다시 올린다 |
| 움직임 줄이기 설정 중 어떤 변경이든 | 진행 중인 애니메이션을 멈추고 같은 프레임에 D=최종 모드, o=0 |

- **불투명도 연속성:** 새 전환은 항상 "현재 o"에서 시작한다(0이나 1로 점프하지 않음). 구현은 o를 별도 값으로 보관하고, 올림·내림 각각의 남은 거리에 비례한 시간으로 이어서 움직인다.

#### 3-3. 연속 요청의 최종 수렴 규칙

- **마지막 provider 상태가 이긴다.** 대기열을 두지 않는다. 전환이 모두 끝난 뒤 반드시 `D == obsModeProvider.mode`, `o == 0`, 입력 차단 없음.
- 짧은 시간에 N번 바뀌어도 커튼은 위 규칙에 따라 오르내림을 이어갈 뿐 새로 생기지 않으며, 테마 교체는 커튼이 1에 닿을 때만 일어난다. 한 번의 1→0 사이에 교체가 두 번 일어나지 않는다.
- 햅틱은 수동 요청 1건마다 1회. 같은 모드 재선택(무시되는 경우)은 햅틱 없음.

#### 3-4. 이전 애니메이션 콜백 무효화

- `AnimationController`는 하나만 쓰고, 새 전환이 시작되면 `stop()` 후 새 구간으로 `animateTo`/`forward`한다. 이전 `TickerFuture`의 `whenComplete`/`then`에 교체·완료 처리를 걸지 않는다.
- 교체(D 변경)와 완료(o=0, 차단 해제)는 **매 틱 계산**으로만 결정한다: `if (세대 == g && 목표 == T && 진행이 교체 지점 통과) D = T`.
- 새 전환마다 g를 1 올린다. 혹시 남는 비동기 처리(예: `addStatusListener`를 쓰게 될 경우, Phase 2의 hold 해제)는 시작 시점의 g를 들고 있다가 실행 시 `g`가 다르면 아무것도 하지 않는다.
- `dispose`에서 컨트롤러를 정리하고, 이후 어떤 처리도 상태를 바꾸지 않는다(`mounted` 확인).

### 4. 접근성과 대비

#### 4-1. 대비 기준 (WCAG 2.2)

| 대상 | 기준 | 예시 |
|---|---|---|
| 일반 텍스트 | 4.5:1 이상 (1.4.3) | 본문, 보조 글자(낮 #5C5C5C, 밤 #B8B8B8), 칩 라벨, 버튼 라벨 |
| 큰 텍스트 (24px 이상, 또는 굵게 18.66px 이상) | 3:1 이상 (1.4.3) | 화면 제목, 큰 수치 |
| 비텍스트 UI (1.4.11) | 인접 색과 3:1 이상 | 칩 테두리(선택 안 됨), 선택된 칩 채움과 바탕, 체크 아이콘, 포커스 링, 탭 표시, 아이콘 버튼 |

#### 4-2. 측정 구간의 구분

| 구간 | 취급 | 검증 |
|---|---|---|
| **정상 표시**: 전환 전, 전환 완료 후(o=0) | 위 기준 전부 적용 | 자동 테스트(테마 색쌍 계산) + 미리보기 확인 |
| **커튼 전환 중**(0 < o < 1) | 의도된 일시적 가림(페이드)으로 별도 취급. 커튼은 글자와 바탕을 같은 비율로 어둡게 할 뿐 둘의 순서를 뒤집지 않는다 | 커튼 아래 테마가 "낮 또는 밤 테마 그대로"인지 확인(=정상 표시 구간과 같은 색쌍). 색 보간으로 글자색과 바탕색이 서로 다가가는 일이 없는지 확인 |
| **완전히 덮인 순간**(o=1) | 의도된 가림. 읽기 대상 아님 | 이 순간에 테마가 교체되는지만 확인 |

- 이 spec이 없애는 것은 "커튼 없이 글자와 바탕 색이 서로 같아지는 상태(현행 lerp)"다. 커튼 전환 중에 화면 전체가 어두워지는 것은 의도된 효과다.

#### 4-3. 화면 낭독기·포커스·움직임

- **커튼은 읽히지 않는다:** 커튼 전체를 `ExcludeSemantics`로 감싼다. 접근성 트리에 커튼 노드(라벨·버튼·장벽)가 생기지 않는다. 새 안내 방송(announce)은 추가하지 않는다.
- **앱 콘텐츠의 접근성 트리는 숨기지 않는다.** `ExcludeSemantics`/`BlockSemantics`로 콘텐츠를 가리면 화면 낭독기 포커스가 처음으로 초기화될 수 있기 때문이다.
- 모드 버튼의 선택 상태는 `obsModeProvider` 기준이라 누르는 즉시 읽힌다.
- 키보드 포커스 위치는 전환 전후로 같다(트리·`FocusNode` 재생성 없음, 3-1 키보드 차단 방식).

**접근성 사용자에게 "숨겨진 화면이 조작 가능한 상태" 처리**

화면 낭독기의 실행 동작(TalkBack 두 번 탭, VoiceOver 실행 등)은 포인터·키 이벤트가 아니라 접근성 동작(`SemanticsAction.tap`)으로 전달되므로 커튼의 포인터·키보드 차단을 거치지 않는다. 이를 다음과 같이 다룬다.

1. **화면 낭독기·접근성 탐색이 켜져 있으면(`MediaQuery.accessibleNavigationOf(context)` true) 커튼 없이 즉시 전환한다**(움직임 줄이기와 같은 경로). 이 경우 "보이지 않지만 조작 가능한" 구간 자체가 생기지 않는다.
2. 1이 감지되지 않는 환경(예: Flutter 웹에서 접근성 신호가 이 값으로 전달되지 않는 경우 — 구현 시 확인해 Notes에 기록)에서는 접근성 동작을 막지 않는다. 화면 낭독기 사용자에게 커튼은 시각 효과일 뿐이고, 아래 콘텐츠가 실제 현재 화면이므로 실행된 동작은 정상 동작이다. 모드 상태가 바뀌면 3-2 규칙으로 수렴한다.
3. 콘텐츠 접근성 트리를 차단해 포커스를 잃게 하는 방식은 쓰지 않는다.

- **움직임 줄이기:** `MediaQuery.disableAnimations`가 켜져 있으면 커튼 없이 같은 프레임에 교체한다. `sceneTransitionDuration`의 움직임 줄이기 값(150/250ms)은 쓰지 않게 되므로 0으로 정리한다.
- 즉시 전환 조건 = `disableAnimations || accessibleNavigation`. 두 값은 전환을 시작할 때 읽는다(현행처럼 `MediaQuery.maybeOf`).
- **깜빡임:** 전환 1회당 밝기 변화는 "어두워짐 1회 + 밝아짐 1회"뿐이다. o ≥ 0.5에서 포인터·키보드 입력이 막히므로 연타로 빠른 점멸을 만들 수 없다(WCAG 2.3.1 초당 3회 기준 해당 없음).

### 5. Phase 1의 알려진 한계 (콘텐츠와 테마 시점 차이)

홈·지도·코스 상세·관찰지 상세·둘레길 상세가 `obsModeProvider`를 직접 구독하므로, **Phase 1만 적용하면** 모드를 바꾼 직후 전반부(수동 약 0.28~0.32초, 자동 0.4초) 동안 **새 모드의 콘텐츠가 이전 테마 색으로** 보이며 어두워진다.

- 예: 낮→밤으로 누르면 커튼이 덮이기 전까지 "오늘 밤하늘" 등 밤 콘텐츠가 흰 바탕에 잠깐 보인다. 지도는 낮 덮개(흰 15%)가 즉시 사라진다.
- 글자는 이전 테마 색쌍이라 정상 대비로 읽힌다(대비 문제는 아님).
- 홈 등장 애니메이션(수동 전환 시 620ms 스태거)은 탭 즉시 시작되므로 앞부분 약 절반이 커튼에 가려진다.
- **Phase 2 필요성은 Phase 1 미리보기 후 사용자가 결정한다.** 이 어긋남이 거슬리지 않으면 Phase 2 없이 마칠 수 있다.

### 6. Phase 2 (보류): 콘텐츠와 테마 동기화

비교한 방식:

| 방식 | 내용 | 변경 범위 | 부작용 |
|---|---|---|---|
| ① 현행 유지 | 콘텐츠는 즉시, 테마만 커튼 뒤에서 교체 | 없음 | 5절의 어긋남 |
| ② **표시 모드 provider (권장)** | `sceneModeProvider` = "지금 화면에 그려진 모드". 평소에는 `obsModeProvider`를 그대로 따르고, 전환 중에만 `main.dart`가 교체 지점까지 이전 값을 붙잡아 둔다 | 새 provider 1개 + 아래 표의 5개 파일, 읽기 7곳 | 데이터 요청이 최대 약 0.3~0.4초 늦게 시작. `discoveryProvider`는 `keepAlive`라 한 번 받은 모드는 즉시 표시 |
| ③ 모드 변경 자체를 늦춤 | `setManual`이 교체 지점에 상태를 바꾸도록 지연 | 컨트롤러·토글·테스트 전반 | 버튼 반응이 늦고 재토글 규칙이 복잡. **비권장** |
| ④ 화면 하위에 provider 덮어쓰기 | `ProviderScope` 중첩으로 이전 값 고정 | 앱 루트 | 중첩 scope에서 `setManual`이 다른 인스턴스로 감. **비권장** |

**②의 provider 구조**
- `sceneHoldProvider`(StateProvider<ObsModeState?>) + `sceneModeProvider = Provider((ref) => ref.watch(sceneHoldProvider) ?? ref.watch(obsModeProvider))`.
- 앱 루트가 없는 화면 단위 테스트에서는 hold가 늘 null → 기존처럼 즉시 따른다(기존 테스트 보호).
- `main.dart`: 전환 시작 시 hold = 이전 표시 상태(같은 이벤트 안에서 동기 설정), 교체 지점에서 hold = null. 움직임 줄이기면 hold 없음. hold 해제는 세대 번호 g로 보호(3-4).

**변경 대상: 5개 파일, provider 읽기 7곳** (줄 번호는 2026-10-30 기준)

| # | 파일 | 현재 읽기 | 바꿀 읽기 | 이 값이 쓰이는 곳 | 바꾸는 이유 |
|---|---|---|---|---|---|
| 1 | `apps/flutter/lib/screens/home_discovery_screen.dart:68-70` | `ref.watch(obsModeProvider)` → `modeState`, `currentMode` | 콘텐츠용 `displayedMode = ref.watch(sceneModeProvider).mode`를 새로 두고, `modeState`는 그대로 유지 | `displayedMode`: `discoveryProvider(…)`(70, 785), 오류·지연 추적 listen(103-114), 새로고침(124, 213), 콘텐츠 분기(287, 304, 408, 482, 668, 799). `modeState` 유지: 모드 버튼 `active`(257, 272), 자동/직접 배지(246, 841) | 콘텐츠는 커튼 뒤에서 바뀌고, 버튼 선택 표시는 누른 즉시 반영(화면 낭독기 포함) |
| 2 | `apps/flutter/lib/screens/home_discovery_screen.dart:90` | `ref.listen(obsModeProvider)` → 등장 애니메이션 | `ref.listen(sceneModeProvider)` | `_staggerController` 시작 | 새 콘텐츠 등장 애니메이션이 커튼이 걷힐 때 시작 |
| 3 | `apps/flutter/lib/screens/observation_map_screen.dart:470` | `ref.watch(obsModeProvider).mode` | `ref.watch(sceneModeProvider).mode` | 물때·달·골든타임 문구(`discoveryProvider`) | 지도 정보 문구가 커튼 전에 바뀌지 않게 |
| 4 | `apps/flutter/lib/screens/observation_map_screen.dart:644` | 같음 | 같음 | 지도 낮 덮개(흰 15%) 표시 여부 | 덮개가 커튼 전에 사라지거나 나타나지 않게 |
| 5 | `apps/flutter/lib/screens/course_detail_screen.dart:170` | 같음 | 같음 | 낮/밤 강조 표시(`dayAccent`/`nightAccent`) | 강조가 이전 테마 위에서 먼저 바뀌지 않게 |
| 6 | `apps/flutter/lib/widgets/observation_spot_detail.dart:87` | 같음 | 같음 | `spotSuitabilityProvider(query)`의 모드 → 관찰지 적합도 | 열린 시트 내용이 커튼 뒤에서 바뀌게. 요청이 최대 약 0.3~0.4초 늦게 시작 |
| 7 | `apps/flutter/lib/widgets/spot_detail/trail_spot_detail.dart:285` | 같음 | 같음 | 낮/밤 강조 표시 | 5번과 같음 |

- **바꾸지 않는 것:** 모드 버튼의 `setManual`(home 262, 277), `resetToAuto`(home 865, 868), `main.dart`의 `ref.listen(obsModeProvider)`(전환을 시작하는 쪽), `scene_transition.dart`의 `ObsModeSource` 사용, `mode_header.dart`(사용처 없음).
- 데이터 요청 지연 상쇄(선택): 전환 시작 시 목표 모드 `discoveryProvider`를 미리 요청. 미리보기에서 지연이 보일 때만 넣는다.

## 054-1과의 관계

**054-1 검증 상태(구분 기록)**
- 전환 완료 후 칩 글자와 선택 상태: **자동 테스트 통과**(앱 경로에서 칩 글자 `WidgetStateColor` 유지, 선택 칩 글자 = `surface`, 대비 ≥ 4.5).
- 전환 **도중** 전체 글자 대비(최대 0.8초 동안 1:1까지 저하): **알려진 이슈**, 054-1 범위 밖이며 이 spec 060에서 해결한다.
- 생태일기 카드, 320px 실제 화면: 사용자가 직접 확인하지 않은 항목은 **미확인**(자동 테스트의 320px 넘침 없음 확인과는 별개).

| 구분 | 054-1에 남기는 것(커밋 1·2) | 060에서 제거·교체하는 것 |
|---|---|---|
| `scene_transition.dart` | `sceneTheme(from, to, t)`(t≥1이면 to, t≤0이면 from, 그 외 lerp), import 변경 | `sceneTheme` 삭제. `curtainOpacity`, `hasSwapped`, `SceneCurtain`, `kCurtainRiseFraction` 추가. 지속 시간·곡선·햅틱 함수는 유지(움직임 줄이기 시간만 0으로) |
| `main.dart` | `sceneTheme` 호출 2곳(현재 테마 캡처, `MaterialApp.theme`) | 두 호출과 `_fromTheme`/`_toTheme` 보간 로직을 "표시 테마 + 커튼 + 세대 번호"로 교체. (Phase 2) hold 설정 추가 |
| 테스트 | `sceneTheme` 그룹 3개, "mode change converges" 칩 `WidgetStateColor` 확인, 054-1 테마·칩 테스트 전부 | `sceneTheme` 그룹 3개 삭제(대상 함수 삭제). converges·지속 시간·움직임 줄이기·재토글 테스트는 새 구조에 맞게 수정. 054-1 테마·칩 테스트는 수정하지 않음 |

**테스트 책임**
- 054-1: 정지 상태의 테마 값, 칩 반전 선택, FilterChip 체크(3곳), ChoiceChip 체크 없음, 320px·포커스·44px, 앱 경로에서 칩 글자 `WidgetStateColor` 유지(전환 완료 후).
- 060: 전환 **도중** 모든 시점의 테마 동일성, 정상 표시 구간 대비, 커튼 동작, 입력 차단, 재토글, 상태 유지, 움직임 줄이기, (Phase 2) 콘텐츠 교체 시점.

**커밋 경계**
1. 054-1 코드 커밋 → 2. 054-1 문서 커밋(053·054).
3. 060 spec 문서 커밋(이 파일만).
4. 060 Phase 1 구현 커밋(`main.dart`, `scene_transition.dart`, `test/scene_transition_test.dart`, 새 테스트, `member.md`).
5. (결정 시) 060 Phase 2 구현 커밋(새 provider, 5개 파일, 관련 테스트).
6. 060 문서 갱신 커밋(체크박스·Notes·Amendments).
- 060 구현은 1·2가 커밋된 뒤 시작한다(같은 파일 `main.dart`·`scene_transition.dart`·`scene_transition_test.dart`를 고치므로 섞이지 않게).
- 모든 커밋에서 제외: `.codex/`, `AGENTS.md`, `.vscode/`, `specs/046-trails-all-regions-backend.md`, `apps/flutter/tool/dev_preview_*.dart`.

## Relevant Files

### Existing Files

- `apps/flutter/lib/main.dart` - 테마 보간 제거, 표시 테마 + `MaterialApp.builder` 커튼 + 세대 번호 기반 재토글. (Phase 2) 전환 시작·교체 시 hold 설정.
- `apps/flutter/lib/theme/scene_transition.dart` - `sceneTheme` 삭제, 커튼 불투명도·교체 판정 함수와 `SceneCurtain` 추가, 움직임 줄이기 시간 0.
- `apps/flutter/test/scene_transition_test.dart` - `sceneTheme` 그룹 삭제, 기존 6개 테스트를 새 구조에 맞게 수정, 아래 테스트 추가.
- `apps/flutter/.team/member.md` - 작업 기록.
- (Phase 2) 6절 표의 5개 파일.

### New Files

- `apps/flutter/test/scene_curtain_test.dart` - 커튼 위젯·불투명도 곡선·입력 차단·접근성 테스트.
- (Phase 2) `apps/flutter/lib/state/scene_mode_providers.dart` - `sceneHoldProvider`, `sceneModeProvider`.
- (Phase 2) `apps/flutter/test/state/scene_mode_providers_test.dart` - hold 없을 때 즉시 따름, hold 중 이전 값 유지, 해제 시 최종 값.
- (검증용, **커밋 금지, 검증 후 삭제**) `apps/flutter/tool/dev_preview_scene.dart` - 아래 "개발용 느린 재생 미리보기" 참고.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 테마 페이드 스루 (색 보간 제거)

테마는 낮/밤 둘 중 하나만 쓰고, 커튼이 완전히 덮였을 때 교체한다. 콘텐츠는 현행대로 즉시 바뀐다(5절 알려진 한계).

- [x] `scene_transition.dart`: (Amendment ①) `kCurtainRiseFraction`, `SceneCurtain`, `SceneInputGuard`, 커튼 곡선 추가, `sceneTheme` 삭제, 움직임 줄이기 시간 0
- [x] `main.dart`: 표시 테마(낮/밤 중 하나) + `builder` 커튼, `AnimatedBuilder`는 커튼만 다시 그림, 3절 규칙(입력 차단·재토글·수렴·세대 번호), 완료·dispose 시 커튼 0
- [x] 햅틱·자동/수동 시간 유지 확인
- [x] 테스트 수정·추가(아래 "테스트 계획" 1~8)
- [x] analyze, 전체 테스트, 웹 빌드(DEMO_FALLBACK 켬·끔)
- [x] 미리보기 확인 — 사용자 전반 확인 완료(약간 부자연스러우나 사용에 지장 없음). "시각 검증" 세부 항목은 개별 미확인
- [x] o ≥ 0.5 구간 시간을 곡선으로 계산해 Notes에 기록

**Phase validation**: 앱 경로의 `MaterialApp.theme`이 전환 중 모든 프레임에서 낮 또는 밤 테마와 동일하고, 커튼이 끝나면 0이며, 기존 테스트 전체 통과.

### Phase 2: 콘텐츠 교체 시점 동기화 (보류 — Phase 1 미리보기 후 별도 결정)

- [ ] `scene_mode_providers.dart`(hold + 표시 모드) 추가
- [ ] `main.dart`: 전환 시작 시 hold = 이전 표시 상태, 교체 시 hold = null(세대 번호 보호), 움직임 줄이기면 hold 없음
- [ ] 6절 표의 읽기 7곳 교체(바꾸지 않는 것 목록은 그대로)
- [ ] (선택) 전환 시작 시 목표 모드 `discoveryProvider` 미리 요청 — 지연이 보일 때만
- [ ] 테스트 추가(아래 9~10), 기존 홈·지도·상세 테스트 무수정 통과 확인
- [ ] analyze, 전체 테스트, 웹 빌드, 미리보기 확인

**Phase validation**: 전환 전반부 프레임에서 홈 콘텐츠가 이전 모드, 후반부에서 새 모드이고, 화면 단위 테스트(앱 루트 없음)는 수정 없이 통과.

## 테스트 계획

1. **테마 동일성:** 낮→밤, 밤→낮 각각 시작·교체 직전·교체 직후·완료 시점에 `Theme.of(context)`가 정확히 이전 또는 목표 테마(보간 테마 없음).
2. **대비(정상 표시 구간, 4-1 기준):** 낮·밤 테마 각각 — 일반 텍스트(본문, 보조 글자, 칩·버튼 라벨) ≥ 4.5:1, 큰 텍스트 ≥ 3:1, 비텍스트(칩 테두리, 선택 칩 채움 대 바탕, 체크 아이콘, 포커스 링, 탭 표시) ≥ 3:1. 칩 글자 `WidgetStateColor`가 모든 시점에서 유지. 전환 중에는 1번(테마 동일성)으로 "색쌍이 정상 구간과 같음"을 보장.
3. **커튼:** 불투명도 0→1→0, 교체 시점에 1, 완료 후 위젯 없음. 커튼 색 #141414. `ExcludeSemantics`로 접근성 트리에 없음.
4. **포인터 차단(3-1):** o < 0.5에서 아래 버튼 탭 전달, o ≥ 0.5에서 탭 버려짐(완료 후 재실행 없음), 완료 후 정상.
4-1. **키보드 차단(3-1):** 버튼(`FocusNode` 지정)에 포커스 → 전환 시작 → o ≥ 0.5까지 진행 → Enter·Space·NumpadEnter 전송 시 `onPressed` 호출 0회, Tab·방향키 전송 후에도 같은 노드가 `hasPrimaryFocus`, Escape 전송 시 열린 시트가 닫히지 않음. o < 0.5로 내려간 뒤와 완료 후에는 Enter로 정상 실행(1회). 가려진 동안 버려진 키가 나중에 실행되지 않음.
4-2. **포커스 유지:** 전환 시작 전·교체 직후·완료 후 모두 같은 `FocusNode`가 `hasPrimaryFocus`.
4-3. **모드 상태는 별도 수렴:** 가려진 구간에 테스트 코드가 `setManual`/`resetToAuto`를 호출 → 키보드·포인터 차단과 관계없이 최종 모드로 수렴, 커튼 0.
4-4. **접근성 트리:** `tester.ensureSemantics()` 상태에서 전환 중 커튼 관련 노드가 없음(라벨·버튼·장벽 없음), 콘텐츠 버튼의 시맨틱 노드는 전환 전후 그대로 존재(`find.bySemanticsLabel`).
4-5. **접근성 탐색 켜짐:** `MediaQuery(accessibleNavigation: true)`에서 모드 변경 → 같은 프레임에 교체, 커튼 없음(움직임 줄이기와 같은 결과).
4-6. **접근성 동작 경로(2번 규칙):** 접근성 탐색 신호 없이 가려진 구간에 시맨틱 실행(`SemanticsAction.tap`)을 보내면 동작이 실행되고, 모드가 바뀐 경우 최종 모드로 수렴(막지 않음을 명시적으로 확인).
5. **상태 유지:** 스크롤한 목록 + 선택한 칩 + 열린 바텀시트 상태에서 전환 → 스크롤 오프셋·선택·시트·`State` 객체가 같음. 하단 탭 위치·포커스 유지.
6. **움직임 줄이기:** 같은 프레임에 교체, 커튼 없음. 전환 도중 설정이 켜진 상태의 재토글도 즉시 수렴.
7. **재토글(3-2):** 전반부 되돌림(교체 없이 커튼 0으로), 후반부 되돌림(다시 덮고 교체), 같은 모드 재선택 무시, `resetToAuto`로 인한 전환(자동 시간·햅틱 없음).
8. **수렴·무효화(3-3, 3-4):** 5회 연속 변경 후 `pumpAndSettle` → D = 최종 모드, o = 0, 차단 없음. 한 번의 커튼 사이클에 교체 1회 이하. 이전 세대 처리가 최종 모드를 뒤집지 않음. 수동 요청당 햅틱 1회. 전환 중 위젯 dispose 시 예외 없음.
9. (Phase 2) **콘텐츠 시점:** 전반부엔 이전 모드 콘텐츠, 교체 후 새 모드 콘텐츠. 버튼 선택 표시는 즉시 바뀜.
10. (Phase 2) **기존 테스트 보호:** 앱 루트 없이 화면만 띄운 테스트에서 `setManual` 즉시 반영(hold 없음).
11. 전체 테스트(현재 365개 기준), analyze 문제 없음, 웹 빌드 켬·끔 성공.

## 개발용 느린 재생 미리보기 (커밋 금지, 검증 후 삭제)

- 파일: `apps/flutter/tool/dev_preview_scene.dart`. 실제 `MyApp`을 그대로 띄우고 `timeDilation`으로 전환만 느리게 재생한다(`?slow=5` 기본 5배). 앱 코드와 인증은 바꾸지 않는다(로그인은 "로그인 없이 둘러보기 (체험 모드)"로 통과).
- **두 용도를 섞지 않는다.** 화면 상단에 고정 라벨을 표시하고, 서버 포트도 나눈다.

| 용도 | 시점 | 화면 라벨 | 포트 | 비고 |
|---|---|---|---|---|
| A. 현행 전환 느린 재생(기준선) — **만들지 않음(2026-10-30 사용자 결정)** | — | "현행 전환(색 보간) · 느린 재생 ×N" | 8113 | 현재 커밋된 lerp 전환을 보여줄 뿐, 새 전환이 아님 |
| B. 060 Phase 1 전환 검증 | Phase 1 구현 후에만 | "060 페이드 스루 · 느린 재생 ×N" | 8114 | Phase 1 코드가 있는 작업 트리로 빌드 |

- 라벨 문구는 빌드 시 `--dart-define=PREVIEW_LABEL=…`로 넣어, 어떤 코드로 빌드했는지 화면에서 구분되게 한다.
- 060 구현 전에 B를 만들거나, A를 새 전환인 것처럼 설명하지 않는다.

## 시각 검증 (PNG/JPG 없음)

- 방법: `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8112`(Hot Reload)를 VS Code Simple Browser로 연다. 구현 확정 후에는 기존 8080(DEMO_FALLBACK 켬)/8081(끔) 빌드를 갱신한다. 서버는 기존 것을 재사용하고 중복 실행하지 않는다. 느린 재생은 Phase 1 구현 후 8114(B)만 사용.
- 확인 목록(사용자 확인 전까지 "미확인"으로 보고):
  - [ ] 낮→밤: 어두워졌다가 밤 화면이 나타남, 회색으로 뭉개지는 순간 없음
  - [ ] 밤→낮: 어둠에서 밝아짐, 흰 화면 번쩍임·눈부심 없음
  - [ ] 전반부·후반부 재토글, 빠른 연타 후 커튼이 남지 않음, 연타가 점멸처럼 보이지 않음
  - [ ] 지도: 열린 관찰지 시트와 선택한 레이어 칩(체크 포함) 유지
  - [ ] 하단 탭 위치와 목록 스크롤 위치 유지
  - [ ] 320px 폭(Simple Browser 창 폭 조정)
  - [ ] Phase 1 알려진 한계(새 콘텐츠가 이전 색으로 잠깐 보임)의 체감 정도 — Phase 2 결정 자료
  - [ ] (Phase 2) 콘텐츠가 커튼 뒤에서 바뀌고, 홈 등장 애니메이션이 커튼이 걷힐 때 시작

## 위험 요소

- **콘텐츠 어긋남(Phase 1만 적용 시):** 5절. Phase 2 또는 전반부 비율 축소로 대응(결정은 미리보기 후).
- **데이터 요청 지연(Phase 2):** 최대 약 0.3~0.4초 — keepAlive 캐시로 대부분 즉시 표시, 필요 시 미리 요청.
- **hold 설정 순서(Phase 2):** `main.dart`의 `ref.listen`이 화면들의 다음 빌드보다 먼저 hold를 설정해야 한다(같은 이벤트 안에서 동기 설정). 전용 테스트로 확인.
- **입력 무시 구간:** o ≥ 0.5 동안(약 0.15~0.4초) 탭·키 입력이 버려짐 — 의도된 동작. 실제 시간은 Phase 1에서 측정.
- **키보드 차단 범위:** `Shortcuts`는 앱 루트 단축키 경로만 가로챈다. 나중에 화면에 자체 키 처리(`onKeyEvent`)가 추가되면 차단을 우회할 수 있으므로 테스트 4-1로 지킨다.
- **웹 접근성 신호:** Flutter 웹에서 화면 낭독기 사용 시 `accessibleNavigation`이 true가 되는지 확실하지 않다. 안 되면 4-3의 2번 규칙(접근성 동작은 막지 않음)이 적용된다. Phase 1에서 확인해 Notes에 기록.
- **기존 테스트 수정:** `scene_transition_test.dart`의 6개 테스트 기대값이 바뀜(보간 → 교체). 054-1 테마·칩 테스트, `mode_header_test.dart`, 화면 테스트는 수정하지 않는 것을 목표로 한다.
- **웹:** 전환 1회당 `MaterialApp` 재빌드 1회(교체 시점, 커튼에 가려짐) + 커튼 알파 변경뿐이라 현행(매 프레임 전체 테마 재생성)보다 가볍다. 실제 프레임은 미리보기로 확인.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.
> (Windows 세션 내 실행: `flutter analyze`, `flutter test`, `flutter build web --dart-define=DEMO_FALLBACK=true|false` — just가 없는 환경의 세션 내 실행 방식)

```sh
just check
```

## Notes (agent scratchpad)

- 2026-10-30 brain: **Phase 1 완료(사용자 승인, 추가 애니메이션 조정 없음).** 검증 기록:
  - `flutter analyze`: PASS(문제 없음).
  - 전체 Flutter 테스트: 389개 통과.
  - 웹 빌드 DEMO_FALLBACK ON/OFF: 성공.
  - 사용자 미리보기 확인(8112 실제 속도, 8114 느린 재생): 낮·밤 전환이 약간 부자연스럽지만 사용에 큰 지장은 없음.
  - 회색으로 글자가 사라지던 기존 색상 보간 문제는 새 구조(테마는 낮/밤 둘 중 하나만, 커튼이 덮인 순간 교체)로 해결. 근거: 자동 테스트(모든 표본 프레임에서 순수 낮/밤 테마, 교체 시 커튼 1.0).
  - Phase 1에서 콘텐츠가 테마보다 먼저 바뀌는 현상은 알려진 한계(5절)로 남는다.
  - Phase 2 콘텐츠 동기화는 승인되지 않았으며 보류.
  - 아래 "시각 검증" 세부 항목과 실제 접근성 환경(화면 낭독기, 웹 `accessibleNavigation` 신호, 키보드 실사용)은 개별로 확인하지 않았으므로 PASS로 기재하지 않는다(미확인). 자동 테스트로 확인된 것은 테스트 계획 1~8 범위뿐이다.
- 2026-10-30 brain: 설계 검토(B안 페이드 스루) 승인 후 문서 초안 작성. 구현·커밋 미승인.
- 2026-10-30 brain: Phase 1 구현(engineer) → lead 검증 PASS. analyze 문제 없음, 테스트 389개 통과(기준 365, sceneTheme 3개 삭제 포함 순증 24), 웹 빌드 DEMO_FALLBACK 켬·끔 성공. 커밋 전.
  - 입력 차단 구간(o ≥ 0.5) 곡선 계산값: 밤으로 수동 280ms(전반 140 + 후반 140), 낮으로 수동 160ms(66 + 94), 자동 밤으로 400ms, 자동 낮으로 200ms.
  - Flutter 웹에서 화면 낭독기 사용 시 `accessibleNavigation` 신호가 들어오는지는 미확인(자동 테스트는 MediaQuery로 강제한 경우만 검증). 신호가 없으면 4-3의 2번 규칙 적용.
  - `MaterialApp`의 기본 `AnimatedTheme`(200ms)이 교체 후 커튼 아래에서 테마를 다시 보간하는 것을 발견해 `themeAnimationStyle: AnimationStyle.noAnimation`으로 막음(기존 lerp 구조에도 있던 중첩 보간).
- 2026-10-30 brain: 054-1 커밋 완료(4f52099 코드, 8c3172c 문서). spec 기본 설계 승인, 키보드·접근성 규칙 보완 후 문서 커밋. 현행 기준선 미리보기(8113)는 만들지 않음. Phase 1 구현은 미승인.
- 2026-10-30 brain: 사용자 결정 반영(확정된 결정 1~6). 남은 결정: Phase 1 구현 승인, (Phase 1 미리보기 후) Phase 2 진행 여부와 전반부 비율 조정 여부.

## Amendments (post-build change history, append-only)

- 2026-10-30: 초안 작성.
- 2026-10-30: Phase 1 구현 중 설계 문구 정리(기능 동일) — ① `curtainOpacity`·`hasSwapped` 함수는 만들지 않음: 컨트롤러 값이 곧 커튼 불투명도이고, 교체는 값이 1에 닿은 틱에서 판정. ② 세대 번호 g는 두지 않음: 매 틱 현재 필드만 읽고 이전 목표를 붙잡는 콜백이 없어 같은 효과. ③ 키 차단 인텐트는 `DoNothingAndStopPropagationIntent` 대신 `DoNothingIntent`(키를 소비해 웹 브라우저 기본 동작 — Tab 이동·Space 스크롤 — 까지 막음). 부작용: 가려진 구간에는 글자 입력란 안의 Space·방향키도 소비됨. ④ `MaterialApp.themeAnimationStyle: AnimationStyle.noAnimation` 추가(기본 AnimatedTheme 보간 차단).
- 2026-10-30: 키보드·접근성 규칙 보완(사용자 요청) — 가려진 구간(o ≥ 0.5)에 Navigator 위 `Shortcuts`로 실행·이동·Escape 키 소비(포커스 유지), 모드 상태 변경은 차단과 별도로 수렴, o < 0.5에서 즉시 복구, 커튼은 `ExcludeSemantics`, 접근성 탐색이 켜져 있으면 즉시 전환, 그 밖의 접근성 동작은 막지 않음. 테스트 4-1~4-6 추가.
- 2026-10-30: 사용자 검토 반영 — 입력 차단(포인터만, o ≥ 0.5)과 재토글(provider 상태 변화 기준) 규칙 분리, 연속 요청 수렴·이전 콜백 무효화 규칙, Phase 2 대상(5개 파일, 읽기 7곳) 표, 대비 기준(일반·큰 텍스트·비텍스트)과 측정 구간 구분, Phase 1 알려진 한계, 개발용 미리보기 용도 구분. Phase 2는 보류.
