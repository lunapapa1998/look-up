# 낮/밤 모드 헤더 골격 (source 확장 + collapsing pinned header + 자동/수동 배지)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-09
- modified: 2026-09-09 <brain/orchestrator>
- refs: `specs/009-discovery-mode-cache-flutter.md`, `specs/007-gps-location-flutter.md`, design-lead 자문 2건(모드 헤더 권고 + collapsing pinned header/HIG 판단), `apps/flutter/lib/screens/home_discovery_screen.dart`, `apps/flutter/lib/screens/app_shell.dart`
- risk: medium - flutter IA/상태 리팩터(SingleChildScrollView→CustomScrollView/SliverAppBar, obsMode enum→{mode,source}). backend·계약 무변경. 후속 011(morph 토글·장면 전환 애니)의 골격.

## Purpose

낮/밤 전환을 "필터 세그먼트"에서 "화면 최상단의 모드 헤더"로 재설계하되, 이번 조각은 그 **골격**(정보구조·상태모델·헤더 거동·자동/수동 표시)만 세운다. 비주얼 morph 토글과 장면 전환 애니는 후속 011.

## Problem

낮/밤 토글이 (1) 필터 문법의 pill 세그먼트라 "장면 전환급 모드"라는 정체성과 충돌하고, (2) `obsModeProvider`가 `ObsMode` 단일 enum이라 "자동(시간대)으로 낮인지, 수동으로 낮인지"를 구분·표시할 수 없으며, (3) 홈이 `SingleChildScrollView`라 헤더가 스크롤과 함께 사라져 모드 컨트롤이 항상 손에 닿지 않는다.

## Solution

`obsModeProvider`를 `{mode, source}`(source: `auto`|`manual`)로 확장하고, 앱 최초 진입 시 디바이스 로컬 시각으로 mode를 자동 결정(source=auto)하며 사용자가 전환하면 source=manual로 영구 유지한다. 홈을 `CustomScrollView`+`SliverAppBar(pinned)`로 바꿔 상단에 **collapsing pinned header**(펼침=아이덴티티 행+모드 헤더 / 접힘=모드 토글 얇은 바+자동/수동 배지)를 두고, 인사말·텔레메트리 라벨은 본문으로 내린다. 세그먼트는 폐기하고 기능적 낮/밤 토글(해/달 아이콘)로 대체하되, morph 애니메이션·장면 전환 연출은 011로 미룬다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/state/discovery_providers.dart` - `obsModeProvider`(현 `StateProvider<ObsMode>`)를 **모드+소스 상태**로 교체. 신규 `ObsModeState`(불변; `mode: ObsMode`, `source: ObsModeSource{auto,manual}`) + `ObsModeController`(`Notifier<ObsModeState>`): `build()`에서 **디바이스 로컬 시각 기반 초기 mode**(예 06:00~18:00=day, else night — Notes의 판정 규칙) + `source=auto`; `setManual(ObsMode)`(사용자 전환 → source=manual); `resetToAuto()`(현재 시각으로 재판정 → source=auto). `discoveryProvider(mode)` family(009)는 `obsModeProvider`의 `.mode`를 키로 계속 사용 — **캐싱 동작 유지**. `hotspotsProvider`/`locationProvider`/`suitabilityApiProvider` 무변경.
- `apps/flutter/lib/models/discovery.dart` - 필요 시 `ObsModeState`/`ObsModeSource`를 여기(또는 state 파일)에 정의. `ObsMode` enum 자체는 유지.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - **구조 전환**: `SingleChildScrollView` → `CustomScrollView` + `SliverAppBar(pinned: true, floating: false, snap: false)`. `expandedHeight ~120`은 **목표치** — 아이덴티티 행+모드 헤더가 넘치면 콘텐츠 기준으로 상향(007 오버플로우 방지 유지). `FlexibleSpaceBar` 펼침 영역 = 기존 아이덴티티 행(로고+위치 칩+프로필) + 그 아래 모드 헤더(낮/밤 토글 + **완전한** 자동/수동 배지). 접힘 `title` = 모드 토글 얇은 바(높이 목표 52pt, 각 토글 ≥44pt 터치 타깃). **접힘 바에는 위치 칩과 완전한 소스 배지를 넣지 않는다** — AUTO는 배지 생략, MANUAL일 때만 토글 옆에 accent dot 또는 "수동" 축약 캡션. 완전한 AUTO/MANUAL 배지 표현은 펼침 영역에만. **접힘 토글의 활성 모드는 배경 fill 또는 accent underline으로 표시**(색 단서만으로 부족 — 굵기/텍스트 병기, WCAG 1.4.1). 인사말 블록("완벽한 하루예요…")과 `LIVE FIELD TELEMETRY` 라벨은 헤더에서 떼어 `SliverList` 본문 최상단으로 이동. **상단 낮/밤 세그먼트(현 라인 140-228, `borderRadius 9999` pill Row) 제거** 후 모드 헤더로 대체. **적합도 카드(현 라인 230-504)·골든타임·텔레메트리·핫스팟 리스트(현 라인 560-821)는 본문 SliverList로 이동 — 삭제가 아님**(라인 440-500대는 적합도/텔레메트리 error 블록이므로 건드리지 말 것). `discoveryProvider(currentMode)`·`.when`·007 오버플로우 방지 유지.
- `apps/flutter/lib/screens/app_shell.dart` - (읽기 확인용) 하단 탭바와의 크롬 병존 확인. 변경 없을 수 있음.
- `apps/flutter/test/suitability_wiring_test.dart` / `test/location_wiring_test.dart` - `obsModeProvider` 상태모델 변경에 맞춰 참조·override 갱신. 캐싱 검증(009) 유지.

### New Files

- `apps/flutter/lib/widgets/mode_header.dart` - 모드 헤더 위젯(낮/밤 토글 + 자동/수동 배지). **expanded/collapsed 두 크기를 지원**하는 형태로 설계(011의 morph 토글이 이 자리에 들어올 수 있게 인터페이스를 열어둠). 이번 조각의 토글은 기능만(탭→`setManual`), 비주얼은 해/달 아이콘 + 라벨의 단순형(morph 애니·장면 전환은 011). 배지: `AUTO`=저채도 outline 칩(비인터랙티브), `MANUAL`=현재 accent filled 칩(**탭하면 `resetToAuto()`**). 접근성 semantics 라벨 필수.
- `apps/flutter/test/mode_header_test.dart` - (1) 최초 상태 source=auto·로컬시각 기반 mode, (2) 토글 탭→source=manual·mode 전환, (3) MANUAL 배지 탭→source=auto 복귀, (4) 첫 수동 전환 시 1회 힌트 노출, (5) SliverAppBar collapse 시 모드 토글이 pinned로 남는지(스크롤 위젯테스트).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 상태 모델 확장 (obsMode {mode, source})

- [x] `ObsModeState`/`ObsModeSource` + `ObsModeController`(Notifier): 로컬시각 초기 자동판정, `setManual`, `resetToAuto`. `discoveryProvider` family 키를 `.mode`로 연결(캐싱 유지). 기존 테스트 참조 갱신.

**Phase validation**: `just flutter-check`(analyze 무경고 + 기존 test green).

### Phase 2: collapsing pinned header 구조 + 모드 헤더 위젯

- [x] `home_discovery_screen.dart`: `CustomScrollView`+`SliverAppBar(pinned)` 전환. 아이덴티티 행+모드 헤더=펼침, 모드 토글 얇은 바=접힘. 인사/텔레메트리 라벨·카드들 본문 이동. 옛 세그먼트 제거.
- [x] `mode_header.dart`: 토글(→setManual) + 자동/수동 배지(MANUAL 탭→resetToAuto) + 첫 수동전환 1회 힌트. expanded/collapsed 크기 지원.

**Phase validation**: `just flutter-check` green.

### Phase 3: 테스트 + 접근성

- [x] `mode_header_test.dart` 5케이스. 배지 대비(WCAG AA)·44pt 터치타깃·semantics 라벨 확인. 캐싱(009) 회귀 없음 확인.
- [x] `just check` green.

**Phase validation**: 아래 Validation Commands.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계 (골격 only)
- **포함**: source 상태모델, 로컬시각 자동 초기판정, collapsing pinned header 구조(SliverAppBar), 모드 헤더 위치/기능 토글, 자동/수동 배지 + 자동복귀 + 첫 전환 힌트, IA 재배치(인사/텔레메트리 본문 이동), 세그먼트 폐기.
- **제외(→011)**: 해/달 **morph 애니메이션**, 낮/밤 **장면 전환 연출**(배경 crossfade·accent lerp·콘텐츠 stagger·haptic). 단 `mode_header.dart`는 011의 morph가 끼워질 수 있게 인터페이스를 열어둘 것.
- **골격 전환 처리(중요)**: 이번엔 morph·장면전환 없이 mode를 바꾸되, **전 요소를 얕은 crossfade 150ms로 통일** 처리한다(적합도 카드는 하드컷인데 hotspot만 fade되는 식의 "일부만 애니 → 깨진 것처럼 보임"을 방지). 기존 hotspot의 `AnimatedOpacity`(현 라인 565 부근, 250ms)도 이 150ms로 정렬. `MediaQuery.disableAnimations=true`면 하드컷 폴백. 진짜 장면전환(배경 crossfade·accent lerp·stagger)은 011.

### 초기 자동 판정 규칙 (골격 단순화)
- 디바이스 **로컬 시각** 기준: 대략 주간=낮, 야간=밤(예: 06:00–18:59=day, 그 외=night — 빌더가 상수로, 결정적). **정밀 일출/일몰(위치별) 연동 및 앱 사용 중 실시간 자동 전환은 이번 범위 밖**(후속). 사용자 요구는 "최초 진입 시 위치의 시간대로 결정"이므로 최초 1회 판정으로 충분.
- 자동/수동 정책(오너 확정): 최초=auto, 사용자가 토글하면 manual로 **영구 유지**(자동 복귀 없음). MANUAL 배지 탭이 유일한 자동 복귀 경로.

### design-lead 설계 그라운드 (자문 요지)
- 세그먼트 pill = 필터 문법 → 장면전환급 모드와 충돌하므로 폐기. "세계 넘기기" 프레이밍.
- 상단 헤더는 **collapsing pinned**(HIG large-title / Material top-app-bar collapse의 교집합). 통째 pin은 상하 크롬이 화면 33%를 먹어 금지 → 접힘 얇은 바(~50pt)만 pin(≈25%). 완전 scroll-away는 모드 접근성 깨져 반대.
- 아이덴티티 행(로고)은 pin 대상 아님(접히면 사라짐), 모드 토글이 pin 핵심. 위치 칩은 접힘 시 secondary로 강등/축약(상세는 후속 위치 UX 부채).
- 배지: AUTO=조용한 outline(비인터랙티브), MANUAL=accent filled(탭→자동복귀). 영구 오버라이드의 함정(수동에서 못 빠져나옴) 방지 위해 자동복귀 어포던스 필수 + 첫 전환 1회 힌트로 인지모델 정렬.

### 불변 원칙
- **backend·계약 무변경**. 순수 flutter. 009 캐싱(family) 회귀 금지. 007 헤더 오버플로우 방지 유지. 003 고정 한글 에러 문구·loading/degraded 처리 유지.

## Amendments (post-build change history, append-only)

- 2026-09-09: `obsModeProvider`가 실제 wall-clock(`DateTime.now()`)에서 초기 mode를 판정하게 되면서, 이 값을 직접 오버라이드하지 않던 기존 테스트들이 실행 시각에 따라 flaky해지는 문제가 생겨 `nowProvider`(`Provider<DateTime>`, overridable)를 신설해 결정적 테스트를 가능하게 했다.
- 2026-09-09: Relevant Files에 명시되지 않았던 세번째 테스트 파일 `apps/flutter/test/screens/home_discovery_screen_test.dart`가 존재해 `obsModeProvider`/구 세그먼트 UI에 의존하고 있었음을 뒤늦게 발견 — Phase 1/3에서 함께 갱신(override 추가, `.mode` 비교, Key 기반 탭으로 교체).
- 2026-09-09: `ModeHeader`의 낮 토글 아이콘을 최초 `Icons.wb_sunny`로 구현했다가 기존 텔레메트리 sky 아이콘과 충돌해 `Icons.light_mode`로 교체(아이콘 재사용 충돌 방지 원칙 확인).
- 2026-09-09: `CustomScrollView`+`SliverList`(`SliverChildListDelegate`)로의 전환은 뷰포트 밖 콘텐츠를 지연 빌드하므로, 기존 `SingleChildScrollView`때는 즉시 보이던 하단 핫스팟 카드를 위젯 테스트에서 찾으려면 `tester.dragUntilVisible(...)`로 먼저 스크롤해야 함 — 이후 유사한 하단 콘텐츠 테스트에 재사용할 패턴으로 기록.
- 2026-09-09: 적합도 카드에 추가한 150ms `AnimatedSwitcher` 크로스페이드 때문에, 모드 전환 직후 구값이 즉시 사라진다고 가정한 테스트는 `tester.pump()`를 최소 150ms 이상의 명시적 duration으로 한 번 더 호출해야 통과함(단순 `pump()` 3회로는 애니메이션이 끝나지 않음).
- modified: 2026-09-09, lead: claude-sonnet-5
