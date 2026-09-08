# GPS 사용자 위치 연동 (홈 화면 실 위치 기반 적합도)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-08
- modified: 2026-09-08 <brain/orchestrator>
- refs: `specs/006-suitability-consumer-flutter.md`, `apps/backend/.team/member.md` §8 (계약 정본)
- risk: medium - 3-layer pipeline. 네이티브 플러그인(geolocator/geocoding) 추가 + 위치 권한 + 역지오코딩. flutter 레인 내로 갇힘, 백엔드 무변경.

## Purpose

홈 화면의 적합도 데이터를 지금의 고정 좌표(강화 갯벌 상수) 대신 사용자의 실제 GPS 위치 기준으로 조회하고, 상단 지역명 라벨을 역지오코딩한 실제 행정지명으로 표시한다.

## Problem

006에서 `discoveryProvider`가 `config.dart`의 고정 상수(`defaultObservationLat/Lng`)를 쿼리에 넣어, 어디서 앱을 켜도 항상 강화 갯벌 기준 데이터만 보여준다. 상단 "강화·서해안" 라벨도 목업에서 온 하드코딩 텍스트라 실제 위치와 무관하다.

## Solution

위치 획득을 `LocationService` 추상 인터페이스로 감싸(001/002/006의 추상+Http/Fake 패턴 일관) `GeolocatorLocationService`(geolocator로 좌표, geocoding으로 지명)와 `FakeLocationService`(테스트)로 분리하고, `locationProvider`(AsyncNotifier)를 도입해 `discoveryProvider`가 실 좌표를 watch하도록 배선한다. 위치 권한 거부·비활성·획득 실패 시에는 기존 고정 상수(강화)로 폴백해 화면이 항상 데이터를 렌더하며, 상단 라벨은 역지오코딩 지명(실패 시 폴백 문구)으로 갱신한다.

## Relevant Files

### Existing Files

- `apps/flutter/pubspec.yaml` - `geolocator`(위치)·`geocoding`(역지오코딩) dependency 추가. 버전은 빌더가 pub.dev 최신 안정 버전으로 명시(예: `geolocator: ^13.x`, `geocoding: ^3.x` — 실제 해석 가능한 캐럿 범위).
- `apps/flutter/ios/Runner/Info.plist` - `NSLocationWhenInUseUsageDescription` 키 추가(한글 설명 문구, 예: "관측 적합도를 현재 위치 기준으로 계산하기 위해 위치를 사용합니다"). 위치 권한 없이도 앱은 폴백으로 동작.
- `apps/flutter/lib/state/discovery_providers.dart` - `locationServiceProvider`(기본 `GeolocatorLocationService`) + `locationProvider`(`AsyncNotifierProvider<LocationNotifier, ObservationLocation>`, 새로고침 메서드 제공) 도입. `DiscoveryNotifier.build()`가 고정 상수 대신 `ref.watch(locationProvider.future)`로 얻은 좌표를 `fetchSuitability`에 사용(위치 갱신 시 적합도 재조회). `obsModeProvider`/`suitabilityApiProvider`/`hotspotsProvider` 시그니처 무변경.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 상단 하드코딩 `const Text('강화·서해안')`(line 63 부근)을 `ref.watch(locationProvider)`의 지명으로 교체(loading=플레이스홀더 텍스트, error/폴백=폴백 문구). raw 예외 비노출(003 패턴). line 95 부제 카피("강화 · 영월 실시간 기상망")는 범위 밖 — 무변경.
- `apps/flutter/lib/config.dart` - 폴백 좌표(`defaultObservationLat/Lng`)는 위치 폴백 상수로 그대로 재사용. 필요하면 폴백 지명 상수(예: `fallbackPlaceName = '강화·서해안'`) 추가.

### New Files

- `apps/flutter/lib/services/location_service.dart` - `ObservationLocation` 모델(`lat`/`lng`/`placeName`(String?)/`isFallback`(bool)) + `LocationService` 추상(`Future<ObservationLocation> currentLocation()`) + `GeolocatorLocationService`(권한 요청→좌표→역지오코딩; 권한 거부/위치 꺼짐/타임아웃/역지오코딩 실패는 모두 방어적으로 폴백 `ObservationLocation`(고정 상수, `isFallback:true`, placeName null) 반환하며 절대 raise 안 함) + `FakeLocationService`(생성자로 반환할 `ObservationLocation` 주입, 네트워크·platform channel 0).
- `apps/flutter/test/location_wiring_test.dart` - `ProviderScope(overrides:[locationServiceProvider.overrideWithValue(FakeLocationService(...)), suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi(...))])`로 홈 화면 위젯테스트. 커버: (1) 권한 허용+지명 있음 → 라벨에 실제 지명 렌더 + 그 좌표로 적합도 조회, (2) 권한 거부/폴백(`isFallback:true`, placeName null) → 폴백 라벨 문구 렌더 + 폴백 좌표로 조회, (3) 위치 loading 상태 표시. `GeolocatorLocationService` 자체(실 플러그인)는 위젯테스트 대상 아님(브레인 수동 검증).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 패키지 + LocationService 추상/구현/Fake

위치 획득 레이어를 먼저 확정한다(권한·역지오코딩·폴백 규칙 포함).

- [x] `pubspec.yaml`: `geolocator`·`geocoding` dependency 추가(해석 가능한 캐럿 버전).
- [x] `ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription` 한글 문구 추가.
- [x] `location_service.dart` 신규: `ObservationLocation` 모델 + `LocationService` 추상 + `GeolocatorLocationService`(모든 실패 경로를 폴백으로 흡수, raise 금지) + `FakeLocationService`.

**Phase validation**: `just flutter-check`(analyze 무경고 + 기존 test 통과). 새 dependency로 pub get이 성공하는지 확인(네트워크 필요 — Notes 참조).

### Phase 2: provider 배선 + 홈 화면 라벨 동적화

위치 provider를 도입하고 적합도 조회·상단 라벨을 실 위치에 물린다.

- [x] `discovery_providers.dart`: `locationServiceProvider` + `locationProvider`(AsyncNotifier, 새로고침 메서드) 도입. `DiscoveryNotifier.build()`가 `ref.watch(locationProvider.future)` 좌표로 `fetchSuitability` 호출(위치 갱신 시 재조회).
- [x] `home_discovery_screen.dart`: 상단 지역명 라벨을 `locationProvider` 값으로 교체(loading 플레이스홀더 + 폴백 문구, raw 예외 비노출). 부제 카피는 무변경.

**Phase validation**: `just flutter-check` green.

### Phase 3: 위젯테스트 + 폴백/권한 케이스 못박기

- [x] `location_wiring_test.dart` 작성: 권한 허용+지명 / 권한 거부 폴백 / loading 3케이스(Relevant Files 참조).
- [x] `just flutter-check` 전체 green 확인.

**Phase validation**: 아래 Validation Commands.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just check
```

## Notes (agent scratchpad)

- **⚠️ 네이티브 플러그인 리스크(브레인 인지)**: `geolocator`/`geocoding`은 네이티브 플러그인이라 `flutter pub get`(pub.dev 다운로드) + iOS `pod install`이 필요하다. flutter-engineer 워커는 Bash 권한이 없어 pub get/pod install을 자체 실행 못 하고, lead의 `just flutter-check`(analyze+test)도 pub 다운로드에 네트워크가 필요하다. **검증이 FAIL로 떨어지면 스펙 결함이 아니라 이 인프라 제약일 가능성이 높다** — 005 패턴처럼 브레인이 `flutter pub get`/시뮬레이터 빌드를 직접 마무리한다. 코드 배선 자체(추상/Fake/provider/위젯테스트)는 네트워크 없이 검증 가능해야 하므로, 위젯테스트는 반드시 `FakeLocationService`로만 돌 것(실 플러그인 미호출).
- **폴백 규칙**: 권한 거부·`LocationServiceDisabled`·타임아웃·역지오코딩 실패 → `GeolocatorLocationService`가 `ObservationLocation(lat=defaultObservationLat, lng=defaultObservationLng, placeName=null, isFallback=true)` 반환. 절대 throw하지 않아 `locationProvider`는 항상 data 상태. 화면 라벨은 placeName null이면 폴백 문구(`config.fallbackPlaceName` 또는 "현재 위치").
- **역지오코딩 언어**: `geocoding`의 `placemarkFromCoordinates`는 OS 로케일을 따른다. 한글 지명은 시뮬레이터/기기 언어가 한국어일 때 나온다. placeName 조립은 `administrativeArea`+`locality`+`subLocality` 중 존재하는 것으로(빌더 재량, null 안전).
- **backend 무변경**: 순수 flutter 조각. `apps/backend/**` 수정 금지. 계약(§8)은 이미 lat/lng를 받으므로 backend 변경 불필요.
- **실 검증은 브레인 몫**: 빌드 PASS(Fake 위젯테스트 green) 후, 브레인이 `xcrun simctl location booted set <lat>,<lng>`로 임의 좌표 주입 → 시뮬레이터에서 (a)권한 다이얼로그, (b)주입 좌표로 점수·지명 변경, (c)권한 거부 시 폴백을 육안 확인한다. 006의 실배선 검증과 동일 철학.
- **범위 밖**: `hotspotsProvider`(mock 유지), 위치 수동 선택 UI(상단 라벨 탭→지역 검색), 백그라운드 위치·정확도 설정. 후속.

## Amendments (post-build change history, append-only)

- (없음)
- 2026-09-08: `geocoding: ^3.3.1`은 pub.dev에서 resolve 불가 — `^5.0.0`으로 정정. geocoding v5는 top-level `placemarkFromCoordinates(lat, lng)` 함수를 제거하고 `Geocoding().placemarkFromCoordinates(lat, lng)` 인스턴스 메서드로 대체(Placemark 필드는 동일) — `location_service.dart`를 이에 맞춰 1줄 수정.
- 2026-09-08: Phase 2 `locationProvider` 도입으로 기존 위젯테스트 3개(`suitability_wiring_test.dart`, `home_discovery_screen_test.dart`, `app_shell_test.dart`)가 실 `GeolocatorLocationService`(플랫폼 채널 미등록)로 인해 회귀 — 스펙에 명시되지 않았던 범위이나 Phase 2 validation(`just flutter-check` green)을 만족시키기 위해 세 파일 모두에 `locationServiceProvider.overrideWithValue(FakeLocationService(...))`를 추가(assertion 변경 없음).
- 2026-09-08: 크로스모델 검증(1차) FAIL 3건 수정: (1) `location_service.dart`의 `isLocationServiceEnabled`/`checkPermission`/`requestPermission` 호출부를 try/catch로 감싸 예외 시 `_fallback` 반환(절대 throw 안 함 보장), (2) 역지오코딩 실패 catch 블록이 실제 GPS 좌표(`isFallback:false`)를 반환하던 것을 고정 `_fallback`(`isFallback:true`) 반환으로 정정, (3) `FakeSuitabilityApi`에 `onFetchSuitability` 콜백 훅 추가 + `location_wiring_test.dart`의 권한 허용/폴백 두 케이스가 실제 `fetchSuitability`에 전달된 lat/lng를 캡처·검증하도록 보강(라벨 assertion 외 좌표 assertion 추가). `just check` 전체 green 재확인(backend 68 passed, flutter analyze 무경고 + 29 tests passed, 위치 관련 3케이스 포함).

## Metadata (append-only)

- modified: 2026-09-08, lead: claude sonnet (flutter-lead)
- modified: 2026-09-08, lead: claude sonnet (flutter-lead) — 크로스모델 검증 FAIL 재수정 후 PASS
