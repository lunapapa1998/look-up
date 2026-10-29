# 이미지·브랜딩·웹 셸: 로고, 앱 아이콘, 앱 이름, web/index.html (5단계)

> Lightweight plan-f3 spec. 이미지 자산과 앱 표시 이름, 웹 첫 화면을 정리한다. 서명 설정은 건드리지 않는다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/055-screens-redesign-responsive-flutter.md, docs/ui-mockups/logo.svg, apps/flutter/tool/gen_icon_sources.dart
- risk: medium

## Purpose

로고와 앱 아이콘을 선명한 원본에서 다시 만들고, 앱 표시 이름과 웹 첫 화면(타이틀, 로딩 배경, 파비콘)을 정리한다.

## Problem

`assets/auth/logo.png`(384px)가 확대되어 계단 현상이 보이고 어두운 배경이 구워져 있어 낮 헤더에서 짙은 사각형으로 뜬다. 앱 아이콘에는 둥근 모서리와 회색 여백이 구워져 있어 런처에서 이중으로 둥글게 잘린다. 웹 셸은 기본 템플릿이라 로딩 중 흰 화면이 보이고 타이틀·파비콘이 기본값이다. 패키지 사진(512×279)은 넓은 화면에서 흐리다.

## Solution

`docs/ui-mockups/logo.svg`를 앱 자산으로 가져와 `flutter_svg`로 렌더링하고, 아이콘 원본을 꽉 찬 정사각형으로 다시 만들어 `flutter_launcher_icons`로 Android·웹 아이콘을 생성한다. 앱 표시 이름을 Android 매니페스트·웹 `index.html`/`manifest.json`·`MaterialApp.title`에 일관되게 적용한다. 패키지 사진은 교체 전까지 `cacheWidth` 지정과 "연출 이미지" 캡션을 붙인다.

## 불변 조건

- **Android 서명 설정(`android/key.properties`, `android/app/build.gradle.kts`의 `signingConfigs`)을 수정하지 않는다.**
- **`applicationId`(`com.feel.lookup`)와 패키지 경로를 바꾸지 않는다.** 바꾸는 것은 사용자에게 보이는 표시 이름(label/title)뿐이다.
- 이미지 파일명은 기존 참조(`stay_package.dart`, `package_extras.dart` 등)를 깨지 않게 유지하거나, 바꾸면 모든 참조를 함께 고친다.

## Relevant Files

### Existing Files

- `apps/flutter/pubspec.yaml` - `flutter_svg` 의존성 추가, assets에 `assets/brand/` 추가, `flutter_launcher_icons`에 `web: generate: true`, `background_color: "#08122D"`, `theme_color: "#08122D"` 추가, 원본 경로 갱신.
- `apps/flutter/tool/gen_icon_sources.dart` - 모서리·여백 없는 1024×1024 아이콘 원본과 adaptive foreground(가운데 66% 안전 영역)를 생성하도록 수정.
- `apps/flutter/lib/widgets/app_header_logo.dart`, `apps/flutter/lib/screens/login_screen.dart` - PNG 로고 대신 `SvgPicture.asset('assets/brand/logo.svg')`. 낮/밤에 맞는 색 처리.
- `apps/flutter/lib/main.dart` - `MaterialApp.title`을 앱 표시 이름으로.
- `apps/flutter/android/app/src/main/AndroidManifest.xml` - `android:label`만 앱 표시 이름으로.
- `apps/flutter/web/index.html`, `apps/flutter/web/manifest.json` - `<title>`, `description`, `theme-color`, `lang="ko"`, 로딩 중 배경 #08122D와 간단한 로고 표시(Flutter 첫 프레임 전 흰 화면 방지), manifest `name`/`short_name`/색.
- `apps/flutter/lib/widgets/packages/package_card.dart`, `apps/flutter/lib/widgets/packages/package_extras.dart` - `Image.asset`에 `cacheWidth` 지정, 사진 아래 작은 캡션 "연출 이미지".

### New Files

- `apps/flutter/assets/brand/logo.svg` - `docs/ui-mockups/logo.svg` 기반(투명 배경).

## Phases

### Phase 1: 로고

- [ ] `flutter_svg` 추가, SVG 로고 적용(헤더, 로그인)

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 앱 아이콘과 웹 셸

- [ ] 아이콘 원본 생성 스크립트 수정, launcher icons 설정(Android·웹)
- [ ] `web/index.html`, `manifest.json` 정리

**Phase validation**: `just flutter-icons` 후 `just flutter-check` 통과.

### Phase 3: 앱 표시 이름과 패키지 사진

- [ ] 표시 이름 적용(MaterialApp.title, AndroidManifest label, web title/manifest)
- [ ] 패키지 사진 cacheWidth와 "연출 이미지" 캡션

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-icons
just flutter-check
```

## Notes (agent scratchpad)

- **앱 표시 이름: "위를 봐요"** (사용자 확정, 2026-10-29). 현재 AndroidManifest `android:label`은 `"lookup"`이다.
- `just flutter-icons`는 브레인이 justfile에 추가하는 maintenance recipe다(`dart run tool/gen_icon_sources.dart && dart run flutter_launcher_icons`).
- 패키지 사진을 실제 사진(예: 한국관광공사 공공누리 1유형)으로 바꾸려면 사용자가 사진을 고르고 출처를 정해야 한다. 이 spec은 기존 사진 유지를 전제로 한다.

## Amendments (post-build change history, append-only)

