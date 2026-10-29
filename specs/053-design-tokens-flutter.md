# 디자인 토큰 기반 정비: 한글 폰트, 색 체계, 간격·모서리 (2단계)

> Lightweight plan-f3 spec. 화면을 바꾸기 전에 테마와 토큰을 먼저 바로잡는다. 기능 변경 없음.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, docs/ui-mockups/README.md, docs/ui-mockups-2-claude-design/
- risk: medium

## Purpose

한글 폰트를 앱에 포함하고, 색 체계와 간격·모서리 토큰을 정리해 이후 화면 작업이 같은 기준을 쓰게 한다.

## Problem

Space Grotesk, Inter, JetBrains Mono에는 한글 글리프가 없어 화면 텍스트 대부분이 시스템 폰트로 그려지고, 폰트를 실행 중에 내려받아 오프라인 APK에서는 원래 폰트도 나오지 않는다. `ColorScheme`이 15개 역할만 정의해 `errorContainer` 등이 Flutter 기본값(밤 모드 경고 배너가 밝은 핑크 #FFB4AB)으로 남는다. `AppRadius.pill=20`인데 실제 pill은 9999로 하드코딩되고, 낮 모드 `Colors.amber` 별점은 대비가 약 1.5:1이다.

## Solution

Pretendard(OFL)를 assets로 번들해 기본 폰트로 쓰고, 숫자 표시용으로만 Space Grotesk/JetBrains Mono를 남긴다(한글 fallback은 Pretendard). 두 `ColorScheme`의 M3 역할을 모두 명시하고, 앱 전용 색은 `ThemeExtension<LookUpColors>`로 추가한다. 간격·모서리·브레이크포인트·최대 폭 토큰을 정리한다.

## 불변 조건

- 화면 구조, 위젯 트리, 기능은 바꾸지 않는다. 바뀌는 것은 테마 값과 토큰 정의, 그리고 토큰 이름이 바뀐 곳의 참조뿐이다.
- 기존 색 정체성(밤 배경 #08122D, 민트 #42E1BE, 앰버 #F5BC7E / 낮 배경 #F4F8FF, 청록 #0A7864)은 유지한다.
- 테스트 기대값을 느슨하게 바꿔 통과시키지 않는다. 폰트 변경으로 레이아웃 테스트가 깨지면 레이아웃을 고친다.

## Relevant Files

### Existing Files

- `apps/flutter/pubspec.yaml` - `flutter.fonts`에 Pretendard(400/500/600/700) 등록. 폰트 파일은 브레인이 사전 준비로 `apps/flutter/assets/fonts/`에 넣어 둔다(Notes 참고).
- `apps/flutter/lib/theme/app_theme.dart` - 기본 `fontFamily: 'Pretendard'`. 표시용(display/headline 숫자)은 Space Grotesk + `fontFamilyFallback: ['Pretendard']`, 수치 텔레메트리 전용 스타일은 JetBrains Mono + 같은 fallback. 글자 크기 단계: scoreDisplay 44/48 w700, headline 24/32, title 18/26, body 15/24, bodySmall 13/20, label 12/16(최소 12). 한글 제목 letterSpacing −0.2. 두 `ColorScheme`에 primaryContainer, secondaryContainer, tertiaryContainer, errorContainer(밤 #93000A/onErrorContainer #FFDAD6, 낮 #FFDAD6/#410002), outlineVariant, surfaceTint, inverseSurface 등 모든 역할을 명시. 낮 모드 작은 글씨에 쓰이는 secondary는 대비 4.5:1 이상 여유가 있도록 조정(예: #08705D 이하). `LookUpColors` extension 등록.
- `apps/flutter/lib/theme/layout_tokens.dart` - `AppSpacing`은 이름 유지(xs4 sm8 md12 lg16 page20 xl24 xxl32) + `xxxl=48` 추가. `AppRadius`를 sm 8 · md 12 · lg 16 · xl 24 · pill 999로 정의하고, 기존 `AppRadius.pill`(20) 사용처를 모두 찾아 의도(카드 16인지 pill인지)에 맞게 옮긴다. `AppBreakpoints`(compact <600, medium 600–1023, expanded ≥1024)와 `AppLayout.maxContentWidth=720`, `maxGridWidth=1120` 추가.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - `Colors.amber`(별점)를 `LookUpColors.rating` 계열로 교체(이 한 곳만, 레이아웃 변경 없음).

### New Files

- `apps/flutter/lib/theme/lookup_colors.dart` - `ThemeExtension<LookUpColors>`: warning/onWarning/warningContainer, provenanceLive/provenanceApprox/provenanceSample/provenanceStale, rating/ratingEmpty(낮·밤 모두 비텍스트 3:1 이상), mapScrim, birdAccent/starAccent. 낮·밤 두 벌과 `lerp` 구현(장면 전환 애니메이션이 ThemeData.lerp를 쓰므로 필수).
- `apps/flutter/test/theme/app_theme_test.dart` - 두 모드에서 핵심 글자·배경 쌍의 명도 대비가 4.5:1 이상인지(onSurface/surface, onSurfaceVariant/surfaceContainer, onErrorContainer/errorContainer, secondary/surface), 별점 색이 3:1 이상인지, `LookUpColors`가 두 테마에 모두 등록되어 lerp가 null을 반환하지 않는지 검증.

## Phases

### Phase 1: 폰트

- [ ] pubspec에 Pretendard 등록, 테마 기본 폰트 교체, 숫자용 폰트에 fallback 지정
- [ ] 위젯 테스트에서 폰트 로딩이 문제를 일으키지 않는지 확인

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 색 체계

- [ ] 두 ColorScheme 전 역할 명시, `LookUpColors` 추가 및 lerp
- [ ] `Colors.amber` 교체, 낮 secondary 대비 조정
- [ ] `app_theme_test.dart` 작성 및 통과

**Phase validation**: `just flutter-check` 통과.

### Phase 3: 간격·모서리·레이아웃 토큰

- [ ] `AppRadius` 재정의와 기존 사용처 이전, 브레이크포인트·최대 폭 토큰 추가

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- Pretendard 정적 폰트(Regular/Medium/SemiBold/Bold, OTF 또는 TTF)는 브레인이 사전 준비 단계에서 공식 배포본(github.com/orioncactus/pretendard, SIL OFL 1.1)으로 `apps/flutter/assets/fonts/`에 넣고 라이선스 파일(`OFL.txt`)도 같이 둔다. 파일이 없으면 이 spec을 시작하지 않는다.
- google_fonts 의존성은 Space Grotesk/JetBrains Mono 때문에 유지한다.
- 대비 기준: 일반 텍스트 4.5:1, 큰 텍스트·비텍스트 3:1 (WCAG 2.1 AA).

## Amendments (post-build change history, append-only)

