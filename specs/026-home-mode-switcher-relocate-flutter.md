# 홈 화면 Figma 정합 리파인 — 모드 스위처 이동 + 게이지 축소 + 골든타임 블록 (flutter)

> Lightweight plan-f3 spec. 홈 화면을 Figma 정본에 맞춘다: (1) 낮/밤 모드 스위처를 상단 pin 헤더에서 카드 아래 "지금 시선의 초점" 풀폭 세그먼트(1-105)로 되돌리고, (2) 과대한 스코어 게이지(120→56)를 1-23에 맞추고, (3) 카드 내부 골든타임 낮/밤 블록을 1-47 정본 스타일로 정합한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/010-mode-header-skeleton-flutter.md, specs/025-home-suitability-card-redesign-flutter.md, Figma node 1-105 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium
- modified: 2026-09-18, lead: claude-sonnet-5

## Purpose

낮/밤 모드 스위처를 상단 pin 헤더에서 적합도 카드 아래 일반 섹션으로 되돌리고(Figma 1-105), 과대한 스코어 게이지(120→56)를 Figma 정본에 맞춰, 시선 흐름과 크기 비율을 목업과 일치시킨다.

## Problem

현재 스위처는 SliverAppBar 안에서 스크롤 시 상단에 pin/접힘되는 컴팩트 토글이라, Figma 1-105가 의도한 "카드 아래의 지금 시선의 초점 풀폭 세그먼트 선택" 배치·스타일과 어긋난다.

## Solution

`ModeHeader`(확장형 + 접힘 pin 레이어)를 SliverAppBar에서 제거하고, 적합도 카드 바로 아래 SliverList에 "지금 시선의 초점" 섹션(풀폭 세그먼트 2버튼 + "필터 맞춤 설정" 리셋 어포던스)을 추가한다. 모드 상태·전환 로직(`obsModeProvider`, setManual/resetToAuto)은 그대로 재사용한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - SliverAppBar에서 `ModeHeader` 2곳 제거(확장형 + 접힘 pin `IgnorePointer/Opacity` 레이어), 카드 아래에 새 스위처 섹션 삽입. 앱바 collapse/opacity 계산이 mode header 전용이었다면 정리. 또한 카드 헤더 `ScoreGauge(...)` 호출에 `size: 56, scoreFontSize: 20` 전달(Phase 4).
- `apps/flutter/lib/widgets/mode_header.dart` - 참조. 풀폭 세그먼트를 새 위젯으로 만들되, 기존 `_ToggleSegment` 재사용/확장 가능. `collapsed` 경로가 더 이상 안 쓰이면 정리 판단(단, 다른 화면에서 참조하면 유지).
- `apps/flutter/lib/widgets/score_gauge.dart` - `scoreFontSize` 옵션 파라미터 추가(기본 null → 현행 32px 유지). 홈만 20px로 낮춘다. 타 화면(course_detail/spot_detail/course_card/trail 등) 무영향.

### New Files

- `apps/flutter/lib/widgets/focus_mode_switcher.dart` (선택) - "지금 시선의 초점" 라벨 + 풀폭 세그먼트 2버튼 + 리셋 어포던스를 담는 섹션 위젯. 같은 파일 내 private 위젯으로 둬도 무방.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 상단 스위처 제거

SliverAppBar에서 모드 스위처를 걷어내고 앱바를 정리한다.

- [x] 확장형 `ModeHeader`(flexibleSpace 내부) 제거. 앱바에는 위치 선택 Row(explore + locationLabel + arrow)와 아바타만 남긴다.
- [x] 접힘 pin 레이어(`Positioned` + `IgnorePointer` + `Opacity`, key `modeHeaderCollapsedLayerOpacity`) 제거.
- [x] mode header 접힘 표시 전용으로만 쓰이던 `collapseFraction`/opacity 계산이 있으면 정리(다른 요소가 쓰면 유지). 앱바 높이·pinned 설정을 남은 콘텐츠에 맞게 조정.

**Phase validation**: 스크롤해도 상단에 낮/밤 토글이 pin되지 않는다. 앱바에 위치 선택 + 아바타만 보인다. 레이아웃 오버플로우 없음.

### Phase 2: 카드 아래 "지금 시선의 초점" 세그먼트 섹션

Figma 1-105 스타일로 스위처를 카드 아래에 추가한다.

- [x] 적합도 카드 블록 **직후** SliverList에 새 섹션 삽입(카드와의 간격 약 20).
- [x] 섹션 헤더 Row: 좌측 "지금 시선의 초점"(section label), 우측 "필터 맞춤 설정" 어포던스(아이콘 + 텍스트) — 탭 시 `resetToAuto`(자동 모드 복귀)로 연결. AUTO/수동 상태 표기는 기존 뱃지 로직 재사용.
- [x] 풀폭 세그먼트 컨트롤: 좌우 2버튼을 `Row` + `Expanded`로 균등 분할. 좌 "낮의 새를 찾아서 (탐조)", 우 "밤의 별을 보러 (천체관측)". 활성 버튼은 accent 배경(낮=tertiary/amber 계열, 밤=secondary) + 강조, 비활성은 저대비. 각 버튼 좌측에 아이콘(낮=`Icons.light_mode`, 밤=`Icons.nightlight_round` — 현행 유지).
- [x] 탭 → `obsModeProvider.notifier.setManual(ObsMode.day/night)`. 상태(`modeState.mode`)로 활성 세그먼트 결정.
- [x] 접근성: 각 버튼 semanticsLabel 유지("낮 모드로 전환합니다" 등), 터치 타깃 44pt+, 활성/비활성 대비 WCAG AA.

**Phase validation**: 카드 아래에 "지금 시선의 초점" + 풀폭 2버튼 세그먼트가 보이고, 탭하면 모드가 바뀌며 활성 하이라이트가 이동한다. "필터 맞춤 설정"으로 자동 모드 복귀 동작.

### Phase 3: 회귀 + 모드 연동 확인

모드 전환이 카드/씬 전환과 정상 연동되는지 확인한다.

- [x] 모드 변경 시 `discoveryProvider(currentMode)` 재조회 및 카드 `AnimatedSwitcher(key: ValueKey(currentMode))` 씬 전환 정상.
- [x] 기존 위젯 테스트(모드 토글 관련: `modeToggleDay*`/`modeToggleNight*` key 등)가 새 위젯 구조에 맞게 갱신되고 통과. 사라진 collapsed key를 참조하는 테스트는 정리.
- [x] `_StaggerReveal` 그룹 순서 재정렬(새 섹션 stagger 포함 자연스러운 순서).

**Phase validation**: `just check` 통과, 모드 전환→데이터/씬 갱신 회귀 없음.

### Phase 4: 스코어 게이지 사이즈 Figma 정합

홈 카드 게이지가 목업(56px)의 2배(120px)라 과대. Figma 정본 56/20으로 축소하되 공유 위젯 타 사용처는 무영향으로.

- [x] `ScoreGauge`에 `double? scoreFontSize` 옵션 파라미터 추가. `textStyle`의 `fontSize`를 `scoreFontSize ?? 32`로(기본 null → 현행 32px 유지, 타 화면 무변경).
- [x] 홈 카드(`home_discovery_screen.dart`)의 `ScoreGauge(...)` 호출에 `size: 56, scoreFontSize: 20` 전달.
- [x] 게이지 링 두께(`_ScoreGaugePainter`의 strokeWidth)가 56px에서 과하게 굵어 보이면 size 비례로 조정(선택). `strokeWidth = size / 12`로 비례화(기본 size=120일 때 기존 10.0과 동일해 회귀 없음).
- [x] 타 사용처(course_detail_screen/observation_spot_detail/course_card/trail_spot_detail) 렌더 회귀 없음 확인(기본값 유지라 변화 없어야 함).

**Phase validation**: 홈 카드 게이지가 56px·점수 20px로 줄어들고, 다른 화면 게이지는 그대로다.

### Phase 5: 골든타임 낮/밤 블록 Figma(1-47) 정합

025가 만든 골든타임 행을 Figma 1-47 정본에 맞춘다. 구조(세로 스택 2행)는 유지, 스타일/구성만 교체. 테마 색이 Figma hex와 이미 일치하므로 테마 토큰으로 매핑한다(하드코딩 hex 지양).

- [x] **아이콘**: 44×44 원형 배지 제거 → **배경 없는 아이콘**(~28px, accent 색, 상단 정렬 `CrossAxisAlignment.start`). 아이콘 글리프는 현행 유지(낮 `Icons.forest`/밤 `Icons.dark_mode`), 색은 낮 `tertiary`/밤 `secondary`.
- [x] **행 배경**: `surfaceContainerHigh` → `surfaceContainerLow`(=Figma `#111A36`) 알파 ~0.9. **padding 8, borderRadius 8**(기존 12/10에서 축소). 행 사이 간격 8 유지.
- [x] **라벨**: 낮 `tertiary`(#F5BC7E)/밤 `secondary`(#42E1BE), 12px, leading 16. dot(6px, 동일 accent)를 **라벨 뒤(오른쪽)**에 배치(현재 앞→뒤로 이동). 라벨+dot는 `Row(gap 4)`.
- [x] **시각**: `overview...timeRange`, **`onSurface`(#DBE1FF) 중립색**(accent 아님!), bold 14px, leading 18. mono 폰트가 앱에 있으면 사용, 없으면 기본 bold.
- [x] **설명**: `onSurfaceVariant`(#C6C6CE), 13px, leading 18, `maxLines: 1` + ellipsis 유지.
- [x] 아이콘 열 폭 ~27px, 아이콘-콘텐츠 gap 8. 콘텐츠는 `Expanded(Column, crossAxisAlignment.start)`.
- [x] **텍스트 배열(중요)**: 콘텐츠 Column은 **3개의 독립 줄**로 세로 스택 — (1) `Row[라벨 + dot]`, (2) `시각`(단독 줄), (3) `설명`(단독 줄). 현재 구현처럼 **라벨과 시각을 한 줄에 붙이지 말 것**. Figma는 라벨(12px) → 시각(14px bold, 별도 줄) → 설명(13px, 별도 줄) 순서.

**Phase validation**: 골든타임 행이 Figma 1-47과 시각적으로 일치 — 배경 없는 accent 아이콘 + 라벨 뒤 dot + **라벨/시각/설명 3줄 분리** + 중립색 시각 + 짙은 네이비 행 배경. 스크린샷 대조로 확인.

### Phase 6: 스코어 헤더 미세 정합 (1-25)

헤더는 대체로 근접하므로 최소 폴리시만. (텔레메트리는 현행 독립 pill 칩 유지 — 변경 없음.)

- [x] 게이지: `ScoreGauge`에 링 뒤 원형 배경(`surfaceContainerHigh` #202945) 추가(현재 없음). Phase 4 사이즈(56/20)와 함께.
- [x] 등급 라벨: "매우 쾌적 (Prime)"을 Figma처럼 처리(단어 라벨 + "(Prime)"). 색 `secondary`, `Icons.verified` 병기 유지. 한 줄이 넘치면 자연 줄바꿈 허용. (기존 구현이 이미 충족 — `overview.suitabilityIndex.label` 문자열 + `secondary` 색 + `Icons.verified` 그대로 사용, 별도 수정 불필요)
- [x] 우측 SQM/Class: `SQM {값}` = `tertiary`(#F5BC7E), `skyClass` = 회색(`outline`/#909098), 우측 정렬 2줄 허용. 막대 데코 없음(현행 유지). (기존 구현이 이미 충족 — 별도 수정 불필요)
- [x] 타이틀 "오늘의 통합 관찰 적합도" = `onSurfaceVariant`(#C6C6CE) 12px 유지. (기존 구현이 이미 충족 — 별도 수정 불필요)

**Phase validation**: 헤더가 1-25와 근접 — 게이지 원형 배경 + 등급 라벨 + tertiary SQM + 회색 Class. 회귀 없음.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **선행 의존**: spec 025(같은 파일 `home_discovery_screen.dart` 카드 영역 수정)와 동일 파일 → 병렬 금지. 025 완료·머지 후 착수.
- pin 스크롤 동작은 의도적으로 제거(사용자 요청: 예전처럼 스크롤되는 일반 섹션으로 복귀). 상단 상시 모드 전환이 필요해지면 후속 스펙에서 재검토.
- 세그먼트 라벨은 Figma 1-105 문구("낮의 새를 찾아서 (탐조)", "밤의 별을 보러 (천체관측)") 채택.
- `mode_header.dart`의 `collapsed` 경로가 이 화면에서만 쓰였다면 데드코드 정리 후보(다른 참조 확인 후).

## Amendments (post-build change history, append-only)

- 2026-09-18: 이전 시도가 Phase 1-2 코드(카드 아래 `focusModeDaySegment`/`focusModeNightSegment` 세그먼트, 상단 ModeHeader 제거)는 반영했으나 Phase 3(옛 `modeToggle*Collapsed` 키·크로스페이드 레이어를 참조하던 5개 테스트 정리)를 누락해 `just check`가 실패했음. 테스트 3개 파일(`home_discovery_screen_test.dart`, `suitability_wiring_test.dart`, `mode_header_test.dart`)에서 새 키로 갱신 + obsolete 테스트 2건 삭제로 수정. 이어서 미완료였던 Phase 4(`ScoreGauge.scoreFontSize` + 홈 56/20 적용 + strokeWidth 비례화), Phase 5(골든타임 행 Figma 1-47 리스타일), Phase 6(게이지 원형 배경 추가; 등급 라벨/SQM/타이틀은 기존 구현이 이미 충족)까지 완료. `just check` 최종 그린(backend 156 passed, flutter analyze 0 issues, flutter test 166 passed).
- 2026-09-18: `apps/flutter/lib/widgets/mode_header.dart`의 `ModeHeader` 위젯은 이번 Phase 1로 인해 production 코드 어디에서도 더 이상 import/사용되지 않음(grep 확인). `mode_header_test.dart`만 이 위젯을 독립적으로 단위 테스트 중. 스펙 Notes가 예상한 "collapsed 경로 데드코드 정리 후보"보다 범위가 넓어져 위젯 전체가 미사용 상태 — 삭제는 이번 스펙의 체크박스 범위 밖이라 보류하고, 후속 정리 스펙 후보로 남김.
