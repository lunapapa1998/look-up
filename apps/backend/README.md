# apps/backend — 위를 봐요 생태 일기 백엔드 (FastAPI)

## API

All endpoints are served under the `/api` prefix.

| Method | Path | Request body | Success | Error |
|---|---|---|---|---|
| GET | `/api/health` | — | 200 `{"status": "ok"}` | — |
| POST | `/api/observations` | `ObservationCreate` (`speciesType`: `"bird"\|"star"`, `speciesName`: str, `note`?: str, `photoUrl`?: str, `observedAt`?: datetime, `lat`?: float, `lng`?: float) | 201 `Observation` | 422 validation error body |
| GET | `/api/observations` | — (query param `speciesType`?: `"bird"\|"star"`) | 200 `Observation[]` | — |
| GET | `/api/observations/{observation_id}` | — | 200 `Observation` | 404 `{"detail": "Observation {id} not found"}` |
| PATCH | `/api/observations/{observation_id}` | `ObservationUpdate` (all fields optional, same shape as `ObservationCreate`) | 200 `Observation` | 404 `{"detail": "Observation {id} not found"}` |
| DELETE | `/api/observations/{observation_id}` | — | 204 (no body) | 404 `{"detail": "Observation {id} not found"}` |
| GET | `/api/badges` | — | 200 `BadgeProgress[]` (`{badge: {id, name, description, targetCount}, achieved, currentCount}`) | — |

`Observation` response shape: `{id, speciesType, speciesName, note, photoUrl, observedAt, lat, lng, createdAt}`.
If `observedAt` is omitted on create, the server defaults it to the current UTC time.

## Run

```
uv run uvicorn app.main:app --reload
```

Run from inside `apps/backend`.

## Test

```
uv run pytest -q
```

Run from inside `apps/backend`.
