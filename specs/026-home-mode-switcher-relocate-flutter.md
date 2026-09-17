# 홈 낮/밤 모드 스위처 하단 이동 + 풀폭 세그먼트화 (flutter)

> Lightweight plan-f3 spec. 상단 앱바에 pin/접힘으로 올라가 있던 낮/밤 모드 스위처를 적합도 카드 아래 일반 섹션으로 되돌리고, Figma 1-105의 "지금 시선의 초점" 풀폭 세그먼트 스타일로 교체한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/010-mode-header-skeleton-flutter.md, specs/025-home-suitability-card-redesign-flutter.md, Figma node 1-105 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium

## Purpose

낮/밤 모드 스위처를 상단 pin 헤더에서 적합도 카드 아래 일반 섹션으로 되돌려, 시선 흐름(요약 카드 → 모드 선택)을 Figma 정본과 일치시킨다.

## Problem

현재 스위처는 SliverAppBar 안에서 스크롤 시 상단에 pin/접힘되는 컴팩트 토글이라, Figma 1-105가 의도한 "카드 아래의 지금 시선의 초점 풀폭 세그먼트 선택" 배치·스타일과 어긋난다.

## Solution

`ModeHeader`(확장형 + 접힘 pin 레이어)를 SliverAppBar에서 제거하고, 적합도 카드 바로 아래 SliverList에 "지금 시선의 초점" 섹션(풀폭 세그먼트 2버튼 + "필터 맞춤 설정" 리셋 어포던스)을 추가한다. 모드 상태·전환 로직(`obsModeProvider`, setManual/resetToAuto)은 그대로 재사용한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - SliverAppBar에서 `ModeHeader` 2곳 제거(확장형 + 접힘 pin `IgnorePointer/Opacity` 레이어), 카드 아래에 새 스위처 섹션 삽입. 앱바 collapse/opacity 계산이 mode header 전용이었다면 정리.
- `apps/flutter/lib/widgets/mode_header.dart` - 참조. 풀폭 세그먼트를 새 위젯으로 만들되, 기존 `_ToggleSegment` 재사용/확장 가능. `collapsed` 경로가 더 이상 안 쓰이면 정리 판단(단, 다른 화면에서 참조하면 유지).

### New Files

- `apps/flutter/lib/widgets/focus_mode_switcher.dart` (선택) - "지금 시선의 초점" 라벨 + 풀폭 세그먼트 2버튼 + 리셋 어포던스를 담는 섹션 위젯. 같은 파일 내 private 위젯으로 둬도 무방.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 상단 스위처 제거

SliverAppBar에서 모드 스위처를 걷어내고 앱바를 정리한다.

- [ ] 확장형 `ModeHeader`(flexibleSpace 내부) 제거. 앱바에는 위치 선택 Row(explore + locationLabel + arrow)와 아바타만 남긴다.
- [ ] 접힘 pin 레이어(`Positioned` + `IgnorePointer` + `Opacity`, key `modeHeaderCollapsedLayerOpacity`) 제거.
- [ ] mode header 접힘 표시 전용으로만 쓰이던 `collapseFraction`/opacity 계산이 있으면 정리(다른 요소가 쓰면 유지). 앱바 높이·pinned 설정을 남은 콘텐츠에 맞게 조정.

**Phase validation**: 스크롤해도 상단에 낮/밤 토글이 pin되지 않는다. 앱바에 위치 선택 + 아바타만 보인다. 레이아웃 오버플로우 없음.

### Phase 2: 카드 아래 "지금 시선의 초점" 세그먼트 섹션

Figma 1-105 스타일로 스위처를 카드 아래에 추가한다.

- [ ] 적합도 카드 블록 **직후** SliverList에 새 섹션 삽입(카드와의 간격 약 20).
- [ ] 섹션 헤더 Row: 좌측 "지금 시선의 초점"(section label), 우측 "필터 맞춤 설정" 어포던스(아이콘 + 텍스트) — 탭 시 `resetToAuto`(자동 모드 복귀)로 연결. AUTO/수동 상태 표기는 기존 뱃지 로직 재사용.
- [ ] 풀폭 세그먼트 컨트롤: 좌우 2버튼을 `Row` + `Expanded`로 균등 분할. 좌 "낮의 새를 찾아서 (탐조)", 우 "밤의 별을 보러 (천체관측)". 활성 버튼은 accent 배경(낮=tertiary/amber 계열, 밤=secondary) + 강조, 비활성은 저대비. 각 버튼 좌측에 아이콘(낮=`Icons.light_mode`, 밤=`Icons.nightlight_round` — 현행 유지).
- [ ] 탭 → `obsModeProvider.notifier.setManual(ObsMode.day/night)`. 상태(`modeState.mode`)로 활성 세그먼트 결정.
- [ ] 접근성: 각 버튼 semanticsLabel 유지("낮 모드로 전환합니다" 등), 터치 타깃 44pt+, 활성/비활성 대비 WCAG AA.

**Phase validation**: 카드 아래에 "지금 시선의 초점" + 풀폭 2버튼 세그먼트가 보이고, 탭하면 모드가 바뀌며 활성 하이라이트가 이동한다. "필터 맞춤 설정"으로 자동 모드 복귀 동작.

### Phase 3: 회귀 + 모드 연동 확인

모드 전환이 카드/씬 전환과 정상 연동되는지 확인한다.

- [ ] 모드 변경 시 `discoveryProvider(currentMode)` 재조회 및 카드 `AnimatedSwitcher(key: ValueKey(currentMode))` 씬 전환 정상.
- [ ] 기존 위젯 테스트(모드 토글 관련: `modeToggleDay*`/`modeToggleNight*` key 등)가 새 위젯 구조에 맞게 갱신되고 통과. 사라진 collapsed key를 참조하는 테스트는 정리.
- [ ] `_StaggerReveal` 그룹 순서 재정렬(새 섹션 stagger 포함 자연스러운 순서).

**Phase validation**: `just check` 통과, 모드 전환→데이터/씬 갱신 회귀 없음.

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

- (없음)
