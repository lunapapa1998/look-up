# 위를 봐요(Look Up) — '수직적 여행' 브랜딩 디자인 패스 (기존 3화면 리스킨 + 한글화)

> plan-f3 경량 템플릿. 플랜은 살아있는 아티팩트 — 빌더가 작업하며 체크리스트와 Amendments를 직접 갱신한다.
> 독자 트라이펙타: 사람(나) / 팀 문서 / AI 에이전트 셋 다 읽는다.

## 메타데이터 (append-only — 줄을 지우지 말고 아래에 추가만)

- created: 2026-09-08
- modified: 2026-09-08 두뇌 세션 — 목업(정본 Figma) 기반 브랜딩 디자인 패스 스펙화. flutter-only, backend 의존 0.
- modified: 2026-09-08, lead: claude-sonnet-5 — Phase 1/2/3 전체 완료, 크로스모델 검증 FAIL 2건 재작업 및 `just check` green 확인.
- refs: [002-ecolog-flutter.md](002-ecolog-flutter.md)(리스킨 대상 3화면), [`../docs/ui-mockups/README.md`](../docs/ui-mockups/README.md)(디자인 토큰 정본 요약), Figma `VIF8Yc0dC2Qq86GOFZkJUA`(목업 정본)
- risk: medium

## Purpose

MVP 조각 1(디지털 생태 일기)의 기존 3화면을 목업의 '수직적 여행' 비주얼 언어(딥네이비 다크 테마 + 틸/골드 액센트 + 커스텀 타이포)로 리스킨하고, 영어 카피를 전부 한글화한다.

## Problem

현재 앱은 `ColorScheme.fromSeed(Colors.green)` 기본 Material 테마에 영어 카피("Observation Diary", "No observations yet", "Retry" 등)를 쓰고 있어, 딥네이비·틸·골드·Space Grotesk로 통일된 목업 정본과 완전히 따로 논다. 브랜딩·타이포·색이 정의된 곳이 없어 후속 화면(적합도 카드 등)도 기준 삼을 테마가 없다.

## Solution

`docs/ui-mockups/README.md`의 디자인 토큰을 정본으로 `lib/theme/`에 Material3 다크 ThemeData(색·타이포·컴포넌트 테마)를 구축하고, `main.dart`에 배선한다. 그 위에서 목록·기록폼·배지 3화면을 목업 비주얼로 리스킨하고 모든 사용자 향 카피를 한글로 바꾸며, 카피가 바뀐 위젯 테스트 기대값을 함께 갱신한다.

## 설계 제약 (후속 조각이 깨지지 않도록)

1. **비주얼·카피 전용, 동작 불변**: 이 패스는 테마·스타일·카피만 바꾼다. API 클라이언트(`api/ecolog_api.dart`)·모델(`models/observation.dart`)·Riverpod 프로바이더의 **로직/시그니처/JSON 계약은 건드리지 않는다**. 배지 name/description은 이미 한국어 계약이므로 그대로 둔다(002 Amendment 참조).
2. **레인 락**: 멤버 쓰기는 `apps/flutter` 안으로 락. `justfile`·다른 앱·backend는 건드리지 않는다.
3. **디자인 토큰 정본**: 색·타이포·스페이싱·반경은 `docs/ui-mockups/README.md`의 "디자인 토큰 요약"을 그대로 옮긴다. 임의 색/폰트 금지. 아래 §디자인 토큰에 못 박은 값을 사용.
4. **한글 카피가 테스트의 새 진실**: 화면 카피를 한글화하면 그 문자열을 기대하는 위젯 테스트(`test/screens/*`)의 `find.text(...)` 기대값도 반드시 동일 한글로 갱신한다. 카피와 테스트가 어긋나면 `flutter analyze && flutter test`가 깨진다.
5. **범위 제한**: 신규 화면·하단 탭 네비게이션·라우팅 추가 금지(이번 조각 아님). 기존 3화면 + 진입점 테마만.
6. **오프라인 실패 회피**: 폰트는 `google_fonts` 패키지를 쓰되, 폰트 로드 실패 시 시스템 폰트로 우아하게 폴백하도록 두어(패키지 기본 동작) 테스트/CI가 네트워크에 의존하지 않게 한다.

## 디자인 토큰 (README 정본에서 못 박음)

**색 (Material 3 다크 ColorScheme 시드값)**
- background/surface `#08122d`, surfaceContainerLowest `#030c28`, surfaceContainerLow `#111a36`, surfaceContainer `#151e3a`, surfaceContainerHigh `#202945`, surfaceContainerHighest `#2b3450`
- secondary `#42e1be`(틸 — 밤/별/CTA), onSecondary `#00382d`
- tertiary `#f5bc7e`(골드 — 낮/새), onTertiary `#482900`
- primary `#bec5e5`, onSurface `#dbe1ff`, onSurfaceVariant `#c6c6ce`, outline `#909098`, error `#ffb4ab`

**의미 매핑 (종류 시각화)**: 새(bird) = 골드 `tertiary`(낮), 별(star) = 틸 `secondary`(밤). 현재 `_SpeciesIconPlaceholder`의 brown/indigo를 이 매핑으로 교체.

**타이포 (`google_fonts`)**: display/headline = Space Grotesk, body/label = Inter, 수치/텔레메트리 표기(날짜·카운트 등) = JetBrains Mono. Material3 TextTheme에 매핑.

**반경**: card/컨테이너 12(xl), 작은 요소 8(lg), 칩/알약 9999(full).

## Relevant Files

### 기존 파일 (수정 대상)

- `apps/flutter/pubspec.yaml` — `google_fonts` 의존성 추가
- `apps/flutter/lib/main.dart` — `ColorScheme.fromSeed(green)` → `AppTheme.dark()` 배선, `darkTheme`/`themeMode: dark` 설정, 앱 타이틀 유지("위를 봐요")
- `apps/flutter/lib/screens/diary_list_screen.dart` — AppBar/카드/빈 상태/에러 리트라이 리스킨 + 한글화("Observation Diary"·"No observations yet."·"Retry"·"Badges" 등), species 색 매핑 골드/틸로 교체
- `apps/flutter/lib/screens/observation_form_screen.dart` — 폼 라벨·버튼·토글 한글화 + 입력/버튼 테마 적용
- `apps/flutter/lib/screens/badges_screen.dart` — 그리드 카드 리스킨(획득/미획득 대비), 헤더 카피 한글화 (배지 name/description은 계약이므로 불변)
- `apps/flutter/test/screens/diary_list_screen_test.dart` — 한글화된 카피로 `find.text(...)` 기대값 갱신
- `apps/flutter/test/screens/observation_form_screen_test.dart` — 동일
- `apps/flutter/test/screens/badges_screen_test.dart` — 헤더 등 화면 카피만 바뀌면 갱신(배지 한국어 기대값은 유지)

### 새 파일

- `apps/flutter/lib/theme/app_theme.dart` — §디자인 토큰을 담은 `AppTheme.dark()` (ColorScheme + google_fonts TextTheme + CardTheme/AppBarTheme/InputDecorationTheme/FilledButtonTheme 등 컴포넌트 테마)

## Phases

> 상태 4종: `[ ]` 미착수 / `[~]` 진행중 / `[x]` 완료 / `[F]` 실패(막힘 — 사유를 Notes에 남기고 진행).
> 규칙: 한 페이즈의 모든 박스가 체크되고 페이즈 검증이 통과하기 전에는 다음 페이즈 금지.

### Phase 1: 디자인 토큰 → ThemeData 배선

목업 토큰을 코드 테마로 정본화하고 진입점에 붙인다.

- [x] `pubspec.yaml`에 `google_fonts` 추가
- [x] `lib/theme/app_theme.dart`: §디자인 토큰의 색을 담은 다크 `ColorScheme` + Space Grotesk/Inter/JetBrains Mono 매핑 `TextTheme` + Card/AppBar/Input/Button 컴포넌트 테마를 담은 `AppTheme.dark()`
- [x] `main.dart`: `AppTheme.dark()` 배선(`theme`/`darkTheme` + `themeMode: ThemeMode.dark`), 기존 green fromSeed 제거

**페이즈 검증**: `just check`(= flutter analyze 무경고 + 기존 flutter test 통과 — 이 페이즈는 카피 미변경이라 테스트 그대로 통과해야 함)

### Phase 2: 3화면 리스킨 + 한글화

테마 위에서 3화면을 목업 비주얼로 바꾸고 카피를 한글화한다.

- [x] `diary_list_screen`: AppBar·카드(surfaceContainer 배경, 12 반경)·빈 상태·에러 리트라이 리스킨, species 색 골드(새)/틸(별) 매핑, 카피 한글화
- [x] `observation_form_screen`: 종류 토글·종명·메모·사진·위치 라벨/버튼 한글화 + 입력/버튼 테마 적용
- [x] `badges_screen`: 그리드 카드 획득/미획득 대비 리스킨 + 화면 헤더 카피 한글화(배지 name/description 불변)
- [x] 카피가 바뀐 위젯 테스트(`test/screens/*`)의 `find.text(...)` 기대값을 새 한글 문자열로 갱신

**페이즈 검증**: `just check`(flutter analyze 무경고 + flutter test 전체 통과)

### Phase 3: 검증

- [x] `just check` 전체 green 최종 확인(backend pytest + flutter analyze/test)

**페이즈 검증**: `just check` 통과

## Validation Commands

> 전체 완료를 증명하는 커맨드. **justfile 레시피만 허용**.
> 리드 Bash 화이트리스트는 `just member-build`/`just check` 프리픽스만 허용하므로(002 Notes 참조) 검증은 `just check`(집계)로 한다.

```sh
just check
```

## Notes (에이전트 자유 구역)

- **[의존 없음]** 이 패스는 backend 계약을 소비하지 않는다. 순수 flutter 비주얼/카피 작업.
- **[선행 확인, 두뇌]** `just check` = `check-teams` + backend-check(pytest) + flutter-check(analyze+test). flutter SDK 런 내 가용은 002에서 확인됨.
- **[google_fonts 주의]** 위젯 테스트 환경에서 폰트 미해결 시 패키지가 시스템 폰트로 폴백 → 테스트 실패 유발 금지. `flutter test`는 폰트 없이도 통과해야 함.
- 후속 조각 예약: 적합도 점수 카드 화면(003 다음, 적합도 엔진 backend 계약 소비), 하단 탭 IA·홈/발견 셸, 지도/패키지 화면.

## Amendments (빌드 후 변경 이력, append-only)

- (없음 — 최초 작성)
- 2026-09-08 크로스모델 검증(FAIL) 재작업: (1) JetBrains Mono가 `TextTheme`에 매핑되지 않고 배지 카운트가 무스타일이던 문제 — `AppTheme.dark()`의 `TextTheme.labelSmall`/`labelMedium`을 `GoogleFonts.jetBrainsMonoTextTheme()`로 매핑하고 정적 헬퍼 `telemetryStyle()`은 삭제, diary 타임스탬프·배지 카운트 모두 `Theme.of(context).textTheme.labelSmall`을 사용하도록 수정. (2) `diary_list_screen.dart`/`badges_screen.dart`의 에러 상태가 raw 예외 객체(영문)를 그대로 노출하던 문제 — 고정 한글 문구("관찰 기록을 불러오지 못했어요.", "배지 정보를 불러오지 못했어요.")로 교체. 부수적으로 `flutter analyze`의 `unnecessary_underscores` 린트(`(_, __)` → `(_, _)`) 수정. `just check` green 확인 완료.
