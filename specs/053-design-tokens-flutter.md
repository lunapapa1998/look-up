# 디자인 토큰 기반 정비: Flim 흑백 테마, Pretendard, 간격·모서리 (2단계)

> Lightweight plan-f3 spec. 화면을 바꾸기 전에 테마와 토큰을 먼저 바로잡는다. 기능 변경 없음. 앱 디자인 기준은 `docs/design/flim.md`(해석·우선순위는 `docs/design/README.md`).

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, docs/ui-mockups/README.md, docs/ui-mockups-2-claude-design/
- risk: medium
- modified: 2026-10-29 brain — 디자인 기준을 Flim(앱) + 사용자 확정 흑백 색상으로 교체. 기존 "색 정체성 유지" 조건 삭제. 폰트 3종은 제거하지 않고 역할 정리
- refs: docs/design/README.md, docs/design/flim.md, docs/design/arte.md, specs/054-shared-components-flutter.md, specs/059-brand-homepage.md

## Purpose

한글 폰트를 앱에 포함하고, 사용자가 확정한 흑백 색상(낮 흰 바탕·검정 글자 / 밤 검정 바탕·흰 글자)과 Flim 레퍼런스의 모서리·간격·그림자 원칙을 토큰으로 정리해 이후 화면 작업이 같은 기준을 쓰게 한다.

## Problem

Space Grotesk, Inter, JetBrains Mono에는 한글 글리프가 없어 화면 텍스트 대부분이 시스템 대체 글꼴로 그려지고, 폰트를 실행 중에 내려받아 오프라인 APK에서는 원래 폰트도 나오지 않는다. `ColorScheme`이 15개 역할만 정의해 `errorContainer` 등이 Flutter 기본값(밤 모드 경고 배너가 밝은 핑크 #FFB4AB)으로 남는다. 현재 색(밤 남색 #08122D·민트 #42E1BE / 낮 #F4F8FF·청록 #0A7864)은 확정된 흑백 체계와 다르고, `AppRadius.pill=20`인데 실제 pill은 9999로 하드코딩되며, 낮 모드 `Colors.amber` 별점은 대비가 약 1.5:1이다.

## Solution

Pretendard(OFL, 이미 `assets/fonts/`에 있음)를 등록해 기본 폰트로 쓰고, 기존 Google Fonts 3종은 제거하지 않은 채 한글 fallback을 Pretendard로 지정하고 역할을 정리한다. 두 `ColorScheme`의 M3 역할을 흑백 기준으로 모두 명시하고, 상태·출처 보조색은 `ThemeExtension<LookUpColors>`로 제한해 추가한다. 모서리(4/8/16/원형), 간격, 브레이크포인트, 최대 폭, 그림자 없음 원칙을 토큰과 컴포넌트 테마 기본값으로 정리한다.

## 불변 조건

- 화면 구조, 위젯 트리, 기능은 바꾸지 않는다. 바뀌는 것은 테마 값과 토큰 정의, 그리고 토큰 이름이 바뀐 곳의 참조뿐이다(화면 배치는 055, 컴포넌트 생성은 054).
- **색상은 사용자 확정값을 따른다.** 낮: 바탕 `#FFFFFF`, 본문 `#141414`. 밤: 바탕 `#141414`, 본문 `#FFFFFF`. 주요(채움) 버튼은 각 모드에서 바탕과 반전되는 흑백(낮 `#141414` 채움·흰 글자, 밤 `#FFFFFF` 채움·`#141414` 글자).
- 밤 보조 글자는 흰색 약 70%를 기본 후보로 하되 실제 배경 대비를 검사해 조정한다(일반 글자 4.5:1 미만이면 올린다).
- 상태·출처 보조색(Flim Signal Green `#30a81d`, Forest `#21935b`, Ember `#ff8400`, Highlight Yellow `#fecc33` 계열)은 점·작은 테두리·아이콘에만 쓴다. 글자색·넓은 면 채움으로 쓰지 않는다. 비텍스트 3:1을 만족하지 못하는 모드에서는 진한/밝은 변형을 정의한다.
- 그림자(elevation) 없음. 깊이는 경계선 1px과 면 색 차이로 표현한다.
- Space Grotesk, Inter, JetBrains Mono는 **이 spec에서 제거하지 않는다**(사용자 결정). 역할을 정리하고 한글이 Pretendard로 그려지도록 fallback만 보장한다. 제거 여부는 사용처 정리 후 별도 결정.
- 052의 샘플 대체·`예시` 표시, 058의 기능, 인증·API·모델·백엔드는 바꾸지 않는다.
- 테스트 기대값을 느슨하게 바꿔 통과시키지 않는다. 폰트 변경으로 레이아웃 테스트가 깨지면 레이아웃을 고친다. 단, 기존 `test/theme/app_theme_test.dart`의 밤 색 "frozen baseline" 테스트는 색 기준 변경이 사용자 결정이므로 **새 기준값으로 의도적으로 갱신**하고 그 사실을 Amendments에 기록한다.

## Relevant Files

### Existing Files

- `apps/flutter/pubspec.yaml` - `flutter.fonts`에 Pretendard(400/500/600/700, `assets/fonts/`) 등록. 새 다운로드 없음.
- `apps/flutter/lib/theme/app_theme.dart`
  - 기본 `fontFamily: 'Pretendard'`. 기존 Google Fonts 역할은 유지하되 모든 스타일에 `fontFamilyFallback: ['Pretendard']`.
  - 폰트 역할 정리(현황은 `docs/design/README.md` 5절): display·headline(현재 Space Grotesk) → 한글 제목은 Pretendard 500~600·자간 −0.02em·줄간격 1.1 이상, 숫자 강조에는 Space Grotesk 유지 가능 / title·body(현재 Inter) → Pretendard / labelSmall·labelMedium(현재 JetBrains Mono, 한글 라벨 다수 포함) → 한글 라벨은 Pretendard, 영문·숫자 전용 라벨에만 mono 스타일(대문자·자간 0.06em)을 별도 스타일로 제공.
  - 글자 크기 단계(Flim 비율을 앱 크기로 조정): caption 12 / body-sm 13 / body 15~16 / subheading 20~21 / heading-sm 26~27 / heading 32 / display 40~48(앱 최대). 최소 12. 한글 줄간격 1.1~1.5.
  - 두 `ColorScheme`의 모든 역할 명시(흑백 기준): surface·surfaceContainer* 단계(낮 `#FFFFFF`·Flim Canvas `#f5f5f5`·Mist `#e9e9e9` 계열, 밤 `#141414`에서 밝아지는 단계), outline·outlineVariant(낮 Hairline `#d9d9d9` 계열), primary/onPrimary(반전 버튼), error/errorContainer(흑백 체계에 맞게 채도 낮춘 값, 대비 검사), inverseSurface 등.
  - 컴포넌트 테마 기본값: Filled/Outlined/Text 버튼 모서리 8, Card 모서리 16·그림자 0·경계선 1px, Chip 원형, NavigationBar·AppBar 그림자 0·surfaceTint 없음.
  - `LookUpColors` extension 등록.
- `apps/flutter/lib/theme/layout_tokens.dart` - `AppSpacing`은 기존 이름 유지(xs4 sm8 md12 lg16 page20 xl24 xxl32) + Flim 간격 `x28`, `x40`, `x52`, `x64`, `x80` 추가(이름은 구현 때 기존 규칙에 맞춤). `AppRadius`를 link 4 · button 8 · card 16 · pill(원형, 999) 으로 정의하고, 기존 `AppRadius.pill`(20) 사용처 2곳(`screens/packages_catalog_screen.dart:170`, `widgets/course_card.dart:213`)과 `BorderRadius.circular(9999)` 하드코딩 6곳의 의도를 확인해 옮긴다. `AppBreakpoints`(compact <600, medium 600–1023, expanded ≥1024)와 `AppLayout.maxContentWidth=720`, `maxGridWidth=1120` 추가.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - `Colors.amber`(별점)를 `LookUpColors.rating` 계열로 교체(이 한 곳만, 레이아웃 변경 없음).
- `apps/flutter/test/theme/app_theme_test.dart` - **이미 있는 파일(113줄)을 확장**한다. 밤 색 frozen baseline 테스트를 새 기준으로 갱신, 낮·밤 핵심 글자/바탕 쌍 4.5:1 이상, 보조 글자(밤 흰 70% 후보 포함) 4.5:1 이상, 보조색 점·별점 3:1 이상, `LookUpColors`가 두 테마에 등록되고 lerp가 null을 반환하지 않음, 낮↔밤 `ThemeData.lerp` 오류 없음.

### New Files

- `apps/flutter/lib/theme/lookup_colors.dart` - `ThemeExtension<LookUpColors>`: warning/onWarning/warningContainer, provenanceLive/provenanceApprox/provenanceSample/provenanceStale(점·테두리 전용), rating/ratingEmpty, hairline, mapScrim, birdAccent/starAccent. 낮·밤 두 벌과 `lerp` 구현(장면 전환 애니메이션이 ThemeData.lerp를 쓰므로 필수).

## Phases

### Phase 1: 폰트

- [ ] pubspec에 Pretendard 등록, 테마 기본 폰트를 Pretendard로, 기존 Google Fonts 스타일에 Pretendard fallback 지정
- [ ] 폰트 역할 정리(한글 제목·본문·라벨은 Pretendard, mono는 영문·숫자 전용 스타일로 분리) — 기존 폰트 제거 없음
- [ ] 위젯 테스트에서 폰트 로딩이 문제를 일으키지 않는지 확인, 웹 빌드 크기 기록

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 색 체계

- [ ] 두 ColorScheme을 흑백 기준으로 전 역할 명시, `LookUpColors` 추가 및 lerp
- [ ] 밤 보조 글자 대비 검사 후 확정, `Colors.amber` 교체
- [ ] `app_theme_test.dart` 확장(frozen baseline 의도적 갱신 포함) 및 통과

**Phase validation**: `just flutter-check` 통과 + 로컬 웹에서 낮·밤 전환 사용자 확인.

### Phase 3: 모서리·간격·레이아웃·그림자

- [ ] `AppRadius` 재정의(4/8/16/원형)와 기존 사용처 이전, 간격·브레이크포인트·최대 폭 토큰 추가
- [ ] 컴포넌트 테마 기본값(버튼 8, 카드 16, 그림자 0, 경계선 1px)

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- Pretendard 정적 폰트(Regular/Medium/SemiBold/Bold, OTF 또는 TTF)는 브레인이 사전 준비 단계에서 공식 배포본(github.com/orioncactus/pretendard, SIL OFL 1.1)으로 `apps/flutter/assets/fonts/`에 넣고 라이선스 파일(`OFL.txt`)도 같이 둔다. 파일이 없으면 이 spec을 시작하지 않는다.
- google_fonts 의존성은 Space Grotesk/JetBrains Mono 때문에 유지한다.
- 대비 기준: 일반 텍스트 4.5:1, 큰 텍스트·비텍스트 3:1 (WCAG 2.1 AA).
- (2026-10-29) Pretendard 4굵기는 커밋 afaa8ac로 이미 저장소에 있다(약 6.1MB). Phase 1에서 웹 첫 로딩 영향을 측정해 보고한다.
- (2026-10-29) 흰 바탕 기준 보조색 대비(근사): Forest `#21935b` 약 3.9:1, Signal Green `#30a81d` 약 3.1:1 → 점·아이콘 가능, 글자 불가. Ember `#ff8400` 약 2.4:1, Highlight Yellow는 그보다 낮음 → 낮 모드용 진한 변형 필요. `#141414` 바탕에서는 네 색 모두 3:1 이상.
- (2026-10-29) 밤 모드 `#141414` + 순백 글자는 별 관측 시 눈부심이 크다. 주요 글자는 사용자 확정대로 `#FFFFFF`, 보조 글자만 낮춘다.

## Amendments (post-build change history, append-only)

- 2026-10-29: 디자인 기준 변경(사용자 결정). 앱은 Flim 레퍼런스 + 사용자 확정 흑백 색상(낮 #FFFFFF/#141414, 밤 #141414/#FFFFFF, 반전 주요 버튼)을 따른다. 삭제한 조건: "기존 색 정체성(밤 #08122D·민트 #42E1BE·앰버 #F5BC7E / 낮 #F4F8FF·청록 #0A7864) 유지". 모서리 계획을 이전안(sm8·md12·lg16·xl24·pill999)에서 Flim 기준(link 4·button 8·card 16·pill 원형)으로 바꿈. 체크 항목 2개 추가(폰트 역할 정리, 컴포넌트 테마 기본값). Space Grotesk·Inter·JetBrains Mono는 제거하지 않고 역할 정리로 변경. 기존 `test/theme/app_theme_test.dart`가 이미 있어 "새 파일"에서 "확장"으로 변경. 기능 요구사항(Pretendard 번들, ColorScheme 전 역할, LookUpColors, 토큰, Colors.amber 교체, 테스트)은 유지.
