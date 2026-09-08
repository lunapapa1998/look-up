# 적합도 엔진 flutter consumer 배선 (홈 화면 실 API 연동)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-08
- modified: 2026-09-08 <brain/orchestrator>
- refs: `specs/005-suitability-engine-backend.md`, `apps/backend/.team/member.md` §8 (계약 정본), `specs/004-home-discovery-flutter.md`
- risk: medium - 3-layer pipeline. 신규 파일 3개 + 홈 화면 async 전환. flutter 레인 내로 갇힘, 백엔드 무변경(순수 consumer).
- modified: 2026-09-08, lead: sonnet
- modified: 2026-09-08, lead: sonnet (goldenHours RangeError fix, re-verify pass)

## Purpose

005에서 live로 완성된 `GET /api/suitability` 계약을 홈 화면에 실제로 물려, 지금 하드코딩된 적합도 지표·골든타임·텔레메트리를 백엔드 실데이터로 대체한다.

## Problem

`lib/state/discovery_providers.dart`의 `discoveryProvider`는 동기 `Provider`가 반환하는 하드코딩 mock이라 백엔드 계약(005, now live)과 단절돼 있다. 또한 `TelemetryReading.icon`이 하드코딩돼 있어 계약이 주는 `telemetry[].kind` 문자열과 매핑되지 않고, 구 mock의 kind(`visibility`/`cloud`)는 계약에서 이미 `sky`/`humidity`/`precip`로 바뀌었다.

## Solution

001/002가 확립한 패턴(추상 API 인터페이스 + `Http`/`Fake` 구현 + `AsyncNotifierProvider` + 위젯테스트의 `ProviderScope` override)을 그대로 재사용해, `discoveryProvider`를 `GET /api/suitability?lat&lng&mode`를 호출하는 async provider로 전환한다. `telemetry[].kind` 문자열 → `IconData` 매핑 함수를 도입하고, 홈 화면은 loading/error/degraded 상태 UI를 003에서 확립한 고정 한글 문구 패턴으로 처리한다. GPS는 이번 범위 밖 — 좌표는 `config.dart`의 고정 상수(계약 예시와 정합하는 강화 갯벌 좌표)를 사용한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/models/discovery.dart` - `SuitabilityIndex`/`GoldenHour`/`TelemetryReading`에 `fromJson` 팩토리 추가. `TelemetryReading.icon`(하드코딩 `IconData`)을 `kind`(String) 필드로 교체하고, kind→IconData 매핑은 위젯 레이어에서 수행(모델은 순수 데이터). `DiscoveryOverview`에 `degraded`(bool) 필드 추가 + `fromJson`. `ObsMode`에 계약 쿼리값(`day`/`night`) 직렬화 헬퍼 추가.
- `apps/flutter/lib/state/discovery_providers.dart` - 하드코딩 `discoveryProvider`(동기 `Provider`)를 `AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>`로 전환. `obsModeProvider`(day/night)와 고정 좌표를 쿼리에 전달하고, `obsModeProvider` 변경 시 재조회(`ref.watch`). `suitabilityApiProvider`(신규 API의 Provider) 도입. `hotspotsProvider`는 이번 범위 밖 — 무변경(mock 유지).
- `apps/flutter/lib/screens/home_discovery_screen.dart` - `ref.watch(discoveryProvider)`가 `AsyncValue<DiscoveryOverview>`가 되므로 `.when(data/loading/error)` 분기. loading=중앙 progress, error=고정 한글 문구(003 패턴, raw 예외 비노출) + 재시도. `degraded==true`면 "일부 데이터를 불러오지 못했어요" 배너 노출. telemetry 렌더에서 `kind`→`IconData` 매핑 함수 사용.
- `apps/flutter/lib/config.dart` - 기본 관측 좌표 상수 추가(`defaultObservationLat`/`defaultObservationLng`, 강화 갯벌 예시 좌표 `37.5921`/`126.3984` — 계약 예시와 정합). GPS 도입 전까지의 고정값임을 주석 명시.

### New Files

- `apps/flutter/lib/api/suitability_api.dart` - `SuitabilityApi` 추상 인터페이스(`Future<DiscoveryOverview> fetchSuitability({required double lat, required double lng, required ObsMode mode})`) + `HttpSuitabilityApi`(http 패키지, `ecolog_api.dart`의 `_checkStatus`/에러 매핑 패턴 미러) + `FakeSuitabilityApi`(네트워크 0, 위젯테스트용 결정적 데이터 반환, mode별 분기). 에러는 `ecolog_api.dart`와 동일 스타일의 예외 타입 사용(신규 `SuitabilityApiException` 또는 공용화 — 빌더 판단, 단 홈 화면엔 raw 노출 금지).
- `apps/flutter/test/suitability_wiring_test.dart` - `ProviderScope(overrides: [suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi(...))])`로 홈 화면 위젯테스트. 커버: (1) data 상태에서 score/label/골든타임/telemetry 렌더, (2) mode 토글 시 재조회(day↔night), (3) loading 상태 표시, (4) error 상태에서 고정 한글 문구 노출(raw 예외 문자열 비노출), (5) `degraded==true` 배너 노출. kind→IconData 매핑 함수 단위 검증 포함.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 모델 + API 클라이언트 (계약 파싱 레이어)

계약 JSON을 파싱하는 순수 레이어를 먼저 확정한다.

- [x] `discovery.dart`: `SuitabilityIndex.fromJson`(`score`/`label`/`sqmValue`/`skyClass`), `GoldenHour.fromJson`(`mode`/`label`/`timeRange`/`description`), `TelemetryReading` — `icon`(IconData) 제거하고 `kind`(String)/`label`/`value` 필드로 교체 + `fromJson`. `DiscoveryOverview.fromJson`(전체 응답 → `suitabilityIndex`/`goldenHours`/`telemetry`/`degraded` 조립). `ObsMode.toQueryValue`(day/night 문자열).
- [x] `suitability_api.dart` 신규: `SuitabilityApi` 추상 + `HttpSuitabilityApi`(`GET {baseUrl}/api/suitability?lat=&lng=&mode=`, non-2xx는 예외로, `ecolog_api.dart` 스타일) + `FakeSuitabilityApi`(mode별 결정적 응답, 네트워크 0).
- [x] `config.dart`: `defaultObservationLat`/`defaultObservationLng` 상수 추가(GPS 전 고정값 주석).

**Phase validation**: `just flutter-check`(analyze 무경고 + 기존 test 통과). 이 단계에선 화면 배선 전이라 기존 테스트가 깨지지 않는지 확인.

### Phase 2: provider async 전환 + 홈 화면 상태 UI

동기 mock provider를 실 API async provider로 바꾸고 화면이 3-상태를 처리하게 한다.

- [x] `discovery_providers.dart`: `suitabilityApiProvider` 도입(기본 `HttpSuitabilityApi(defaultApiBaseUrl)`). `discoveryProvider`를 `AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>`로 전환 — `build()`에서 `obsModeProvider`를 `ref.watch`하고 고정 좌표+mode로 `fetchSuitability` 호출. `obsModeProvider`/`hotspotsProvider`는 시그니처 무변경.
- [x] `home_discovery_screen.dart`: `ref.watch(discoveryProvider)` → `AsyncValue` `.when` 분기. loading=중앙 `CircularProgressIndicator`, error=고정 한글 문구(예: "적합도 정보를 불러오지 못했어요") + 재시도 버튼(`ref.invalidate(discoveryProvider)`), raw 예외 비노출. `data.degraded==true`면 상단에 경고 배너. telemetry는 `kind`→`IconData` 매핑 함수로 아이콘 결정(`sky`/`humidity`/`wind`/`precip`/`tide` + fallback).
- [x] kind→IconData 매핑 함수 정의(위젯 레이어, 예: `_iconForTelemetryKind` 또는 helper). 미지의 kind는 안전한 기본 아이콘.

**Phase validation**: `just flutter-check` green(analyze 무경고 + test 통과).

### Phase 3: 위젯테스트 + 계약 정합 확인

배선을 테스트로 못박는다.

- [x] `suitability_wiring_test.dart` 작성: data/loading/error/degraded/mode-toggle 5케이스 + kind 매핑 단위 검증(Relevant Files 참조).
- [x] `just flutter-check` 전체 green 확인.

**Phase validation**: 아래 Validation Commands.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just check
```

## Notes (agent scratchpad)

- **계약 정본은 `apps/backend/.team/member.md` §8** (필드명 alias 변환 없음, 그대로 파싱). 응답 필드: `mode`/`location{lat,lng}`/`score`/`label`/`sqmValue`/`skyClass`/`degraded`/`goldenHours[]{mode,label,timeRange,description}`/`telemetry[]{kind,label,value}`/`layers[]{key,weight,subScore,status}`. 이번 화면은 `layers[]`를 직접 렌더하지 않음(레이어 breakdown UI는 후속) — 파싱은 선택.
- **telemetry kind 값**: `sky`·`humidity`·`wind`·`precip`·`tide`. 구 mock의 `visibility`·`cloud`는 없어짐(005 §12에서 KMA 전환으로 교체). 매핑 예: sky→`Icons.wb_sunny`/`filter_drama`, humidity→`Icons.water_drop`, wind→`Icons.air`, precip→`Icons.grain`, tide→`Icons.waves`. 정확한 아이콘은 빌더 재량(003 테마 톤 유지), 단 미지 kind fallback 필수.
- **degrade는 200**: 백엔드는 provider 실패 시에도 200 + `degraded:true`로 응답(5xx 아님). 따라서 error 상태는 주로 네트워크/서버 다운/422이고, degraded는 정상 200 안의 부분 실패 → 둘을 구분해 UI 처리.
- **backend 무변경**: 이 스펙은 순수 consumer. `apps/backend/**` 절대 수정 금지. 계약이 부족하면 Amendment로 브레인에 에스컬레이션.
- **실 배선 최종 확인은 브레인 몫**: flutter 팀은 Fake 기반 위젯테스트로 검증(네트워크 0). 실 백엔드(`uv run uvicorn app.main:app --reload`) + `.env` 실키로 화면이 실제로 도는지는 빌드 PASS 후 브레인이 수동 확인(005 `just suitability-live` 패턴과 동일 철학).
- **GPS/핫스팟은 범위 밖**: 좌표는 고정 상수, `hotspotsProvider`는 mock 유지. GPS 위치·핫스팟 랭킹 배선은 후속 조각.

## Amendments (post-build change history, append-only)

- 2026-09-08 <flutter-lead>: Phase 1 체크리스트 항목 중 `TelemetryReading.icon → kind` 교체가 Phase 1 자체에서 이미 요구되어 있었는데, 이 필드 제거는 `discovery_providers.dart`의 목업 생성 코드와 `home_discovery_screen.dart`의 `.icon` 렌더링을 동시에 깨뜨린다 — 후자의 kind→IconData 매핑은 스펙상 Phase 2 항목이라, Phase 1만 단독으로는 "기존 테스트가 깨지지 않는지 확인"(Phase 1 validation 문구)이 불가능한 순서였다. 실용적으로 Phase 1(모델+API 클라이언트)과 Phase 2(provider async 전환+화면 배선)의 5개 태스크를 모두 위임한 뒤 `just check` 게이트 1회로 묶어 검증했다(analyze 무경고 + flutter test 20개 통과). 추가로, Phase 2 전환이 기존 `test/screens/home_discovery_screen_test.dart`(003/004에서 이미 존재하던 동기 mock 기반 위젯테스트)를 깨뜨리는 것도 스펙에 명시돼 있지 않았던 부수 효과라, 같은 게이트 안에서 그 파일도 `FakeSuitabilityApi` override + async pump로 업데이트했다(스펙이 요구한 신규 `suitability_wiring_test.dart`는 별도로 Phase 3에서 작성).
- 2026-09-08 <flutter-lead>: 크로스모델 검증(codex)에서 FAIL 발견 — `home_discovery_screen.dart`의 골든타임 `Row`가 `List.generate(2, (i) { ... overview.goldenHours[i] ... })`로 정확히 2개 항목을 하드코딩하고 있었는데, `apps/backend/.team/member.md` §8에 따르면 실 백엔드는 mode/layer 조합에 따라 `goldenHours`가 비어있거나 1개만 반환할 수 있어(day 모드에선 astronomy가 golden hour를 내지 않고 tide만 냄) `goldenHours[1]` 접근 시 `RangeError`로 런타임 크래시가 발생했다. `List.generate(overview.goldenHours.length, ...)`로 교체하고 margin 로직을 `left: i==0 ? 0 : 8, right: i==goldenHours.length-1 ? 0 : 8`로 바꿔 0/1/N개 항목을 모두 안전하게 렌더링하도록 수정, `apps/flutter/.team/member.md`에 핸드오프 노트 추가. `just check` 재검증 green(analyze 무경고 + flutter test 26개 통과, backend pytest 68 passed/3 skipped).
