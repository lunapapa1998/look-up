# 낮/밤 토글 상단 이동 + mode별 캐싱 (위치 개선 + 로딩바·재호출 제거)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-08
- modified: 2026-09-08 <brain/orchestrator>
- refs: `specs/006-suitability-consumer-flutter.md`, `specs/007-gps-location-flutter.md`, `specs/004-home-discovery-flutter.md`, `docs/ui-mockups-2-claude-design/Look Up App.dc.html`(정본 목업), `apps/flutter/lib/state/discovery_providers.dart`
- risk: medium - flutter 상태관리 리팩터(단일 provider → family + keepAlive) + 홈 화면 토글 위치 이동. backend 무변경, 계약 무변경, 순수 클라이언트.

## Purpose

낮/밤 mode 토글을 목업대로 화면 최상단(헤더 아래·적합도 카드 위)으로 옮겨 컨트롤과 결과를 붙이고, 토글 시 매번 백엔드를 재호출하며 로딩바가 뜨던 것을 없애 각 mode를 한 번만 불러와 캐시·즉시 전환되게 한다.

## Problem

두 가지 결함이 얽혀 있다. (1) **토글 위치**: 정본 목업은 낮/밤 토글을 홈 최상단(헤더 아래, 적합도 카드 위)에 두는데, 004 구현이 이를 화면 하단(적합도 카드 아래, "지금 시선의 초점"/핫스팟 섹션 근처)에 배치해, 화면 전체 컨텍스트를 지배하는 컨트롤이 그 결과(적합도 카드)와 멀리 떨어져 스크롤해야 보인다. (2) **재로딩**: `DiscoveryNotifier`가 `obsModeProvider`를 `ref.watch`하는 단일 `AsyncNotifierProvider`라 토글마다 provider 전체가 rebuild→`loading`으로 돌아가 로딩바가 깜빡이고 `GET /api/suitability`를 불필요하게 재호출한다.

## Solution

(1) 홈 화면에서 낮/밤 토글 세그먼트를 목업 순서대로 **헤더 바로 아래·적합도 카드 위**로 이동한다(전역 컨텍스트 컨트롤을 상단에). (2) `discoveryProvider`를 `AsyncNotifierProvider.family`(인자 = `ObsMode`)로 바꿔 낮·밤을 독립 캐시 인스턴스로 분리하고, `build()`에서 `ref.keepAlive()`로 화면에서 벗어나도 캐시를 유지한다. mode는 더 이상 `watch`하지 않고 family 인자로 받으므로 토글은 이미 캐시된 인스턴스로 즉시 전환된다(재호출·로딩바 없음). 위치(`locationProvider.future`)는 계속 watch하여, 위치가 바뀌면 두 mode 캐시가 함께 자동 무효화·갱신된다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/state/discovery_providers.dart` - `DiscoveryNotifier`를 `FamilyAsyncNotifier<DiscoveryOverview, ObsMode>`로 전환. `build(ObsMode mode)`에서 `ref.keepAlive()` 호출 후, `obsModeProvider` watch를 **제거**(mode는 인자로 받음)하고 `suitabilityApiProvider`·`locationProvider.future`는 그대로 watch. `discoveryProvider = AsyncNotifierProvider.family<DiscoveryNotifier, DiscoveryOverview, ObsMode>(DiscoveryNotifier.new)`. `obsModeProvider`(현재 선택 mode)·`locationProvider`·`suitabilityApiProvider`·`hotspotsProvider`는 시그니처 무변경.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - **(위치)** 낮/밤 토글 세그먼트(현재 하단 "지금 시선의 초점"/핫스팟 근처, 라인 ~440-500)를 **헤더/인사말 블록 아래·적합도 카드(surfaceContainer, 라인 ~125) 위**로 이동. 토글 자체의 버튼 스타일·아이콘·색(day=tertiary, night=secondary)은 유지, 위치만 이동. "지금 시선의 초점" 섹션은 토글을 뺀 채(있다면 라벨/필터만) 그대로 두거나 핫스팟 헤더로 정리(빌더 재량, 단 토글은 상단으로). **(캐싱)** `ref.watch(discoveryProvider)` → `ref.watch(discoveryProvider(currentMode))`(라인 18). 재시도 버튼 `ref.invalidate(discoveryProvider)`(라인 407) → `ref.invalidate(discoveryProvider(currentMode))`. 토글 버튼(`obsModeProvider` 변경)은 이제 다른 family 인스턴스를 watch하게 되어 캐시 히트 시 즉시 data 렌더. `.when`의 loading/error/degraded 분기 구조는 유지. 이동 후에도 헤더 Row 오버플로우(007 수정분) 유지 확인.
- `apps/flutter/test/suitability_wiring_test.dart` - `discoveryProvider` 참조를 `discoveryProvider(ObsMode.day)` 등 family 형태로 갱신. **mode 토글 케이스는 "토글 시 재호출하지 않음"을 검증하도록 강화**: `FakeSuitabilityApi`의 `onFetchSuitability` 콜백으로 호출 횟수를 세어, 낮→밤→낮 토글 시 각 mode가 1회씩만 호출되고 재방문 시 추가 호출이 없음을 assert. loading은 각 mode 최초 진입 시에만 뜸을 확인.
- `apps/flutter/test/location_wiring_test.dart` - `discoveryProvider` 참조를 family 형태로 갱신(로직 변경 없이 인자 추가). 위치 변경/폴백 케이스가 여전히 통과하는지 확인.

### New Files

- (없음)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: provider family 전환

- [x] `discovery_providers.dart`: `DiscoveryNotifier`를 `FamilyAsyncNotifier<DiscoveryOverview, ObsMode>`로, `build(mode)`에 `ref.keepAlive()` + `obsModeProvider` watch 제거 + `locationProvider.future` watch 유지. `discoveryProvider`를 `.family`로 선언.

**Phase validation**: `just flutter-check`(analyze 무경고). 화면 참조가 아직 안 바뀌었으면 analyze가 잡음 — Phase 2와 함께 green 되도록.

### Phase 2: 홈 화면 토글 상단 이동 + 참조 갱신

- [x] `home_discovery_screen.dart`: 낮/밤 토글 세그먼트를 헤더/인사말 아래·적합도 카드 위로 이동(버튼 스타일 유지, 위치만). 하단 옛 위치의 토글 제거.
- [x] `discoveryProvider` → `discoveryProvider(currentMode)`(watch·invalidate 두 곳). `.when` 구조 유지, 헤더 오버플로우 방지(007) 유지.

**Phase validation**: `just flutter-check` green.

### Phase 3: 테스트 갱신 + 캐싱 행동 못박기

- [x] `suitability_wiring_test.dart`: family 참조 갱신 + "토글 시 mode별 1회만 호출(재방문 무호출)" 캐싱 검증 케이스.
- [x] `location_wiring_test.dart`: family 참조 갱신, 기존 케이스 통과 확인.
- [x] `just flutter-check` 전체 green.

**Phase validation**: 아래 Validation Commands.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **핵심 메커니즘**: `family`로 낮/밤이 별도 provider 인스턴스가 되고 `ref.keepAlive()`로 autoDispose를 막아 세션 내 캐시가 유지된다. `obsModeProvider`는 "지금 어느 인스턴스를 보여줄지" 선택만 하므로, 토글은 이미 살아있는 캐시 인스턴스로의 전환 → 재호출·로딩 없음.
- **위치 변경 시 갱신**: `build()`가 `ref.watch(locationProvider.future)`를 유지하므로, `locationProvider`가 갱신되면(위치 새로고침/변경) keepAlive여도 두 mode 인스턴스가 모두 rebuild되어 새 좌표로 재조회된다 — 캐시가 stale 좌표에 고착되지 않음.
- **신선도 한계(의도된 트레이드오프)**: 위치가 안 바뀌면 세션 동안 mode별 캐시가 갱신되지 않는다(조석/기상은 시간에 따라 변함). 사용자 요구("매번 불러올 필요 없다")에 따른 선택이며, 명시적 새로고침(당겨서 새로고침/새로고침 버튼)은 후속 조각(위치 UX 마감)에서 다룬다.
- **backend·계약 무변경**: `GET /api/suitability` 및 §8 계약은 그대로. 순수 flutter 상태관리 리팩터.
- **Riverpod 버전**: `flutter_riverpod: ^2.6.1`. `FamilyAsyncNotifier`/`AsyncNotifierProvider.family` 사용(코드 생성 없이 수기 클래스, 기존 `AsyncNotifier` 패턴과 동일 계열).

## Amendments (post-build change history, append-only)

- 2026-09-08: `suitability_wiring_test.dart`/`location_wiring_test.dart`는 애초에 `discoveryProvider`를 이름으로 참조하지 않고 위젯 트리를 통해서만 간접 구동하므로, family 전환 후에도 참조 갱신이 불필요했음(계획 대비 축소). 대신 `suitability_wiring_test.dart`에 캐싱 검증 케이스(낮→밤→낮→밤 토글, 총 fetch 2회, 재방문 시 스피너 없음)를 신규 추가.
- modified: 2026-09-08, lead: flutter-lead (claude)
