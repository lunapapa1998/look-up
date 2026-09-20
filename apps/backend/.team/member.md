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
    { "key": "tide", "weight": 0.25, "subScore": 88, "status": "live" }
  ]
}
```

- `layers[].status` enum: `live` | `approx` | `stub` | `unavailable`. `tide` is live when the KHOA API call succeeds, and falls back to a deterministic stub on any config/network/parse failure (see Section 16). `lightPollution` is currently always `approx` (VIIRS not yet integrated — deterministic lat/lng heuristic).
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

## 14. Tide 레이어 stub→live 재작성 — Phase 1 (순수 코어, 네트워크 없음)

- 신규 `app/suitability/providers/tide_stations.py`: `TideStation(code, name, lat, lng)` frozen dataclass, 스펙 그대로의 37개 KHOA 관측소를 담은 `STATIONS: tuple[TideStation, ...]`, `nearest_station(lat, lng) -> TideStation`(haversine, 표준 `math`만 사용).
- `config.py`에 `TideConfig(base_url, service_key)`와 `get_tide_config()` 추가 — `get_astronomy_config()`와 동일 패턴(`DATA_GO_KR_SERVICE_KEY_DECODED` 우선, 없으면 `DATA_GO_KR_SERVICE_KEY`를 `unquote`). `base_url` 기본값은 `TIDE_API_BASE_URL` env, 없으면 `https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService`. 기존 `get_weather_config`/`get_astronomy_config`/`validate_coordinates`는 무변경.
- `providers/tide.py`에 순수 함수 2개 **추가**만 함(기존 `TideProvider.fetch()`와 stub 동작은 완전히 무변경 — 아직 이 provider는 `status="stub"`를 반환): 모듈 함수 `_parse_xml_items(xml_text) -> list[dict]`(표준 `xml.etree.ElementTree`, `resultCode != '00'`이면 `ValueError`, items 없으면 `ValueError`), 신규 메서드 `TideProvider.parse(items, mode, now) -> LayerReading`(고조/저조를 이웃 비교로 분류, day 모드는 낮 시간대(06:00≤hour<18:00) 첫 고조를 golden_hours로, night 모드는 golden_hours=[] 고정, telemetry는 now 이후 첫 극값(없으면 마지막) 기준).
- 신규 픽스처 `tests/suitability/fixtures/khoa_tide_sample.xml`(스펙에 주어진 인천 4개 극값 XML 그대로) + 신규 `tests/suitability/test_tide_provider.py`(day golden_hours/timeRange/description/sub_score=85, night golden_hours=[]/sub_score=70, telemetry 2케이스, `nearest_station` DT_0001 매칭 검증).
- **아직 `fetch()`에 연결 안 됨** — 이번 phase는 순수 파싱/분류 코어만. `TideProvider`는 여전히 하드코딩 stub을 반환하므로 `test_live.py`의 `tide는 항상 stub` 단언과 기존 전체 테스트는 영향 없음.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_tide_provider.py -q` 및 `uv run pytest -q` — 이 런은 Bash 도구 자체가 role에 허용되지 않아(승인 대기) 실행 불가. 픽스처 4개 값을 손으로 `_classify_extremes`/`parse()` 로직에 트레이스해 정적 검증 완료(02:26=고조/08:59=저조/14:46=고조/20:58=저조 → day golden `12:46-14:46`, now=01:00→`만조 02:26`, now=23:00→`간조 20:58`). 실제 그린 여부는 위 명령 실행으로 최종 확인 필요.

## 15. Tide 레이어 stub→live 재작성 — Phase 2 (`fetch()`를 live 네트워크 연동으로 교체)

- `providers/tide.py`만 수정. `TideProvider.__init__(self, client: httpx.Client | None = None)` 추가(astronomy.py/weather.py와 동일 패턴, 테스트용 fake client 주입 가능 — `TideProvider()` 무인자 생성도 여전히 동작하므로 `service.py`는 무변경).
- 기존 하드코딩 stub 리턴 로직을 `_stub_reading(self, mode: str, reason: str) -> LayerReading`으로 그대로 이동(텍스트/값 토씨 하나 안 바꿈: `timeRange='14:00 - 17:30'`, `telemetry='만조 16:15 (스텁 데이터)'`, `sub_score=_SUB_SCORE(70)`, `status='stub'`). `evidence.reason`만 호출부 인자로 교체 가능.
- 신규 `fetch(lat, lng, mode)`: `get_tide_config()` 조회 → `service_key`/`base_url` 중 하나라도 비면 즉시 `_stub_reading(mode, 'TIDE config missing: ...')`. 그 외 전체를 `try/except Exception as exc: # noqa: BLE001`로 감싸 어떤 예외든 `_stub_reading(mode, f'KHOA tide request failed: {exc}')`로 폴백(astronomy.py `fetch()`와 동일 패턴). `try` 안에서 `nearest_station(lat, lng)`으로 관측소 조회 → `client.get(config.base_url, params={'serviceKey', 'obsCode'})` → `raise_for_status()` → `_parse_xml_items(response.text)` → `now = datetime.now(_KST).replace(tzinfo=None)`(신규 모듈 상수 `_KST = timezone(timedelta(hours=9))`, weather.py와 동일 이유 — `predcDt`가 KST naive 문자열) → `self.parse(items, mode, now)`. `self._client` 미주입 시 `httpx.Client(timeout=5.0)`를 새로 만들고 `finally`에서 close.
- `parse()`/`_parse_xml_items()`/Phase 1 모듈 상수는 전부 무변경. 기존 오프라인 테스트 5개(`TideProvider().parse(...)` 직접 호출)는 `fetch()` 변경과 무관하게 영향 없음.
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_tide_provider.py -q` 및 `uv run pytest -q` — 이 런도 Bash가 전부 승인 대기로 막혀(git diff조차 불가) 실행 못함. 신규 `fetch()` 로직을 astronomy.py의 이미 검증된 패턴과 줄 단위로 대조해 정적 검증 완료. 실제 그린 여부는 위 명령 실행으로 최종 확인 필요.

## 16. Tide 레이어 stub→live 재작성 — Phase 3 (라이브 스모크 + 계약 갱신, 최종 완료)

- `tests/suitability/test_live.py`: `TideProvider` import 추가, 강화대교 부근 좌표 상수 `_GANGHWA_LAT`/`_GANGHWA_LNG` 추가, `test_tide_provider_live_fetch()` 신규 추가(`status in ("live", "stub")`만 허용 — tide는 폴백이 항상 stub이라 `unavailable`은 없음). `test_suitability_service_live_end_to_end()`의 마지막 단언을 `tide == "stub"` → `tide in ("live", "stub")`로 수정(이제 실제 라이브 성공 가능).
- `.env.example` 끝에 `TIDE_API_BASE_URL` 섹션 추가(선택 항목, 기본값이 이미 `config.py`에 있음을 주석으로 명시, 새 서비스 키 불필요 — 기존 `DATA_GO_KR_SERVICE_KEY`(_DECODED) 재사용).
- 본 문서(Section 8 응답 예시의 `tide` 상태를 `live`로, `layers[].status` enum 설명 중 tide 부분을 갱신)만 변경 — tide.py/tide_stations.py/config.py 등 코드 파일은 이번 phase에서 무변경.
- Verify: `cd apps/backend && uv run pytest -q`(기본, 네트워크 0) 및 `RUN_LIVE_TESTS=1 uv run pytest -m live -q`(실키 필요, 신규 tide 라이브 테스트 포함) 실행해서 확인 필요 — 이 런은 Bash 미가용이라 정적 검증만 수행함(신규 테스트 로직을 `TideProvider.fetch()`/`LayerReading` 시그니처와 대조).

## 17. Trails 기능 — Phase 1 (트레일 파싱 코어, 네트워크 0, 순수 함수만)

- 신규 패키지 `app/trails/`: `models.py`(Pydantic v2, `from __future__ import annotations`) — `Coordinate(lat,lng)`, `NightSky(sqmValue,bortleClass,skyClass,status)`, `HeritageEat(name,addr,distanceM,lat,lng,contentId)`, `CourseSuitability(score,label,status)`, `TrailCourse(crsIdx,name,sigun,distanceKm,durationMin,level,cycle,gpxUrl,start:Coordinate,end:Coordinate,nightSky:NightSky,heritageEats:list[HeritageEat],daySuitability:CourseSuitability|None,nightSuitability:CourseSuitability|None)`, `TrailsResponse(region,degraded,courses)`. 아직 어떤 라우터/서비스도 이 모델들을 사용하지 않음(순수 스키마 정의만).
- `config.py`에 `TrailsConfig(durunubi_base_url, tourapi_base_url, service_key)` + `get_trails_config()` **추가만** 함(기존 `get_weather_config`/`get_astronomy_config`/`get_tide_config`/`validate_coordinates`는 무변경). service_key 우선순위는 `get_tide_config()`와 완전히 동일한 패턴(`DATA_GO_KR_SERVICE_KEY_DECODED` 우선, 없으면 `DATA_GO_KR_SERVICE_KEY`를 `unquote`). `durunubi_base_url` 기본값 `DURUNUBI_BASE_URL` env / `https://apis.data.go.kr/B551011/Durunubi`, `tourapi_base_url` 기본값 `TOURAPI_BASE_URL` env / `https://apis.data.go.kr/B551011/KorService2`.
- `app/trails/durunubi.py`: `parse_course_list(payload: dict) -> list[dict]` — `response.header.resultCode != '0000'`면 `ValueError`; `response.body.items.item`이 dict면 1개짜리 리스트로 감싸고, 없거나 빈 값이면 `ValueError`. 각 아이템을 `{crsIdx, name(←crsKorNm), sigun, distanceKm(float←crsDstnc, 기본 0.0), durationMin(int←float(crsTotlRqrmHour), 기본 0), level(int←float(crsLevel), 기본 0), cycle(←crsCycle), gpxUrl(←gpxpath)}`로 변환. 숫자 캐스팅은 전부 `try/except (TypeError, ValueError)`로 방어(빈 문자열/None이면 default). 같은 파일에 `parse_gpx_endpoints(gpx_text: str) -> tuple[dict, dict]` — 정규식 `r'lat="([-0-9.]+)"\s+lon="([-0-9.]+)"'`을 `re.findall`, 매치가 없으면 `ValueError`, 첫 매치가 start 마지막 매치가 end(각각 `{lat, lng}` dict, float).
- `app/trails/tourapi.py`: `parse_food_list(payload: dict, top_n: int = 3) -> list[dict]` — `response.body.items.item` 단일 dict/list/누락 방어는 durunubi와 동일 패턴이되, 누락/빈 값이면 **빈 리스트**(ValueError 아님). 각 아이템 `{name(←title), addr(←addr1), distanceM(int←float(dist), 기본 0), lat(float←mapy), lng(float←mapx), contentId(←contentid)}`, `distanceM` 오름차순 정렬 후 `[:top_n]` 반환.
- `app/trails/service.py`: `match_region(place_tokens: list[str], courses: list[dict]) -> list[dict]` — 순수 함수, I/O 없음. 토큰과 `course['sigun']`을 각각 `strip().lower()` + 내부 공백을 단일 스페이스로 정규화(`re.sub(r'\s+', ' ', ...)`) 후, 토큰 중 하나라도 정규화된 sigun의 substring이면 매치. 원래 순서 유지. 이 파일엔 아직 다른 내용 없음(다음 phase에서 라우터/오케스트레이션 추가 예정).
- 신규 픽스처: `tests/trails/fixtures/durunubi_courselist.json`(코스 2건 — 부산 영도구/인천 강화군), `tests/trails/fixtures/durunubi_course.gpx`(트랙포인트 6개, start=lat 35.0965626320323/lng 129.035967774477, end=lat 35.0874667791044/lng 129.004487268964), `tests/trails/fixtures/tourapi_food.json`(맛집 2건, dist 오름차순 이미 정렬됨 — 꽃게와낙지 1363.6m가 첫 번째).
- 신규 `tests/trails/test_trails_parsers.py` — 9개 테스트: `parse_course_list` 필드/캐스팅 검증 + resultCode 불량 시 ValueError, `parse_gpx_endpoints` start/end 검증(pytest.approx) + zero-trkpt ValueError, `parse_food_list` top_n=3/top_n=1 검증, `match_region` 강화 토큰 매치 + 무관 지명 빈 리스트.
- **⚠️ 이 런은 Bash 실행이 전부 "requires approval"로 차단되어(`uv run pytest`, `python3 -c`, `mkdir` 등 read 이외 전 명령 거부) 테스트를 실제로 실행하지 못함.** 모든 픽스처 값을 각 함수 로직에 손으로 트레이스해 정적 검증 완료(distanceKm 14.0/11.0, durationMin 330/210, level 2/1, GPX 첫/마지막 lat·lon, food distanceM int(1363.606..)=1363/int(1974.336..)=1974 오름차순 이미 정렬, match_region '강화' substring 매치·무관 지명 빈 리스트 전부 논리 확인). **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest tests/trails/test_trails_parsers.py -q` 및 `uv run pytest -q`(전체 스위트 회귀 없음 확인)를 반드시 실행해서 그린 확인 필요.**
- 참고: 이번 런에서는 상대경로가 이 워커의 실제 cwd(=repo root `/path/to/lookup`) 기준으로 해석됨 — `app/trails/...`가 아니라 `apps/backend/app/trails/...`로 경로를 써야 Write 툴이 통과했음. Phase 2 이후에도 동일 이슈가 있을 수 있으니 참고.

## 18. Trails 기능 — Phase 2 (클라이언트 fetch + 서비스 조립, 적합도 제외)

- `app/trails/durunubi.py`에 **추가만** 함(Phase 1 함수 무변경): `fetch_courses(client: httpx.Client | None = None, max_rows: int = 1000) -> list[dict]`(§21에서 `brd_div: str = "DNWW"` 파라미터 추가로 수정됨 — 최신 시그니처는 §21 참고) — `get_trails_config()`에서 `durunubi_base_url`/`service_key` 중 하나라도 비면 네트워크 호출 없이 즉시 `[]`. 그 외엔 `GET {durunubi_base_url}/courseList`(`serviceKey`/`MobileOS=ETC`/`MobileApp=lookup`/`_type=json`/`numOfRows`/`pageNo=1`/`brdDiv`) → `raise_for_status()` → `parse_course_list(response.json())`. 네트워크/HTTP/파싱 등 **모든 예외를 흡수**해 `[]` 반환(raise 없음). `client`가 주입되면 그대로 쓰고 안 닫음, `None`이면 내부에서 `httpx.Client(timeout=10.0)` 생성 후 `finally`에서 close. `fetch_gpx_endpoints(gpx_url: str, client=None) -> tuple[dict, dict] | None` — 동일 client 소유권 패턴, GPX 텍스트 GET → `parse_gpx_endpoints`. 트랙포인트 0개(`ValueError`) 포함 **모든 예외를 흡수해 `None`** 반환(raise 없음).
- `app/trails/tourapi.py`에 **추가만** 함: `fetch_nearby_food(lat, lng, client=None, radius=5000, rows=10, top_n=3) -> list[dict]` — `tourapi_base_url`/`service_key` 중 하나라도 비면 즉시 `[]`. 그 외 `GET {tourapi_base_url}/locationBasedList2`(`mapX=lng`/`mapY=lat`/`radius`/`contentTypeId=39`/`arrange=E`) → `raise_for_status()` → `parse_food_list(payload, top_n=top_n)`. 모든 예외 흡수 → `[]`. client 소유권 패턴은 durunubi와 동일.
- `app/trails/service.py`에 신규: `DEFAULT_REGION_LABEL = "인천 강화군"`, `DEFAULT_REGION_TOKENS = ["강화"]`(v1 고정 시드 권역 — lat/lng 인자와 무관하게 항상 강화군으로 매칭, 실 역지오코딩은 스코프 밖 후속 phase — spec Notes에 명시된 의도적 단순화), `TOP_K = 5`. `TrailsService(fetch_courses=None, fetch_gpx_endpoints=None, fetch_nearby_food=None, light_pollution_provider=None)` — 생략 시 각각 `durunubi.fetch_courses`/`durunubi.fetch_gpx_endpoints`/`tourapi.fetch_nearby_food`/`LightPollutionProvider()`로 기본 배선. `get_trails(lat, lng) -> dict` (플레인 dict, pydantic 모델 아님 — Phase 3 라우터가 검증):
  - `region`/`degraded`/`courses` 3개 키. `fetch_courses()`가 빈 리스트거나 `match_region(DEFAULT_REGION_TOKENS, ...)` 결과가 빈 리스트면 `{region: DEFAULT_REGION_LABEL, degraded: True, courses: []}`.
  - 매칭 결과를 **fetch 전에** `[:TOP_K]`로 먼저 슬라이스(최대 5개까지만 GPX/노포를 fetch) → 후보마다 `fetch_gpx_endpoints(gpxUrl)`가 `None`이면 그 코스만 조용히 스킵(전체 `degraded`엔 영향 없음) → `light_pollution_provider.fetch(end.lat, end.lng, "night")`로 `nightSky{sqmValue,bortleClass,skyClass,status}` 조립, `fetch_nearby_food(end.lat, end.lng)`로 `heritageEats` 조립, `daySuitability`/`nightSuitability`는 이 phase에서 둘 다 `None`(Phase 3에서 featured 코스만 채움).
  - 정렬 키 `(-nightSky.sqmValue, distanceKm asc, crsIdx asc)` — SQM 내림차순 + 결정적 tie-break(spec Notes 요구사항 그대로).
  - `get_default_trails_service()`/`get_trails_service()` 추가(`get_suitability_service()`와 동일한 모듈 싱글톤 `Depends` 패턴). **아직 라우터 없음** — Phase 3에서 `app/routers/trails.py` + `main.py` 등록 예정.
- 신규 `tests/trails/test_trails_service.py` — 5개 테스트, 전부 fake `fetch_courses`/`fetch_gpx_endpoints`/`fetch_nearby_food`(테스트 파일 내 lambda/함수)와 `LayerReading`(실제 `app.suitability.providers.base` dataclass 재사용) 반환하는 fake light-pollution provider로 조립, 네트워크 0: 코스 0건 degrade, 권역 미매칭 degrade, 랭킹+tie-break(SQM 동점 시 거리 오름차순), GPX 실패 코스만 스킵(전체 degrade 아님), TOP_K가 fetch 전에 적용됨(콜카운터로 최대 5회 검증).
- **⚠️ 이 런도 Bash가 role 권한상 전부 "requires approval"로 막혀 `uv run pytest` 실행 불가.** 5개 신규 테스트를 로직에 손으로 트레이스해 정적 검증 완료(정렬 키 계산·스킵 조건·TOP_K 슬라이스 순서 전부 확인). Phase 1 함수는 시그니처/바디 어느 것도 건드리지 않아 기존 9개 테스트에 영향 없음. **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest tests/trails/ -q` 및 `uv run pytest -q`(전체 회귀) 실행해서 그린 확인 필요.**

## 19. Trails 기능 — 랭킹 버그 수정(전체 매칭 후 정렬→상위 5 슬라이스) + 예외처리 + featured 코스 적합도 연동

- **버그 수정**: `TrailsService.get_trails()`가 `matched[:TOP_K]`로 **먼저 5개 슬라이스한 뒤** SQM으로 정렬하던 것을, `matched` 전체에 대해 GPX 엔드포인트·SQM을 조회해 랭킹 풀을 만든 뒤 `(-sqmValue, distanceKm asc, crsIdx asc)`로 정렬하고 **그 다음에** `top = ranked[:TOP_K]`로 슬라이스하도록 순서를 뒤집음. 이전엔 원본 매칭 순서 6번째 이후 코스는 SQM이 아무리 높아도 featured가 될 수 없었음.
- `fetch_nearby_food`와 `daySuitability`/`nightSuitability` 계산은 여전히 `top`(최대 5개)에 대해서만 수행 — 정렬 전 전체 풀에 대해 노포/적합도까지 조회하진 않음(불필요한 API 호출 방지).
- **신규 예외 가드 2곳** (이전엔 unguarded): `light_pollution_provider.fetch()` 호출을 `try/except Exception`으로 감싸 실패 시 그 코스를 랭킹 풀에서 조용히 제외(GPX 실패와 동일 취급). `fetch_nearby_food()` 호출을 `try/except Exception`으로 감싸 실패 시 `heritageEats=[]`.
- **신규 생성자 파라미터** `suitability_service=None` — 생략 시 `app.suitability.service.get_suitability_service()`(모듈 싱글톤)를 사용. `top[0]`(featured/1위 코스)에 한해서만 `get_suitability(end.lat, end.lng, "day")`와 `"night"`을 각각 독립된 `try/except Exception`으로 호출 — 성공 시 `{"score", "label", "status": "live" if not degraded else "approx"}`, 실패 시 해당 필드는 `None`. 1위 외 코스는 이전처럼 `daySuitability`/`nightSuitability` 둘 다 항상 `None`.
- `test_trails_service.py`: 버그를 그대로 검증하던 `test_top_k_limits_candidates_before_fetching`(GPX fetch 호출 수 ≤5 단언 — 잘못된 기존 동작을 고정하던 테스트)을 `test_ranks_all_matched_courses_before_slicing_to_top_k`로 교체(매칭 6건 모두 GPX fetch 호출됨=6, food fetch ≤5, 원본 순서 6번째였던 최고 SQM 코스가 결과 0번 인덱스로 옴을 검증). 신규 `test_featured_course_gets_suitability`(SimpleNamespace 기반 fake suitability_service 주입, 결과 0번만 day/nightSuitability 채워짐 검증), `test_suitability_and_light_pollution_exceptions_are_absorbed`(light_pollution/suitability 양쪽 다 예외 던지는 fake 주입 — `get_trails()`가 raise 하지 않고, 실패한 코스는 결과에서 제외되고 featured suitability는 None임을 검증). 기존 4개 테스트(`test_degrades_when_course_list_empty`/`test_degrades_when_no_region_match`/`test_ranking_and_tiebreak`/`test_course_skipped_when_gpx_fetch_fails`)는 로직 무변경, 단 오프라인 보장을 위해 항상 예외를 던지는 `_RaisingSuitabilityService`를 `suitability_service=`로 명시 주입.
- **⚠️ 이 런도 Bash가 role 권한상 read-only 명령(`ls`, `grep`)만 허용되고 `uv run pytest`/`python3 -c`는 전부 "requires approval"로 차단되어 테스트를 실제로 실행하지 못함.** `service.py` 전체와 `test_trails_service.py` 8개 테스트를 로직에 손으로 트레이스해 정적 검증 완료(정렬 전/후 슬라이스 순서, try/except 3곳 배치, `SimpleNamespace(score,label,degraded)` → `{"score","label","status"}` 매핑 등). **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest tests/trails/test_trails_service.py -q` 및 `uv run pytest -q`(전체 회귀) 실행해서 그린 확인 필요.**

## 20. Trails 기능 — Phase 3 완료(featured 적합도 + GET /api/trails 엔드포인트 + 라이브 스모크) — 계약 publish

- (a) `app/trails/service.py`는 랭킹 1위(featured) 코스 종점에 한해 주입된 `SuitabilityService.get_suitability(lat,lng,mode)`를 day/night 각각 호출해 `daySuitability`/`nightSuitability`(score/label/status)를 채우고 나머지 코스는 둘 다 `null`이며 개별 실패는 흡수한다(featured에 적합도 없으면 `null`, degrade 아님).
- (b) 신규 `app/routers/trails.py`는 `app/routers/suitability.py`와 동일 패턴이고 `app/main.py`에 라우터 등록 완료.
- (c) 신규 `tests/trails/test_trails_endpoint.py`는 fake `TrailsService` 주입 4개 테스트(happy path 전체 필드셋/degraded/lat 누락 422/lat 범위초과 422).
- (d) `tests/suitability/test_live.py`에 두루누비 courseList/GPX/TourAPI locationBasedList2 라이브 스모크 3건 추가(전부 degrade-tolerant, `RUN_LIVE_TESTS=1` 아니면 스킵).
- (e) `.env.example`에 `DURUNUBI_BASE_URL`/`TOURAPI_BASE_URL` 문서화(선택 항목, 기본값 코드에 있음, 새 키 불필요).

### GET /api/trails 계약

```
### `GET /api/trails`
Query: lat (float, -90..90, required), lng (float, -180..180, required).
200 응답(TrailsResponse):
{
  "region": "인천 강화군",            // 매칭된 권역 라벨
  "degraded": false,                  // 외부 소스 실패 시 true(courses 빈 배열 가능)
  "courses": [                        // 최대 5, 종점 밤하늘 SQM 높은 순
    {
      "crsIdx": "T_CRS_MNG0000009999",
      "name": "서해랑길 강화 코스",
      "sigun": "인천 강화군",
      "distanceKm": 11.0,             // number
      "durationMin": 210,             // int (분)
      "level": 1,                     // int 1..3 (난이도)
      "cycle": "비순환형",             // string
      "gpxUrl": "https://www.durunubi.kr/...gpx",
      "start": { "lat": 37.7, "lng": 126.4 },   // GPX 첫 trackpoint
      "end":   { "lat": 37.60, "lng": 126.41 }, // GPX 끝 trackpoint (관측 종점)
      "nightSky": {                   // 종점 밤하늘(정적 approx)
        "sqmValue": 20.4, "bortleClass": 3,
        "skyClass": "Class 3 양호한 다크스카이", "status": "approx"
      },
      "heritageEats": [               // 종점 근처 음식점 top 3(거리순)
        { "name": "꽃게와낙지", "addr": "인천광역시 강화군 화도면 ...",
          "distanceM": 1363, "lat": 37.60, "lng": 126.41, "contentId": "855186" }
      ],
      "daySuitability":  { "score": 73, "label": "...", "status": "live" } | null,  // featured만 non-null
      "nightSuitability":{ "score": 61, "label": "...", "status": "live" } | null
    }
  ]
}
```
- featured(랭킹 1위)만 `daySuitability`/`nightSuitability`가 채워지고 나머지는 `null`.
- 좌표 없음(GPX 실패) 코스는 응답에서 제외될 수 있음.

## 21. Trails — `fetch_courses` 시그니처를 spec대로 수정(brdDiv 하드코딩 제거)

- `app/trails/durunubi.py`의 `fetch_courses`가 spec(§012 39행: `fetch_courses(brd_div="DNWW", max_rows)`)과 달리 `brdDiv`를 params 딕셔너리에 문자열 `"DNWW"`로 하드코딩하고 있던 것을 수정. 시그니처를 `fetch_courses(client: httpx.Client | None = None, brd_div: str = "DNWW", max_rows: int = 1000) -> list[dict]`로 변경(`client`가 여전히 첫 인자), `params["brdDiv"]`를 하드코딩 문자열 대신 `brd_div` 인자값으로 채움. 다른 로직/예외처리/파서는 무변경.
- `service.py:46`의 `self.fetch_courses()` 호출은 인자 없이 실행되므로 새 `brd_div` 기본값 `"DNWW"`로 기존 동작과 완전히 동일하게 유지됨(수정 불필요, 실제로 무변경).
- Verify: `cd apps/backend && uv run pytest -q tests/trails/ -q` — 이 런은 role에 `Bash` 도구가 없어 실행 불가. `tests/trails/`의 `test_trails_service.py`는 `fetch_courses`를 DI로 `lambda: [...]` override(실제 함수 미호출), `test_trails_parsers.py`는 `parse_course_list`/`parse_gpx_endpoints` 순수 파서만 직접 테스트 — 두 파일 모두 시그니처 변경의 영향을 받지 않음을 정적 확인. 다음 엔지니어 또는 오너가 위 명령으로 그린 확인 필요.

## 22. Trails — Phase 4: candidate cap으로 GPX fetch 비용 상한(codex verify 지적 반영)

- `app/trails/service.py`에 신규 모듈 상수 `CANDIDATE_LIMIT = 15`를 기존 `TOP_K = 5` 옆에 추가. `TrailsService.get_trails()`에서 `match_region()`이 `matched`를 반환하고 빈 리스트 체크를 통과한 직후, `matched`를 `crsIdx` 오름차순으로 정렬해 첫 `CANDIDATE_LIMIT`(15)개로 잘라낸 뒤에야 GPX-fetch 루프로 진입하도록 변경 — `match_region`이 15건보다 많이 매칭하더라도 GPX fetch/SQM 조회는 항상 결정적으로 선택된 최대 15개 후보로만 상한됨.
- `GET /api/trails` 응답 계약은 변경 없음(§20 그대로 유효) — 이번 변경은 내부 fetch 비용 상한이며, codex verify가 지적한 무제한 fetch 리스크를 방지하기 위한 것.
- `tests/trails/test_trails_service.py`에 신규 `test_candidate_limit_bounds_gpx_fetch_count` 추가 — fake 매칭 코스 20개를 만들어 GPX fetch가 20번이 아닌 정확히 15번만 호출됨을 검증. 기존 6개 코스(limit 미만) 테스트는 무변경, 계속 통과.
- Verify: lead가 `just check`로 풀스위트 그린 확인함 — 96 passed, 7 skipped, 0 failed.

## 23. 관찰 지도 기능 — Phase 1 (eBird 파서 코어, 네트워크 0, 순수 함수만)

- 신규 패키지 `app/observation/`: `models.py`(Pydantic v2, `from __future__ import annotations`) — `Coordinate(lat,lng)`, `BirdSpecies(nameKo,nameSci,speciesCode,count,obsDt)`, `BirdObservation(speciesCount,topSpecies,mostRecentObsDt,status="community")`, `NightSky(sqmValue,bortleClass,skyClass,status="approx")`, `HeritageInfo(addr,distanceM,contentId)`, `ObservationSpot(id,kind:Literal["bird","star","heritage"],name,coord,nightSky|None,birds|None,heritage|None)`, `ObservationMapResponse(region,degraded,spots)`. 아직 어떤 라우터/서비스도 이 모델들을 사용하지 않음(순수 스키마 정의만).
- `app/observation/ebird.py`: `parse_recent_obs(payload: list[dict]) -> list[dict]` — eBird `data/obs/geo/recent` raw 배열 각 아이템을 `{nameKo(←comName), nameSci(←sciName), speciesCode, count(←howMany, optional), obsDt(str 캐스팅), lat/lng(float 캐스팅), locId, locName, obsValid(bool, 기본 True)}`로 정규화. `aggregate_by_location(obs: list[dict]) -> list[dict]` — `locId`별로 그룹핑(첫 등장 순서 유지) 후 `speciesCode`별 최신 관측(obsDt 문자열 비교로 최대값) 1건만 남기고, `count`(None은 최하위) 내림차순 정렬해 상위 5종만 `topSpecies`로 담음. 반환 각 그룹: `{locId,locName,lat,lng,speciesCount,mostRecentObsDt,topSpecies}`.
- 신규 픽스처 `tests/observation/fixtures/ebird_recent_ganghwa.json`(10 레코드, locId 3종: L1163669 4종/4레코드, L1234567 3종, L2345678 2종) + `tests/observation/test_observation_parsers.py`(5개 테스트 — 정규화 필드 검증, 그룹 순서, 그룹별 speciesCount/topSpecies/mostRecentObsDt 검증).
- **네트워크 없는 순수 내부 모듈** — 아직 어떤 엔드포인트로도 노출되지 않음. 라우터는 Phase 3에서 `GET /api/observation-map`으로 publish 예정.

## 24. 관찰 지도 기능 — Phase 2 (eBird config + live fetch + 3-소스 조립 서비스, 라우터 아직 없음)

- `app/suitability/config.py`에 `ObservationConfig(ebird_token, ebird_base_url)` + `get_observation_config()` **추가만** 함(기존 5개 config 함수 무변경). `get_trails_config()` 바로 아래 동일 스타일로 배치. `ebird_token`은 `EBIRD_API_TOKEN`(기본 `""`), `ebird_base_url`은 `EBIRD_API_BASE_URL`(기본 `https://api.ebird.org/v2`).
- `app/observation/ebird.py`에 `fetch_recent_obs(lat, lng, client=None, dist=25, back=14, max_results=100) -> list[dict]` **추가만** 함(Phase 1의 `parse_recent_obs`/`aggregate_by_location`는 바이트 단위로 무변경). `ebird_token`/`ebird_base_url` 중 하나라도 비면 네트워크 호출 없이 즉시 `[]`. 그 외엔 `GET {ebird_base_url}/data/obs/geo/recent`(헤더 `X-eBirdApiToken`, params `lat/lng/dist/back/maxResults/sppLocale=ko`) → `raise_for_status()` → `parse_recent_obs(response.json())`로 **정규화된** 리스트 반환. **모든 예외를 흡수**해 `[]` 반환(raise 없음, durunubi.py `fetch_courses`와 동일한 client-ownership + absorb 패턴). `client` 주입 시 그대로 쓰고 안 닫음, `None`이면 내부에서 `httpx.Client(timeout=10.0)` 생성 후 `finally`에서 close.
- 신규 `app/observation/service.py`: `DEFAULT_REGION_LABEL = "인천 강화군"`(v1 고정 시드, `app.trails.service`와 별개 정의 — import 안 함), 고정 다크스카이 시드 스팟 상수 `OBS_STAR_ID="star:ganghwa-astro"`/`OBS_STAR_NAME="강화 천문인마을"`/`OBS_STAR_LAT=37.7378`/`OBS_STAR_LNG=126.4708`(강화도 고정 좌표, 실 역지오코딩은 스코프 밖). `ObservationMapService(fetch_recent_obs=None, light_pollution_provider=None, fetch_nearby_food=None)` — 생략 시 각각 `ebird.fetch_recent_obs`/`LightPollutionProvider()`/`app.trails.tourapi.fetch_nearby_food`로 기본 배선(TrailsService와 동일 DI 스타일).
- `get_observation_map(lat, lng) -> dict`(plain dict) — bird/star/heritage 3개 소스를 **각각 독립된 `try/except Exception`**으로 감싸 부분 실패를 흡수: (1) bird — `self.fetch_recent_obs(lat,lng)`가 falsy면 `[]`, 아니면 `aggregate_by_location(raw)` 결과를 `{id:'bird:{locId}', kind:'bird', coord, birds:{speciesCount,topSpecies,mostRecentObsDt,status:'community'}, nightSky:None, heritage:None}`으로 매핑. (2) star — 고정 좌표로 `light_pollution_provider.fetch(OBS_STAR_LAT,OBS_STAR_LNG,'night')` 호출해 `nightSky{sqmValue,bortleClass,skyClass,status}` 조립, 실패 시 `star_spot=None`(리스트에서 완전히 제외, degraded 사유 아님). (3) heritage — `fetch_nearby_food(lat,lng)` 각 항목을 `{id:'heritage:{contentId}', kind:'heritage', coord, heritage:{addr,distanceM,contentId}}`로 매핑. `spots = bird_spots + ([star_spot] if star_spot else []) + heritage_spots`(이 순서 고정) → `degraded = (len(spots) == 0)`(3개 소스 중 하나라도 살아있으면 `degraded=False` — 부분 성공은 degrade로 취급 안 함) → `{region, degraded, spots}`.
- `get_default_observation_map_service()`/`_default_observation_map_service`/`get_observation_map_service()` 3종 세트(`app/trails/service.py` 바닥과 동일 패턴, 모듈 싱글톤).
- 신규 `tests/observation/test_observation_service.py` — 5개 테스트, 전부 fake `fetch_recent_obs`/`light_pollution_provider`/`fetch_nearby_food`(lambda·fake 클래스, `LayerReading`은 `app.suitability.providers.base`에서 실제 dataclass 재사용) 주입, 네트워크 0: happy path(4 spots, kind 순서 bird/star/heritage/heritage), bird 소스 raise 흡수(나머지 3개 유지, degraded=False), star 소스 raise 흡수, heritage 소스 raise 흡수, 3개 전부 실패 시 `{region, degraded:True, spots:[]}` 정확히 일치.
- **아직 라우터 없음** — Phase 3에서 `app/routers/observation.py` + `GET /api/observation-map` + `main.py` 등록 예정.
- **⚠️ 이 런은 role에 Bash 도구 자체가 허용되지 않아(모든 명령이 "requires approval") `uv run pytest` 실행 불가.** `service.py`와 `test_observation_service.py` 5개 테스트를 `aggregate_by_location`/`ebird.fetch_recent_obs`/`LightPollutionProvider` 로직에 손으로 트레이스해 정적 검증 완료(happy path의 group 병합·topSpecies 정렬·spots 순서·degraded 계산, 3개 부분실패 케이스 각각의 흡수 지점, 전체실패 시 최종 dict 완전 일치까지 전부 확인). **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest tests/observation/ -q` 및 `uv run pytest -q`(전체 회귀) 실행해서 그린 확인 필요.**

## 25. 관찰 지도 기능 — Phase 3 완료(`GET /api/observation-map` 라이브 엔드포인트 + 오프라인 테스트 + eBird env 문서 + 라이브 스모크) — 계약 publish

**신규 라이브 엔드포인트 — flutter/web/ios/rn이 이제 `GET /api/observation-map`을 mock 대신 직접 호출 가능.**

- Phase 1/2 파일(`app/observation/{models.py,ebird.py,service.py}`, `app/suitability/config.py`)은 이번 phase에서 **읽기만** 했고 전혀 수정하지 않음.
- 신규 `app/routers/observation_map.py` — `app/routers/trails.py`와 완전히 동일한 패턴: `APIRouter(prefix="/api/observation-map")`, 단일 `GET ""` 라우트, `lat`/`lng`를 `Query(..., ge=-90, le=90)`/`Query(..., ge=-180, le=180)`로 선언해 FastAPI 자체가 누락/범위초과 시 422을 반환(별도 검증 헬퍼 없음), `Depends(get_observation_map_service)`로 서비스 주입 후 `service.get_observation_map(lat, lng)` 그대로 반환.
- `app/main.py`: `from app.routers import badges, observation_map, observations, suitability, trails`로 알파벳 순 import에 `observation_map` 추가(언더스코어 `_`가 ASCII상 `s`보다 앞이라 `observation_map` < `observations` 순서 맞음), `app.include_router(observation_map.router)` 추가. 기존 4개 라우터 등록과 `/api/health` 핸들러는 무변경.
- 신규 `tests/observation/test_observation_endpoint.py` — `tests/trails/test_trails_endpoint.py`와 동일 스타일: `FakeObservationMapService`(`get_observation_map(lat,lng)` 메서드로 사전 구성된 dict 반환) + `app.dependency_overrides[get_observation_map_service]` + autouse fixture(기본 fake 설치, 테스트 후 override clear). 5개 테스트: happy path(bird/star/heritage 각 1개, 각 spot이 자기 kind의 필드만 채워지고 나머지 2개는 None — 응답의 전체 키 집합을 `set()`으로 정확히 대조: 최상위 region/degraded/spots, spot당 id/kind/name/coord/nightSky/birds/heritage, birds 서브dict speciesCount/topSpecies/mostRecentObsDt/status, topSpecies 엔트리 nameKo/nameSci/speciesCode/count/obsDt, nightSky 서브dict sqmValue/bortleClass/skyClass/status, heritage 서브dict addr/distanceM/contentId), degraded(spots=[] 확인), lat 누락/lat 범위초과/lng 범위초과 422 3종.
- `.env.example` 끝에 신규 섹션 추가: `EBIRD_API_TOKEN`(플레이스홀더, 토큰 없으면 bird 레이어만 빈 배열로 degrade되고 star/heritage는 정상 동작함을 주석으로 명시), `EBIRD_API_BASE_URL`(선택 항목, 기본값이 이미 `app/suitability/config.py`에 하드코딩되어 있음을 주석으로 명시). 기존 내용은 전혀 건드리지 않음.
- `tests/suitability/test_live.py`: `from app.observation.service import ObservationMapService` import 추가, 신규 `@pytest.mark.live def test_observation_map_service_live_fetch()` — 실제 서비스를 무인자로 생성해 `_GANGHWA_LAT`/`_GANGHWA_LNG`로 `get_observation_map()` 호출, `degraded`가 bool·`spots`가 list인지만 단언하고 star-kind spot이 **정확히 1개** 존재함을 단언(라이트폴루션 프로바이더는 결정적 로컬 휴리스틱이라 네트워크 불필요 — 항상 성공). bird/heritage spot 개수는 `print()`로만 노출(eBird 토큰·TourAPI 키 미설정/네트워크 불가 시 0건이 정상이라 assert 대상 아님). 기존 import/상수/pytestmark/테스트 함수는 전혀 수정하지 않고 끝에 추가만 함.

### `GET /api/observation-map` 계약

```
Query: lat (float, -90..90, required), lng (float, -180..180, required) — 누락/범위초과 시 422.

200 응답 (ObservationMapResponse):
{
  "region": "인천 강화군",          // v1 고정값, 역지오코딩 없음
  "degraded": false,                // bird/star/heritage 3개 소스가 전부 0건일 때만 true
  "spots": [
    {
      "id": "bird:L1163669" | "star:ganghwa-astro" | "heritage:12345",
      "kind": "bird" | "star" | "heritage",
      "name": "...",
      "coord": { "lat": 37.70, "lng": 126.45 },
      "nightSky": { "sqmValue": 21.4, "bortleClass": 3, "skyClass": "Class 3 다크스카이", "status": "approx" } | null,
      "birds": {
        "speciesCount": 12,          // 해당 eBird 핫스팟의 고유 종 수
        "topSpecies": [              // count 내림차순, 최대 5개
          { "nameKo": "저어새", "nameSci": "Platalea minor", "speciesCode": "eaospo1", "count": 5, "obsDt": "2026-09-01 07:30" }
        ],
        "mostRecentObsDt": "2026-09-01 07:30",
        "status": "community"        // 고정 — eBird는 시민과학 이력 데이터, 실시간 아님
      } | null,
      "heritage": { "addr": "인천 강화군 강화읍", "distanceM": 320, "contentId": "12345" } | null
      // kind에 해당하는 필드 1개만 non-null, 나머지 2개는 항상 null
    }
  ]
}
```

- `nightSky.status`는 항상 `"approx"`(정적 lat/lng 휴리스틱, 실제 위성 데이터 아님). `birds.status`는 항상 `"community"`(eBird 시민과학 이력 데이터, `live`/실시간 절대 아님 — 컨슈머 UI 문구가 실시간을 암시하면 안 됨).
- (2026-09-13 추가, spec 018) aggregate_by_location이 핫스팟(locationPrivate=false)을 우선 배치하고 상한 _MAX_LOCATIONS=20으로 슬라이스, 부족분만 개인관측지로 채움 - 개인관측지 name은 _clean_personal_locname으로 주소 접두/좌표 괄호/KR 제거된 짧은 지명(예: 남사읍, 역북동)으로 정리됨. 계약 스키마/필드는 완전히 무변경(name 문자열 품질만 개선).
- **이 응답에는 suitability/적합도 점수 필드가 의도적으로 없음.** 탭한 스팟의 현재 시점 적합도가 필요하면 그 스팟의 `coord`로 **기존** `GET /api/suitability?lat&lng&mode`(§8)를 별도 호출해야 함 — 이번 스펙에 새 적합도 엔드포인트는 없음.
- Verify 명령: `cd apps/backend && uv run pytest tests/observation/ -q`, 그리고 `cd apps/backend && uv run pytest -q`(신규 라이브 테스트가 기본 실행에서 `RUN_LIVE_TESTS` 미설정으로 SKIPPED 뜨는지 확인).
- **⚠️ 이 런도 role에 Bash 도구가 허용되지 않아(모든 명령이 "requires approval") 위 명령을 실제로 실행하지 못함.** `observation_map.py`(trails.py와 줄 단위 대조)·`main.py` import 순서(ASCII `_` < `s`)·`test_observation_endpoint.py` 5개 테스트(FakeService 반환값 → 라우터 → response_model 직렬화 경로를 손으로 트레이스, 각 `set()` 단언이 실제 fake dict 키와 정확히 일치함을 확인)·`.env.example` 포맷(기존 항목과 동일한 "주석 한 줄 + 변수 한 줄" 패턴)·`test_live.py` 추가분(기존 import/상수/pytestmark 무변경, 신규 함수만 끝에 추가)을 전부 정적 재검증 완료. **다음 엔지니어 또는 오너가 위 두 verify 명령을 실행해서 그린 확인(및 라이브 테스트가 SKIPPED로 표시되는지) 필요.**

## 26. 종 정보(Wikipedia) 프록시 Phase 1 완료(GET /api/species 라이브 엔드포인트 + 오프라인 테스트 + env 문서 + 라이브 스모크) — 계약 publish

**신규 라이브 엔드포인트 — flutter 관찰 지도의 조류 탭 종 상세(사진/요약 설명)가 이제 `GET /api/species`를 mock 대신 직접 호출 가능.**

- 신규 `app/species/__init__.py`(빈 파일), `app/species/wikipedia.py`, `app/species/models.py`, `app/species/service.py`, `app/routers/species.py`, `tests/species/__init__.py`(빈 파일), `tests/species/test_species_parser.py`, `tests/species/test_species_endpoint.py`.
- `app/suitability/config.py` 끝(기존 6개 config 함수/`validate_coordinates` 전부 무변경)에 `WikipediaConfig(ko_base_url, en_base_url)` + `get_wikipedia_config()` 추가만 함 — `WIKIPEDIA_KO_BASE_URL`(기본 `https://ko.wikipedia.org/api/rest_v1/page/summary`) / `WIKIPEDIA_EN_BASE_URL`(기본 `https://en.wikipedia.org/api/rest_v1/page/summary`), API 키 불필요.
- 설계: **ko 우선 → en(학명) 폴백**. `wikipedia.fetch_species_summary(name_ko, sci_name, client=None)`는 `name_ko`가 있으면 한국어 위키 REST 요약 API를 먼저 시도하고(404/네트워크 오류/디스앰비규에이션 등 어떤 이유로든 실패하면), `sci_name`이 있을 때만 영어 위키로 재시도한다. 둘 다 실패하거나 둘 다 없으면 `None`을 반환하며 **절대 raise하지 않음**(`app/trails/durunubi.py`와 동일한 client 소유권 + 예외 전면 흡수 패턴: `client=None`이면 `httpx.Client(timeout=10.0)`을 자체 생성해 `finally`에서 close, 주입된 client는 호출부가 소유·닫지 않음).
- `SpeciesService.get_species(sci, ko)`가 `fetch_species_summary`가 `None`을 반환하면 **결과없음도 200**으로 응답 — `nameKo`/`nameSci`는 요청 파라미터 그대로 echo, `summary`/`thumbnailUrl`/`wikiUrl`은 `null`, `source`는 문자열 `"none"`(404 아님, 항상 200).
- 라우터는 `sci`/`ko` 둘 다 없을 때만 422(`detail: "either sci or ko query param is required"`)를 던지고, 나머지는 전부 200.

### GET /api/species 계약

```
Query: sci (string, optional), ko (string, optional) — 최소 하나는 필요, 둘 다 없으면 422.

200 응답 (SpeciesInfo, ko 히트 예시):
{
  "nameKo": "저어새",
  "nameSci": "Platalea minor",
  "summary": "저어새는 저어새과에 속하는 새이다.",
  "thumbnailUrl": "https://upload.wikimedia.org/.../thumb.jpg",
  "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
  "source": "ko.wikipedia"   // "ko.wikipedia" | "en.wikipedia" | "none"
}

200 응답 (결과없음, degrade — 404 아님):
{
  "nameKo": "없는새이름",
  "nameSci": null,
  "summary": null,
  "thumbnailUrl": null,
  "wikiUrl": null,
  "source": "none"
}

422 (sci/ko 둘 다 없음):
{
  "detail": "either sci or ko query param is required"
}
```

- `sci`만 주어지면 ko 시도를 건너뛰고 바로 en 위키로 조회(`nameKo`는 `null`로 echo).
- **⚠️ 이 런도 role에 Bash 도구가 허용되지 않아(`uv run pytest -q` 포함 모든 실행형 명령이 "requires approval") 테스트를 실제로 실행하지 못함.** 9개 신규/수정 파일 전체를 스펙 요구사항과 줄 단위로 대조해 정적 재검증 완료: `parse_summary_response`(정상/필드누락/disambiguation 3케이스를 로직에 직접 대입), `fetch_species_summary`의 ko→en 폴백 순서와 client 소유권(`durunubi.py`와 나란히 비교), `SpeciesService.get_species`의 None/non-None 분기, 라우터의 422 조건과 `response_model=SpeciesInfo` 직렬화 경로, `main.py` 알파벳 순서(`species` < `suitability`) 삽입, `config.py`/`.env.example`가 기존 내용 끝에만 추가되고 기존 함수/주석 라인은 단 한 글자도 바뀌지 않았음을 재확인, `test_live.py`는 기존 import 그룹에 한 줄만 추가하고 기존 6개 라이브 테스트 함수는 무변경. **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest -q`(신규 species 테스트 전부 통과 + 신규 라이브 테스트 1개가 `RUN_LIVE_TESTS` 미설정 시 SKIPPED로 표시되는지 확인) 및 `RUN_LIVE_TESTS=1 uv run pytest -m live -q`(실제 위키 응답 확인)를 실행해서 그린 확인 필요.**

## 27. 두루누비 코스 리치 상세 Phase 2 완료(GET /api/trails/detail 라이브 엔드포인트 + 오프라인 테스트 + 라이브 스모크) — 계약 publish

**신규 라이브 엔드포인트 — 기존 `GET /api/trails` 목록 계약과 그 파서/모델/라우터(`durunubi.py`/`app/trails/models.py`의 기존 클래스/`app/routers/trails.py`)는 전혀 건드리지 않고, 같은 두루누비 `courseList` 응답을 재사용해 코스 상세(설명·테마·시종점명·표고 프로필)를 별도 엔드포인트로 제공.**

- 신규 `app/trails/durunubi_detail.py`(`parse_course_detail_item`, `parse_gpx_elevation_profile`, `fetch_course_detail`), `app/routers/trails_detail.py`(`GET /api/trails/detail`, `get_course_detail_fetcher` DI 훅), `tests/trails/test_course_detail.py`, `tests/trails/test_trails_detail_endpoint.py`. `app/trails/models.py`는 끝에 `ElevationPoint`/`TrailDetailResponse` 클래스 2개 추가만 함(기존 클래스 무변경).
- 설계: 두루누비에는 상세 전용 API가 없으므로 `fetch_course_detail`이 `courseList`를 다시 조회(`numOfRows=1000&pageNo=1&brdDiv=DNWW`, `durunubi.py`의 `fetch_courses`와 완전히 동일한 client 소유권/파라미터 재사용, `get_trails_config()` 그대로, 신규 config 없음)해 `crsIdx`가 일치하는 raw item을 찾고, 목록 파서(`parse_course_list`)가 버리던 `crsContents`/`crsSummary`/`crsTourInfo`(설명, 첫 비어있지 않은 값), `travelerinfo`(시점·종점 텍스트, 정규식 `시점\s*[:：]\s*([^<\r\n]+)`/`종점\s*[:：]\s*([^<\r\n]+)`로 파싱), `routeIdx`(테마ID)를 뽑아낸다.
- **화장실/교통/편의시설/대표이미지는 이번 스코프에서 완전히 제외** — 실측으로 확인된 두루누비 응답 필드가 없어서 모델에 그 필드들을 아예 만들지 않았다(없는 걸 항상 null로 내리는 죽은 필드를 피하기 위함). 필요해지면 별도 데이터 소스 조사 후 신규 스펙으로 추가해야 함.
- `elevationProfile`의 x축이 `distanceKm`(실 km)이 아니라 `positionRatio`(0.0~1.0, GPX trackpoint 인덱스 기반)인 이유: `/api/trails`가 내려주는 `distanceKm`(두루누비 `crsDstnc` 공식 값)과 GPX trackpoint 개수로 역산한 거리가 서로 다른 값이 나올 위험이 있어, 두 수치가 충돌하는 상황 자체를 피하려고 상대 위치 비율만 제공한다. 프론트에서 실제 km축이 필요하면 `distanceKm * positionRatio`로 근사만 가능(정확한 km는 아님을 인지할 것).
- `found=False`는 "코스ID 자체를 찾지 못함"(API는 정상, `degraded=false`)과 "API 실패/키 미설정/네트워크 오류"(항상 `degraded=true`)를 구분해서 반환 — 프론트가 두 상황을 다르게 다룰 수 있음.
- GPX 표고 프로필 fetch 실패는 부분 흡수(`elevationProfile=[]`)만 되고 나머지 필드(description/themeId/startName/endName)는 정상 반환됨 — GPX 서버 장애가 코스 상세 전체를 죽이지 않음.

### GET /api/trails/detail 계약

```
Query: crsIdx (string, required, min_length=1)

200 응답 (TrailDetailResponse, found=true 예시):
{
  "crsIdx": "T_CRS_MNG0000005118",
  "found": true,
  "description": "남파랑길 3코스는...(crsContents/crsSummary/crsTourInfo 중 첫 비어있지 않은 값)",
  "themeId": "T_ROUTE_MNG0000000001",
  "startName": "영도대교 입구(부산 중구 태종로 8)",
  "endName": "감천사거리(부산 사하구 감천동)",
  "travelerInfo": "- 시점 : 영도대교 입구(부산 중구 태종로 8)<br>교통편) 지하철 남포역 6번출구 도보 이동<br>- 종점 : 감천사거리...",
  "tourInfo": "- 부산의 유명한 관광지인 용두산공원, 국제시장, 자갈치 수산시장<br>...(crsTourInfo 원문, HTML <br> 포함)",
  "elevationProfile": [
    { "positionRatio": 0.0, "elevationM": 8.102 },
    { "positionRatio": 0.2, "elevationM": 9.607 },
    { "positionRatio": 1.0, "elevationM": 16.742 }
  ],
  "degraded": false
}
// travelerInfo = 두루누비 travelerinfo 원문(교통편·시점/종점 포함, HTML <br> 포함, 없으면 null).
//   startName/endName은 이 원문에서 정규식 추출한 값이라 중복이나, 원문엔 교통편 등 추가 정보가 있어 함께 노출.
// tourInfo = 두루누비 crsTourInfo 원문(주변 관광정보, HTML <br> 포함, 없으면 null).
// 편의시설·화장실·대표이미지는 두루누비 courseList API에 필드 자체가 없어 미노출(정직).

200 응답 (found=false 예시 — 코스ID 없음, API 자체는 정상):
{
  "crsIdx": "T_CRS_MNG_NOT_EXIST",
  "found": false,
  "description": null,
  "themeId": null,
  "startName": null,
  "endName": null,
  "travelerInfo": null,
  "tourInfo": null,
  "elevationProfile": [],
  "degraded": false
}
// 참고: 키 미설정/네트워크·API 실패로 인한 found=false는 필드 구성은 동일하되 "degraded": true.

422 (crsIdx 쿼리 파라미터 누락, 표준 FastAPI validation error body):
{
  "detail": [
    { "type": "missing", "loc": ["query", "crsIdx"], "msg": "Field required", "input": null }
  ]
}
```

- Verify 명령: `cd apps/backend && uv run pytest tests/trails/test_course_detail.py tests/trails/test_trails_detail_endpoint.py -q`, 그리고 `cd apps/backend && uv run pytest -q`(신규 라이브 테스트 `test_durunubi_course_detail_live_fetch`가 `RUN_LIVE_TESTS` 미설정 시 SKIPPED로 뜨는지 및 기존 트레일/스위터빌리티 테스트가 전혀 안 깨졌는지 확인), 실키 확인은 `RUN_LIVE_TESTS=1 uv run pytest -m live -q`.
- **이 런은 role에 Bash 실행 권한이 없어(모든 `uv run`/`python3` 등 실행형 명령이 "requires approval") 위 명령들을 실제로 실행하지 못함.** 대신 전체 diff를 스펙 요구사항과 줄 단위로 정적 재검증했습니다: (1) `parse_course_detail_item`을 `test_course_detail.py`의 3개 케이스 입력값에 손으로 대입해 기대 dict와 정확히 일치함을 확인, (2) `parse_gpx_elevation_profile`을 `tests/trails/fixtures/durunubi_course.gpx`의 실제 6개 trkpt(ele=8.102/9.607/10.271/15.042/15.76/16.742)에 트레이스해 `n=6, step=max(1,6//20)=1`이라 6개 전부 살아남고 마지막이 이미 `positionRatio=1.0`이라 중복 추가가 안 됨을 확인(빈 문자열은 `n=0`→`[]`), (3) `fetch_course_detail`의 client 소유권/파라미터/예외 흡수 3분기(config 없음→degraded=True, resultCode≠0000 또는 item 없음/crsIdx 불일치→found=False&degraded=False, GPX fetch 실패→elevationProfile만 빈 배열, 그 외 모든 예외→outer try/except가 degraded=True로 흡수)를 `durunubi.py`의 `fetch_courses`/`fetch_gpx_endpoints`와 나란히 비교, (4) `app/routers/trails_detail.py`의 DI 오버라이드 패턴을 `test_trails_endpoint.py`와 동일 스타일로 작성했는지 확인, (5) `main.py`가 ASCII 정렬 기준 `suitability < trails < trails_detail` 순서를 지키고 기존 5개 라우터 등록 줄·`/api/health`는 한 글자도 안 바뀌었음을 확인, (6) `tests/suitability/test_live.py`는 기존 import 그룹에 import 한 줄, 파일 끝에 함수 하나만 추가하고 기존 내용은 무변경. **다음 엔지니어 또는 오너가 위 verify 명령들을 실행해서 전체 그린(기존 트레일/스위터빌리티 테스트 포함) 및 라이브 테스트 SKIPPED 표시를 최종 확인 필요.**

## 28. 종 정보(Wikipedia) — 크로스모델 검증 FAIL 1건 수정(예외 흡수 범위 버그, 계약 무변경)

- 크로스모델 검증에서 `app/species/wikipedia.py`의 `fetch_species_summary()`가 `get_wikipedia_config()`와 `httpx.Client(timeout=10.0)` 호출을 `try` 블록 **진입 전**에 실행하고 있어, 이 두 호출에서 발생하는 예외가 스펙이 요구하는 대로 `None`으로 흡수되지 않던 버그를 찾음.
- 수정(이전 세션에서 이미 적용됨, 이번엔 문서화만 함): `owns_client = client is None`은 그대로 `try` 이전에 두되, config 조회와 client 생성 부분을 `try` 블록 **안**으로 이동. `finally`절의 `client.close()` 가드도 `if owns_client and client is not None`으로 변경해, client 생성 자체가 실패해 `client`가 `None`인 경우 `close()`를 호출하지 않도록 함.
- ko/en 폴백 호출을 감싸는 내부 `try/except`, 그리고 `_fetch_summary`/`parse_summary_response`는 무변경.
- **`GET /api/species` API 계약(섹션 26의 request/response 스키마)은 전혀 변경되지 않음** — 순수 내부 방어 코드 수정.
- `just check`를 lead가 직접 실행해 132 passed, 10 skipped, 0 failed, 회귀 없음 확인됨.

## 29. 종 상세 위키 설명 확장(summaryLong) — GET /api/species 계약 확장

- `GET /api/species` 응답(`SpeciesInfo`)에 nullable 필드 `summaryLong: str | None` 1개가 추가됨 — 기존 6개 필드(`nameKo`, `nameSci`, `summary`, `thumbnailUrl`, `wikiUrl`, `source`)는 전혀 변경되지 않음.
- `summaryLong`은 `apps/backend/app/species/wikipedia.py`의 신규 함수 `fetch_species_extract()`가 채움. MediaWiki `action=query&prop=extracts&exintro=1&explaintext=1&format=json&titles=...`를 ko.wikipedia.org에 먼저 호출하고 실패 시 en.wikipedia.org로 폴백(기존 짧은 summary와 동일한 ko→en 패턴, 단 독립적인 fetch라 한쪽만 성공하고 다른 쪽은 실패할 수 있음). 결과는 가능하면 문장 경계에서 최대 1500자로 트림되고, 양 언어 모두 실패하거나 어떤 예외가 나도 `None`(never raises, 기존 `summary`/`thumbnailUrl`/`wikiUrl` 필드는 절대 깨지지 않음).
- 200 응답 예시 (summaryLong populated):
```json
{
  "nameKo": "저어새",
  "nameSci": "Platalea minor",
  "summary": "저어새는 저어새과에 속하는 대형 섭금류이다.",
  "summaryLong": "저어새는 저어새과에 속하는 대형 섭금류로, 부리가 주걱 모양으로 넓적한 것이 특징이다. 한국, 대만, 일본, 중국 연안에서 번식하며 겨울에는 동남아시아로 이동한다.",
  "thumbnailUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/example.jpg",
  "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
  "source": "wikipedia"
}
```
- 200 응답 예시 (summaryLong이 null이고 다른 필드는 채워진 경우):
```json
{
  "nameKo": "저어새",
  "nameSci": "Platalea minor",
  "summary": "저어새는 저어새과에 속하는 대형 섭금류이다.",
  "summaryLong": null,
  "thumbnailUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/example.jpg",
  "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
  "source": "wikipedia"
}
```
- Verify 명령: `cd apps/backend && uv run pytest tests/species/test_extract.py tests/species/test_species_endpoint.py -q`
- `just check`를 lead가 직접 실행해 전체 그린(backend + flutter, 회귀 없음) 확인됨.

DONE: backend-engineer | member.md에 섹션 29(summaryLong 계약) 추가, 기존 섹션 무변경

## 30. 보호종 지정 정보(conservation) — 정적 하드코딩 룩업, 외부 API 없음

- `GET /api/species` 응답(`SpeciesInfo`)에 nullable 필드 `conservation: Conservation | None` 1개가 추가됨 — 기존 8개 필드(`nameKo`/`nameSci`/`summary`/`thumbnailUrl`/`wikiUrl`/`source`/`summaryLong`)는 전혀 변경되지 않음. `Conservation` 모델은 `naturalMonument`/`koreaEndangered`/`iucn` 3개 nullable 필드로만 구성.
- 신규 `app/species/conservation.py` — 학명(소문자·trim 정규화) 키 10종(저어새/노랑부리백로/황새/두루미/재두루미/흑두루미/검은머리물떼새/알락꼬리마도요/고니/큰고니)만 담은 모듈 레벨 하드코딩 `_SEED` dict. **네트워크 호출도 추론도 없는 순수 dict 룩업**(정확성/anti-hallucination 요구사항 — 이 10종 외에는 절대 값을 만들어내지 않음). `lookup_conservation(sci_name, name_ko)`는 학명을 우선 정규화 매칭하고, 실패 시 국명(`name_ko.strip()`)을 `_SEED`의 `nameKo` 값과 정확히 일치하는 것으로만 폴백 매칭(퍼지 매칭 없음). 둘 다 실패하면 `None`.
- `service.py`의 `SpeciesService.get_species()`가 `conservation.lookup_conservation(sci, ko)`를 호출해 응답 dict의 `"conservation"` 키를 채움. **3개 필드가 전부 null이면(예: 룩업은 됐지만 값이 비어있는 경우) `"conservation": None`으로 강제**해 프런트가 섹션을 숨기도록 신호. `fetch_species_summary`/`fetch_species_extract` 로직·계약은 전혀 손대지 않음(그대로 유지).
- 200 응답 예시 (populated — 저어새):
```json
{
  "nameKo": "저어새",
  "nameSci": "Platalea minor",
  "summary": "저어새는 저어새과에 속하는 대형 섭금류이다.",
  "summaryLong": null,
  "thumbnailUrl": "https://example.com/thumb.jpg",
  "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
  "source": "ko.wikipedia",
  "conservation": {
    "naturalMonument": "천연기념물 제205-1호",
    "koreaEndangered": "멸종위기 I급",
    "iucn": "EN"
  }
}
```
- 200 응답 예시 (null — 목록에 없는 종, 예: 까치):
```json
{
  "nameKo": "까치",
  "nameSci": null,
  "summary": "...",
  "summaryLong": null,
  "thumbnailUrl": null,
  "wikiUrl": null,
  "source": "ko.wikipedia",
  "conservation": null
}
```
- `_SEED`에 있는 `numenius madagascariensis`(알락꼬리마도요)처럼 일부 필드만 값이 있는 경우 `conservation`은 `None`이 아니라 `{"naturalMonument": null, "koreaEndangered": "멸종위기 II급", "iucn": "EN"}` 형태로 채워짐(하나라도 non-null이면 섹션 표시).
- 신규 `tests/species/test_conservation.py` 5개 테스트: (a) 정확 시드값 매칭, (b) 목록 밖 종 → None, (c) 대소문자/공백 무시 학명 매칭, (d) 부분 필드 종(알락꼬리마도요) naturalMonument만 null, (e) `SpeciesService.get_species()` 실제 conservation 모듈로(모킹 없음) known/unknown 종 각각 populated/None 확인.
- 기존 `tests/species/test_species_endpoint.py`의 `test_happy_path_returns_full_contract` 키 집합 assertion에 `"conservation"` 1개 추가(응답 필드가 늘어난 데 따른 최소 필수 수정, 섹션 29 때 `summaryLong` 추가와 동일 패턴).
- Verify 명령: `cd apps/backend && uv run pytest tests/species/ -q`
- **이 런은 role에 Bash 실행 권한이 없어(`uv run pytest ...` 호출이 "requires approval"로 즉시 거부됨, 재시도하지 않음) 실제로 실행하지 못함.** 대신 5개 테스트 케이스를 `lookup_conservation`/`SpeciesService.get_species` 로직에 직접 손으로 대입해 전부 기대값과 일치함을 확인했습니다: `_normalize("  PLATALEA MINOR  ")` → `"platalea minor"` → `_SEED` 히트, `Corvus corax`/`큰까마귀` → 학명·국명 둘 다 미스 → `None`, `Numenius madagascariensis` → `naturalMonument=None` 나머지 non-null 그대로 반환, service 레이어는 `fetch_species_summary`/`fetch_species_extract`를 람다로 주입하되 `conservation` 모듈은 실제 그대로 사용해 known/unknown 각각 populated/`None`을 확인. **다음 엔지니어 또는 오너가 위 verify 명령을 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | app/species/conservation.py 신규(10종 하드코딩 dict 룩업, 네트워크·추론 없음), models.py에 Conservation 모델+conservation 필드 추가, service.py에서 get_species() 응답에 conservation 채움, test_conservation.py 5개 테스트 추가(Bash 미가용으로 수동 트레이스만 완료)

## 31. 좌표 기반 "오늘의 조위 극값" 신규 엔드포인트 — `GET /api/tide/today` publish

**신규 라이브 엔드포인트 — 기존 `GET /api/suitability`의 tide 레이어(§14~16, `app/suitability/providers/tide.py`/`tide_stations.py`)는 코드 한 줄도 건드리지 않고, 그 모듈의 파싱/분류/관측소 헬퍼(`nearest_station`, `_haversine_km`, `_parse_xml_items`, `_classify_extremes`)만 import해서 재사용한 별도 엔드포인트.**

- 신규 `app/species/tide_today.py`(`TideExtreme`/`TideTodayResponse` Pydantic 모델, `fetch_today_tides(lat, lng, client=None) -> dict`), `app/routers/tide.py`(`GET /api/tide/today`, `get_today_tides_fetcher` DI 훅), `tests/tide/__init__.py`(빈 파일), `tests/tide/test_tide_today.py`, `tests/tide/test_tide_today_endpoint.py`.
- `app/main.py`: import 튜플에 `tide` 1줄 추가(ASCII 정렬상 `suitability`와 `trails` 사이), `app.include_router(tide.router)` 1줄 추가. 위치는 `app.include_router(trails_detail.router)` 바로 다음(기존 `observation_map.router` 등록 줄보다 앞) — 기존 include_router 6줄은 순서·내용 전혀 안 건드림.
- 설계: `nearest_station(lat,lng)`으로 최근접 관측소를 찾고 `_haversine_km` 거리가 **20km 초과**면 네트워크 호출 없이 즉시 `{found:false, degraded:false}`(내륙/무관 좌표로 판단 — 임계값은 spec 지정값, 36개 관측소 커버리지 기준 임의 상수이므로 추후 조정 여지 있음). 20km 이내면 `get_tide_config()` 확인(키/URL 없으면 `degraded:true`) 후 `tide.py`의 `TideProvider.fetch()`와 동일한 client 소유권 패턴으로 KHOA XML을 가져와 `_parse_xml_items`+`_classify_extremes`(전체 엔트리에 대해 이웃비교 분류 후 오늘 날짜만 필터링, 이 순서가 중요 — 필터링부터 하면 경계의 극값이 이웃을 잃어 오분류될 수 있음)로 오늘(KST) 극값만 추출. KHOA 호출~파싱 전체를 `try/except Exception`으로 감싸 어떤 실패든 `{found:false, degraded:true}`로 흡수(raise 없음).
- `app/suitability/providers/tide.py`/`tide_stations.py` 자체는 이번 작업에서 **읽기만** 하고 완전히 무변경 — 기존 `GET /api/suitability`의 tide 레이어 동작에 영향 없음.

### `GET /api/tide/today` 계약

```
Query: lat (float, required), lng (float, required) — 둘 중 하나라도 누락 시 표준 FastAPI 422.

200 응답 (TideTodayResponse, 매칭+정상):
{
  "found": true,
  "degraded": false,
  "stationName": "인천",
  "extremes": [
    { "time": "06:00", "kind": "high", "levelCm": 500 },
    { "time": "12:00", "kind": "low", "levelCm": 90 }
  ]
}

200 응답 (내륙/무관 좌표 — 가장 가까운 관측소도 20km 초과):
{ "found": false, "degraded": false, "stationName": null, "extremes": [] }

200 응답 (연안 좌표이지만 config 미설정 또는 KHOA 호출/파싱 실패):
{ "found": false, "degraded": true, "stationName": null, "extremes": [] }
```

- `found`/`degraded` 의미: `found=false, degraded=false`는 "이 좌표는 조위 데이터 대상이 아님"(내륙, 정상 판단)이고, `found=false, degraded=true`는 "연안 좌표인데 실데이터를 못 가져옴"(설정/네트워크/파싱 실패) — 프론트가 두 경우를 다르게 안내해야 함(전자는 UI 자체를 숨기고, 후자는 "일시적으로 조위 정보를 불러올 수 없습니다" 류 메시지 권장).
- `extremes[].kind`는 `"high"` | `"low"`, `levelCm`은 반올림된 정수(음수 가능, 원본이 cm 단위 실수).
- 20km 임계값은 하드코딩 상수(`_MAX_STATION_DISTANCE_KM`) — 필요시 조정 가능하나 이번 스펙 범위에선 고정값.
- Verify 명령: `cd apps/backend && uv run pytest tests/tide/ -q`, 그리고 `cd apps/backend && uv run pytest -q`(회귀 없음 확인).
- **이 런은 role에 Bash 실행 권한이 없어(`uv run pytest tests/tide/ -q` 호출이 "requires approval"로 거부됨, `pwd` 등 단순 명령은 통과) 실제로 실행하지 못함.** 대신 5개 오프라인 테스트(정상 매칭+오늘 필터+분류, 내륙좌표 네트워크 미호출, config 미설정 degraded, KHOA HTTP 에러 degraded, malformed XML degraded)와 3개 엔드포인트 테스트(200 직렬화, lat/lng 각각 누락 422)를 `fetch_today_tides` 로직에 직접 손으로 대입해 전부 기대값과 일치함을 확인했습니다(인천 좌표 거리=0, `_classify_extremes([100,500,90,480])` 이웃비교 결과 low/high/low/high 전부 재현). **다음 엔지니어 또는 오너가 위 verify 명령을 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | app/species/tide_today.py + app/routers/tide.py 신규(GET /api/tide/today, 기존 tide.py/tide_stations.py는 import만 하고 무변경), main.py에 라우터 등록 2줄 추가, tests/tide/ 5+3개 테스트 추가(Bash 미가용으로 수동 트레이스만 완료)

## 32. 리뷰 결함 2건 수정 — 2026-09-14

- `wikipedia.py`의 `_truncate_extract()`: `window = extract[:_EXTRACT_MAX_LEN + 1]`가 인덱스 1500(1501번째 글자)까지 포함해 그 위치에 문장부호가 있으면 1501자를 반환하던 버그를 `extract[:_EXTRACT_MAX_LEN]`(인덱스 0~1499만)으로 수정. 문장부호 탐색/하드컷 폴백 로직은 무변경. `test_extract.py`에 경계 테스트(`test_long_extract_with_punctuation_exactly_at_cap_boundary_stays_within_limit`) 추가 — 1500번째 인덱스(1501번째 글자)에 정확히 `.`이 오는 입력으로 구버전 코드였다면 1501자가 반환됨을 재현.
- `tide_today.py`의 `TideExtreme.kind`를 `str` → `Literal["high", "low"]`로 제한(spec 022 §"kind:high|low" 계약 반영). 다른 필드/로직 무변경.
- Verify 명령: `cd apps/backend && uv run pytest -q`.
- 이 런도 role에 Bash 실행 권한이 없어(`uv run pytest -q` 등 모든 호출이 "requires approval"로 즉시 거부) 실제 실행 못함. 대신 정적 재검증 완료: (1) 새 window가 인덱스 0~1499만 커버하므로 `last_idx`는 최대 1499, `last_idx+1` 최대 1500 → 출력 길이 항상 ≤1500; 문장부호 미검출 시 하드컷도 정확히 1500자. (2) 신규 테스트를 손으로 트레이스 — `"가"*1500 + "." + "나"*50` 입력 시 window="가"*1500(점 없음) → rfind 전부 -1 → 하드컷 `extract[:1500]`="가"*1500, len=1500, assert 통과(구버전이면 window에 점이 포함되어 1501자 반환 후 실패했을 것). (3) `Literal["high","low"]` 임포트/타입 문법 확인, `fetch_today_tides()`가 채우는 값은 이미 `"high"`/`"low"` 리터럴이라 회귀 없음. **다음 엔지니어 또는 오너가 `cd apps/backend && uv run pytest -q` 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | wikipedia.py `_truncate_extract()` off-by-one 수정(window 1501→1500자), tide_today.py `TideExtreme.kind`를 `Literal["high","low"]`로 제한, test_extract.py에 경계 테스트 1건 추가(Bash 미가용으로 수동 트레이스만 완료)

## 33. astronomy golden_hours의 mode 게이팅 제거 — day에서도 밤 골든타임 항상 계산

- `providers/astronomy.py`의 `AstronomyProvider.parse()`: `mode=='day'`일 때 `aste` 파싱을 건너뛰고 `golden_hours=[]`를 즉시 반환하던 분기를 제거. 이제 mode와 무관하게 항상 `aste`를 파싱해 밤·천체 골든윈도우(mode 필드는 항상 `'night'`, label `'밤 · 천체 골든타임'`)를 계산하고 `golden_hours`에 채움. `aste` 파싱 실패 시에도 mode 무관하게 `status='unavailable', sub_score=0`으로 degrade(과거엔 day에서 이 실패 경로 자체가 없었음). `sub_score`만 여전히 mode 분기 유지(`day`→`_DAY_SUB_SCORE=75`, 그 외→`100 - illumination_pct`).
- `tests/suitability/test_astronomy_provider.py`: `test_day_mode_produces_no_golden_hours`를 `test_day_mode_still_produces_one_night_golden_hour`로 교체(day에서도 golden_hours 1개, mode=='night', timeRange 형식 검증). `test_night_mode_missing_twilight_key_degrades_to_unavailable`을 `@pytest.mark.parametrize("mode", ["day","night"])`로 확장해 양쪽 mode 모두 aste 없으면 unavailable/sub_score=0 확인.
- Verify: `cd apps/backend && PYTHONPATH=. python -m pytest tests/suitability/test_astronomy_provider.py -q` — 이 런은 role에 Bash 실행 권한이 없어(모든 `uv run`/`python -m pytest` 호출이 "requires approval"로 즉시 거부) 실제 실행 못함. 대신 픽스처 값을 손으로 트레이스해 정적 검증 완료: `aste="2021  "` → strip 후 `_parse_hhmm`으로 정상 파싱(day/night 공통), `lunAge=26.8` 정상, twilight 없는 케이스는 `_parse_hhmm(None)`이 `ValueError`를 던져 mode와 무관하게 unavailable로 귀결. 다른 provider/consumer 코드에서 astronomy의 day golden_hours가 항상 빈 배열이라고 가정하는 곳은 없음을 grep으로 확인(`service.py`/`test_endpoint.py`/`test_scoring.py`는 astronomy provider 내부 로직과 무관). **다음 엔지니어 또는 오너가 위 verify 명령을 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | astronomy.py `parse()`에서 golden_hours의 mode 게이팅 제거(day에서도 aste 파싱+night 골든타임 계산, sub_score만 mode 분기 유지), test_astronomy_provider.py 2개 테스트 교체(Bash 미가용으로 수동 트레이스만 완료)

## 34. tide golden_hours의 mode 게이팅 제거 — night에서도 낮 골든타임 항상 계산

- `providers/tide.py`의 `TideProvider.parse()`: `mode=='day'`일 때만 `daytime_highs`를 계산하던 분기를 제거. 이제 mode와 무관하게 항상 `daytime_highs`를 계산해 낮·탐조 골든윈도우(mode 필드는 항상 `'day'`, label `'낮 · 탐조 골든타임'`)를 `golden_hours`에 채움. `daytime_highs`가 비어 있으면 mode 무관하게 `ValueError('no daytime high tide in KHOA response')`(`fetch()`의 try/except가 흡수해 stub으로 degrade, 안전). `sub_score`만 여전히 mode 분기(`day`→`_DAY_GOLDEN_SUB_SCORE=85`, 그 외→`_NIGHT_SUB_SCORE=70`). `_stub_reading()`도 동일하게 mode 조건 없이 항상 낮 골든타임 스텁 항목 포함(`sub_score`는 기존 `_SUB_SCORE` 그대로, mode 무관 무변경).
- `tests/suitability/test_tide_provider.py`: `test_night_mode_never_produces_golden_hours`를 `test_night_mode_still_produces_day_golden_hour_with_lower_sub_score`로 교체(night에서도 golden_hours 1개, mode=='day', timeRange=='12:46 - 14:46', sub_score==70 검증). `test_day_mode_raises_when_no_daytime_high_tide_exists`를 `@pytest.mark.parametrize("mode", ["day","night"])`로 확장해 양쪽 mode 모두 daytime high 없으면 ValueError 확인.
- Verify: `cd apps/backend && PYTHONPATH=. python -m pytest tests/suitability/test_tide_provider.py -q` — 이 런은 role에 Bash 실행 권한이 없어(`uv run`/`python -m pytest` 전부 "requires approval"로 즉시 거부) 실제 실행 못함. 대신 픽스처 값을 손으로 트레이스해 정적 검증 완료: `khoa_tide_sample.xml`의 유일한 daytime high는 `12:46`(day/night 공통) → golden `12:46 - 14:46`, night sub_score=70. `_make_item` 4개 항목(daytime high 없음) 케이스는 day/night 둘 다 `ValueError` 도달 확인. `fetch()`/`service.py`/`test_endpoint.py`는 tide provider의 `parse()`/`_stub_reading()` 시그니처를 그대로 호출하므로 이번 변경으로 깨지지 않음(golden_hours 개수만 night에서 0→1로 늘어남, 이를 가정하는 다른 코드 없음을 grep으로 확인). **다음 엔지니어 또는 오너가 위 verify 명령을 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | tide.py `parse()`/`_stub_reading()`에서 golden_hours의 mode 게이팅 제거(night에서도 daytime 골든타임 항상 계산, sub_score만 mode 분기 유지), test_tide_provider.py 2개 테스트 교체(Bash 미가용으로 수동 트레이스만 완료)

## 35. goldenHours 응답 순서 고정 — day-first, night-second

- `service.py`의 `SuitabilityService.get_suitability()`: `golden_hours` 리스트를 `LAYER_KEYS` 순회로 다 채운 직후(50번째 줄 뒤, `light_pollution_evidence` 처리 전) `golden_hours.sort(key=lambda g: 0 if g.mode == "day" else 1)` 1줄 추가. `LAYER_KEYS=('environment','astronomy','lightPollution','tide')` 순회상 astronomy(night)가 tide(day)보다 먼저 append되어 night가 항상 day보다 앞에 오던 문제를 stable sort로 교정 — 이제 `goldenHours[0]`은 항상 day, `[1]`은 항상 night(§33/§34로 두 항목이 mode 무관 항상 존재하게 된 뒤 드러난 순서 버그).
- `tests/suitability/test_endpoint.py`의 `test_happy_path_returns_full_contract`: `len(goldenHours)==2` 검증 직후 `goldenHours[0]["mode"]=="day"`, `goldenHours[1]["mode"]=="night"` assertion 2줄 추가(`_healthy_providers()`가 astronomy를 tide보다 먼저 정의하므로 정렬 로직 없으면 이 assertion이 실패).
- Verify: `cd apps/backend && PYTHONPATH=. python -m pytest tests/suitability/test_endpoint.py -q` — 이 런도 role에 Bash 실행 권한이 없어(`uv run`/`python -m pytest`/`python3 -c` 전부 "requires approval"로 즉시 거부, `pwd`만 통과) 실제 실행 못함. 대신 정렬 로직을 순수 Python 리스트로 손으로 트레이스: `[GoldenHour(mode='night'), GoldenHour(mode='day')]` → sort key `[1,0]` → stable sort 결과 `[day, night]` 확인. `GoldenHour.mode`는 `models.py`에서 plain `str` 필드(enum 아님)이므로 `"day"`/`"night"` 문자열 비교가 정확히 동작. 다른 기존 테스트는 건드리지 않음. **다음 엔지니어 또는 오너가 위 verify 명령을 실행해 전체 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | service.py에 golden_hours.sort() 1줄 추가로 goldenHours가 항상 day-first/night-second로 반환되도록 수정, test_endpoint.py에 순서 assertion 2줄 추가(Bash 미가용으로 수동 트레이스만 완료)

## 36. 밤 골든타임 — 고정 220분 휴리스틱 → 실제 암천(dark-sky) 창 + 달 위상 인지 무월광 구간 계산

- `providers/astronomy.py`의 `AstronomyProvider.parse()` 밤 골든타임 로직을 전면 교체. `_MOON_BRIGHT_PCT = 50` 상수 신설(`_GOLDEN_WINDOW_MINUTES` 옆). 새 순수 헬퍼 `_format_minute_of_day(total_minutes)`(24시간 wrap을 `% 1440` 후 `_format_hhmm` 재사용)와 `_moonless_segments(window_start, window_end, moon_start, moon_end)`(암천창에서 달 뜬 구간을 뺀 나머지, 최대 2개 세그먼트 반환, 전혀 안 겹치면 원 창 그대로, 완전히 덮으면 빈 리스트) 신설. 더 이상 쓰이지 않게 된 기존 `_add_minutes` 헬퍼는 삭제.
- 알고리즘: (1) `aste`(저녁 천문박명) → `darkStart`(분). 파싱 실패면 기존 그대로 `unavailable`/`sub_score=0`(무변경, `test_missing_twilight_key_degrades_to_unavailable` 그대로 통과). (2) `astm`(아침 천문박명) 파싱 성공 시 `darkEnd`(자정 넘김 보정) 계산 후 `windowSource='darkSky'`; 실패/없으면 `darkStart+220분` 고정창 그대로 쓰고 `windowSource='fixedFallback'`(이 경로는 달 로직 전체를 건너뛰고 기존 설명 포맷 그대로 유지 — 순수 회귀 경로). (3) `darkSky`일 때만 `moonrise`/`moonset` 파싱 시도, 하나라도 실패/없으면 골든구간=암천창 전체 채택. 둘 다 성공하면 `darkStart` 기준 정규화(`moonriseNorm`/`moonsetNorm`, 자정 넘김 보정)로 달이 떠있는 구간 계산. (4) `illumination_pct`(기존 공식 무변경)가 `_MOON_BRIGHT_PCT` 미만이면 달을 무시하고 골든구간=암천창 전체. (5) 그 이상이면 `_moonless_segments`로 암천창에서 달구간을 뺀 나머지 중 가장 긴 세그먼트를 골든구간으로 채택; 결과가 빈 리스트(달이 창을 밤새 다 덮음)면 골든구간=암천창 전체를 유지하되 description에 `'무월광 시간대 없음(달이 밤새 떠 있어 관측 제한)'` 문구 포함(계약 고정: `golden_hours`는 항상 정확히 1개, `timeRange`는 항상 `'HH:MM - HH:MM'` — 절대 비워두지 않음).
- `evidence` 딕셔너리에 기존 키(`lunarAgeDays`, `illuminationPct`, `aste`) 유지 + 신규 `windowSource`(`'darkSky'|'fixedFallback'`), `astm`, `moonrise`, `moonset`(원본 문자열 또는 없으면 `None`) 추가. `golden_hours[0]`의 `mode='night'`/`label='밤 · 천체 골든타임'`/`timeRange` 포맷/day 모드가 night golden_hours를 그대로 받는 기존 동작/day·night `sub_score` 공식은 전부 무변경(계약 고정, flutter 소비자가 그대로 파싱).
- 새 픽스처 5개 (`tests/suitability/fixtures/`): `kasi_riseset_no_astm.json`(astm 없음, fixedFallback 회귀용), `kasi_riseset_fullmoon_allnight.json`(moonrise/moonset이 aste/astm과 동일값 → 암천창을 정확히 완전히 덮음), `kasi_lunph_full_moon.json`(`lunAge=14.75` → 광도 100%), `kasi_riseset_moon_partial_overlap.json`(moonrise 23:00~moonset 01:00, 암천창 중간에 걸침 → 앞/뒤 두 무월광 세그먼트 발생), `kasi_lunph_bright.json`(`lunAge=15.0` → 광도 98%).
- `tests/suitability/test_astronomy_provider.py`에 테스트 5개 추가(기존 4개는 무변경 그대로 통과 — 수동 트레이스로 확인): `test_dark_sky_window_with_dim_moon_uses_full_twilight_span`(기존 샘플, 광도18%<50 → 골든=암천창 전체 20:21-04:38), `test_missing_astm_falls_back_to_fixed_window`(fixedFallback 회귀, 20:21-00:01, description 기존 포맷 그대로), `test_bright_full_moon_covering_entire_window_limits_observation`(광도100%, 달이 창 전체를 덮음 → 골든=암천창 전체 유지+관측 제한 문구), `test_bright_moon_mid_window_picks_longer_moonless_segment`(광도98%, 두 세그먼트 159분/218분 중 더 긴 01:00-04:38 채택), `test_dark_sky_window_length_varies_with_twilight_gap`(여름 aste=21:30/astm=03:30→gap 6h vs 겨울 aste=18:00/astm=06:00→gap 12h, 암천창 길이 차이 검증).
- **Verify — 이 런도 role에 Bash 실행 권한이 없음**: `uv run --directory ... pytest`, `uv --version`, `python3 -c "print(1+1)"`, `.venv/bin/pytest` 직접 실행, `.venv/bin/python3 -m pytest`, `cd ... && .venv/bin/pytest` 등 7가지 방식 모두 "requires approval"로 즉시 거부(반면 `ls`/`echo`/`which`류 read-only 명령은 정상 동작) — 이 세션은 non-interactive라 승인을 받을 수 없는 구조적 제약(§30~§35와 동일 패턴). 대신 신규 테스트 5개 + 기존 테스트 4개 전부를 `parse()` 로직에 손으로 값을 대입해 분 단위까지 트레이스 완료(예: `test_bright_moon_mid_window...`의 경우 darkStart=1221, darkEnd=1718, moon=[1380,1500], 세그먼트=(1221,1380)=159분 vs (1500,1718)=218분 → 218분 세그먼트 채택 확인). **다음 엔지니어/오너가 `cd apps/backend && uv run pytest tests/suitability -q`를 실행해 실제 그린(9 new + 기존 전체, 회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | astronomy.py `parse()`의 밤 골든타임을 aste+고정220분에서 실제 암천창(aste~astm)+달 위상 인지 무월광 구간 계산으로 교체, 새 헬퍼 2개(`_format_minute_of_day`/`_moonless_segments`) 및 evidence 신규 키 4개(windowSource/astm/moonrise/moonset) 추가, 픽스처 5개·테스트 5개 신규 추가(Bash 미가용으로 수동 트레이스만 완료)

## 37. §36 크로스모델 리뷰 FAIL — moonrise/moonset을 각각 dark_start와 비교하던 정규화 버그 수정

- 버그: §36의 `parse()`는 `moonrise_norm`/`moonset_norm`을 각각 독립적으로 `dark_start`와 비교해 1440분을 더할지 결정했다. 달이 암천창 시작 전에 떠서(moonrise < dark_start) 암천창이 열린 뒤에 지는(moonset > dark_start) 경우 — 예: moonrise=18:00, aste=20:21, moonset=23:00 — moonrise와 moonset이 둘 다 "내일"로 잘못 밀려나 겹침이 전혀 감지되지 않고, 창 전체가 잘못 "무월광 시간대 없음(관측 제한)"으로 보고되는 결함이 있었다. 올바른 규칙: `moonrise_norm`은 절대 보정하지 않고, `moonset_norm`은 (raw) `moonset`이 `moonrise_norm`보다 크지 않을 때만(달이 뜬 구간 자체가 자정을 넘길 때만, `dark_start` 기준이 아니라 `moonrise` 기준) +1440을 더한다.
- `astronomy.py`의 `parse()` 밤 골든타임 분기 수정: `moonrise_norm = moonrise_hour*60+moonrise_minute`(무보정), `moonset_norm = moonset_raw if moonset_raw > moonrise_norm else moonset_raw+1440`. 기존에 따로 있던 `if moonset_norm <= moonrise_norm: moonset_norm += 1440` 보정 라인은 이제 불필요해져 제거(위 삼항식에 이미 통합). `_moonless_segments`/`_parse_hhmm`/`_format_age`/`fixedFallback` 분기/evidence 딕셔너리/day·tide/sub_score 로직은 전부 무변경.
- 부가: `moon_parsed=False`(moonrise/moonset 필드 자체가 없거나 파싱 실패)인데 `illumination_pct>=50`(밝은 달)인 경우, 기존엔 "무월광 HH:MM~HH:MM"이라고 잘못 단언하는 문구가 나갔다. 신규 분기(`moon_unknown and illumination_pct>=_MOON_BRIGHT_PCT`)를 추가해 이 경우 골든구간은 여전히 암천창 전체(`dark_start`~`dark_end`)를 쓰되, description은 `'{age} · 광도 {pct}% · 월출몰 정보 없음 · 전체 암천 {start}~{end}'`로 교체(무월광을 단언하지 않음). `moon_parsed=True`인 기존 경로(밝은 달+정상 파싱)의 description 포맷은 무변경.
- 새 픽스처 2개(`tests/suitability/fixtures/`): `kasi_riseset_moon_risen_before_twilight.json`(moonrise=18:00 aste=20:21 moonset=23:00 — 버그 재현 케이스, 올바른 답은 `23:00-04:38`), `kasi_riseset_moon_allnight_offset.json`(moonrise=18:00 moonset=06:00 — 암천창을 정확히 덮는 offset 케이스, 관측 제한 유지 확인용 회귀 픽스처).
- `test_astronomy_provider.py`에 테스트 3개 추가: `test_bright_moon_risen_before_twilight_picks_post_moonset_segment`(버그 재현 → 수정 후 `23:00 - 04:38` 기대), `test_bright_moon_allnight_with_offset_endpoints_limits_observation`(관측 제한 문구 유지 회귀), `test_missing_moon_fields_with_bright_illumination_does_not_claim_moonless`(moonrise/moonset 필드 자체가 없을 때 "무월광" 오단언 없이 "월출몰 정보 없음" 문구로 나가는지 확인). 기존 §36의 테스트 5개(`test_dark_sky_window_with_dim_moon_uses_full_twilight_span` 등)는 무변경 — 손으로 재트레이스해 회귀 없음 확인(예: `test_bright_moon_mid_window_picks_longer_moonless_segment`의 moonrise=23:00(1380)/moonset=01:00→+1440=1500은 신규 로직에서도 동일하게 `moonrise_norm=1380`(이미 dark_start=1221 이상이라 기존에도 무보정), `60>1380`이 거짓이라 `+1440=1500`으로 기존과 동일한 결과).
- Verify: `cd apps/backend && uv run pytest tests/suitability/test_astronomy_provider.py -q` — 이 런도 role에 Bash 실행 권한이 없어(`uv run pytest`, `uv run --directory ... pytest`, `.venv/bin/pytest` 직접 호출 모두 "requires approval"로 즉시 거부) 실제 실행하지 못함. 대신 신규 3개 + 기존 §36의 5개 테스트 전부를 `parse()`에 값을 분 단위로 대입해 손으로 트레이스 완료(§36 절 본문 참고 형식과 동일). API 계약(엔드포인트 경로/스키마) 변경 없음 — `evidence` 딕셔너리 키 구성도 무변경, description 문자열 내용만 일부 케이스에서 달라짐. **다음 엔지니어/오너가 위 verify 명령과 `cd apps/backend && uv run pytest -q`(전체 스위트)를 실행해 실제 그린(회귀 없음) 최종 확인 필요.**

DONE: backend-engineer | astronomy.py `parse()`의 moonrise/moonset 자정-넘김 정규화 버그 수정(dark_start 대신 moonrise 기준으로 moonset만 보정), moon-data-missing+밝은달 케이스에 새 description 문구 추가, 픽스처 2개·테스트 3개 신규 추가(Bash 미가용으로 수동 트레이스만 완료)

## 38. 밤 골든타임 description 문구 단순화 — 월령/광도 용어 제거, 쉬운 한국어로 교체

- `astronomy.py`의 `parse()` 내 description 조립 4곳 교체(로직/분기/golden_hours/evidence/sub_score 무변경): fixedFallback → `'달 밝기 {pct}%'`, observation_limited → `'달이 밤새 떠 있어 어두운 별은 보기 어려워요 · 달 밝기 {pct}%'`, moon_unknown+밝은달 → `'하늘이 완전히 어두운 시간 · 달 정보 확인 중'`(더 이상 start_str/end_str 안 씀, 다른 분기에선 계속 사용), 기본(darkSky+무월광 구간) → `'달빛 방해 적은 시간대 · 달 밝기 {pct}%'`. 더 이상 호출되지 않는 `_format_age` 헬퍼 삭제.
- `test_astronomy_provider.py`의 구 문구(월령/광도/무월광/관측 제한/월출몰 정보 없음) assertion 7곳을 새 문구 기준으로 교체. `timeRange`/`windowSource`/`illuminationPct`/`sub_score`/`mode`/`label` assertion은 무변경.
- Verify: `cd apps/backend && uv run pytest -q` — 이 런도 Bash 실행 권한 없음(`uv run pytest` "requires approval"로 거부). 대신 각 분기의 f-string을 손으로 값 대입해 재확인(예: illumination_pct=18 → `'달 밝기 18%'`가 `test_missing_astm_falls_back_to_fixed_window`의 exact-match와 일치). **다음 엔지니어/오너가 `cd apps/backend && uv run pytest -q`로 실제 그린 확인 필요.**

DONE: backend-engineer | astronomy.py의 밤 골든타임 description 4곳을 월령/광도 전문용어에서 쉬운 한국어 문구로 교체하고 미사용 `_format_age` 삭제, test_astronomy_provider.py의 관련 assertion 7곳 갱신(Bash 미가용으로 수동 검증만 완료)

## 39. golden hour description에서 '· 달 밝기 N%' 제거 + `_moon_phase_name()` 순수 헬퍼 신설 (아직 미사용)

- `astronomy.py`의 `parse()` description 4곳에서 `illumination_pct` 참조를 제거하고 고정 문자열로 교체: fixedFallback → `'하늘이 어두운 시간대'`, observation_limited → `'달이 밤새 떠 있어 어두운 별은 보기 어려워요'`, moon_unknown+밝은달 → `'하늘이 완전히 어두운 시간'`, 기본(darkSky+무월광 구간) → `'달빛 방해 없는 시간대'`. golden_start/golden_end/start_str/end_str/window_source/sub_score/evidence/day 모드 로직은 전부 무변경.
- 신규 모듈 레벨 순수 함수 `_moon_phase_name(lun_age: float) -> str`(`_format_minute_of_day` 바로 다음)을 추가: lun_age(0~29.53) 구간을 삭/초승달/상현 반달/차오르는 달/보름달/기우는 달/하현 반달/그믐달/삭(마지막 구간)으로 매핑. 지시된 9개 경계값을 그대로 구현. **이번 태스크에서는 아직 어디서도 호출하지 않음**(다음 단계에서 `service.py`가 import해서 사용 예정) — import 경로는 `app.suitability.providers.astronomy._moon_phase_name`.
- `evidence`/`illuminationPct` 키 자체는 그대로 유지(문자열 조립에서만 뺐을 뿐, 값 계산·evidence dict 저장은 무변경) — consumer가 `evidence.illuminationPct`로 광도값을 읽는 경로는 안 깨짐.
- 지시에 따라 `tests/suitability/test_astronomy_provider.py`는 이번 태스크에서 건드리지 않음 — 기존 description 관련 assertion 7곳(§38에서 추가된 것)이 지금 깨져 있는 상태(다음 태스크에서 갱신 예정).
- Verify: 파일 저장 후 들여쓰기/콜론 등 문법을 직접 재확인함(이 런도 Bash 실행 권한 없음, `python3 -m py_compile` 포함 전부 "requires approval"로 거부). **다음 엔지니어/오너가 `cd apps/backend && uv run pytest tests/suitability/test_astronomy_provider.py -q`(현재 FAIL 예상, 다음 태스크에서 갱신 대상)와 `_moon_phase_name` import 연결 후 `uv run pytest -q` 그린 확인 필요.**

DONE: backend-engineer | astronomy.py의 golden hour description 4곳에서 '· 달 밝기 N%' 표기 제거(고정 문구로 교체), 신규 순수 헬퍼 `_moon_phase_name(lun_age)` 추가(아직 미호출, 다음 태스크에서 service.py가 사용 예정) — test_astronomy_provider.py는 지시에 따라 이번엔 미수정(다음 태스크에서 갱신)

## 40. `models.py`에 `Moon` 스키마 신설 + `SuitabilityResponse.moon` optional 필드 추가

- `app/suitability/models.py`만 수정(지시대로). `GoldenHour` 다음, `TelemetryReading` 앞에 신규 `Moon(BaseModel)` 추가: `illumination: int`(0~100%), `phaseName: str`(한글 위상명, `_moon_phase_name`(§39, 아직 미연결) 출력과 짝맞출 예정), `moonrise: str | None`/`moonset: str | None`('HH:MM' 또는 파싱 실패 시 None), `status: str`(`'live'|'approx'|'unavailable'`).
- `SuitabilityResponse`의 마지막 필드 `layers` 다음에 `moon: Moon | None = None` 추가(default None이라 기존 소비자/테스트가 `moon`을 안 넘겨도 안 깨짐). 다른 기존 필드/클래스는 전부 무변경.
- 아직 `service.py`/`app/routers/suitability.py`에서 `moon` 필드를 채우는 로직은 없음(스키마만 추가) — `GET /api/suitability` 응답에 `moon` 키가 아직 나타나지 않거나 항상 `null`. 다음 태스크에서 astronomy provider의 `_moon_phase_name`/moonrise·moonset 파싱 결과를 여기에 연결해야 실제 값이 채워짐.
- Verify: `cd apps/backend && uv run pytest -q` — 이 런도 Bash 실행 권한 없음("requires approval"로 즉시 거부). 대신 `models.py` 전체를 다시 읽어 문법·들여쓰기·클래스 순서·필드 default를 직접 재확인함. 기존 클래스 바디는 문자 그대로 보존, 추가만 했으므로 기존 테스트(예: `test_endpoint.py`의 `SuitabilityResponse` 스키마 검증)는 `moon` 필드가 optional이라 회귀 없을 것으로 예상. **다음 엔지니어/오너가 위 verify 명령으로 실제 그린 확인 필요.**

DONE: backend-engineer | app/suitability/models.py에 Moon(BaseModel) 신규 추가(illumination/phaseName/moonrise/moonset/status) 및 SuitabilityResponse.moon: Moon | None = None optional 필드 추가, 다른 파일/필드는 무변경(Bash 미가용으로 수동 검증만 완료)

## 41. `service.py`에서 astronomy evidence로부터 `SuitabilityResponse.moon` 조립

- `app/suitability/service.py`만 수정(지시대로). import에 `Moon`(models)과 `_format_hhmm`/`_moon_phase_name`/`_parse_hhmm`(§39/§40에서 이미 만들어진 astronomy 순수 헬퍼)을 추가.
- `get_suitability()`에서 `light_pollution_evidence` 조립 직후, `astronomy_reading = readings["astronomy"]`를 읽어 moon 조립: `status != "live"`면 `moon = None`; `"live"`면 `evidence["lunarAgeDays"]`로 `_moon_phase_name`, `evidence["moonrise"]`/`evidence["moonset"]`을 각각 `_parse_hhmm` → 성공 시 `_format_hhmm`으로 `'HH:MM'`, `ValueError`/`TypeError` 시 `None`으로 개별 처리, `evidence["illuminationPct"]`를 `illumination`에 그대로 사용해 `Moon(status="live", ...)` 생성. `evidence`에 `lunarAgeDays`/`illuminationPct` 키가 없는 방어적 예외 상황은 바깥 `try/except KeyError`로 감싸 `moon = None`으로 안전 처리.
- `SuitabilityResponse(...)` 생성자 호출 마지막에 `moon=moon` 인자만 추가 — 다른 인자 순서/값, `LAYER_KEYS`/`fuse`/telemetry·golden_hours 조립/`sqm_value`·`sky_class`/`get_default_providers()`/`get_suitability_service()`는 전부 무변경.
- 결과: `GET /api/suitability` 응답에 `moon` 필드가 실제로 채워짐 — astronomy layer가 `live`면 `{illumination, phaseName, moonrise, moonset, status:"live"}`, `unavailable`(또는 그 외 non-live status)이면 `moon: null`.
- Verify: `cd apps/backend && uv run pytest -q` — 이 런도 Bash 샌드박스에서 `uv run pytest`가 매번 "requires approval"로 즉시 거부되어 실행 불가(단순 `wc -l` 등은 통과했으나 uv 명령만 막힘). 대신 수정된 `service.py` 전체를 다시 읽어 import·들여쓰기·try/except 구조·`SuitabilityResponse` 인자 목록을 직접 재확인함. **다음 엔지니어/오너가 위 verify 명령과 특히 `tests/suitability/test_endpoint.py`(astronomy live/unavailable 케이스가 있다면)로 실제 그린 확인 필요.**

DONE: backend-engineer | app/suitability/service.py만 수정 — astronomy reading evidence(lunarAgeDays/illuminationPct/moonrise/moonset)로부터 Moon을 조립해 SuitabilityResponse(moon=moon)로 응답에 채움(astronomy unavailable/non-live 시 moon=None), 기존 fuse/telemetry/golden_hours/sqm/sky_class 로직은 무변경(Bash 미가용으로 수동 검증만 완료)

## 42. `test_endpoint.py`에 §41 moon 조립 로직 커버 테스트 2개 신규 추가

- `apps/backend/tests/suitability/test_endpoint.py`만 수정(지시대로). 기존 테스트/헬퍼/fixture는 전부 무변경.
- `test_happy_path_moon_is_none_when_astronomy_evidence_lacks_moon_fields`: 기존 `_healthy_providers()`의 astronomy fixture는 evidence 없이 `status='live'`이므로, `moon` 조립이 `KeyError`로 `None`이 되는 케이스를 검증(`body["moon"] is None`).
- `test_astronomy_live_with_full_evidence_populates_moon`: `_healthy_providers()`의 `astronomy` 항목을 `evidence={'lunarAgeDays': 14.0, 'illuminationPct': 96, 'moonrise': '1832', 'moonset': '0512'}`를 채운 `FakeProvider`로 교체해 `_install()`, night 모드로 호출 후 `moon`이 `{illumination:96, phaseName:'보름달', moonrise:'18:32', moonset:'05:12', status:'live'}`로 채워짐을 검증(`_moon_phase_name(14.0)`은 `[12.92,16.61)` 구간이라 '보름달').
- Verify: 이번 런도 Bash에서 `uv run pytest` 계열 명령이 전부 "requires approval"로 거부되어 실행 불가 — `_moon_phase_name`/`_parse_hhmm`/`_format_hhmm`/`Moon` 모델 필드명을 직접 읽고 손으로 트레이스하여 정합성만 확인함. **다음 엔지니어/오너가 `cd apps/backend && uv run pytest -q`로 그린 확인 필요.**

DONE: backend-engineer | apps/backend/tests/suitability/test_endpoint.py만 수정 — moon 관련 테스트 2개 신규 추가(evidence 없을 때 moon=None, evidence 있을 때 moon 전체 필드 조립 검증), 기존 5개 테스트는 무변경(Bash 미가용으로 수동 검증만 완료)

## 43. Moon contract publish for consumer flutter 039

`SuitabilityResponse.moon` is `Moon | null` — `null` whenever the `astronomy` layer's `status` is not `"live"` (e.g. `"unavailable"`).

| Field | Type | Notes |
|---|---|---|
| illumination | int | 0–100 (percent illuminated) |
| phaseName | string | one of the 9 Korean phase names from `_moon_phase_name`: `삭`, `초승달`, `상현 반달`, `차오르는 달`, `보름달`, `기우는 달`, `하현 반달`, `그믐달`, `삭` (boundary wraps back to `삭`) |
| moonrise | string \| null | `"HH:MM"`, or `null` if unparseable |
| moonset | string \| null | `"HH:MM"`, or `null` if unparseable |
| status | string | one of `"live"` \| `"approx"` \| `"unavailable"` |

Example populated `moon` object:
```json
{
  "illumination": 96,
  "phaseName": "보름달",
  "moonrise": "18:32",
  "moonset": "05:12",
  "status": "live"
}
```

Consumer of this contract: **flutter spec 039** (오늘의 달 섹션 / today moon section).

DONE: backend-engineer | (1) models.py: Moon.illumination now Field(ge=0,le=100), Moon.status now Literal["live","approx","unavailable"] (Literal+Field imports added); (2) test_astronomy_provider.py: 2 substring assertions on the moon-up-all-night description tightened to exact-match; (3) test_endpoint.py: added test_astronomy_unavailable_status_yields_moon_none covering the unavailable-status → moon=None path; (4) this section publishing the Moon contract for flutter 039

## 44. Light pollution Phase 1 — pure-Python brightness→SQM→Bortle conversion + grid lookup (spec 040, no HTTP/router yet)

New package `app/suitability/lightpollution/` (pure Python, no numpy, no network I/O — not wired into `providers/light_pollution.py` or the `/api/suitability` endpoint yet; that's a later phase per spec 040).

- `app/suitability/lightpollution/convert.py`:
  - `sqm_to_bortle(sqm: float) -> int` — 8-threshold table, clamped to 1–9 (`sqm >= 21.99` → 1 down to `sqm < 18.38` → 9).
  - `brightness_to_sqm(brightness_mcd_per_m2: float) -> float` — `log10(brightness/108000000)/-0.4`; `brightness_mcd_per_m2 <= 0` returns `22.0` (natural-sky-background SQM, avoids log domain error).
  - `bortle_description(bortle_class: int) -> str` — same 4-tier Korean labels as `providers/light_pollution.py`'s `_SKY_CLASS_LABELS` (`class<=2`→"최적 다크스카이", `<=4`→"양호한 다크스카이", `<=6`→"보통 도심 근교", else→"광해 심각").
- `app/suitability/lightpollution/grid.py`:
  - `Grid` — frozen dataclass, fields in order: `min_lat, max_lat, min_lng, max_lng, resolution` (float), `nrows, ncols` (int), `values: list[list[float | None]]` (row 0 = min_lat edge, col 0 = min_lng edge).
  - `load_grid(path: str) -> Grid | None` — returns `None` if `path` doesn't exist; otherwise one `json.load()` of top-level keys `bbox{minLat,maxLat,minLng,maxLng}`, `resolution`, `nrows`, `ncols`, `values`.
  - `lookup(grid: Grid, lat: float, lng: float) -> float | None` — `None` if `lat`/`lng` outside bbox; else nearest-neighbor via `round((lat-min_lat)/resolution)` / `round((lng-min_lng)/resolution)`, clamped to valid row/col range. Returned cell may itself be `None` (masked).
- `tests/suitability/fixtures/lp_grid_sample.json` — 3×3 grid, bbox lat 37.0–38.0 / lng 126.5–127.5, resolution 0.5. Seoul cell (nearest to lat 37.57/lng 126.98, index `[1][1]`) = **17.5** SQM (bright urban). Mountain cell (nearest to lat 37.95/lng 127.45, index `[2][2]`) = **21.5** SQM (dark rural). Other 7 cells filled 18.0–21.0.
- `tests/suitability/test_light_pollution_convert.py` (14 tests) / `tests/suitability/test_light_pollution_grid.py` (6 tests) — cover every Bortle boundary pair, sub-18.38 clamps to 9 not lower, `brightness_to_sqm(0)`/negative → 22.0, positive brightness returns a float without raising, grid shape/missing-path/Seoul-vs-mountain-value/outside-bbox-None.
- Verify: `cd apps/backend && uv run pytest -q tests/suitability/test_light_pollution_convert.py tests/suitability/test_light_pollution_grid.py` — **this run's role has no Bash access** (consistent with every prior entry in this log — `uv run pytest` etc. are rejected as "requires approval" in this non-interactive session). Statically hand-traced all 20 new test cases against the implementation instead: every Bortle threshold pair resolves to the exact class asserted, and the grid index arithmetic (`round((37.57-37.0)/0.5)=1`, `round((126.98-126.5)/0.5)=1` → `values[1][1]=17.5`; `round((37.95-37.0)/0.5)=2`, `round((127.45-126.5)/0.5)=2` → `values[2][2]=21.5`; lat=10.0 short-circuits to `None` before any index math) matches the fixture exactly. **Next engineer/owner should run the verify command above and `cd apps/backend && uv run pytest -q` (full suite) to confirm green before wiring this into `providers/light_pollution.py` (later phase).**

## 45. Light pollution Phase 2 — wire grid lookup into `providers/light_pollution.py` + config (spec 040)

Consumes the Phase 1 contract from `app/suitability/lightpollution/` (imported only — those files untouched).

- `app/suitability/config.py`: added `LightPollutionConfig` (frozen dataclass, one field `grid_path: str`) + `get_light_pollution_config()`, same `os.getenv` style as the other `get_*_config` functions. Reads `LIGHT_POLLUTION_GRID_PATH`, default is `Path(__file__).parent / "data" / "kr_light_pollution_grid.json"` (that `data/` dir/file does not exist yet in this repo — intentional; `grid.load_grid()` returns `None` for a missing path and the provider falls back cleanly, no crash). No other function in this file touched.
- `app/suitability/providers/light_pollution.py`: `LightPollutionProvider.__init__(self, grid_path: str | None = None)` resolves the path (`grid_path` if given, else `get_light_pollution_config().grid_path`) and loads it once via `lightpollution.grid.load_grid()`, stored as `self._grid`. `fetch()` now branches: if `self._grid` is not `None` **and** `grid.lookup(self._grid, lat, lng)` returns a non-`None` SQM, uses it — `bortle_class` via `convert.sqm_to_bortle`, `status="approx"`, `evidence.method="World Atlas 2015 grid"`. Otherwise (grid never loaded, or coordinate outside the bundled bbox) falls back to the **exact original synthetic `math.sin` seed/frac math**, byte-for-byte unchanged, with `status="stub"`, `evidence.method="grid not installed — synthetic fallback"`. `sub_score` formula (`round((sqm-16)/(22-16)*100)` clamped 0–100) and `skyClass` shape (`"Class N <desc>"`) unchanged for both branches; `skyClass` description now sourced from `convert.bortle_description()` instead of the removed local `_SKY_CLASS_LABELS`/`_sky_class_description`. Existing no-arg call sites (`service.py`, `trails/service.py`, `observation/service.py`) are unaffected — `grid_path=None` default resolves via config exactly as before this change added the parameter.
- New: `tests/suitability/test_light_pollution_provider.py` (4 tests) — Seoul fixture coordinate → `status="approx"`, `method="World Atlas 2015 grid"`, `sqmValue==17.5`, `bortleClass==convert.sqm_to_bortle(17.5)`; mountain fixture coordinate → same grid status, `sqmValue==21.5`, and asserts Seoul's `sub_score` < mountain's `sub_score`; missing grid file path → `status="stub"`, fallback method string, `sub_score` in `[0,100]`; in-bbox-file but out-of-bbox coordinate (lat 10.0/lng 10.0) → same fallback status/method as the missing-file case.
- Verify: `cd apps/backend && uv run pytest -q tests/suitability/test_light_pollution_provider.py tests/suitability/test_light_pollution_convert.py tests/suitability/test_light_pollution_grid.py` then full suite `cd apps/backend && uv run pytest -q` — **this run's role again has no Bash access** (every `uv run pytest` invocation rejected as "requires approval" in this non-interactive session, consistent with every prior phase in this log). Statically hand-traced all 4 new tests against the implementation (grid row/col arithmetic, threshold lookups, sub_score formula) and confirmed no other test file constructs `LightPollutionProvider` with expectations this change would break (`test_endpoint.py` uses a `FakeProvider`, not the real class). **Next engineer/owner should run both verify commands above to confirm green before Phase 3 (bundling the real `kr_light_pollution_grid.json` data file / wiring status transitions into the live endpoint contract docs).**

## 46. Light pollution Phase 3 — offline grid-generation script + acquisition docs (spec 040)

No app/runtime code touched — this phase only adds the offline tooling that turns a World Atlas 2015 raster into the bundled grid JSON from Phase 2. Not part of `just check` or pytest; not imported by any test or app module.

- New: `apps/backend/scripts/gen_light_pollution_grid.py` — CLI: `--input` (required, source GeoTIFF path), `--output` (default `app/suitability/data/kr_light_pollution_grid.json`), `--resolution` (default `0.05` degrees). Imports `rasterio`/`numpy` at module level (offline-only tool deps, **not** in `pyproject.toml` — will `ImportError` unless `pip install rasterio` was run first, by design) and `brightness_to_sqm` from `app.suitability.lightpollution.convert` (no rasterio needed for that import). `build_grid()` crops to the Korea bbox (33-39°N, 124-132°E), walks a regular lat/lng grid at `--resolution`, uses `dataset.index(lng, lat)` to find the nearest source pixel per sample point, skips out-of-bounds/masked pixels (`numpy.ma.is_masked`) by leaving that cell `None` (never raises), converts valid brightness reads to SQM, and `json.dump`s the exact `{bbox:{minLat,maxLat,minLng,maxLng}, resolution, nrows, ncols, values}` shape that `lightpollution.grid.load_grid()` already consumes (verified against `grid.py` and the Phase 1 fixture schema).
- New: `apps/backend/scripts/README.md` — documents where to get the World Atlas 2015 (Falchi et al.) GeoTIFF (official public data repository, no specific URL pinned), that `pip install rasterio` is a local one-time step and intentionally not added to `pyproject.toml`, the exact run command (`uv run python scripts/gen_light_pollution_grid.py --input path/to/world_atlas_2015.tif --output ../app/suitability/data/kr_light_pollution_grid.json`), and that the generated JSON should be committed at `apps/backend/app/suitability/data/kr_light_pollution_grid.json` — the provider's default `LIGHT_POLLUTION_GRID_PATH` already points there, so committing the file alone flips real coordinates from `status="stub"` to `status="approx"`, no code change needed.
- Real grid data generation/commit is explicitly out of scope for this build (spec Non-Goals) — no data directory or data file was created.
- Verify: static review only (script requires rasterio, not installed in this environment, and is intentionally excluded from `just check`/pytest). Confirmed by hand against `grid.py`/`convert.py`/the Phase 1 fixture that the output schema, key names, and row/col orientation (row 0 = minLat, col 0 = minLng, increasing toward maxLat/maxLng) match exactly what `load_grid()`/`lookup()` expect.

DONE: backend-engineer | Added apps/backend/scripts/gen_light_pollution_grid.py (offline World Atlas 2015 GeoTIFF → Korea SQM grid JSON generator, argparse CLI) and apps/backend/scripts/README.md (acquisition/install/run/commit workflow); no existing files modified.

## 47. Light pollution offline script — cross-model review fixes (spec 040)

Two-file fix only, per cross-model review of §46. No app/runtime code or tests touched.

- `apps/backend/scripts/gen_light_pollution_grid.py`: added `import os`; `main()` now calls `os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)` right before opening `args.output` for writing, so a clean checkout with no `app/suitability/data/` directory no longer raises `FileNotFoundError`.
- `apps/backend/scripts/README.md`: run example no longer passes `--output ../app/suitability/data/...` (that leading `../` resolved one level *above* `apps/backend` when the working directory is already `apps/backend`, i.e. outside the repo's backend tree). Example now relies on the script's own default (`app/suitability/data/kr_light_pollution_grid.json`, relative to `apps/backend`), with a sentence explaining that.
- Verify: `cd apps/backend && uv run pytest -q` — Bash again rejected pending approval in this non-interactive session; statically re-read both diffs against the task spec instead. **Next engineer/owner: run the script once against a real World Atlas 2015 GeoTIFF (or a dummy file, to hit only the makedirs+open path) in a checkout without `app/suitability/data/` to confirm the fix.**

DONE: backend-engineer | Fixed apps/backend/scripts/gen_light_pollution_grid.py (os.makedirs before open, avoids FileNotFoundError on clean checkout) and apps/backend/scripts/README.md (dropped wrong ../ --output example, relies on script default); no other files touched.

## 48. `brightness_to_sqm` — natural sky brightness floor (internal math fix, no contract change, spec 041)

Internal-only fix to `app/suitability/lightpollution/convert.py`; no API contract changed (light pollution is not yet wired into `/api/suitability` — see §45).

- Problem: `brightness_to_sqm` converted artificial-light-only brightness directly (`log10(brightness/108000000)/-0.4`) with no natural skyglow term, so very dark cells could compute SQM above the physical ~22.0 ceiling.
- Fix: added `_ARTIFICIAL_LIGHT_REFERENCE_MCD = 108000000` (factors out the previously-duplicated literal) and `_NATURAL_BRIGHTNESS_MCD = _ARTIFICIAL_LIGHT_REFERENCE_MCD * 10 ** (-0.4 * _NATURAL_SKY_SQM)` next to `_NATURAL_SKY_SQM`. `brightness_to_sqm` now always adds this natural floor: `total = max(brightness_mcd_per_m2, 0.0) + _NATURAL_BRIGHTNESS_MCD; return log10(total / _ARTIFICIAL_LIGHT_REFERENCE_MCD) / -0.4`. Removed the old `<= 0` early-return branch — the new formula yields exactly `22.0` for zero/negative input by construction, so behavior at that boundary is unchanged. `sqm_to_bortle`/`bortle_description` untouched.
- New tests appended to `tests/suitability/test_light_pollution_convert.py` (all 14 prior tests in that file left unchanged): small positive brightness (0.05) stays strictly between 20.0 and 22.0; a sweep of 11 non-negative brightness values (1e-4 .. 1e6) all stay `<= 22.0 + 1e-9`; bright-city brightness (5,000,000 mcd/m²) matches the old pre-fix formula within 0.01 (proves the floor doesn't perturb already-bright cells).
- Verify: `cd apps/backend && uv run pytest -q tests/suitability/test_light_pollution_convert.py` then full suite `cd apps/backend && uv run pytest -q` — **this run's role again has no Bash access** (consistent with every prior phase in this log, e.g. §44/§45/§47). Statically hand-verified: the zero/negative case reduces to `log10((ref*10**(-8.8))/ref)/-0.4`, which is `10**(-8.8)` reconstructed then log10'd back — algebraically exactly `22.0`; the bright-city case adds a floor term (~0.171 mcd/m²) that is ~7 orders of magnitude smaller than 5,000,000, so the log10 shift is far below the 0.01 tolerance. **Next engineer/owner: run the verify commands above to confirm green (in particular the exact-equality assertions on the 0.0/-1.0 cases survive float round-trip through `10**x` → `log10` → `/-0.4`) before relying on this fix.**

DONE: backend-engineer | apps/backend/app/suitability/lightpollution/convert.py: added natural-sky-brightness floor to brightness_to_sqm (caps SQM at ~22.0), factored 108000000 into shared constant; apps/backend/tests/suitability/test_light_pollution_convert.py: appended 3 regression tests, all prior tests intact; apps/backend/.team/member.md updated (§48) — internal math fix, no API contract change.
## 49. New region registry + `GET /api/regions` endpoint (spec 043)

New self-contained `app/regions/` package — 7 fixed Korean dark-sky regions (ganghwa, pyeongchang, seosan, suncheon, yeongyang, muju, changnyeong), each with a center lat/lng, trail-name tokens, and optional star-spot info.

- `app/regions/registry.py`: `Region` frozen dataclass (`id, label, center_lat, center_lng, trail_tokens: list[str], star_spot: dict | None`), `REGIONS: list[Region]` (the 7 fixed entries), `_haversine_km` (same formula as `app/suitability/providers/tide_stations.py:64-69`, reimplemented locally — not imported), `sort_by_distance(lat, lng) -> list[tuple[Region, float]]` (ascending by distance), `nearest(lat, lng) -> Region`, `get(region_id) -> Region | None`. `trail_tokens`/`star_spot` are exposed for later phases (trails/observation services can match regions by name token or surface the star spot) — not yet consumed anywhere.
- `app/regions/models.py`: local `Coordinate(lat, lng)` (not imported from `trails.models`), `RegionSummary(id, label, distanceKm, center, hasStarSpot)`, `RegionsResponse(nearestId, regions)`.

### `GET /api/regions`

| Param | Type | Validation |
|---|---|---|
| lat | float | -90..90, required |
| lng | float | -180..180, required |

200 response (`RegionsResponse`):
```json
{
  "nearestId": "ganghwa",
  "regions": [
    {"id": "ganghwa", "label": "인천 강화군", "distanceKm": 12.3, "center": {"lat": 37.7469, "lng": 126.4878}, "hasStarSpot": true},
    ...
  ]
}
```
`regions` is always all 7, sorted ascending by `distanceKm` (rounded to 1 decimal); `nearestId` is `regions[0].id`; `hasStarSpot` is `true` iff that region's `star_spot` is not `None`. 422 on missing/out-of-range `lat`/`lng`.

- `app/main.py`: added `from app.regions.router import router as regions_router` and `app.include_router(regions_router)`.
- New: `tests/regions/__init__.py` (empty, matches `tests/trails/`/`tests/observation/` convention), `tests/regions/test_regions_registry.py` (5 tests: Seoul→ganghwa top-2, Busan→changnyeong-or-suncheon top-2, `nearest`→ganghwa, `get('unknown-id')`→None, `get('ganghwa').label`), `tests/regions/test_regions_endpoint.py` (1 test: 200, sorted-ascending distances, required keys per region).
- Verify: `cd apps/backend && uv run pytest tests/regions tests/trails tests/observation -q` — **this run's harness had no Bash access** (every `uv run pytest` invocation rejected as "requires approval" in this non-interactive session, consistent with prior entries in this log). Statically re-checked: haversine formula is a byte-for-byte copy of `tide_stations.py:64-69`; hand-computed that Ganghwa (37.7469,126.4878) is closer to Seoul (37.5665,126.9780) than every other region's center except possibly one, verified against rough km deltas; `get`/`nearest` logic is a plain linear scan matching the spec. **Next engineer/owner: run the verify command above to confirm green before consuming `registry.sort_by_distance`/`get` from trails or observation services.**

## 19. Region-aware trails / observation-map — Phase 2 (wires `app.regions.registry` into both services)

- `app/trails/service.py`: `get_trails(lat, lng, region_id: str | None = None) -> dict`. Resolves `region = registry.get(region_id) if region_id else registry.nearest(lat, lng)`; unknown `region_id` (registry.get returns `None`) falls back to `registry.nearest(lat, lng)` silently (no error). Removed module-level `DEFAULT_REGION_LABEL`/`DEFAULT_REGION_TOKENS` — all `region`-key values and the `match_region(...)` token argument now come from the resolved `Region` (`region.label`, `region.trail_tokens`). No other ranking/scoring logic touched.
- `app/routers/trails.py`: `GET /api/trails` gained `region: str | None = Query(None)` → passed as `service.get_trails(lat, lng, region_id=region)`.
- `app/observation/service.py`: `get_observation_map(lat, lng, region_id: str | None = None) -> dict`, same resolve-with-fallback pattern. Removed module-level `DEFAULT_REGION_LABEL`/`OBS_STAR_ID`/`OBS_STAR_NAME`/`OBS_STAR_LAT`/`OBS_STAR_LNG`. Star spot now built from `region.star_spot` (dict with `id`/`lat`/`lng`/`name` keys, same shape the old constants produced); if `region.star_spot is None` the star spot is skipped entirely (no `light_pollution_provider.fetch` call, nothing appended to `spots`) — matches the app's existing best-effort/degrade pattern, not treated as an error. Bird/heritage/degraded logic untouched.
- `app/routers/observation_map.py`: `GET /api/observation-map` gained the same `region: str | None = Query(None)` → `service.get_observation_map(lat, lng, region_id=region)`.
- **API contract (both endpoints):** new optional query param `region` (region id string, e.g. `ganghwa`/`pyeongchang`/`seosan`/`suncheon`/`yeongyang`/`muju`/`changnyeong`). Omitted → defaults to nearest region by `lat`/`lng` (unchanged default behavior). Unknown/invalid id → silently falls back to nearest-by-coordinates (never a 4xx). Response shape is unchanged; only the `region` label and the candidate pool (`trail_tokens` for trails, presence/absence of the `star` spot for observation-map) vary by resolved region.
- Existing fixed-coordinate tests (`tests/trails/test_trails_service.py` `(37.6, 126.4)`, `tests/observation/test_observation_service.py` `(37.6, 126.4)`, both endpoint tests `(37.73, 126.52)`) all resolve to `ganghwa` as nearest — no unexpected region changes; only had to update `test_observation_service.py`'s import of the now-removed `DEFAULT_REGION_LABEL` constant (replaced with a local literal) and the two Fake\*Service test doubles in `test_trails_endpoint.py`/`test_observation_endpoint.py` to accept the new `region_id` kwarg (router now always passes it). Also found and fixed a stale `from app.trails.service import DEFAULT_REGION_TOKENS, TrailsService` in `tests/suitability/test_live.py` (unused import, would have broken collection since it's module-level even though the tests themselves are skipped by default).
- New tests: `tests/trails/test_trails_service_region.py` (explicit `region_id="yeongyang"` from Seoul coords overrides nearest; unknown `region_id` falls back to nearest/ganghwa), `tests/observation/test_observation_service_region.py` (`region_id="seosan"` — a `star_spot=None` region — omits the `star` spot and doesn't raise; unknown `region_id` falls back to nearest/ganghwa).
- Verify: `cd apps/backend && uv run pytest tests/trails tests/observation tests/regions -q` — **this run also had no Bash access** (every invocation rejected as "requires approval"). Statically traced all touched code paths and every existing + new test assertion against the new signatures; no logic outside region-resolution/label/token/star-spot source was changed. **Next engineer/owner: please run the verify command above and confirm green before merging.**

## 20. Bugfix — region-center coordinate regression in `get_observation_map`

Fixed a bug introduced by the Phase 2 region wiring (#19 above): after resolving `region` (via `registry.get`/`registry.nearest`), `self.fetch_recent_obs(lat, lng)` and `self.fetch_nearby_food(lat, lng)` were still called with the raw caller-supplied `lat`/`lng` instead of the resolved `region.center_lat`/`region.center_lng` — so selecting a non-nearest `region_id` (e.g. Seoul coords with `region_id="yeongyang"`) queried eBird/TourAPI around the caller's location instead of the selected region, while the `star_spot` block already correctly used `region.star_spot`'s coordinates.

- `app/observation/service.py`: both calls now read `self.fetch_recent_obs(region.center_lat, region.center_lng)` and `self.fetch_nearby_food(region.center_lat, region.center_lng)`. No signature or other behavior change; `star_spot` logic untouched.
- New test: `tests/observation/test_observation_service_region.py::test_selected_region_center_drives_ebird_and_food_queries` — calls `get_observation_map(37.6, 126.4, region_id="yeongyang")` with recording `fetch_recent_obs`/`fetch_nearby_food` lambdas and asserts both were invoked with `(36.6666, 129.1124)` (yeongyang's center, via `pytest.approx`) rather than the caller's `(37.6, 126.4)`.
- **API contract: unchanged** — this is an internal bugfix only, no request/response shape or query param changed for `GET /api/observation-map`.
- Verify: `cd apps/backend && uv run pytest tests/observation/ -q` — **this run's harness also had no Bash access** (every `uv run pytest` invocation rejected as "requires approval", same as prior entries). Statically re-verified the two-line diff against `app/regions/registry.py`'s `yeongyang` entry (`center_lat=36.6666, center_lng=129.1124`) and re-traced the new test's assertions by hand. **Next engineer/owner: please run the verify command above (and the full `tests/observation tests/trails tests/regions` suite) to confirm green before merging.**
