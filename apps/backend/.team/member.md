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
