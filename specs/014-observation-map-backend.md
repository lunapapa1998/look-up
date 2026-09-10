# 관찰 지도 backend 계약 (스팟 by 지역: 조류 eBird + 별 SQM + 노포, 측정값/적합도 분리)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-10
- modified: 2026-09-10 <brain/orchestrator>
- refs: `specs/012-trails-heritage-backend.md`(라이브 캡처+픽스처 패턴·`app/trails/tourapi.py` 재사용), `apps/backend/app/suitability/providers/light_pollution.py`(별 SQM approx 재사용), `apps/backend/app/suitability/service.py`(스팟 상세 적합도=기존 `GET /api/suitability` 재사용), `apps/backend/app/suitability/config.py`(`get_*_config` 패턴), `apps/backend/app/routers/trails.py`(라우터 스타일), design-lead 관찰지도 자문(2026-09-10, PROGRESS "관찰 지도=앱 핵심" 절), Figma `node 1-2104`/`19-1959`("생태 & 다크스카이 관찰 지도"=관찰 지도 탭 index1)
- risk: high - 신규 외부 통합(eBird API 2.0) + 다종 스팟 집계(조류 locId 집계·별 seed+SQM·노포 POI) + 신규 엔드포인트. backend publisher(flutter 관찰지도 consumer가 후속 소비). 기존 계약(`/api/suitability`,`/api/trails`) 무변경.

## Purpose

앱의 핵심인 "관찰 지도 탭"이 소비할 backend 계약을 만든다 — 유저 위치/설정 지역 주변에서 **무엇을(새·별·노포) 관찰할 수 있는지**를 스팟 목록으로 publish하는 신규 엔드포인트 `GET /api/observation-map`.

## Problem

1. 관찰 지도 탭(flutter index1)이 소비할 "지역 주변 관찰 스팟" 데이터가 전무하다 — 조류(eBird) 레이어는 아예 없고, 별/노포는 trails 계약 안에 코스 종속으로만 존재(독립 스팟 목록 없음).
2. 홈 `hotspotsProvider`가 여전히 mock이다(실 위치 기반 관찰 스팟이 없음).

## Solution

(1) eBird API 2.0 최근관측(`/data/obs/geo/recent`, `sppLocale=ko`)을 프록시·관측지(locId)로 집계해 **조류 스팟**을 만들고, (2) 기존 `LightPollutionProvider`로 **별(다크스카이) 스팟**의 SQM/Bortle 측정값을, 기존 `tourapi`로 **노포 스팟**을 채워, (3) `GET /api/observation-map?lat&lng`가 이 셋을 **측정값만 실은 스팟 목록**(degraded 플래그 포함)으로 반환한다. **적합도 점수는 이 응답에 넣지 않는다** — 스팟 탭 시 flutter가 기존 `GET /api/suitability?lat&lng&mode`(무변경)를 그 스팟 좌표로 호출한다(013 "측정값 vs 적합도 종 분리" 계승).

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/config.py` - `get_observation_config()` **추가만**(기존 무변경). `ObservationConfig(ebird_token, ebird_base_url)` — `EBIRD_API_TOKEN`(필수), `EBIRD_API_BASE_URL`(기본 `https://api.ebird.org/v2`). 토큰 없으면 조류 레이어만 비고 degrade(별/노포는 유지).
- `apps/backend/app/main.py` - `observation_map` 라우터 등록(기존 등록부 무변경).
- `apps/backend/app/suitability/providers/light_pollution.py` - **무변경 재사용**. `LightPollutionProvider().fetch(lat,lng,"night").metadata`의 `sqmValue`/`bortleClass`/`skyClass`로 별 스팟 측정값 구성.
- `apps/backend/app/trails/tourapi.py` - **무변경 재사용**. `fetch_nearby_food(lat,lng,...)`로 노포 스팟(종점 아닌 지역 중심 좌표 기준).
- `apps/backend/.env.example` - `EBIRD_API_TOKEN`/`EBIRD_API_BASE_URL` 섹션 추가(값 없이 키만, 문서화). ⚠️ 실토큰은 레포 루트 `.env`(gitignore)에 이미 있음 — 커밋 금지.
- `apps/backend/.team/member.md` - 신규 절(§21류) 추가: `GET /api/observation-map` 계약 publish(flutter 관찰지도 consumer 핸드오프).

### New Files

- `apps/backend/app/observation/__init__.py`, `models.py`, `ebird.py`, `service.py` - 신규 패키지(trails 패키지와 동형 구조).
  - `models.py`(Pydantic v2, `from __future__ import annotations`): `Coordinate(lat,lng)`(trails와 동일 형태 — 재사용 or 재정의 빌더 판단), `BirdSpecies(nameKo, nameSci, speciesCode, count:int|None, obsDt:str)`, `BirdObservation(speciesCount:int, topSpecies:list[BirdSpecies], mostRecentObsDt:str, status:str="community")`, `NightSky(sqmValue,bortleClass,skyClass,status="approx")`(trails와 동일), `HeritageInfo(addr, distanceM:int|None, contentId)`, `ObservationSpot(id, kind:Literal["bird","star","heritage"], name, coord, nightSky:NightSky|None, birds:BirdObservation|None, heritage:HeritageInfo|None)`, `ObservationMapResponse(region, degraded:bool, spots:list[ObservationSpot])`. **kind별로 정확히 하나의 측정 블록만 non-null**(bird→birds, star→nightSky, heritage→heritage). 적합도(score) 필드 없음(의도적 — §설계).
  - `ebird.py`: `parse_recent_obs(payload:list[dict]) -> list[dict]`(순수 파서 — 각 레코드 `comName/sciName/speciesCode/howMany/obsDt/lat/lng/locId/locName/obsValid` 매핑, `howMany` 없으면 None). `aggregate_by_location(obs:list[dict]) -> list[dict]`(locId로 묶어 스팟화: 관측지명=locName, 좌표=대표 lat/lng, `topSpecies`=count 내림차순 top N(예 5), `speciesCount`=distinct species, `mostRecentObsDt`=max obsDt). `fetch_recent_obs(lat,lng,client=None,dist=25,back=14,max_results=100) -> list[dict]`(config에서 token/base 비면 즉시 `[]`; `GET {base}/data/obs/geo/recent`+header `X-eBirdApiToken`+`sppLocale=ko`; **모든 예외 흡수→`[]`**, client 소유권 패턴은 trails durunubi와 동일).
  - `service.py`: `ObservationMapService`(DI: `fetch_recent_obs`/`light_pollution_provider`/`fetch_nearby_food`, 생략 시 기본 배선). `get_observation_map(lat,lng) -> dict`: (a) 지역 매칭(trails의 `DEFAULT_REGION`/`match_region` 시드 재사용 or 동형 — v1 강화 고정 시드 허용), (b) **조류 스팟**=eBird fetch→집계, (c) **별 스팟**=지역 seed 다크스카이 좌표(최소 1개, 예 강화 천문인마을) + `LightPollutionProvider` SQM, (d) **노포 스팟**=`fetch_nearby_food` top N, (e) 각 소스 개별 실패는 흡수(해당 kind만 비고 나머지 유지), 전부 실패 시 `degraded=true`. 좌표/필드 검증은 라우터(Pydantic).
- `apps/backend/app/routers/observation_map.py` - `GET /api/observation-map?lat&lng`(query 검증=`validate_coordinates` 재사용, 범위 밖 422). `app/routers/trails.py`와 동일 패턴, `get_observation_map_service()` Depends 싱글톤. **주의: 기존 `routers/observations.py`(생태일기)와 다른 파일·다른 경로**(`/api/observation-map`).
- `apps/backend/tests/observation/` - `fixtures/ebird_recent_ganghwa.json`(아래 §라이브 캡처 실데이터 임베드), `fixtures/ebird_notable.json`(선택), `test_observation_parsers.py`(parse/aggregate 순수함수), `test_observation_service.py`(fake 3소스 주입, 네트워크 0: 조류 집계·별 seed·노포·부분실패 degrade·전체실패 degrade), `test_observation_endpoint.py`(fake service 주입, happy/degraded/422), `tests/suitability/test_live.py`에 eBird 라이브 스모크 1건 추가(`RUN_LIVE_TESTS` 게이트).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 모델 + eBird 파서/집계 (순수, 네트워크 없음)

- [x] `app/observation/models.py`(위 스키마, kind별 단일 측정 블록, 적합도 필드 없음).
- [x] `app/observation/ebird.py`의 `parse_recent_obs`/`aggregate_by_location`(순수 함수) + 픽스처 `ebird_recent_ganghwa.json`(§라이브 캡처 임베드).
- [x] `test_observation_parsers.py`(파싱 필드/캐스팅, locId 집계·topSpecies 정렬·mostRecentObsDt·speciesCount, howMany None 방어).

**Phase validation**: `just check` green(신규 파서 테스트 통과, 기존 회귀 없음). — 확인됨(리드, 101 passed/7 skipped).

### Phase 2: config + eBird fetch + 3소스 서비스 조립

- [x] `config.get_observation_config()` 추가(EBIRD_API_TOKEN/BASE_URL, tide/trails와 동일 패턴).
- [x] `ebird.fetch_recent_obs`(token/base 비면 `[]`, 모든 예외 흡수, sppLocale=ko).
- [x] `service.ObservationMapService.get_observation_map`(조류 집계 + 별 seed+SQM + 노포, 부분실패 흡수, 전체실패 degrade). 지역 매칭은 trails 시드 재사용/동형(v1 강화 고정 허용).
- [x] `test_observation_service.py`(fake 3소스, 네트워크 0: 집계/별/노포/부분·전체 degrade).

**Phase validation**: `just check` green. — 확인됨(리드, 106 passed/7 skipped).

### Phase 3: 라우터 + 계약 publish + 라이브 스모크

- [x] `routers/observation_map.py`(`GET /api/observation-map`, Query ge/le로 422 — trails.py/suitability.py와 동일 패턴, `validate_coordinates`는 기존에도 미사용 죽은 코드라 재사용하지 않음) + `main.py` 등록.
- [x] `test_observation_endpoint.py`(fake service 주입 happy/degraded/lat누락 422/범위 422).
- [x] `.env.example` eBird 섹션 + `tests/suitability/test_live.py`에 eBird 라이브 스모크(`RUN_LIVE_TESTS` 게이트) 추가.
- [x] `.team/member.md`에 `GET /api/observation-map` 계약 publish(§25).

**Phase validation**: 아래 Validation Commands. — 확인됨(리드, 111 passed/8 skipped, 신규 라이브 테스트는 기본 실행에서 SKIPPED). 발사 후 브레인 uvicorn end-to-end 라이브 검증(강화 좌표 → 조류/별/노포 스팟 실데이터 확인, `/api/suitability` 재사용 정합) — 아래 Notes에 결과 기록.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: `GET /api/observation-map`(조류 eBird 집계·별 SQM seed·노포), 측정값만(적합도 제외), degraded, 지역 시드 매칭(v1 강화), eBird ko 로케일·정직 필드(obsDt·status=community). config/env/계약 publish/픽스처/라이브 스모크.
- **제외(후속)**: 조류 히트맵 집계·Bortle 색면 raster·다중 지역 bbox·"이 지역 검색"·트레일 선 레이어(트레일 탭이 이미 담당)·스팟 상세 적합도 신규 엔드포인트(기존 `/api/suitability` 재사용)·notable 전용 강조 로직(픽스처만 확보, 렌더는 flutter 후속).

### ⭐ 설계 핵심 — 측정값 vs 적합도 분리 (013 계승, 절대 위반 금지)
- 스팟 목록 응답은 **측정값만**: 별=SQM/Bortle(장소 고정), 조류=최근관측 종수+obsDt(관측 로그), 노포=주소/거리. **score(적합도) 필드를 넣지 마라.**
- 적합도는 "스팟 탭 → 시트 상세"에서 flutter가 **기존 `GET /api/suitability?lat&lng&mode`**를 그 스팟 좌표로 호출(신규 backend 없음). 시점이 "지금"으로 확정되는 그 화면에서만 점수가 의미.
- 이유: 지도에 여러 스팟이 동시에 뜨는데 시점 의존 점수를 핀마다 박으면 시점 불명·소음(design-lead A-4).

### ⭐ eBird 정직 표기 (013 P1-4 계승, 절대 위반 금지)
- eBird는 **과거 시민관측 로그**다. 응답 `status`는 항상 `"community"`(절대 `"live"` 아님). `obsDt`(관측 시각)를 **필수로 실어** flutter가 "최근 관측·N일 전"으로 표기하게 한다. backend는 "실시간/지금 출현" 뉘앙스 필드를 만들지 않는다.
- `obsValid`(eBird 검토 플래그)도 실어 flutter가 신뢰도 표기에 쓸 수 있게(선택).

### 라이브 캡처 그라운드 트루스 (브레인, 2026-09-10, 강화 37.5921/126.3984 — 스펙 임베드, 008/012 패턴)
- **엔드포인트**: `GET https://api.ebird.org/v2/data/obs/geo/recent?lat=&lng=&dist=25&back=14&maxResults=100&sppLocale=ko`, header `X-eBirdApiToken: <EBIRD_API_TOKEN>`. HTTP 200, JSON 배열.
- **레코드 필드**(실캡처): `comName`(ko 로케일 시 한국어 "알락꼬리마도요"), `sciName`, `speciesCode`, `howMany`(int, **없을 수 있음→None**), `obsDt`("2026-09-09 16:16"), `lat`,`lng`, `locId`("L..."), `locName`("영종도--송산만과 갯벌(...)"), `locationPrivate`(bool), `obsValid`(bool), `obsReviewed`(bool), `subId`.
- **집계 근거**: 100건이 distinct **9개 locId(관측지=birding hotspot)**로 묶임 → locId 집계로 스팟화가 자연스러움. 실측 예: 영종도 송산만 갯벌(알락꼬리마도요 280·개꿩 80·중부리도요 4·흑꼬리도요 6…). **좌표는 관측지 대표점**(같은 locId면 동일 lat/lng).
- **notable(희귀/특이)** `GET /data/obs/geo/recent/notable?...&detail=full`: 청머리오리, 혹부리오리 70, **한국뜸부기 @ "강화도--여차리 물꽝"**(Figma 목업의 여차리 갯벌과 실제 일치). MVP는 일반 recent만; notable은 픽스처만 확보(후속 강조용).
- **토큰**: 레포 루트 `.env`에 `EBIRD_API_TOKEN`(36자 UUID형) 존재·유효 확인(브레인 라이브 200). 멤버는 네트워크 없으니 **픽스처로 구현**하고, 브레인이 발사 후 uvicorn 라이브 검증.

### 재사용 맵 (신규 최소화)
- 별 SQM: `LightPollutionProvider().fetch(lat,lng,"night")` → `.metadata` `sqmValue/bortleClass/skyClass`(status="approx"). 신규 코드 없음.
- 노포: `app/trails/tourapi.py:fetch_nearby_food(lat,lng,...)` 그대로. (지역 중심 좌표 기준으로 호출.)
- 지역 시드: `app/trails/service.py`의 `DEFAULT_REGION_LABEL`/`DEFAULT_REGION_TOKENS`/`match_region` — 재사용 or 동형(v1 강화 고정 허용, 실 역지오코딩은 후속).
- 스팟 상세 적합도: 기존 `GET /api/suitability`(신규 없음).

### §계약 초안 (member.md publish용)
```
### GET /api/observation-map
Query: lat (-90..90, required), lng (-180..180, required).
200 (ObservationMapResponse):
{
  "region": "인천 강화군",
  "degraded": false,                 // 3소스 전부 실패 시 true
  "spots": [
    { "id": "bird:L123456", "kind": "bird",
      "name": "영종도 송산만과 갯벌", "coord": {"lat":37.47,"lng":126.53},
      "birds": { "speciesCount": 12, "mostRecentObsDt": "2026-09-09 16:16",
                 "status": "community",
                 "topSpecies": [ {"nameKo":"알락꼬리마도요","nameSci":"Numenius madagascariensis",
                                  "speciesCode":"faecur","count":280,"obsDt":"2026-09-09 16:16"} ] },
      "nightSky": null, "heritage": null },
    { "id": "star:ganghwa-astro", "kind": "star",
      "name": "강화 천문인마을", "coord": {...},
      "nightSky": {"sqmValue":21.7,"bortleClass":3,"skyClass":"Class 3 ...","status":"approx"},
      "birds": null, "heritage": null },
    { "id": "heritage:855186", "kind": "heritage",
      "name": "강화어부네꽃게탕", "coord": {...},
      "heritage": {"addr":"인천 강화군 ...","distanceM":377,"contentId":"855186"},
      "birds": null, "nightSky": null }
  ]
}
```
- kind별 정확히 하나의 측정 블록만 non-null. **적합도(score) 필드 없음** — 스팟 탭 시 `GET /api/suitability` 재사용.
- 조류 status는 항상 `community`(절대 live 아님), `obsDt` 필수.

### 불변 원칙
- 기존 계약(`/api/suitability`,`/api/trails`,`/api/observations`) 무변경. `LightPollutionProvider`/`tourapi`/`suitability/service` 무변경 재사용. `.env` 실토큰 커밋 금지(.env.example엔 키만). 지역 시드 v1=강화 고정(후속 역지오코딩). eBird status=community·obsDt 필수(정직).

### 교훈 계승 (008/012)
- 외부 API 신규 통합 → 브레인 라이브 캡처 그라운드 트루스 임베드 + 멤버 오프라인 픽스처 구현 + 브레인 발사 후 uvicorn 라이브 검증(008 tide·012 trails 성공 패턴). 크로스모델(codex) verify가 오프라인 결함 커버.
- 멤버 자체 완료 보고 불신 — 리드/브레인이 `just check` 직접 재실행([[factory-verdict-false-negative]]).

## Amendments (post-build change history, append-only)

- 2026-09-10 (리드): 3 phase 전부 구현·`just check`로 직접 재검증(111 passed, 8 skipped, flutter 회귀 없음). 라우터 422는 스펙 원문의 `validate_coordinates 재사용` 대신 기존 `trails.py`/`suitability.py`와 동일한 `Query(ge=,le=)` 패턴을 썼음 — `validate_coordinates`는 이 리포에서 애초에 어디서도 호출되지 않는 죽은 함수라 실제 컨벤션과 스펙 문구가 어긋나 있었음(기존 라우터들과 일관성을 우선함).
- 2026-09-10 (리드): Phase validation 마지막 항목("발사 후 브레인 uvicorn end-to-end 라이브 검증")은 **미완료** — 이 리드 세션의 Bash 툴이 `uv run uvicorn ...`(백그라운드 서버 기동)과 `curl`을 전부 "requires approval"로 차단해(헤드리스 모드라 승인 프롬프트를 띄울 수 없음 — 스카우트가 남긴 것과 동일한 제약) 실행하지 못함. `tests/suitability/test_live.py::test_observation_map_service_live_fetch`(신규, RUN_LIVE_TESTS=1 게이트)가 오프라인 스위트에서는 SKIPPED로만 확인됨. **오너가 대화형 세션에서 `RUN_LIVE_TESTS=1 uv run pytest -m live -q`(apps/backend/) 또는 실제 uvicorn 기동 후 강화 좌표(`lat=37.7378&lng=126.4708`)로 `GET /api/observation-map` curl 검증을 직접 수행 필요**.
- 2026-09-10 (리드, 재검증): 크로스모델(codex) verifier가 동일한 FAIL(Phase 3 uvicorn 라이브 검증 미수행)을 재보고. 재진단 결과 이는 코드 결함이 아니라 구조적 권한 제약임을 확인: (1) 라이브 스모크 테스트(`test_observation_map_service_live_fetch`, `-m live`)는 이미 정상 구현되어 기존 `just suitability-live`(`RUN_LIVE_TESTS=1 uv run pytest -m live -q -s`) 레시피로 그대로 실행 가능함 — 코드 누락 없음. (2) 리드 Bash는 `just member-build`/`just check` 프리픽스로만 화이트리스트되어 `just suitability-live`/uvicorn/curl을 직접 실행 불가. (3) `backend-engineer` 멤버는 Bash 툴 자체가 없어(Read/Grep/Glob/Edit/Write만) pytest·uvicorn 실행 불가. (4) 스카우트(jetski)도 동일 사유("command 권한, 헤드리스 승인 불가")로 실행 실패. 이 단계는 스펙 설계상 원래도 "브레인 발사 후 uvicorn 라이브 검증"으로 명시되어 있어 리드/멤버 계층 책임이 아님. 같은 지점이 두 세션째 동일하게 막혀 재위임하지 않고 사용자/브레인에게 에스컬레이션함(코디네이션 코어 규칙 5) — 대화형 세션에서 `just suitability-live` 실행 또는 uvicorn 기동 후 강화 좌표(`lat=37.7378&lng=126.4708`) curl 검증 필요.
- modified: 2026-09-10, lead: claude-sonnet-5
- 2026-09-10 (brain, 라이브 검증 완료 — codex 유일 FAIL 해소): 리드가 규칙5대로 에스컬레이션한 "발사 후 uvicorn end-to-end 라이브 검증"을 브레인이 수행. `.env` 실토큰으로 uvicorn 기동 → `GET /api/observation-map?lat=37.5921&lng=126.3984`(강화) **HTTP 200, region "인천 강화군", degraded=false, 18 스팟(조류 14 + 별 1 + 노포 3)**. 조류=eBird 실데이터 locId 집계(영종도 송산만 갯벌 36종·알락꼬리마도요 280, 강화 여차리 갯벌/물꽝, 초지리 들판 황로 14 등), 전부 `status="community"` + `mostRecentObsDt`(정직 표기 준수, "live" 아님). 별=강화 천문인마을 SQM 16.81 Bortle 8 approx(light_pollution 재사용). 노포=꽃게와낙지 1363m 등 3(tourapi 재사용). **응답에 `score`(적합도) 필드 없음 확인 — 측정값/적합도 종분리 준수.** codex verify가 지적한 유일 FAIL(라이브 검증 미수행)은 코드 결함이 아니라 이 브레인 단계 미완이었고 이로써 해소. `just backend-check` 111 passed/8 skipped green. **실질 PASS 확정 → 체크포인트 커밋.** verdict=FAIL은 verify2 미기록發 false-negative([[factory-verdict-false-negative]]).
