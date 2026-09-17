# 홈 통합 관찰 적합도 카드 Bento HUD 리디자인 (flutter)

> Lightweight plan-f3 spec. 홈 최상단 히어로 카드를 Figma 목업(Bento Style HUD) 방향으로 재배치한다.
> 디자인 방향은 design-lead 자문(채택/보류/폐기 판정)을 반영했다. 목업을 맹신하지 않는다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/004-home-discovery-flutter.md, specs/006-suitability-consumer-flutter.md, Figma node 1-23 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium
- modified: 2026-09-18, lead: claude-sonnet-5

## Purpose

홈 화면 최상단 "오늘의 통합 관찰 적합도" 카드의 레이아웃·비주얼을 Figma Bento HUD 방향으로 재정비해 가독성과 브랜드 톤(데이터 신뢰)을 끌어올린다.

## Problem

골든타임이 가로 2분할이라 폭이 좁아 설명("만조 2시간 전 갯벌 유입 피크")이 여러 줄로 깨지고, 텔레메트리는 가로 스크롤 divider 리스트라 숨은 항목의 발견성이 나쁘며, 카드에 브랜드 무드가 약하다.

## Solution

골든타임을 세로 스택 2행으로, 텔레메트리를 독립 pill 칩 3개 고정 배치로 바꾸고, 카드 우상단에 은은한 ambient glow(밤 모드 dim)를 추가한다. 스코어 헤더·게이지·SQM 노출·아이콘은 현행을 유지한다. 백엔드 계약 변경 없음(flutter 전용).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/home_discovery_screen.dart` - 카드 컨테이너(약 296–301행), 스코어 행(342–427), 골든타임(429–518), 텔레메트리(520–586) 재작성
- `apps/flutter/lib/widgets/score_gauge.dart` - 변경 없음(숫자 이미 링 내부 배치). 참조만.
- `apps/flutter/lib/models/discovery.dart` - 변경 없음. `SuitabilityIndex/GoldenHour/TelemetryReading` 필드 참조.

### New Files

- 없음. (glow 데코·칩·골든타임 행은 private helper 위젯/메서드로 같은 파일 내에 추가 가능)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 카드 프레임 + ambient glow

카드 컨테이너를 glow를 담을 수 있는 구조로 바꾼다.

- [x] 기존 카드 `Container`(surfaceContainer, radius 12, padding 16)를 `ClipRRect(radius 12)` + `Stack` 구조로 감싸, 자식 콘텐츠는 그대로 두고 뒤에 glow 레이어를 깐다.
- [x] 우상단에 은은한 ambient glow 데코 1개 추가: `Positioned`로 우상단 바깥에 걸치는 원형(약 140pt), `RadialGradient`(colorScheme.secondary 계열 저알파 → 투명) + `IgnorePointer`. 카드 밖으로 넘치는 부분은 ClipRRect가 잘라낸다.
- [x] glow는 밤 모드에서 dim: `currentMode == ObsMode.night`이면 alpha를 크게 낮추거나(예: 기존의 약 30%) 렌더 생략. 암적응 방해를 피한다.
- [x] `AnimatedSwitcher`/`KeyedSubtree(key: ValueKey(currentMode))` 모드 전환 래핑은 유지.

**Phase validation**: 낮 모드에서 카드 우상단에 은은한 glow가 보이고, 밤 모드에선 약하거나 사라진다. 바(막대) 장식은 어디에도 없다.

### Phase 2: 골든타임 세로 스택 2행

가로 2분할(Row+Expanded)을 세로 스택 2행으로 교체한다.

- [x] `Row(children: List.generate(...Expanded...))`를 `Column`(각 골든타임 1행)으로 교체. 낮(day) 위, 밤(night) 아래 순서 보장(현재 정렬이 시간순이 아니면 mode 기준 day→night 정렬).
- [x] 각 행 레이아웃: 좌측 `[원형 배지 아이콘]`(약 44–48pt 라운드 컨테이너, 배경=accent 저알파, 아이콘=accent) + 우측 `Expanded(Column)`: (1행) 라벨 + 시각(timeRange, bold), (2행) 설명. 행은 surfaceContainerHigh 블록(radius 10, padding 12) 유지, 행 사이 간격 8.
- [x] 아이콘은 현행 유지: 낮=`Icons.forest`, 밤=`Icons.dark_mode`. 액센트 현행 유지: 낮=tertiary, 밤=secondary.
- [x] 설명 텍스트 `maxLines: 1` + `TextOverflow.ellipsis`로 카드 높이 예측 가능하게.
- [x] 라벨 앞 dot 인디케이터(6pt accent 원)는 유지 가능하나 배지 아이콘과 중복이면 생략 판단은 구현자 재량(과밀 회피 우선). (구현자가 dot 유지 선택)

**Phase validation**: 낮·밤 골든타임이 세로로 쌓이고, 각 행에서 설명이 1줄로 들어가며 ellipsis로 잘린다. 전폭을 사용한다.

### Phase 3: 텔레메트리 독립 칩

가로 스크롤 divider 리스트를 pill 칩 고정 배치로 교체한다.

- [x] `SingleChildScrollView(horizontal)` + divider 로직 제거.
- [x] 각 텔레메트리를 독립 pill 칩으로: 라운드 컨테이너(surfaceContainerHigh, radius 999 또는 12, padding H10/V6) 안에 `[아이콘] + Column(라벨 / 값 bold)`. 아이콘은 현행 `_iconForTelemetryKind` 유지.
- [x] 배치는 `Row`(3칩 균등, `Expanded` 또는 spacing 8) 기본. 항목이 4개 이상이면 `Wrap`(spacing/runSpacing 8, 2줄 접힘)으로 자연 폴백. 가로 스크롤은 만들지 않는다. (Row 대신 Wrap 단일 구현으로 3개/4개+ 모두 커버 — 스펙 의도 충족)
- [x] 터치 타깃/대비: 칩 높이 44pt 이상, 텍스트 대비 WCAG AA 유지.

**Phase validation**: 텔레메트리 3개가 스크롤 없이 한 줄에 보이고, 각 칩이 독립 배경을 가진다. 4개로 늘려도 2줄로 접힌다(가로 스크롤 없음).

### Phase 4: 유지 확인 + 회귀

현행으로 남겨야 할 것들이 그대로인지 확인한다.

- [x] 스코어 헤더: `ScoreGauge`(숫자 링 내부) + 우측 타이틀 "오늘의 통합 관찰 적합도" + 등급 라벨(label, `Icons.verified`) 현행 유지. SQM/Class는 우측에 **항상** 노출, 막대 데코 없이 숫자+단위+Class 텍스트만. (Phase 1~3 diff가 glow/골든타임/텔레메트리 블록만 건드려 미변경 확인)
- [x] `degraded` 배너(일부 데이터 미수신) 현행 유지. (미변경 확인)
- [x] loading/error 상태 위젯 현행 유지. (미변경 확인)
- [x] `_StaggerReveal` 4그룹 stagger(80/120/160…) 유지. 골든타임은 세로 스택 전환 후에도 startMs:120 그룹 하나로 묶어 유지(행별로 쪼개 깜빡임 늘리지 말 것).

**Phase validation**: `just check`(flutter analyze/test 포함) 통과, 스코어 헤더·SQM·degraded·모션이 회귀 없이 동작.

## Validation Commands

> 아래 블록의 각 줄이 순서대로 실행되어 모두 exit 0 이어야 한다.

```sh
just check
```

## Notes (agent scratchpad)

- 백엔드 계약 변경 없음. `DiscoveryOverview`에 텔레메트리 소스별 상태(live/approx/stub) 필드가 없어 칩별 상태 도트는 이번 범위 제외(overview `degraded` 배너로 대체). 향후 백엔드에서 소스 상태를 내려주면 후속 스펙에서 칩 도트 추가.
- 폐기 확정(넣지 말 것): SQM 옆·타이틀 옆 막대 그래픽 등 모든 가짜 바차트 데코. glow는 유지하되 밤 모드 dim.
- 게이지 라벨(Prime)은 목업(게이지 밑 분리)이 아니라 현행(타이틀 아래, 라벨-값 결합)을 유지 — design-lead 판정.
- 후속 UX 부채(이번 범위 아님): 게이지 링 색을 점수 구간에 매핑(현재 항상 secondary), 텔레메트리 소스 상태 토큰화.

## Amendments (post-build change history, append-only)

- 2026-09-18: 크로스모델 검증(codex) FAIL 수신 — Phase 1 `Stack` 자식 순서가 `[Container(콘텐츠), Positioned(glow)]`라 glow가 콘텐츠 위에 그려짐(later-child-on-top). flutter-engineer에게 재위임해 순서를 `[Positioned(glow), Container(콘텐츠)]`로 스왑(내부 내용 불변). `just check`(flutter analyze 0 issues, flutter test 168 passed) 재확인 완료.
- modified: 2026-09-18, lead: claude-sonnet-5
