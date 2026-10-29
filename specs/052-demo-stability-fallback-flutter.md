# 시연 안정성: 요청 타임아웃 + 샘플 데이터 대체 모드 (1단계)

> Lightweight plan-f3 spec. 백엔드(Cloud Run)가 503인 상태에서도 웹·Android 시연이 끊기지 않게 한다. 기존 API 연동은 그대로 두고 바깥에 감싸는 계층만 추가한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: apps/flutter/lib/api/*.dart, apps/flutter/lib/state/discovery_providers.dart, apps/flutter/lib/state/providers.dart, docs/deploy/backend-cloudrun.md
- risk: medium

## Purpose

백엔드가 응답하지 않거나 오류를 낼 때 화면이 비거나 스피너에 갇히지 않게 하고, 시연용 샘플 데이터를 실제 공공데이터와 명확히 구분해 보여준다.

## Problem

모든 `Http*Api`가 타임아웃 없이 `client.get`을 호출해 서버가 응답 없이 멈추면 로딩이 끝나지 않는다. 배포된 백엔드가 현재 503이고 CORS도 없어서 웹 빌드에서는 홈·관찰 지도·둘레길 탭이 모두 오류 화면만 보인다. 생태일기 저장(`/api/observations`)도 같은 이유로 실패한다.

## Solution

(1) 모든 HTTP 클라이언트에 기본 10초 타임아웃을 추가한다. (2) `DEMO_FALLBACK` 컴파일 플래그가 켜졌을 때만 동작하는 `Fallback*Api` 래퍼를 만든다. 래퍼는 실제 API를 먼저 호출하고, 실패할 때만 샘플 데이터를 반환하며, 샘플을 반환한 사실을 Riverpod 상태에 기록한다. (3) 기록된 상태를 읽어 "예시 데이터" 안내 배너와 `예시` 표시를 보여준다.

## 불변 조건 (반드시 지킬 것)

- **기존 API 클라이언트(`Http*Api`), `Fake*Api`, 인증(`lib/auth/*`), 데이터 모델(`lib/models/*`)을 삭제하거나 교체하지 않는다.** 클래스 시그니처를 바꾸지 말고, 타임아웃은 선택 생성자 인자(기본값 10초)로만 추가한다.
- 실제 API를 **항상 먼저** 호출한다. 샘플은 실패(예외, 타임아웃, non-2xx)했을 때만 쓴다.
- `DEMO_FALLBACK`이 꺼져 있으면(기본값) 지금과 똑같이 동작해야 한다. 기존 오류 상태 테스트는 수정하지 않고 그대로 통과해야 한다.
- 샘플 데이터에는 실제 업소명, 실존 인물, 실측처럼 보이는 정밀 수치를 쓰지 않는다. 식당·노포 이름은 "예시 식당 A"처럼 누가 봐도 예시인 이름으로 한다. 샘플 문자열은 모두 `lib/api/demo/` 안에만 둔다.
- 한국관광공사(KorService2/두루누비) 연동 경로(백엔드 `/api/trails`, `/api/observation-map`, `/api/trails/detail`, 앱의 GPX 직접 호출)는 그대로 유지한다.
- `apps/backend`는 수정하지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/api/suitability_api.dart`, `starlight_api.dart`, `observation_map_api.dart`, `trails_api.dart`, `regions_api.dart`, `tide_api.dart`, `species_api.dart`, `ecolog_api.dart`, `gpx_api.dart` - `Http*Api`에 `Duration timeout = const Duration(seconds: 10)` 생성자 인자를 추가하고 요청에 `.timeout(timeout)`을 적용한다. 타임아웃은 각 클라이언트의 기존 예외 경로(XxxApiException 또는 기존 throw)로 흘러가게 한다. GPX는 기존처럼 `[]`를 반환한다.
- `apps/flutter/lib/config.dart` - `const bool demoFallbackEnabled = bool.fromEnvironment('DEMO_FALLBACK');`를 추가한다.
- `apps/flutter/lib/state/discovery_providers.dart`, `apps/flutter/lib/state/providers.dart` - API provider를 만드는 곳에서 `demoFallbackEnabled`이면 `Fallback*Api(primary: Http*Api(...), ...)`로 감싼다. provider 이름과 타입(인터페이스)은 그대로 유지해 기존 override와 테스트가 깨지지 않게 한다.
- `apps/flutter/lib/screens/home_discovery_screen.dart`, `observation_map_screen.dart`, `trails_catalog_screen.dart` - 화면 상단(헤더 바로 아래)에 `SampleDataNotice`를 넣는다. 샘플 데이터로 그린 카드와 스팟에는 `예시` 표시를 붙인다. 레이아웃 재설계는 하지 않는다(4단계 범위).

### New Files

- `apps/flutter/lib/api/demo/sample_data.dart` - 샘플 응답 데이터. 강화 기준 적합도, 별빛 예보, 관찰 지도 스팟(새·별·둘레길·노포 각 2~3개), 둘레길 코스 3개(GPX URL 없음, 출발·도착 좌표만), 둘레길 상세, 지역 목록, 물때, 종 정보. 각 값에 "예시" 성격이 드러나게 한다.
- `apps/flutter/lib/api/demo/fallback_apis.dart` - `FallbackSuitabilityApi`, `FallbackStarlightApi`, `FallbackObservationMapApi`, `FallbackTrailsApi`, `FallbackRegionsApi`, `FallbackTideApi`, `FallbackSpeciesApi`, `FallbackEcologApi`. 각 클래스는 원래 인터페이스를 구현한다. `FallbackEcologApi`는 쓰기가 실패하면 기기 메모리에 저장하고(`FakeEcologApi` 재사용 가능) 그 항목을 샘플(이 기기에만 저장)로 표시한다.
- `apps/flutter/lib/state/sample_data_provider.dart` - 샘플을 반환한 출처 집합(`Set<SampleSource>`, enum: suitability, starlight, observationMap, trails, regions, tide, species, ecolog)을 담는 Notifier. 실제 호출이 다시 성공하면 해당 출처를 집합에서 제거한다.
- `apps/flutter/lib/widgets/sample_data_notice.dart` - 배너: "서버에 연결할 수 없어 예시 데이터를 보여드려요" + "다시 시도" 버튼(해당 provider invalidate). 카드용 작은 `예시` 표시(점선 테두리 + 텍스트, 색에만 의존하지 않음). 정식 스타일링은 3단계 `ProvenanceChip`에서 다시 한다.
- `apps/flutter/test/api/fallback_apis_test.dart` - 각 Fallback 래퍼 테스트: primary 성공 → 실제 데이터, 출처 미기록 / primary 예외 → 샘플 + 출처 기록 / primary 타임아웃 → 샘플 / 성공 후 출처 제거.
- `apps/flutter/test/widgets/sample_data_notice_test.dart` - 출처 집합이 비어 있으면 배너 없음, 있으면 배너와 "다시 시도" 표시.

## Phases

### Phase 1: 타임아웃

- [ ] 모든 `Http*Api`에 선택 인자 `timeout`(기본 10초)과 `.timeout()` 적용
- [ ] 기존 테스트 전부 통과 확인

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 샘플 데이터 + Fallback 래퍼 + 출처 상태

- [ ] `sample_data.dart`, `fallback_apis.dart`, `sample_data_provider.dart` 작성
- [ ] `config.dart`에 `demoFallbackEnabled` 추가, provider 생성부에서 플래그가 켜졌을 때만 래핑
- [ ] `fallback_apis_test.dart` 작성 및 통과

**Phase validation**: `just flutter-check` 통과. 플래그가 꺼진 기본 상태에서 기존 오류 상태 테스트(suitability_wiring, observation_map_wiring, trails_wiring 등)가 수정 없이 통과한다.

### Phase 3: 화면 표시

- [ ] `SampleDataNotice` 배너와 `예시` 표시 위젯 작성 및 테스트
- [ ] 홈, 관찰 지도, 둘레길 화면에 배너 연결. 샘플로 그린 카드와 스팟에 `예시` 표시
- [ ] 생태일기 저장이 샘플 모드로 처리되면 "이 기기에만 저장됨" 안내

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 실행 예(브레인이 수동 확인): `flutter run -d edge --dart-define=DEMO_FALLBACK=true --dart-define=API_BASE_URL=https://<CLOUD_RUN_SERVICE_URL>`
- 테스트에서 플래그를 켜려면 `--dart-define` 대신 provider override로 Fallback 래퍼를 직접 주입한다.
- 503 원인은 컨테이너가 아니라 Cloud Run 플랫폼 단계(Google Frontend HTML 응답)로 추정된다. 서버 쪽 조치는 이 spec 범위가 아니다.

## Amendments (post-build change history, append-only)

- 2026-10-29 (lead 분해 후 brain 확정):
  - `SampleSource` enum과 `SampleSourceReporter`(콜백 2개)는 api 계층이 Riverpod을 import하지 않도록 `lib/api/demo/fallback_apis.dart`에 정의하고, `lib/state/sample_data_provider.dart`에서 re-export한다.
  - 타임아웃은 각 클라이언트의 기존 예외 클래스로 `statusCode 408`, 메시지 '서버 응답 시간이 초과됐어요'로 던진다. starlight는 기존처럼 일반 `Exception`으로 던진다.
  - 배너·'예시'·'이 기기에만 저장됨' 같은 UI 문구는 샘플 데이터가 아니므로 widgets/screens에 둔다.
  - `Fake*Api`의 실제 업소명 데이터는 샘플로 재사용하지 않는다.
  - `ObservationMarker`, `buildObservationMarkers`, `ObservationSpotSheet`, `CourseCard`에 기본값 false인 선택 인자 `isSample`을 추가하는 것을 허용한다. 샘플 코스에는 '두루누비 코스' 배지를 표시하지 않는다.

