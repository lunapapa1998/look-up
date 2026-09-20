# 지역 레지스트리 + 거리순 지역 API (backend)

> Lightweight plan-f3 spec. 강화 고정 시드를 다지역 레지스트리로 확장하고, 사용자 좌표 기준 거리순 지역 목록 API와 지역 선택 파라미터를 노출한다. flutter가 소비할 계약 publisher.

## 메타데이터 (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 <brain>
- modified: 2026-09-21 <lead>
- refs: apps/backend/app/trails/service.py, apps/backend/app/observation/service.py, apps/backend/app/suitability/providers/tide_stations.py(_haversine_km 재사용), specs/041·042
- risk: medium — 신규 모듈 + 2개 서비스/라우터 계약 확장 (3계층 파이프라인)

## Purpose

강화 고정 시드(`DEFAULT_REGION_*`)를 7개 지역 레지스트리로 확장하고, 사용자 위치에서 가까운 순으로 정렬된 지역 목록을 반환하는 `/api/regions` API와 트레일/관찰지도의 지역 선택(`region`) 파라미터를 추가한다.

## Problem

`trails/service.py`·`observation/service.py`가 좌표와 무관하게 항상 `인천 강화군` 고정 시드로만 응답한다. 다른 지역을 검색할 수 없고, 사용자 위치 기준으로 지역을 고를 방법(거리순 목록/선택기)이 없다.

## Solution

신규 `app/regions/` 모듈에 7개 지역(강화·평창·서산·순천·영양·무주·창녕) 레지스트리를 두고, 각 지역의 중심좌표·트레일 토큰·(있으면)별관측 스팟을 정의한다. `GET /api/regions?lat=&lng=`는 haversine 거리 오름차순 지역 목록 + `nearestId`를 반환한다. `trails`/`observation-map` 라우터에 선택적 `region`(지역 id) 쿼리를 추가해, 지정 시 해당 지역 시드로, 미지정 시 최근접 지역 시드로 응답한다(하위호환: region 없어도 동작). 베스트에포트 — 별관측 스팟/물때가 없는 지역은 해당 필드를 자연스럽게 비운다(degraded).

## Relevant Files

### New Files

- `apps/backend/app/regions/__init__.py`
- `apps/backend/app/regions/registry.py` - `Region` 데이터클래스(id, label, center_lat, center_lng, trail_tokens: list[str], star_spot: dict|None{id,name,lat,lng})와 `REGIONS` 상수(아래 시드 표). `sort_by_distance(lat, lng) -> list[tuple[Region, float]]`(km 오름차순), `nearest(lat, lng) -> Region`, `get(region_id) -> Region|None`. 거리 계산은 `app.suitability.providers.tide_stations._haversine_km` 재사용 또는 동등 haversine.
- `apps/backend/app/regions/router.py` - `GET /api/regions?lat&lng` → `{nearestId, regions:[{id,label,distanceKm,center:{lat,lng},hasStarSpot:bool}]}` (distanceKm 반올림 1자리, 거리 오름차순).
- `apps/backend/app/regions/models.py` - `RegionSummary`, `RegionsResponse` pydantic 모델.

### Existing Files

- `apps/backend/app/main.py` - `regions.router` include 추가.
- `apps/backend/app/trails/service.py` - `get_trails(lat, lng, region_id: str|None=None)`. region_id 있으면 `regions.get(region_id)`, 없으면 `regions.nearest(lat,lng)`로 지역 결정 → 그 지역의 `trail_tokens`/`label`로 매칭(기존 `DEFAULT_REGION_TOKENS` 하드코드 제거). 매칭 결과 없으면 기존처럼 degraded.
- `apps/backend/app/trails/router.py` - 선택적 `region: str|None = Query(None)` 추가, 서비스에 전달.
- `apps/backend/app/observation/service.py` - `get_observation_map(lat, lng, region_id: str|None=None)`. 지역 결정 후 그 지역의 `star_spot`(없으면 star 스팟 생략)와 지역 중심좌표로 eBird/light-pollution/nearby-food 시드 조회. `OBS_STAR_*` 하드코드 상수는 강화 레지스트리 항목으로 이관.
- `apps/backend/app/routers/observation_map.py` - 선택적 `region: str|None` 추가, 서비스에 전달.

## Phases

### Phase 1: 레지스트리 + /api/regions

지역 레지스트리와 거리순 목록 API를 만든다.

- [x] `regions/registry.py`에 7개 지역 시드 + `sort_by_distance`/`nearest`/`get`
- [x] `regions/models.py` + `regions/router.py`(`GET /api/regions`)
- [x] `main.py`에 라우터 등록
- [x] 단위 테스트: 거리순 정렬(서울 좌표→강화가 상위, 부산 좌표→창녕/순천 상위), `nearest`, 알 수 없는 id 처리

**Phase validation**: `/api/regions?lat=37.5&lng=127.0` 응답이 거리 오름차순이고 `nearestId`가 최근접 지역.

### Phase 2: trails/observation 지역 선택 연동

두 서비스/라우터가 region 파라미터를 소비하도록 확장(하위호환 유지).

- [x] `trails/service.py` region_id 지원 + 하드코드 토큰 제거, `trails/router.py` region 쿼리
- [x] `observation/service.py` region_id 지원 + star_spot 레지스트리화, `routers/observation_map.py` region 쿼리
- [x] 기존 테스트(강화 기본 동작) 그린 유지 + region 지정 케이스 테스트 추가

**Phase validation**: region 미지정 시 최근접(강화 좌표→강화) 동작, region=yeongyang 지정 시 영양 시드 응답. `just check` 통과.

## 지역 시드 표 (best-effort — 중심좌표는 거리정렬용, 별관측 좌표는 근사)

| id | label | center(lat,lng) | trail_tokens | star_spot(name,lat,lng) |
|----|-------|-----------------|--------------|--------------------------|
| ganghwa | 인천 강화군 | 37.7469, 126.4878 | ["강화"] | 강화 천문인마을, 37.7378, 126.4708 |
| pyeongchang | 강원 평창군 | 37.3705, 128.3900 | ["평창","정선"] | 청옥산 육백마지기, 37.3607, 128.6620 |
| seosan | 충남 서산시 | 36.7849, 126.4503 | ["서산"] | (none) |
| suncheon | 전남 순천시 | 34.9506, 127.4872 | ["순천"] | (none) |
| yeongyang | 경북 영양군 | 36.6666, 129.1124 | ["영양"] | 영양 반딧불이생태공원(국제밤하늘공원), 36.6790, 129.0930 |
| muju | 전북 무주군 | 36.0069, 127.6608 | ["무주"] | 무주 반디랜드, 36.0330, 127.7360 |
| changnyeong | 경남 창녕군 | 35.5447, 128.4923 | ["창녕"] | (none) |

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 조위는 `tide_stations.py`가 좌표 최근접 자동선택이라 별도 지역 배선 불필요 — 지역 중심좌표가 suitability로 흐르면 해안 지역은 자동 매칭, 내륙은 먼 station/degraded(베스트에포트 허용).
- 별관측 스팟 좌표는 근사값 — 실측 검증은 후속 과제(brain amendment로 갱신 가능).
- 계약 CONSUMER는 flutter(후속 spec 045: 거리순 지역 선택기 UI).
- 세션 Bash 승인 이슈로 빌더가 `just check` 자체 실행 실패 시 verdict 오탐 가능 → brain이 직접 재검증.

## Amendments (post-build change history, append-only)

- 2026-09-20: 최초 작성 (brain)
- 2026-09-21: Phase 1·2 빌드 완료 (lead=claude). 멤버 세션은 이번 런에서도 Bash 권한 차단(uv run pytest 승인 대기)으로 자체 검증 불가 — 리드가 `just check`로 직접 재검증(212 passed, 12 skipped, flutter 그린) 후 체크박스 확정. 첫 Phase 1 시도는 대용량 멀티파일 프롬프트에서 permission 블록으로 실패(파일쓰기 자체는 이후 소규모 진단 태스크로 정상 확인) → 작업을 쪼개 재위임해 성공. 구현은 스펙 계약과 100% 일치(7개 지역 시드값, `/api/regions` 응답 shape, region_id 폴백 로직, star_spot 없는 지역의 degraded 생략) — 코드 리뷰로 확인.
- 2026-09-21: 크로스모델 검증(codex)에서 FAIL 2건 발견 — `observation/service.py`의 `get_observation_map`이 region 해석 후에도 eBird(`fetch_recent_obs`)/nearby-food(`fetch_nearby_food`) 호출에 여전히 호출자 원본 `lat`/`lng`를 사용해, `region_id`로 비최근접 지역을 명시 선택해도(예: 서울 좌표 + `region_id=yeongyang`) 새·음식 시드는 서울 기준으로 조회되는 계약 위반(라벨만 영양, 데이터는 서울). `star_spot` 로직은 이미 `region.star_spot` 좌표를 올바르게 사용 중이라 영향 없음. 두 번째 FAIL(회귀 테스트 부재)도 동일 위임으로 함께 해결.
  - 수정: `app/observation/service.py` — `fetch_recent_obs`/`fetch_nearby_food` 호출을 `region.center_lat`/`region.center_lng`로 변경(시그니처·기타 로직 불변).
  - 신규 테스트: `tests/observation/test_observation_service_region.py::test_selected_region_center_drives_ebird_and_food_queries` — `region_id="yeongyang"`(center 36.6666, 129.1124) 선택 시 두 fetch 콜백이 호출자 좌표(37.6, 126.4)가 아닌 영양 중심좌표로 호출됨을 `pytest.approx`로 검증.
  - 리드가 `just check` 직접 실행으로 재검증: backend 213 passed / 12 skipped, flutter 전체 그린. 체크박스는 이미 [x]였으므로 변경 없음(버그 수정이며 신규 항목 아님).
