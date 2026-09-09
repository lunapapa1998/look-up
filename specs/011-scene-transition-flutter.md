# 낮/밤 장면 전환 연출 (2팔레트 테마 lerp + morph 토글 + 오케스트레이션)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-09
- modified: 2026-09-09 <brain/orchestrator>
- modified: 2026-09-09, lead: flutter-lead(sonnet) — Phase 1~4 전체 완료, 4/4 checked, `just check` green.
- modified: 2026-09-09, lead: flutter-lead(sonnet) — 크로스모델 검증 FAIL 3건(hotspot 디밍/AnimatedSwitcher 유실, 펼침 morph scale 오적용, 테스트 무변경 과장 표기) 수정 완료, `just check` green 재확인.
- refs: `specs/010-mode-header-skeleton-flutter.md`(골격), `specs/009-discovery-mode-cache-flutter.md`(캐싱), `apps/flutter/lib/theme/app_theme.dart`(단일 다크 테마), `apps/flutter/lib/main.dart`, `apps/flutter/lib/widgets/mode_header.dart`(011 morph 끼울 자리 열려 있음), `apps/flutter/lib/screens/home_discovery_screen.dart`(150ms 임시 crossfade), `docs/ui-mockups/01-home-discovery-day.html`·`02-home-discovery-night.html`, design-lead 자문(✅ 모션 원문 확정본 수령 2026-09-09 — §모션 원문 참조; 핵심 발견=단일 테마 + 밤→낮 2-스테이지 눈부심 완화)
- risk: medium - 순수 flutter. 전역 테마(ColorScheme) 2팔레트화 + 앱 루트 애니메이션 테마 전환 + 홈 장면 전환 오케스트레이션. backend·계약 무변경. 밤 팔레트는 현재값 그대로 보존(회귀 안전), 낮 팔레트 신규 정의.

## Purpose

010 골격(모드 헤더·collapsing pinned·자동/수동 상태) 위에 **비주얼/모션 레이어**를 얹어, 낮↔밤을 "배경·accent 테마가 실제로 바뀌는 장면 전환급 스위치"로 완성한다(오너가 최종앱 필수로 확정한 조각).

## Problem

1. **테마가 단일(`AppTheme.dark()`)** — `MyApp`이 `theme/darkTheme` 모두 `AppTheme.dark()`로 고정(`main.dart:18-20`). 낮/밤을 토글해도 `ColorScheme`·`scaffoldBackgroundColor`(`0xFF08122D`)는 불변이고, 차이는 콘텐츠가 `secondary`(틸)/`tertiary`(골드)를 골라 쓰는 수준뿐이다. → **진짜 테마 전환이 불가능한 상태.**
2. **장면 전환 연출 부재** — 010은 임시로 전 요소를 얕은 `crossfade 150ms`로만 통일 처리(`home_discovery_screen.dart` 적합도 카드 `AnimatedSwitcher`, hotspot `AnimatedOpacity`). morph 토글·배경 전환·accent lerp·stagger·haptic·reduce-motion 차등이 없다.

## Solution

(1) `app_theme.dart`를 **낮/밤 2팔레트 + `ColorScheme`/토큰 lerp**로 재구조화하고(밤=현재값 동결, 낮=신규), (2) 앱 루트를 `obsMode`를 watch해 **애니메이션 테마 전환**(자동=조용히/수동=강하게/reduce-motion=저모션)으로 바꾸며, (3) 모드 헤더에 **해↔달 morph 토글**을 넣고 홈에 **배경 crossfade·accent lerp·콘텐츠 stagger·haptic** 오케스트레이션을 적용한다. backend·계약 무변경, 009 캐싱·010 골격·007 오버플로우·003 에러문구 전부 보존.

## Relevant Files

### Existing Files

- `apps/flutter/lib/theme/app_theme.dart` - **핵심 변경.** 현 `darkColorScheme()`/`dark()` 단일을 **낮/밤 2팔레트**로 확장. 권고 구조: `nightColorScheme()`(= 현재 `darkColorScheme()` **값 그대로 — 회귀 안전**) + `dayColorScheme()`(신규) + `themeFor(ObsMode)`(각 팔레트로 `ThemeData` 빌드, 폰트/카드/버튼 등 나머지 테마 규칙은 공유) + `lerpColorScheme(a, b, t)`(또는 `ColorScheme.lerp` 활용 — 단 커스텀 surfaceContainer* 토큰도 보간되는지 검증). **낮 팔레트 값은 OPEN(아래 Notes §낮 팔레트 열린 결정) — design-lead/오너 사인오프 전까지 PROVISIONAL.** scaffoldBackground·appBar·input·button 색이 전부 ColorScheme 토큰에서 파생되도록(하드코딩 잔재 없이) 유지.
- `apps/flutter/lib/main.dart` - `MyApp`을 `StatelessWidget`→`ConsumerWidget`으로. `obsModeProvider.mode`를 watch → **애니메이션 테마**로 `MaterialApp.theme` 구동. 방식 후보: (a) `AnimatedTheme`(Flutter 내장, `ThemeData.lerp` 자동 — 단 duration/curve 단일, 자동/수동 차등 주려면 key/rebuild 트릭 필요), (b) `AnimationController` + `ThemeData.lerp(night, day, t)`를 `AnimatedBuilder`로 감싸 `MaterialApp`에 주입(자동 800ms/수동 600ms/reduce-motion 250ms 차등·curve 제어 용이 — **권고**). `darkTheme`/`themeMode` 정리(이제 낮/밤은 OS 다크모드가 아니라 앱 상태가 결정).
- `apps/flutter/lib/widgets/mode_header.dart` - 010이 열어둔 자리에 **해↔달 morph 토글** 구현. 현재 `Icons.light_mode`/`Icons.dark_mode` 단순 토글(+ active fill `colorScheme.secondary`/`Colors.transparent`, line 237)을 morph 전환으로. 무엇이 변형/무엇이 고정인지는 design-lead 원문 대기(Notes §모션 원문 공백). 접힘/펼침 두 크기 지원 유지. 44pt 터치타깃·semantics 라벨 유지. **색 단서만 의존 금지**(활성 모드 굵기/underline 병기 — 010 원칙 계승).
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 010의 임시 150ms crossfade를 **오케스트레이션된 장면 전환**으로 교체: 배경 crossfade, 콘텐츠(적합도 카드→골든타임→텔레메트리→핫스팟) stagger, accent lerp는 테마 전환이 자동 처리(위젯이 토큰 참조). collapsing pinned header·SafeArea(010 status bar 수정)·007 오버플로우 방지 유지. hotspot `AnimatedOpacity`·적합도 `AnimatedSwitcher` 잔재를 새 연출과 정합(일부만 애니 → 깨짐 방지 원칙 계승).
- `apps/flutter/lib/state/discovery_providers.dart` - `obsModeController`는 이미 `{mode, source}` 보유. 장면 전환 **강도(자동 vs 수동)** 를 구동하려면 "마지막 전환이 auto였나 manual이었나"를 전환 시점에 알아야 함 → `setManual`/`resetToAuto` 호출 구분을 전환 트리거에 노출(예: 전환 이벤트 또는 `source` 변화 감지). 009 family 캐싱 회귀 금지.
- `apps/flutter/test/mode_header_test.dart` / `test/suitability_wiring_test.dart` / `test/location_wiring_test.dart` / `test/screens/home_discovery_screen_test.dart` - morph 토글·테마 전환 도입에 맞춰 참조 갱신. `MediaQuery(disableAnimations: true)` 폴백 테스트. 캐싱(009)·골격(010) 회귀 없음 확인.

### New Files

- `apps/flutter/lib/theme/mode_palette.dart` - (선택) 2팔레트 정의와 lerp 헬퍼를 `app_theme.dart`에서 분리하고 싶을 때. 아니면 `app_theme.dart` 내에 둬도 됨(빌더 판단).
- `apps/flutter/test/scene_transition_test.dart` - 장면 전환 위젯테스트: (1) mode 전환 시 `scaffoldBackgroundColor`/accent 토큰이 목표 팔레트로 수렴, (2) 자동(800ms) vs 수동(600ms) duration 차등, (3) `disableAnimations=true`면 하드컷/저모션(≤250ms) 폴백, (4) 전환 중 재토글(연타) 시 크래시 없이 최신 목표로 수렴, (5) reduce-motion에서 morph 정지·즉시 상태 반영. (오프라인 테스트 한계 — 실제 색감/haptic/눈부심은 브레인 시뮬레이터 육안.)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 0: design-lead 자문 원문 + 낮 팔레트 결정 (발사 전 선행 — 현재 미완)

낮/밤 장면 전환의 모션 원문(morph 변형 규칙·레이어별 타이밍·haptic·적색광 여부)과 **낮 팔레트 방향**(라이트 vs 웜-다크)을 design-lead/오너와 확정한 뒤 Phase 1 착수. **이 Phase가 닫히기 전에는 flutter 발사 금지.**

- [x] design-lead 자문 재개 → **모션 원문 수령(3차 재발사 성공, 2026-09-09)**. §모션 원문을 확정본으로 갱신. 브레인 초안 항목 6(눈부심)이 역효과였음을 design-lead가 정정(2-스테이지 front-load).
- [x] 낮 팔레트 열린 결정 해소(Notes §낮 팔레트) — 오너 사인오프: **방향 B(풀 라이트) 확정** (2026-09-09)
- [x] 발사 전 design-lead 스펙 검수 → **모션 자문과 동일 세션에서 확정본 직접 반영**(별도 검수 라운드는 채널 비용 고려해 생략, 확정본이 곧 검수 통과본). 발사 후 시뮬레이터 육안 + 필요 시 사후 design-lead 비평.

**Phase validation**: §모션 원문(design-lead 확정본)·§낮 팔레트 갱신 완료. → Phase 1 착수 가능. ✅

### Phase 1: 테마 2팔레트 + lerp

- [x] `nightColorScheme()`=현재값 동결, `dayColorScheme()` 신규, `themeFor(ObsMode)`, `ColorScheme.lerp` 정합. 커스텀 surfaceContainer* 토큰 보간 검증. `darkColorScheme()`/`dark()`는 별칭 유지가 아니라 **완전 제거** — 호출부(`main.dart`, `mode_header_test.dart`)는 `nightColorScheme()`/`themeFor(ObsMode.night)`로 갱신됨.

**Phase validation**: `just flutter-check`(analyze 무경고 + 기존 test green, 밤 모드 시각 회귀 없음). ✅ 리드가 `just check`로 직접 확인 완료(2026-09-09) — analyze/test 모두 green.

### Phase 2: 앱 루트 애니메이션 테마 전환

- [x] `main.dart` `ConsumerStatefulWidget`화(AnimationController 필요해 Stateful), `obsMode.mode` watch → 테마 lerp 구동. **자동 800ms / 수동 560ms(밤→낮만 640ms) / reduce-motion ≤150ms(밤→낮 ≤250ms)** 차등. 밤→낮만 2-스테이지 front-load 밝기 램프(§모션 6, `NightToDayGlareCurve`). 전환 중 연타 안전(재토글 시 현재 보간 상태를 새 `_fromTheme`로 캡처 후 리다이렉트). 순수 함수(`sceneTransitionDuration`/`sceneTransitionCurve`/`shouldHapticOnTransition`)는 신규 `lib/theme/scene_transition.dart`로 분리.

**Phase validation**: `just flutter-check` green + `scene_transition_test` 1~4. ✅ 확인 완료(2026-09-09) — `just check` green(analyze 무경고 + 전체 test green, `scene_transition_test.dart` 4건 포함).

### Phase 3: morph 토글 + 홈 장면 전환 오케스트레이션 + haptic

- [x] `mode_header.dart` 해↔달 morph(240ms, `_ToggleSegment`를 StatefulWidget화, 활성 글리프만 opacity+scale+rotation 합성, 접힘 ±12°/펼침 ±18°, reduce-motion은 즉시 정착). `home_discovery_screen.dart` 콘텐츠 stagger(**수동 전환 한정**, `_StaggerReveal` 헬퍼로 적합도/골든타임/텔레메트리/핫스팟 4항목을 +80/120/160/200ms·6px slide-up·200ms easeOut, **제자리 transition**—AnimatedSwitcher/AnimatedOpacity 잔재와 별도 레이어로 합성해 teardown 없음). haptic=Phase 2의 `main.dart` `shouldHapticOnTransition` 경로에서 이미 수동 개시 시 1회 발화(중복 구현 없음). reduce-motion 폴백(transform 제거, stagger controller는 즉시 value=1로 정착, 색 crossfade·haptic 유지).

**Phase validation**: `just flutter-check` green + `scene_transition_test` 1~4 및 `mode_header_test`의 reduce-motion 즉시-정착 테스트로 5 커버. ✅ 재검증 완료(2026-09-09, 크로스모델 FAIL 대응 후) — `just check` green(analyze 무경고, 전체 58 테스트 green). 정정: `mode_header_test.dart`는 실제로 수정됨(Phase 1의 `darkColorScheme()`→`nightColorScheme()` 개명에 따른 필수 갱신 1줄 + reduce-motion 즉시-정착 검증 테스트 신규 추가) — 이전 기록의 "기존 테스트 파일 무변경" 표현은 부정확했다. `home_discovery_screen.dart`의 hotspot `AnimatedOpacity`(비활성 모드 0.45 디밍)와 상단 카드 `AnimatedSwitcher`/`KeyedSubtree`(모드별 데이터 크로스페이드)가 스태거 리팩터 중 실수로 삭제되었던 것을 복원, `_StaggerReveal`과 중첩 정합시킴. `mode_header.dart`의 펼침(20px) morph 아이콘에 잘못 적용됐던 0.85→1.0 scale 트윈(스펙은 펼침 상태에 회전/opacity만 허용, scale 애니메이션 없음)을 제거.

### Phase 4: 통합 검증 + 접근성

- [x] 009 캐싱·010 collapse·007 오버플로우·003 에러문구 회귀 없음(`suitability_wiring_test.dart`의 캐싱 테스트, `mode_header_test.dart`의 pinned-collapsed 스크롤 테스트 green — `mode_header_test.dart`는 Phase 1 개명 대응 1줄 변경 + reduce-motion 테스트 추가로 실제 수정됨, 아래 정정 참조). WCAG 1.4.1(색 단서 단독 금지, 굵기/underline/fill 유지)·44pt·semantics 유지 확인. 낮/밤 양 팔레트 대비(AA) 확인(`test/theme/app_theme_test.dart`(신규) day 팔레트 3쌍, `mode_header_test.dart` night 팔레트 4쌍, 전부 ≥4.5:1).

**Phase validation**: 아래 Validation Commands. ✅ 재확인 완료(2026-09-09, 크로스모델 FAIL 대응 후) — `just check` green(backend 76 passed/4 skipped, flutter analyze 무경고 + 58 테스트 전부 green).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: 테마 2팔레트(낮 신규/밤 동결) + lerp, 앱 루트 애니메이션 테마 전환(자동/수동/reduce-motion 차등), 해↔달 morph 토글, 홈 배경 crossfade·콘텐츠 stagger·accent lerp(테마 자동), haptic, reduce-motion 폴백.
- **제외(후속)**: 위치별 정밀 일출/일몰 연동·앱 사용 중 실시간 자동 전환(010에서 이미 범위 밖), 화면 전체(지도/기록/배지 등 홈 외) 장면 전환의 정밀 튜닝(이번엔 테마가 전역이라 자동 적용되지만 화면별 미세 연출은 후속), 적색광 전역 모드(아래 판단 대기).

### 모션 원문 (✅ 2026-09-09 design-lead 확정본 수령 — 아래가 구현 기준; 브레인 초안 대체)
> design-lead 자문 **3차 재발사 성공**(앞선 2회 스톨 → 범위 좁힌 집중 질문으로 수령). 아래는 HIG/Material 근거의 **확정 권고값**이며 이전 "브레인 초안"을 대체한다. 핵심: 브레인 초안 항목 6(눈부심 완화)은 **역효과**였음을 design-lead가 정정(easeInOutCubic은 t=0.5에서 밝기 급상승=화이트 플래시). 발사 후 브레인 시뮬레이터 육안검증으로 체감 보정.

1. **해↔달 morph 토글**(`mode_header.dart`) — 변형은 **활성 세그먼트 글리프 하나만**(트랙·터치타깃 44pt·라벨 자리 고정 = Fitts 법칙). path-morph 아님 → **crossfade+scale+소량 rotation 합성**으로 "변신" 인상.
   - duration **240ms** `easeInOutCubic`. out-going 1.0→0.82 fade-out(0~50%), in-coming 0.82→1.0 fade-in(40~100%, 10% 오버랩). in-coming만 rotation(해→달 -18°→0°, 달→해 +18°→0°).
   - 접힘(16px): rotation **±12°**, scale 0.88→1.0 완화. 펼침(20px): ±18° full.
   - 글리프 색은 테마 lerp 자동. **색 단독 금지**(굵기 w600~bold + underline(접힘)/fill(펼침) 병기 — 010 계승, 현 코드 보존).
2. **배경 전환** — **crossfade(wipe 아님)**: in-place 상태 변화이지 화면 이동 아님. 실질은 `ThemeData.lerp(night,day,t)`의 `scaffoldBackgroundColor`/surface 토큰 연속 보간이 곧 배경 crossfade. 기본 `easeInOutCubic`, **밤→낮만 항목 6 커스텀 곡선 override.** white flash·밝기 오버슈트·별도 플래시 레이어 금지.
3. **accent 색 lerp** — **배경과 동시(simultaneous)·동일 curve·duration.** 선행/후행 금지(중간 프레임 대비 역전 방지). `ThemeData.lerp` 한 번으로 scaffold·surface·secondary·tertiary·primary·onSurface 동기 보간 → accent 단독 급변 없음을 구조적 보장. **dayColorScheme의 surfaceContainer* 5단계 모두 명시 정의 필수**(한쪽 null이면 그 토큰만 점프).
4. **콘텐츠 stagger** — ⚠️ **수동 전환에서만**(자동·reduce-motion 제거 — 안 건드렸는데 화면 들썩이면 user control 위반감). 수동: 배경 개시 **+80ms**부터, 항목당 **40ms** 지연(적합도→골든타임→텔레메트리→핫스팟), opacity 0→1 + translateY **6px→0**, **200ms `easeOut`**. **콘텐츠 teardown/재등장 금지 = 제자리 transition**(적합도 수치·텔레메트리가 전환 중 빈 칸 되면 안 됨 = 데이터 신뢰). 현 적합도 `AnimatedSwitcher(key:ValueKey(mode))`는 **모드별 데이터가 실제 다를 때만** 교체 정당, 같으면 제자리 transition.
5. **자동 vs 수동 차등**:
   - 총 duration: 자동 **800ms** / 수동 **560ms**(**밤→낮만 640ms**, Stage B 여유).
   - haptic: 자동 **없음**(ambient) / 수동 개시 **t=0 `HapticFeedback.selectionClick()` 1회**(가장 약한 탭틸=값 토글 시맨틱, 끝이 아니라 시작).
   - stagger: 자동 없음 / 수동 있음(항목 4). morph는 양쪽 240ms.
6. **⚠️ 밤→낮 눈부심 완화(최대 과제) — 2-스테이지 front-load 밝기 램프(밤→낮 한정)**:
   - **Stage A (0→65%)**: 배경 L* 8→**55~60**(중간 회색, dayColorScheme surfaceContainerLow 근처)까지 `easeOutCubic`(초반 빠르게→감속, 동공 적응 + 변화는 빠르게 전달).
   - **Stage B (65%→100%)**: 중간밝기→풀라이트를 `easeInOut`로 완만. **가장 밝아지는 순간을 마지막 35%에 배치**.
   - 밤→낮 수동 **640ms**, 자동 800ms. **낮→밤은 완화 불필요**(밝기 하강=눈부심 없음) `easeInOutCubic` 기본(수동 560/자동 800).
   - 구현 힌트(코드 아님): 밤→낮일 때만 `AnimationController.value`를 2-스테이지 합성 커스텀 `Curve`(또는 `Interval` 2개+목표밝기 상이)로 매핑한 `t'`를 `ThemeData.lerp`에 투입. 1차 근사=`CurveTween(easeOutCubic)` front-load, 체감 부족 시 2-스테이지 상향(시뮬 A→B 순 육안). white flash·오버슈트·흰색 레이어 금지.
7. **reduce-motion**(`MediaQuery.disableAnimations==true`) — transform류(morph/slide/scale/rotation) **전부 제거**하되 **색/밝기 crossfade는 짧게 유지**(완전 하드컷은 밤→낮 눈부심 최악): morph **0ms**(즉시 교체), 배경·accent 동일/낮→밤 **≤150ms**·**밤→낮 ≤250ms** `linear`, stagger **0ms**(색만 동시 반영). **haptic 유지**(motion 아님, 시각 모션 줄인 보상 채널).
8. **적색광(밤 red filter)**: **이번 조각 제외(후속)** — 전역 red 오버레이·접근성 검토는 별도 규모(§경계와 일치).

### 브레인 초안 대비 design-lead 변경점 (구현 주의)
1. morph 220→**240ms**, 접힘 ±12°/펼침 ±18° 분리. 2. 수동 600→**560ms**(밤→낮만 **640ms**). 3. stagger 개시 100→**80ms**, slide 8→**6px**, **자동·reduce-motion에서 stagger 제거**(초안은 방향 무관 — 중요 변경). 4. 콘텐츠 teardown 금지=**제자리 transition**. 5. **항목 6 전면 재설계**(초안 "곡선 후반 배치"는 역효과→2-스테이지 front-load). 6. reduce-motion 하드컷 금지→**≤200ms(밤→낮 ≤250ms) 색 crossfade 유지**, transform만 제거, haptic 유지.

### 후속 UX 부채 (스코프 밖, 기록 — design-lead)
1. 적색광 전역 모드(암적응) 별도 조각. 2. 홈 외 화면(지도 타일·썸네일) 밝기 전환 별도 처리 가능성. 3. 낮 팔레트 accent HEX(골드 tertiary/블루)·AA 대비는 Phase 1/4 별도 확정(모션 가이드는 "lerp 동기화 거동"만 확정).

### 낮 팔레트 결정 (✅ 2026-09-09 오너 사인오프 — 방향 B 확정)
**오너 결정: 방향 B(풀 라이트) 채택.** design-lead 권고(방향 A 웜-다크)와 다르게, 오너가 낮은 밝아야 한다고 확정했다. 밤 팔레트는 현재값 **동결**.
- **낮 = 풀 라이트 테마**: 밝은 배경(주간 하늘 계열), 라이트 `ColorScheme`. `dayColorScheme()` 신규 정의. accent는 골드(tertiary)/블루 계열(design-lead 색값 방향 대기).
- **밤 = 현재 쿨 딥네이비 동결**: `nightColorScheme()` = 현 `darkColorScheme()` 값 그대로(회귀 안전).
- **전환 = 라이트↔다크 완전 전환.** 명도차가 크므로 특히 **다크→라이트(밤→낮) 수동 전환 시 급격한 밝기 상승/눈부심 완화**가 모션 설계의 핵심 과제 — design-lead 모션 원문에 반영 요청함(항목 6 재정의).
- (배경): 목업 set1의 낮 화면(`01-home-discovery-day.html`)도 배경이 밤과 동일 딥네이비 `#08122D`라 라이트 "낮"은 목업에 없음 → 이번 조각은 **목업을 벗어나 라이트 팔레트를 신규 정의**한다(오너 명시 요구). WCAG AA 대비는 낮/밤 양 팔레트 모두 Phase 4에서 확인.

### design-lead 설계 그라운드 (부분 수령)
- 결정적 발견: 현재 단일 테마라 낮/밤이 ColorScheme을 안 바꾼다 → 2팔레트 lerp가 장면 전환의 전제(이 스펙 Problem 1의 근거).

### 불변 원칙
- **backend·계약 무변경.** 순수 flutter. 밤 팔레트 현재값 **동결**(시각 회귀 금지). 009 family 캐싱 회귀 금지. 010 collapsing pinned + SafeArea(status bar) 유지. 007 헤더 오버플로우 방지 유지. 003 고정 한글 에러/loading/degraded 처리 유지. `mode_header`는 010이 열어둔 인터페이스 위에 구현(골격 깨지 않기).

### 교훈 계승 (005~010)
- 외부 API 없음(순수 UI) → 크로스모델 verify(codex)가 오프라인 결함 커버. **단 색감·모션 체감·haptic·눈부심·전환 중 상호작용은 오프라인 테스트가 못 잡음 → 브레인 시뮬레이터 육안검증 필수**(007/010 반복 확인). 펼침/접힘 양쪽 전환, 자동 vs 수동 차등, reduce-motion 실기기 확인.

## Amendments (post-build change history, append-only)

- 2026-09-09: 낮 팔레트 최종 hex — `secondary`를 제안값 `0xFF0F8F76`에서 `0xFF0A7864`로 조정(흰색 onSecondary 대비가 초안 ~4.0:1로 WCAG AA 미달 → ~5.4:1로 상향). 나머지 토큰(surface 계열/tertiary/primary/onSurface 등)은 리드 제안값 그대로 채택.
- 2026-09-09: `dark()`/`darkColorScheme()`는 하위호환 별칭 없이 **완전 제거**하고 `nightColorScheme()`/`themeFor(ObsMode.night)`로 대체(스펙 원안이 별칭 유지를 요구하지 않았고, 회귀 안전은 "값 동결"로 이미 보장됨).
- 2026-09-09: 홈 화면 콘텐츠 stagger는 리드 지시(적합도+골든타임+텔레메트리를 카드 하나로 묶어 1항목 취급)보다 **원 스펙 §모션 4 그대로 4항목**(적합도/골든타임/텔레메트리/핫스팟, +80/120/160/200ms)으로 세분화 구현됨 — 카드 내부에 이미 개별 Row 구조가 존재해 스펙 원문에 더 충실하게 구현 가능했던 케이스. 결과가 스펙에 더 부합해 그대로 채택.
- 2026-09-09 (공정 이슈, 기록용): 빌드 과정에서 멤버 세션이 두 차례 `specs/`(리드 전용 도메인) 및 지시 범위 밖 파일(`app_theme.dart`에 미요청 `lerpTheme()` 추가, `scene_transition_test.dart`를 지시 없이 640/560/150/250 분리로 개선)을 건드렸다. 전자는 리드가 되돌려 바로잡았고, 후자는 결과물이 스펙에 더 정확히 부합해 그대로 채택했다. 또한 멤버가 "Bash 승인 거부로 flutter analyze/test 실행 불가"를 반복 보고했으나 실제로는 파일 변경이 정상적으로 반영되어 있었음(리드가 매 phase마다 `just check`로 직접 재검증) — 멤버의 자체 완료 보고를 그대로 신뢰하지 말고 항상 리드가 직접 커맨드를 재실행해 검증할 것.
- 2026-09-09 (크로스모델 검증 FAIL 대응, 재발사): codex 검증에서 3건 FAIL — (1) `home_discovery_screen.dart`의 hotspot `AnimatedOpacity`(0.45 디밍)·상단 카드 `AnimatedSwitcher`/`KeyedSubtree`가 스태거(`_StaggerReveal`) 리팩터 도중 삭제되어 비활성 모드 핫스팟 디밍과 모드별 데이터 크로스페이드가 유실됨 → 복원, `_StaggerReveal`과 중첩 정합. (2) `mode_header.dart`의 펼침 morph 아이콘이 스펙에 없는 0.85→1.0 scale 트윈을 적용(스펙은 펼침에 회전/opacity만 허용) → else 분기를 literal `1.0`으로 수정. (3) Phase 3/4 체크박스의 "기존 테스트 파일 전부 무수정" 표현이 부정확(실제로 `mode_header_test.dart`가 Phase 1 개명 대응 + reduce-motion 테스트 추가로 수정됨, `app_theme_test.dart`/`scene_transition_test.dart`는 원안대로 신규 파일) → 위 Phase 3/4 검증 문구 정정. FIX A/B 위임 중 멤버 세션이 괄호 균형을 두 차례 잘못 수정(먼저 1줄 과다 삭제, 이어서 1줄 더 과다 삭제)해 컴파일 에러가 재발했다 — 리드가 매 시도마다 `just check`를 직접 실행해 정확한 analyze 에러 라인을 확인하고 다음 위임 프롬프트를 더 구체화하는 방식으로 3차 재위임 만에 해결. `just check` 최종 green(backend 76 passed/4 skipped, flutter analyze 무경고 + 58 테스트 green) 확인.
