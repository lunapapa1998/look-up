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
