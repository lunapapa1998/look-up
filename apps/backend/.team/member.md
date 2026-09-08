# Backend API Contract — Flutter Consumer Handoff

Standalone reference. This app is single-user (no auth, no `userId` field anywhere).
All endpoints are prefixed with `/api`. Request/response bodies are JSON.

## 1. Base URL & conventions

- Base path: `/api` (e.g. `GET {base}/api/health`)
- No authentication/authorization on any endpoint.
- No `userId` / multi-tenant concept — every observation belongs to the single implicit user.
- Content-Type: `application/json` for all bodies.

## 2. Endpoint table

| Method | Path | Request body | Success | Error(s) |
|---|---|---|---|---|
| GET | `/api/health` | none | 200 `{"status": "ok"}` | — |
| POST | `/api/observations` | `ObservationCreate` | 201 `Observation` | 422 (validation) |
| GET | `/api/observations` | none (optional query `speciesType=bird\|star`) | 200 `Observation[]` | 422 if `speciesType` invalid value |
| GET | `/api/observations/{id}` | none | 200 `Observation` | 404 if not found |
| PATCH | `/api/observations/{id}` | `ObservationUpdate` | 200 `Observation` | 404 if not found; 422 (validation) |
| DELETE | `/api/observations/{id}` | none | 204 (no body) | 404 if not found |
| GET | `/api/badges` | none | 200 `BadgeProgress[]` (always 5 entries) | — |

## 3. Schemas

### SpeciesType (enum, string values)
- `"bird"`
- `"star"`

### ObservationCreate (POST body)
| Field | Type | Required | Notes |
|---|---|---|---|
| speciesType | SpeciesType | required | `"bird"` or `"star"` |
| speciesName | string | required | min length 1 |
| note | string \| null | optional | |
| photoUrl | string \| null | optional | |
| observedAt | ISO 8601 datetime \| null | optional | **if omitted, server defaults to current UTC time** |
| lat | float \| null | optional | |
| lng | float \| null | optional | |

### ObservationUpdate (PATCH body)
| Field | Type | Required | Notes |
|---|---|---|---|
| speciesType | SpeciesType | optional | if present, must NOT be `null` (422 if `null`) — `speciesType` is required non-null in `Observation` |
| speciesName | string | optional | if present, must NOT be `null` (422 if `null`) — min length 1; `speciesName` is required non-null in `Observation` |
| note | string \| null | optional | |
| photoUrl | string \| null | optional | |
| observedAt | ISO 8601 datetime \| null | optional | if present, must NOT be `null` (422 if `null`) — `observedAt` is required non-null in `Observation` |
| lat | float \| null | optional | |
| lng | float \| null | optional | |

**All fields are optional. Only fields explicitly present in the request body are changed; omitted fields keep their current stored value.** (Standard Pydantic partial-update semantics — there is no separate "clear field" sentinel; sending a field with value `null` sets it to null.) **Exception: `speciesType`, `speciesName`, and `observedAt` do NOT accept explicit `null`** — PATCH with `{"speciesType": null}` or `{"speciesName": null}` returns 422, because both fields are required and non-nullable on the `Observation` response schema. The "sending a field with value `null` sets it to null" rule applies only to `note`, `photoUrl`, `lat`, and `lng`.

### Observation (response object)
| Field | Type | Required | Notes |
|---|---|---|---|
| id | int | always | server-assigned |
| speciesType | SpeciesType | always | |
| speciesName | string | always | |
| note | string \| null | always present (may be null) | |
| photoUrl | string \| null | always present (may be null) | |
| observedAt | ISO 8601 datetime | always | user-provided or server default (UTC now) |
| lat | float \| null | always present (may be null) | |
| lng | float \| null | always present (may be null) | |
| createdAt | ISO 8601 datetime | always | server-assigned, record creation time |

### Badge (fixed catalog, 5 entries)
| Field | Type | Notes |
|---|---|---|
| id | string | one of: `first_step`, `explorer`, `master`, `bird_watcher`, `star_gazer` |
| name | string | Korean display name |
| description | string | Korean description |
| targetCount | int | threshold to achieve the badge |

### BadgeProgress (GET /api/badges response item)
| Field | Type | Notes |
|---|---|---|
| badge | Badge | see above |
| achieved | bool | `currentCount >= badge.targetCount` |
| currentCount | int | current progress count for that badge's criterion |

## 4. Concrete examples

### POST /api/observations — request
```json
{
  "speciesType": "bird",
  "speciesName": "까치",
  "note": "아파트 단지 나무 위",
  "photoUrl": null,
  "observedAt": null,
  "lat": 37.5665,
  "lng": 126.9780
}
```

### POST /api/observations — 201 response
```json
{
  "id": 1,
  "speciesType": "bird",
  "speciesName": "까치",
  "note": "아파트 단지 나무 위",
  "photoUrl": null,
  "observedAt": "2026-09-07T05:12:34.123456Z",
  "lat": 37.5665,
  "lng": 126.978,
  "createdAt": "2026-09-07T05:12:34.123456Z"
}
```
(`observedAt` was omitted in the request, so the server filled it with the current UTC time — identical to `createdAt` in this case.)

### GET /api/observations — 200 response (2 items)
```json
[
  {
    "id": 1,
    "speciesType": "bird",
    "speciesName": "까치",
    "note": "아파트 단지 나무 위",
    "photoUrl": null,
    "observedAt": "2026-09-07T05:12:34.123456Z",
    "lat": 37.5665,
    "lng": 126.978,
    "createdAt": "2026-09-07T05:12:34.123456Z"
  },
  {
    "id": 2,
    "speciesType": "star",
    "speciesName": "북두칠성",
    "note": null,
    "photoUrl": "https://example.com/photos/2.jpg",
    "observedAt": "2026-09-06T20:00:00Z",
    "lat": null,
    "lng": null,
    "createdAt": "2026-09-06T20:05:00Z"
  }
]
```

### PATCH /api/observations/{id} — request
```json
{
  "note": "수정된 메모입니다"
}
```

### PATCH /api/observations/{id} — 200 response
```json
{
  "id": 1,
  "speciesType": "bird",
  "speciesName": "까치",
  "note": "수정된 메모입니다",
  "photoUrl": null,
  "observedAt": "2026-09-07T05:12:34.123456Z",
  "lat": 37.5665,
  "lng": 126.978,
  "createdAt": "2026-09-07T05:12:34.123456Z"
}
```
(Only `note` was sent, so only `note` changed; every other field is unchanged from before the PATCH.)

### 404 error body example (GET/PATCH/DELETE on missing id)
```json
{
  "detail": "Observation 999 not found"
}
```

### GET /api/badges — 200 response (always all 5, fixed catalog)
```json
[
  {
    "badge": {
      "id": "first_step",
      "name": "첫 관찰",
      "description": "첫 관찰 기록을 남겼어요",
      "targetCount": 1
    },
    "achieved": true,
    "currentCount": 2
  },
  {
    "badge": {
      "id": "explorer",
      "name": "탐험가",
      "description": "총 5개의 관찰을 기록했어요",
      "targetCount": 5
    },
    "achieved": false,
    "currentCount": 2
  },
  {
    "badge": {
      "id": "master",
      "name": "관찰 마스터",
      "description": "총 20개의 관찰을 기록했어요",
      "targetCount": 20
    },
    "achieved": false,
    "currentCount": 2
  },
  {
    "badge": {
      "id": "bird_watcher",
      "name": "새 관찰자",
      "description": "새(bird) 관찰을 5회 기록했어요",
      "targetCount": 5
    },
    "achieved": false,
    "currentCount": 1
  },
  {
    "badge": {
      "id": "star_gazer",
      "name": "별 관찰자",
      "description": "별(star) 관찰을 5회 기록했어요",
      "targetCount": 5
    },
    "achieved": false,
    "currentCount": 1
  }
]
```
(`first_step`/`explorer`/`master` count all observations regardless of species; `bird_watcher`/`star_gazer` count only observations of that `speciesType`.)

## 5. Status & Verification

- Status: Phase 0–3 complete. CRUD for observations plus badge derivation are fully wired on top of `app/models.py`, `app/repository.py`, and `app/badges.py`; `app/main.py` serves `/api/health` plus both routers.
- Verification: `cd apps/backend && uv run pytest -q` passes 27 tests.

## 6. Suitability engine — Phase 1 (pure scoring core, no HTTP yet)

- Not yet a live endpoint. This phase only lands `app/suitability/models.py` (Pydantic schemas: `ObsMode`, `Location`, `GoldenHour`, `TelemetryReading`, `LayerScore`, `SuitabilityResponse`), `app/suitability/providers/base.py` (`LayerReading` dataclass + `LayerProvider` Protocol, no I/O), and `app/suitability/scoring.py` (pure fusion: `WEIGHTS_BY_MODE`, `LABEL_THRESHOLDS`, `label_for_score`, `fuse`). No router, no `main.py` change yet — consumer teams have nothing to call yet.
- `fuse(mode, sub_scores, statuses)` excludes `status == "unavailable"` layers from the weighted average and renormalizes remaining weights; `layers[].weight` in the returned dict is always the **original static weight** from `WEIGHTS_BY_MODE`, not the renormalized one. Missing keys in `sub_scores`/`statuses` default to `0`/`"unavailable"`.
- Score/label thresholds (exact Korean strings, see `scoring.LABEL_THRESHOLDS`): 85+ `"매우 쾌적 (Prime)"`, 70+ `"쾌적"`, 50+ `"보통"`, else `"제한적"`.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_scoring.py -q` (this run's harness had no Bash access — statically re-verified the arithmetic by hand instead of executing; please run this command to confirm green before building Phase 2/3 on top).
- Full-response wiring (`GET /api/suitability`, `sqmValue`/`skyClass`/`goldenHours`/`telemetry` population, degrade-to-200 behavior) lands in later phases per `specs/005-suitability-engine-backend.md`.

## 7. Suitability engine — Phase 2c (KASI astronomy live adapter)

- New: `app/suitability/providers/astronomy.py` — `AstronomyProvider` (`key="astronomy"`). `fetch(lat, lng, mode)` calls two KASI data.go.kr endpoints (riseset + lunar phase, from `get_astronomy_config()`); `parse(riseset_item, lunar_item, mode)` is the network-free, unit-tested core. Both are fully defensive — malformed/missing fields degrade to `status="unavailable", sub_score=0` and never raise.
- Moon illumination: `illumination_pct = round(100 * (1 - abs(lunAge - 14.75) / 14.75))`, clamped 0–100. Night mode `sub_score = 100 - illumination_pct` (darker moon = better stargazing); day mode is a fixed `sub_score=75` (astronomy is low-priority for birdwatching) and never fails on missing twilight data.
- Night golden time: parsed from `astronomicalTwilightEnd` (HHMM → HH:MM), window is twilight-end to +3h40m (wraps past midnight). Day mode always returns `golden_hours=[]` — day golden time is owned by the tide layer.
- **Fixtures are hand-authored, not captured** (`tests/suitability/fixtures/kasi_riseset_sample.json`, `kasi_lunph_sample.json`) — this task had no network access to KASI, so the exact data.go.kr response envelope (`response.body.items.item`, field names `sunrise`/`sunset`/`civilTwilightEnd`/`astronomicalTwilightEnd`/`lunAge`) is a well-documented-style assumption, not a verified real capture. Pending confirmation via the later `@pytest.mark.live` smoke test (spec Phase 4) before this is trusted for production scoring.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_astronomy_provider.py -q` (this run's harness had no Bash access — statically re-traced both fixture values through `parse()` by hand for day/night/missing-twilight cases instead of executing; please run this command to confirm green, and then `uv run pytest -q` for the full suite, before building Phase 2 (light_pollution) or Phase 3 (service/router) on top).

## 7b. Suitability engine — Phase 2b (live OpenWeatherMap adapter)

- New: `app/suitability/providers/weather.py` — `WeatherProvider` (key = `environment`). `parse(data, mode)` is network-free and unit-tested directly; `fetch(lat, lng, mode)` reads `get_weather_config()`, short-circuits to `status=unavailable` (no network call) if `api_key` is empty or provider is not `openweathermap`, otherwise GETs `{base_url}/data/2.5/weather` with `lat`/`lon`/`appid`/`units=metric` and a 5s timeout and never raises (any `httpx` error or malformed-JSON parse error also degrades to `status=unavailable`). An `httpx.Client` can be injected via the constructor for testing; if none is injected, `fetch()` creates and closes a short-lived one itself.
- Sub-score weighting differs by mode (night favors cloud cover for stargazing, day favors visibility/wind for birdwatching). `evidence.visibilityCapKm` is always `10` and `evidence.visibilityCapped` is `true` whenever OWM raw visibility meters is `10000` or more (OWM cannot report beyond a 10km cap, so 25km+ conditions are indistinguishable from exactly-10km — telemetry appends a plus sign to the km value in that case).
- New: `tests/suitability/fixtures/owm_weather_sample.json` — hand-authored fixture matching OWM public Current Weather Data response shape; not a live-captured response (no network access available when this file was written).
- New: `tests/suitability/test_weather_provider.py` — parses the fixture directly (zero network) for both day and night modes, plus a test that monkeypatches `get_weather_config()` to an empty `api_key` and asserts `fetch()` degrades to `unavailable` without a network call.
- Not yet wired into the `/api/suitability` endpoint or `service.py` — that lands in a later phase.
- Verify command: `cd apps/backend && uv run pytest tests/suitability/test_weather_provider.py -q`

## 8. Suitability engine — Phase 3 (`GET /api/suitability` live endpoint)

**New live endpoint — flutter/web/ios/rn can now call this instead of mocking it.**

### `GET /api/suitability`

Query params (all required):

| Param | Type | Validation | Notes |
|---|---|---|---|
| lat | float | -90 ≤ lat ≤ 90 | 422 if missing or out of range |
| lng | float | -180 ≤ lng ≤ 180 | 422 if missing or out of range |
| mode | string enum | `"day"` \| `"night"` | 422 if missing or any other value |

200 response (`SuitabilityResponse`, all field names are exactly as shown — no alias transform):

```json
{
  "mode": "day",
  "location": { "lat": 37.5921, "lng": 126.3984 },
  "score": 88,
  "label": "매우 쾌적 (Prime)",
  "sqmValue": 21.6,
  "skyClass": "Class 2 최적 다크스카이",
  "degraded": false,
  "goldenHours": [
    { "mode": "day", "label": "낮 · 탐조 골든타임", "timeRange": "14:00 - 17:30", "description": "만조 2시간 전 갯벌 유입 피크" },
    { "mode": "night", "label": "밤 · 천체 골든타임", "timeRange": "21:40 - 01:20", "description": "월령 12% 삭 근처 · 운량 0%" }
  ],
  "telemetry": [
    { "kind": "sky", "label": "하늘상태", "value": "맑음" },
    { "kind": "humidity", "label": "습도", "value": "55%" },
    { "kind": "wind", "label": "풍속·풍향", "value": "2.1 m/s (NW)" },
    { "kind": "precip", "label": "강수형태", "value": "없음" },
    { "kind": "tide", "label": "조위 상태", "value": "만조 16:15" }
  ],
  "layers": [
    { "key": "environment", "weight": 0.40, "subScore": 90, "status": "live" },
    { "key": "astronomy", "weight": 0.20, "subScore": 85, "status": "live" },
    { "key": "lightPollution", "weight": 0.15, "subScore": 80, "status": "approx" },
    { "key": "tide", "weight": 0.25, "subScore": 88, "status": "stub" }
  ]
}
```

- `layers[].status` enum: `live` | `approx` | `stub` | `unavailable`. `tide` is currently always `stub` (KHOA not yet integrated). `lightPollution` is currently always `approx` (VIIRS not yet integrated — deterministic lat/lng heuristic).
- `degraded: true` whenever any layer's `status == "unavailable"` — this happens when a live provider (`environment`/`astronomy`) fails or throws; the endpoint still returns **200**, never 5xx. The failing layer's weight is excluded and the rest are renormalized (see `scoring.fuse`, Section 6).
- `telemetry`/`goldenHours` ordering follows layer order `environment → astronomy → lightPollution → tide`; either array can be empty for a given mode/layer combination (e.g. `astronomy` emits no `goldenHours` in day mode).
- `sqmValue`/`skyClass` are always sourced from the `lightPollution` layer's evidence; if that layer is ever `unavailable`, they safely default to `0.0`/`"알 수 없음"`.

422 error cases: missing `lat`, missing `lng`, missing `mode`, `lat`/`lng` out of range, or `mode` not in `{"day","night"}` (standard FastAPI validation error body).

### Implementation notes
- New: `app/suitability/service.py` — `SuitabilityService(providers)` orchestrates all 4 layer providers, catches **any** `Exception` from `provider.fetch()` (not just anticipated ones) and converts it to `LayerReading(status="unavailable", sub_score=0)` so one bad provider can never 500 the endpoint. `get_default_providers()` wires the real `WeatherProvider`/`AstronomyProvider`/`LightPollutionProvider`/`TideProvider`; `get_suitability_service()` is the FastAPI `Depends` target (module-level singleton, same pattern as `get_repository`).
- New: `app/routers/suitability.py` — `APIRouter(prefix="/api/suitability")`, single `GET ""` route, plain sync handler.
- `app/main.py`: registered `suitability.router` alongside `observations`/`badges`.
- New: `tests/suitability/test_endpoint.py` — `TestClient` + `app.dependency_overrides[get_suitability_service]` pattern (mirrors `tests/test_observations.py`), with a `FakeProvider` test double so no real network calls happen. Covers happy path (full contract shape), day vs night score difference, one-provider-raises → 200 + `degraded=true` + that layer `unavailable`, and 422s (missing `lat`, invalid `mode`, out-of-range `lat`).
- Verify: `cd apps/backend && uv run pytest -q` — **this run's harness had no working Bash/uv access** (every non-trivial shell command, including `uv run pytest` and even `python3 -c "..."`, was blocked pending approval that couldn't be granted in this non-interactive session). The diff was statically re-checked line-by-line against `models.py`/`providers/base.py`/`scoring.py`/all 4 provider adapters instead of executed. Please run the full suite to confirm green before this phase is considered verified.

## 9. Suitability engine — Phase 4 (live-API smoke test, final phase)

- New: `tests/suitability/test_live.py` — three tests that hit the **real** OpenWeatherMap and KASI APIs over the network (Seoul coordinates 37.5665/126.9780): `WeatherProvider().fetch(...)`, `AstronomyProvider().fetch(...)`, and a full `SuitabilityService(get_default_providers()).get_suitability(...)` end-to-end call. Each asserts `status in ("live", "unavailable")` — an `unavailable` status (e.g. missing/invalid API key) still passes but surfaces the `evidence["reason"]` via `print`/assert so a misconfigured key is visible in test output, not silently green. The end-to-end test also asserts `lightPollution` is always `"approx"` and `tide` is always `"stub"` regardless of network/keys.
- **Skipped by default, no network in the normal run.** The module has `pytestmark = pytest.mark.skipif(os.getenv("RUN_LIVE_TESTS") != "1", ...)` at the top, which skips the whole module unless `RUN_LIVE_TESTS=1` is set — this is the primary safety net and does not depend on marker selection. Every test is additionally decorated `@pytest.mark.live` so a live-only run can select just these tests once opted in.
- New: `[tool.pytest.ini_options]` section added to `pyproject.toml` registering the `live` marker (was previously undeclared, would have warned).
- New: `.env.example` at `apps/backend/.env.example` — documents `WEATHER_PROVIDER`, `OPENWEATHERMAP_BASE_URL`, `OPENWEATHERMAP_API_KEY`, `KASI_RISESET_BASE_URL`, `KASI_LUNPH_BASE_URL`, `DATA_GO_KR_SERVICE_KEY`, all as placeholders — no real values. It explicitly notes these vars belong in the **repo-root** `.env` (`lookup/.env`, two directories up), which `app/suitability/config.py` loads via `python-dotenv`'s `find_dotenv()` — not an `apps/backend/.env` file.
- **How to run for real:** from `apps/backend`, run `RUN_LIVE_TESTS=1 uv run pytest -m live -q`. This requires real API keys to already be present in the repo-root `.env` for the `"live"` status path to be exercised; without keys, providers degrade to `"unavailable"` and the tests still pass (that's expected and fine — the tests only prove the pipeline runs end-to-end without raising, not that keys are valid).
- **Outstanding for the brain/orchestrator:** a `justfile` recipe wrapping `RUN_LIVE_TESTS=1 uv run pytest -m live -q` (from `apps/backend`) has not been added — `justfile` is outside this team's write lane (`apps/backend/` only).
- Verify (default run, must stay zero-network): `cd apps/backend && uv run pytest -q` — **this run's harness again had no working Bash access** (blocked pending approval in this non-interactive session, same as Phase 3). Statically re-verified: (1) `pytestmark` skipif correctly gates the entire module before any test body executes, so `provider.fetch()` — the only network-triggering call — is never reached in the default run; (2) all imports (`app.suitability.models.SuitabilityResponse`, `providers.astronomy.AstronomyProvider`, `providers.weather.WeatherProvider`, `service.SuitabilityService`/`get_default_providers`) match the real module contents read before writing this file; (3) `pyproject.toml` TOML syntax is valid. Please run `uv run pytest -q` to confirm the 3 new tests show as `SKIPPED` and the full suite is still green before treating Phase 4 as verified.

## 10. Suitability engine — 크로스모델 검증 FAIL 3건 수정

- `providers/weather.py`의 `parse()` night 모드 sub_score 공식에 `humidity_pct` 기반 `humidity_score`(`= max(0, 1 - humidity_pct/100) * 100`)를 반영해 `visibility*0.15 + wind*0.10 + cloud*0.45 + humidity*0.30`으로 교체함(day 모드는 변경 없음) — 스펙의 "밤=운량·습도 우선" 요구를 반영.
- `fetch()`에서 `WEATHER_PROVIDER=kma`인 경우를 별도 분기로 명시해 `evidence.reason='KMA provider not yet implemented (see spec Phase 2 note)'`로 구분(기존 범용 unsupported-provider 분기와는 별개).
- `tests/suitability/test_endpoint.py`에 `test_missing_lng_returns_422`, `test_missing_mode_returns_422`, `test_lng_out_of_range_returns_422` 3개 테스트 추가.
- `just check`로 64 passed, 3 skipped 확인됨(네트워크 0).

## 11. KASI 어댑터 — 실측 그라운드 트루스 반영 (서비스키 디코딩·엔드포인트·필드 버그 수정)

- `config.py`의 `get_astronomy_config()`: `DATA_GO_KR_SERVICE_KEY`가 Encoding 형식 키라 httpx params에 그대로 넣으면 이중 인코딩되어 403이 나던 문제를 수정. `DATA_GO_KR_SERVICE_KEY_DECODED` 환경변수가 있으면 그 값을 그대로, 없으면 `DATA_GO_KR_SERVICE_KEY`를 `urllib.parse.unquote()`로 디코딩해 `service_key`로 반환(dataclass 필드명 변경 없음).
- `astronomy.py`의 `fetch()`: base_url에 오퍼레이션(`/getLCRiseSetInfo`, `/getLunPhInfo`)을 붙이지 않고 호출해 `NO_OPENAPI_SERVICE_ERROR`가 나던 버그를 수정. riseset params는 `dataType` 대신 `_type: 'json'`을 사용(`_type`이어야 JSON 응답이 옴). lunph params는 `locdate` 문자열 대신 `solYear`/`solMonth`/`solDay`로 분리해서 전달.
- `parse()`: 실제로 존재하지 않는 `astronomicalTwilightEnd` 필드 대신 실측 필드명 `aste`(끝에 공백 패딩, 예 `'2021  '`)를 사용하도록 교체. evidence 딕셔너리 키도 `astronomicalTwilightEnd` → `aste`로 변경(day/night 모드 둘 다).
- 픽스처 2개(`kasi_riseset_sample.json`, `kasi_lunph_sample.json`)를 서울 2026-09-08 실측 캡처값으로 교체 — riseset은 `aste`/`astm`/`civile`/`civilm`/`naute`/`nautm`/`sunrise`/`sunset`/`moonrise`/`moonset`/`moontransit`/`suntransit`/`location` 필드로 구성(모두 공백 패딩 유지), lunph는 `lunAge: 26.8`(숫자형) + `solYear`/`solMonth`/`solDay`/`solWeek`.
- `test_astronomy_provider.py`: `test_night_mode_missing_twilight_key_degrades_to_unavailable`에서 제거 대상 키를 `astronomicalTwilightEnd` → `civile`로 바꾸고(다른 필드는 sunrise/sunset 유지), `aste` 키 자체가 없는 상태에서 unavailable로 정상 degrade하는지 검증. 다른 3개 테스트는 필드명 변경만 반영, 로직 변경 없음.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_astronomy_provider.py -q` — 이 런에서는 Bash 실행이 승인 대기로 막혀 있어 직접 실행하지 못함. 5개 파일을 스펙과 대조해 정적 재검증 완료(픽스처 값을 `parse()` 로직에 손으로 트레이스: `aste='2021  '` → strip → `_parse_hhmm` 통과, `lunAge=26.8` → `float()` 정상, missing-key 테스트는 `aste` 부재 시 `twilight_raw=None` → `_parse_hhmm(None)` ValueError → unavailable 확인). 실제 그린 여부는 `uv run pytest -q` 실행으로 최종 확인 필요.

## 12. 기상 소스 전면 교체 — OpenWeatherMap → 기상청 API 허브(KMA)

- `config.py`의 `WeatherConfig` 필드를 `provider`/`base_url`/`api_key` → `provider`/`kma_base_url`/`kma_api_key`로 개명. `get_weather_config()`는 `WEATHER_PROVIDER`(기본값 `kma`), `KMA_APIHUB_BASE_URL`(기본값 `https://apihub.kma.go.kr/api/typ01/cgi-bin/url`), `KMA_APIHUB_KEY`(기본값 `""`)를 읽음. `AstronomyConfig`/`get_astronomy_config`는 무변경.
- `providers/weather.py` 전면 재작성. `parse(values: dict, mode: str)`는 이미 격자에서 추출된 스칼라 `{'SKY','REH','WSD','VEC','PTY'}`를 받는 순수 함수(네트워크 없음)로 변경 — 더 이상 OWM JSON 응답 형태를 받지 않음. **telemetry `kind`가 완전히 바뀜**: 기존 `['visibility','wind','cloud']` → 신규 `['sky','humidity','wind','precip']`(정확히 이 순서). `evidence` 키도 `visibilityCapKm`/`visibilityCapped`/`humidityPct` → `skyCode`/`ptyCode`/`precipitationDetected`로 교체.
- 강수 페널티: `PTY != 0`(비/비눈/눈/소나기)이면 `base_sub_score`에 `0.3`을 곱해 최종 `sub_score`로 사용(관측 적합도 대폭 하락). day/night `base_sub_score` 가중치 공식도 KMA 변수 기준으로 재정의(day = wind*0.5+sky*0.5, night = sky*0.45+humidity*0.35+wind*0.20).
- `fetch(lat,lng,mode)`: (1) `nph-dfs_xy_lonlat`로 위경도→격자좌표(nx,ny) 변환, (2) `SKY`/`REH`/`WSD`/`VEC`/`PTY` 5개 변수를 `nph-dfs_odam_grd`에 **변수당 개별 요청**(그리드 레이아웃 모호성 회피, 코드 주석 참고)으로 조회 후 `parse()` 호출. `KMA_APIHUB_KEY` 미설정 시 즉시 `unavailable`(reason=`'KMA_APIHUB_KEY not configured'`), `provider != 'kma'`면 `unavailable`(reason=`'unsupported weather provider: ...'`). 네트워크/파싱 예외(`httpx.HTTPError`/`ValueError`/`IndexError`)는 모두 흡수해 `raise` 없이 `unavailable`로 반환(astronomy.py와 동일한 방어적 패턴).
- 픽스처 교체: `owm_weather_sample.json` → `kma_weather_sample.json`(`{'SKY':1,'REH':55,'WSD':2.1,'VEC':315,'PTY':0}`). `test_weather_provider.py` 전면 재작성 — parse() day/night 검증, telemetry kind 순서 검증, 강수 페널티(PTY!=0 시 sub_score 하락) 검증, `_parse_xy_response`/`_parse_grid_value`를 손으로 만든 3x3 텍스트 그리드로 인덱싱 검증, api key 없을 때 네트워크 없이 unavailable 검증(모두 포함).
- **⚠️ 블로커**: `tests/suitability/fixtures/owm_weather_sample.json` 삭제가 아직 안 됨. 이 런의 Bash 툴이 `rm`/`git rm` 모두 "requires approval"로 차단되어 실행 불가(read-only 명령인 `git status`는 정상 동작 — 삭제류만 막힘). 새 `kma_weather_sample.json`은 생성 완료. **누군가 `git rm apps/backend/tests/suitability/fixtures/owm_weather_sample.json`(또는 수동 삭제) 실행 필요** — 남아있어도 아무 코드가 참조하지 않아 테스트에 영향은 없지만, 사양 완료 기준(owm 픽스처 삭제)을 완전히 만족하려면 삭제가 필요함.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_weather_provider.py -q` 및 `uv run pytest -q` — 이 런도 Bash 실행이 승인 대기로 전부 차단되어 (`uv run`, `rm`, `git rm` 전부 거부) 실행하지 못함. `parse()`/`_parse_xy_response`/`_parse_grid_value` 로직을 픽스처·테스트 데이터로 손으로 트레이스해 정적 검증 완료. `service.py`의 `get_default_providers()`는 `WeatherProvider()`를 키만으로 참조하므로 이번 변경으로 깨지지 않음. `test_endpoint.py`의 하드코딩된 `visibility`/`cloud` mock 텔레메트리는 실제 `WeatherProvider`를 호출하지 않는 `FakeProvider` 기반이라 영향 없음(단, 실제 API 예시와는 이제 불일치하니 참고용으로만 볼 것). 실제 그린 여부는 `uv run pytest -q` 실행으로 최종 확인 필요.
test_endpoint.py 텔레메트리 계약을 sky/humidity/wind/precip로 갱신

## 13. KMA 전환 마무리 — 라이브 스모크 테스트·env 문서·계약 핸드오프 갱신

- `tests/suitability/test_live.py`: docstring/주석의 'OpenWeatherMap' → 'KMA(기상청 API 허브)'로 교체, 필요 env 안내를 `KMA_APIHUB_KEY`/`KMA_APIHUB_BASE_URL`/`KASI_*`/`DATA_GO_KR_SERVICE_KEY(또는 _DECODED)`로 갱신, `test_weather_provider_live_fetch()`의 `assert len(reading.telemetry) == 3` → `== 4`(KMA는 sky/humidity/wind/precip 4종)로 수정. 스킵 마커·live 마커·좌표 상수·astronomy/service 테스트는 무변경.
- `.env.example` 전면 교체: `OPENWEATHERMAP_*` 완전 제거, `WEATHER_PROVIDER=kma`/`KMA_APIHUB_BASE_URL`/`KMA_APIHUB_KEY` 추가, `DATA_GO_KR_SERVICE_KEY`(Encoding, 자동 unquote)/`DATA_GO_KR_SERVICE_KEY_DECODED`(있으면 우선) 주석 명시.
- `member.md` Section 8의 `GET /api/suitability` 200 응답 예시 `telemetry` 배열을 `sky`/`humidity`/`wind`/`precip`/`tide` 5종으로 교체(Section 8 안에는 별도의 'telemetry[].kind enum' 문장이나 잔존 'visibility'/'cloud' 언급이 없어 추가 수정 불필요 — 해당 표현은 Section 7b/10/12의 과거 이력 서술에만 남아 있으며 이번 작업 범위 밖).
- Verify: Bash 미가용, 3개 파일을 스펙 요구사항과 줄 단위로 대조해 정적 재검증 완료. `cd apps/backend && uv run pytest -q`(기본, 네트워크 0) 및 `RUN_LIVE_TESTS=1 uv run pytest -m live -q`(실키 필요) 실행해서 확인 필요.
