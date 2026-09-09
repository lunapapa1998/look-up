# 트레일·노포 카탈로그 실연동 (두루누비 코스 + 종점 밤하늘 + 근처 노포)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-09
- modified: 2026-09-09 <brain/orchestrator>
- refs: `specs/008-tide-live-backend.md`(라이브 캡처 패턴), `apps/backend/app/suitability/service.py`(featured 적합도 재사용), `apps/backend/.team/member.md` §8(계약 스타일), design-lead IA 자문(2026-09-09, 아래 Notes 요약)
- modified: 2026-09-09, lead: backend-lead(claude)
- modified: 2026-09-10, lead: backend-lead(claude)
- risk: high - 외부 실 API 2종 신규 연동(두루누비 courseList + GPX 파일 + TourAPI locationBasedList2, 브레인 라이브 캡처 그라운드 트루스 기반) + 신규 엔드포인트/모델/계약. backend 레인 갇힘, 소비 계약 신규 publish(§14).

## Purpose

"트레일·노포" 탭이 물 backend 계약을 신설한다: 사용자 권역의 두루누비 걷기 코스 카탈로그를 코스별 거리/소요/난이도 + 시작·종점 좌표 + 종점 밤하늘(SQM/Bortle) + 코스 종점 근처 노포(음식점 POI)로 반환하고, 최상위 featured 코스 1개에만 낮/밤 관측 적합도를 실연동한다.

## Problem

트레일·노포 탭은 현재 `PlaceholderScreen`("준비 중이에요")이고 backend에 트레일/노포 데이터가 전혀 없다. 두루누비 `courseList`에는 위경도 필터 파라미터가 없어(전국 페이징) "내 근처 코스"를 좌표로 못 거른다. 코스별 풀 다층 적합도(KMA 격자 등)는 캐싱 없이 코스마다 계산하면 지연이 과하다.

## Solution

`GET /api/trails?lat&lng`를 신설한다: (1) 두루누비 `courseList`(brdDiv=DNWW)를 페이징 조회해 사용자 위치의 역지오코딩 권역 토큰으로 `sigun`을 매칭·필터, (2) 상위 K=5 코스의 `gpxpath` GPX를 받아 시작/종점 좌표(첫/끝 trackpoint) 추출, (3) 각 종점의 밤하늘 지표를 기존 `LightPollutionProvider`(무네트워크 approx)로, (4) 각 종점 근처 노포를 TourAPI `locationBasedList2`(contentTypeId=39, 거리순)로 top 3, (5) 랭킹 1위(featured) 코스에만 기존 `SuitabilityService`로 낮·밤 적합도를 실연동한다. 모든 외부 호출 실패는 흡수해 `degraded=true` + 결정적 폴백으로 degrade하며 절대 raise하지 않는다(005/008 방어 패턴).

## Relevant Files

### Existing Files

- `apps/backend/app/main.py` - `app.include_router(trails.router)` 한 줄 추가.
- `apps/backend/app/suitability/config.py` - `get_trails_config()` 추가(두루누비 base_url `DURUNUBI_BASE_URL`, TourAPI base_url `TOURAPI_BASE_URL`, `DATA_GO_KR_SERVICE_KEY(_DECODED)` unquote 재사용 — KASI/tide와 동일 패턴, **새 키 불필요**).
- `apps/backend/.env.example` - `DURUNUBI_BASE_URL`/`TOURAPI_BASE_URL` 문서화(기본값 있음). 키는 기존 data.go.kr 재사용 주석.
- `apps/backend/.team/member.md` - §14 신규 절 추가(아래 §14 초안 그대로 publish). flutter consumer 핸드오프.

### New Files

- `apps/backend/app/trails/__init__.py`
- `apps/backend/app/trails/models.py` - pydantic 응답 모델(`Coordinate`, `NightSky`, `HeritageEat`, `CourseSuitability`, `TrailCourse`, `TrailsResponse`). 스키마는 아래 §14.
- `apps/backend/app/trails/durunubi.py` - 두루누비 클라이언트. `fetch_courses(brd_div="DNWW", max_rows)` → courseList 조회(순수 파싱 함수 `parse_course_list(payload)` 분리), `fetch_gpx_endpoints(gpx_url)` → GPX 텍스트 받아 시작/종점 좌표(순수 파서 `parse_gpx_endpoints(gpx_text)` = 첫/끝 `<trkpt lat lon>`). 예외 흡수.
- `apps/backend/app/trails/tourapi.py` - TourAPI 노포 클라이언트. `fetch_nearby_food(lat, lng, radius, rows)` → locationBasedList2 조회(순수 파서 `parse_food_list(payload)` 분리). 예외 흡수 → 빈 리스트.
- `apps/backend/app/trails/service.py` - `TrailsService`: 권역 매칭(`match_region(place_tokens, courses)` 순수 함수) → 상위 K GPX/SQM/노포 조립 → featured 적합도(주입된 `SuitabilityService` 재사용) → `TrailsResponse`. 좌표 근접이 아니라 **sigun 문자열 매칭**(오너 결정). 역지오코딩 권역 토큰 유도는 아래 Notes 참조.
- `apps/backend/app/routers/trails.py` - `GET /api/trails` 라우터(`suitability.py` 미러). `lat`/`lng` Query 검증.
- `apps/backend/tests/trails/__init__.py`
- `apps/backend/tests/trails/fixtures/durunubi_courselist.json` - **아래 Notes의 실 캡처 courseList** 축약본(2~3 item). 손으로 지어내지 말 것.
- `apps/backend/tests/trails/fixtures/durunubi_course.gpx` - **아래 Notes의 실 GPX 축약본**(첫3+끝3 trackpoint) 그대로 저장.
- `apps/backend/tests/trails/fixtures/tourapi_food.json` - **아래 Notes의 실 캡처 locationBasedList2** 축약본.
- `apps/backend/tests/trails/test_trails_parsers.py` - 순수 파서 단위 테스트(courseList 파싱, GPX 시작/종점, 노포 파싱, sigun 매칭). 네트워크 0, 픽스처 기반.
- `apps/backend/tests/trails/test_trails_service.py` - `TrailsService`를 fake 클라이언트/`FakeSuitabilityService`로 조립 테스트(랭킹, featured만 적합도, degrade 폴백, 노포 top3).
- `apps/backend/tests/trails/test_trails_endpoint.py` - `TestClient`로 `GET /api/trails` 200 스키마 검증(서비스 의존성 override, 네트워크 0).
- `apps/backend/tests/suitability/test_live.py` - `@pytest.mark.live` 그룹에 두루누비 courseList + GPX + TourAPI 실 호출 스모크 케이스 추가(`degraded in (True,False)` 허용, reason surface).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 순수 파서 코어 + 모델 + config

두루누비/GPX/TourAPI 응답을 네트워크 없이 파싱하는 순수 함수와 응답 모델, config를 만든다.

- [x] `models.py`: §14 스키마대로 pydantic 모델.
- [x] `config.py`: `get_trails_config()`(두루누비/TourAPI base_url + data.go.kr 키 unquote 재사용).
- [x] `durunubi.py`의 `parse_course_list(payload)`(dict item 또는 단일 item 방어) + `parse_gpx_endpoints(gpx_text)`(첫/끝 `<trkpt>` → `Coordinate` start/end; trackpoint 0개면 `ValueError`).
- [x] `tourapi.py`의 `parse_food_list(payload)`(item 리스트/단일 방어, `dist` float, top N slice).
- [x] `service.py`의 `match_region(place_tokens, courses)` 순수 함수(코스 `sigun`에 권역 토큰이 부분포함되면 매칭; 대소문자/공백 정규화).
- [x] 픽스처 3종을 Notes 실 캡처로 저장. `test_trails_parsers.py`로 단위 검증.

**Phase validation**: `cd apps/backend && uv run pytest tests/trails/test_trails_parsers.py -q` (네트워크 0). — 브레인이 `just check`로 실행 확인(84 passed, 4 skipped, 0 failed, 2026-09-09).

### Phase 2: 클라이언트 fetch + 서비스 조립(적합도 제외)

실 API를 치는 fetch 메서드와, featured 적합도를 뺀 카탈로그 조립을 만든다.

- [x] `durunubi.py`: `fetch_courses()`(courseList GET, `_type=json`, brdDiv=DNWW, numOfRows 크게) + `fetch_gpx_endpoints(gpx_url)`(GPX 텍스트 GET → `parse_gpx_endpoints`). 모든 예외 흡수.
- [x] `tourapi.py`: `fetch_nearby_food(lat,lng,...)`(locationBasedList2 GET, mapX=lng/mapY=lat, contentTypeId=39, arrange=E). 예외 → `[]`.
- [x] `service.py`: `get_trails(lat,lng)` → (역지오코딩 권역 토큰은 backend가 아직 안 함 → **Notes의 sigun 후보 유도 규칙** 적용, 최소안으로 축소: 좌표 무관 강화군 토큰 고정) → `match_region` → 상위 K=5 → 각 코스 GPX 종점 + `LightPollutionProvider().fetch(end)` SQM + `fetch_nearby_food(end)` top3. courseList 실패/매칭 0건 → `degraded=true` + Notes 폴백.
- [x] `test_trails_service.py`: fake 클라이언트로 랭킹/폴백/노포 top3 검증.

**Phase validation**: `just backend-check`(전체 오프라인 green). — 브레인이 `just check`로 실행 확인(89 passed, 4 skipped, 0 failed, 2026-09-09).

### Phase 3: featured 적합도 + 엔드포인트 + 라이브 스모크 + 계약

- [x] `service.py`: 랭킹 1위(featured) 코스 종점에 대해 주입된 `SuitabilityService.get_suitability(endLat,endLng,mode)`를 day/night 두 번 호출 → `daySuitability`/`nightSuitability`(각 score/label/status). 나머지 코스는 `null`. 적합도 예외는 흡수(featured에 적합도 없으면 `null`, degrade 아님).
- [x] `routers/trails.py` + `main.py` 등록. `test_trails_endpoint.py`(서비스 override, 200 스키마).
- [x] `test_live.py`에 두루누비+GPX+TourAPI 실 호출 스모크 추가. `.env.example` 갱신.
- [x] `member.md` §14 publish.
- [x] `just check` 전체 green(live 제외 offline).

**Phase validation**: 아래 Validation Commands.

### Phase 4: 후보 상한 바운딩 (codex verify FAIL 반영, 2026-09-10)

codex verify가 "GPX fetch가 top-K slice 전에 매칭 전부에 대해 일어남"을 FAIL로 지적. 근본 원인은 스펙 자기모순(위 "GPX fetch 바운딩" 정정 참조)이므로 스펙을 정정하고, 무한 성장 방어로 명시적 후보 상한을 코드에 추가한다.

- [x] `service.py`: `match_region` 결과를 GPX fetch **전에** 결정적 순서(`crsIdx` 사전순 등)로 `CANDIDATE_LIMIT=15`개까지 잘라 후보 확정 → 그 후보들만 GPX/SQM 계산 → SQM 랭킹 후 top-K=5 slice(기존 유지). 모듈 상수로 노출.
- [x] `test_trails_service.py`: 매칭 > `CANDIDATE_LIMIT`일 때 GPX fetch가 정확히 `CANDIDATE_LIMIT`회로 제한됨을 검증(기존 "N매칭→N GPX" 케이스는 N≤15에서 유효 유지, 변경 불필요).

**Phase validation**: `just check` green + codex 재검증 통과.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just check
```

## Notes (agent scratchpad)

### ⭐ 브레인 라이브 캡처 그라운드 트루스 (2026-09-09, 실 API 실측 — 추정 금지)

#### A. 두루누비 courseList (코스 목록)
- **엔드포인트**: `GET {DURUNUBI_BASE_URL}/courseList`, `DURUNUBI_BASE_URL=https://apis.data.go.kr/B551011/Durunubi`.
- **요청 파라미터**: `serviceKey`(필수, 기존 data.go.kr decoded 키 — httpx params 이중인코딩 방지 위해 KASI/tide처럼 `unquote`된 decoded 키 사용), `MobileOS=ETC`, `MobileApp=lookup`, `_type=json`(JSON 정상 응답), `numOfRows`, `pageNo`, `brdDiv=DNWW`(걷기여행길; 자전거=DNMT 등). **위경도 필터 파라미터 없음** — 전국 코스 페이징이므로 numOfRows를 크게(예 1000) 잡고 `sigun` 문자열로 필터.
- **응답(JSON)**: `response.body.items.item`(리스트; 1건이면 dict일 수 있어 방어). `response.header.resultCode=="0000"`가 정상. item이 없거나 resultCode≠0000이면 degrade.
- **item 필드**(실측 키): `crsIdx`(코스 ID, 예 `T_CRS_MNG0000005118`), `crsKorNm`(코스명 예 "남파랑길 3코스"), `sigun`(권역 문자열 예 "부산 영도구" / "인천 강화군"), `crsDstnc`(거리, **km 정수/실수 문자열** 예 "14"), `crsTotlRqrmHour`(총소요 **분** 문자열 예 "330"), `crsLevel`(난이도 "1"~"3"), `crsCycle`("순환형"/"비순환형"), `crsContents`/`crsSummary`/`crsTourInfo`(HTML 설명, `<br>` 포함), `travelerinfo`(시점/종점 **주소 텍스트** — 좌표 아님), `gpxpath`(GPX 파일 URL), `routeIdx`(테마 ID), `brdDiv`.
- ⚠️ `crsDstnc`/`crsTotlRqrmHour`/`crsLevel`은 전부 **문자열** → 파서에서 숫자 캐스팅(빈/비정상 값 방어).

#### B. GPX 파일 (시작/종점 좌표 소스)
- `courseList` item의 `gpxpath`가 GPX **파일 URL**(durunubi.kr 호스트, 예 `https://www.durunubi.kr/editImgUp.do?filePath=/data/.../xxx.gpx`). 좌표는 courseList JSON에 인라인으로 없고 이 파일에만 있음.
- **파일 형식**: GPX 1.1 XML. `<trkpt lat="35.09.." lon="129.03..">` 다수(실측 한 코스 1492개) + 선택 `<ele>`. **시작=첫 trkpt, 종점=마지막 trkpt**.
- **파서 규칙**: 정규식 `lat="([-\d.]+)"\s+lon="([-\d.]+)"`로 순서대로 추출, 첫/끝을 start/end로. 0개면 `ValueError`(→ 상위 try/except가 그 코스를 좌표 없이 스킵 또는 degrade).
- ⚠️ 런타임엔 서버가 파일을 실제로 fetch(서버 네트워크 있음). 단위 테스트는 아래 축약 GPX 픽스처로만(네트워크 0).

#### C. TourAPI 노포(음식점) locationBasedList2
- **엔드포인트**: `GET {TOURAPI_BASE_URL}/locationBasedList2`, `TOURAPI_BASE_URL=https://apis.data.go.kr/B551011/KorService2`.
- **요청 파라미터**: `serviceKey`(동일 decoded 키), `MobileOS=ETC`, `MobileApp=lookup`, `_type=json`, `numOfRows`, `pageNo`, `mapX`(**경도 lng**), `mapY`(**위도 lat**), `radius`(미터, 예 5000), `contentTypeId=39`(음식점), `arrange=E`(거리순; E=대표이미지정렬+거리순, S=거리순 — 거리순이면 top N이 최근접).
- **응답(JSON)**: `response.body.items.item`(리스트/단일 방어). item 필드(실측): `title`(상호), `addr1`(주소), `dist`(**거리 m, 실수 문자열**), `mapx`(경도)/`mapy`(위도), `tel`(빈 값 흔함), `firstimage`(빈 값 흔함), `contentid`(POI ID), `contenttypeid`("39"), `cat3`/`sigungucode`.
- **노포 정의(v1)**: "노포"를 판별하는 플래그는 TourAPI에 없음 → v1은 **종점 근처 음식점 POI**를 거리순 top 3으로 그대로 노출(이름/주소/거리/좌표/contentId). ⚠️ **영업시간(opentimefood via detailIntro2)·"골든타임 사이 영업 노포" 로직은 스코프 밖(후속 부채)** — design-lead §5-3, 아래 후속 참조.

### 실 캡처 픽스처 (그대로 저장 — 지어내지 말 것)

`durunubi_courselist.json` (축약, 2 item):
```json
{"response":{"header":{"resultCode":"0000","resultMsg":"OK"},"body":{"items":{"item":[
 {"crsIdx":"T_CRS_MNG0000005118","crsKorNm":"남파랑길 3코스","sigun":"부산 영도구","crsDstnc":"14","crsTotlRqrmHour":"330","crsLevel":"2","crsCycle":"비순환형","routeIdx":"T_ROUTE_MNG0000000001","brdDiv":"DNWW","gpxpath":"https://www.durunubi.kr/editImgUp.do?filePath=/data/koreamobility/file/2025/05/sample.gpx","travelerinfo":"- 시점 : 영도대교 입구(부산 중구 태종로 8)<br>- 종점 : 감천사거리(부산 사하구 감천동)"},
 {"crsIdx":"T_CRS_MNG0000009999","crsKorNm":"서해랑길 강화 코스","sigun":"인천 강화군","crsDstnc":"11","crsTotlRqrmHour":"210","crsLevel":"1","crsCycle":"비순환형","routeIdx":"T_ROUTE_MNG0000000064","brdDiv":"DNWW","gpxpath":"https://www.durunubi.kr/editImgUp.do?filePath=/data/koreamobility/file/2025/05/ganghwa.gpx","travelerinfo":"- 시점 : 강화 창후리<br>- 종점 : 여차리 갯벌"}
]}}}}
```

`durunubi_course.gpx` (축약, 실측 첫3+끝3 trackpoint):
```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="GPS Visualizer">
 <trk><name>sample</name><trkseg>
  <trkpt lat="35.0965626320323" lon="129.035967774477"><ele>8.102</ele></trkpt>
  <trkpt lat="35.096704206603" lon="129.035932154219"><ele>9.607</ele></trkpt>
  <trkpt lat="35.0967668428986" lon="129.035909652987"><ele>10.271</ele></trkpt>
  <trkpt lat="35.0872876798053" lon="129.004815420786"><ele>15.042</ele></trkpt>
  <trkpt lat="35.0873771276554" lon="129.004746498963"><ele>15.76</ele></trkpt>
  <trkpt lat="35.0874667791044" lon="129.004487268964"><ele>16.742</ele></trkpt>
 </trkseg></trk>
</gpx>
```
→ 파싱 기대: start=(35.0965626320323, 129.035967774477), end=(35.0874667791044, 129.004487268964).

`tourapi_food.json` (축약, 2 item — 실측 강화 여차리 부근):
```json
{"response":{"header":{"resultCode":"0000","resultMsg":"OK"},"body":{"items":{"item":[
 {"title":"꽃게와낙지","addr1":"인천광역시 강화군 화도면 해안남로2029번길 7","dist":"1363.6063908871436","mapx":"126.4097886867","mapy":"37.6003291209","tel":"","firstimage":"","contentid":"855186","contenttypeid":"39"},
 {"title":"멍때림","addr1":"인천광역시 강화군 화도면 해안남로 1970-34","dist":"1974.3362329380407","mapx":"126.4101967937","mapy":"37.6071699975","tel":"","firstimage":"","contentid":"2836874","contenttypeid":"39"}
]}}}}
```

### 설계/제약

- **팀 권한 한계 인지(005/008 재확인)**: backend-engineer 워커는 Bash/네트워크 없음 → 라이브 캡처·`uv run pytest` 자체 실행 불가. 위 그라운드 트루스·픽스처를 완비했으니 파서는 픽스처로만 단위 검증(네트워크 0). **verify가 라이브 사유로 FAIL하면 스펙 결함 아님** — 브레인이 `test_live.py` + 실 호출로 최종 확인.
- **sigun 권역 유도(v1 임시 규칙)**: backend는 아직 역지오코딩을 하지 않는다(007에서 flutter만 함). v1은 좌표→권역을 위해 **정적 근사**를 쓴다: `TrailsService`에 소수의 시드 권역 bbox/중심(강화·서해안 등 앱 기본 권역 최소 1개 + 필요한 만큼)을 두고 `lat/lng`에 가장 가까운 권역의 **sigun 토큰 리스트**(예 ["강화","인천 강화"])를 골라 `match_region`에 넘긴다. 좌표 근접 코스 랭킹(전국 GPX 파싱)은 명시적 후속(성능·캐싱 필요). ⚠️ 이 규칙이 과하면 빌더는 "사용자 lat/lng와 무관하게 기본 권역(강화) 토큰 고정" 최소안으로 축소해도 됨(첫 조각 목표는 계약·배선).
- **랭킹**: 매칭된 코스를 **종점 SQM(밤하늘) 높은 순** 정렬 → 상위 K=5. 1위가 featured. ⚠️ **결정적 tie-break 필수**(design-lead 검수 §3-2): SQM approx는 정적 격자라 인접 코스가 동값으로 뭉칠 수 있음 → 동점 시 2차 키(거리 짧은 순), 그래도 동점이면 3차 키(`crsIdx` 사전순)로 고정. 새로고침마다 featured가 흔들리면 "데이터 불안정" 인상.
- **비용 바운딩**: 풀 다층 적합도(`SuitabilityService`)는 **featured 1개 × (day+night) = 2회만** 호출(KMA 격자 등 무거움). 리스트의 나머지 코스는 `LightPollutionProvider`(무네트워크 approx)로 `nightSky`만. 노포 fetch는 top-K=5로, featured 적합도는 1개로 제한.
- **GPX fetch 바운딩(정정, codex FAIL 반영)**: ⚠️ 종점 SQM 랭킹은 종점 좌표(=GPX)가 선행되어야 하므로 "GPX도 top-K로 제한"은 논리적으로 불가능(랭킹 전엔 어느 K개가 상위인지 모름). 따라서 **매칭된 후보 전부의 GPX를 받아 종점 SQM으로 랭킹한 뒤 top-K=5를 slice**한다. 단 매칭이 많은 시군(실측: 전국 DNWW 142코스, 시군 매칭 최대 12·강화 2) 대비 **명시적 후보 상한 `CANDIDATE_LIMIT=15`**: `match_region` 결과를 GPX fetch 전에 결정적 순서(예 `crsIdx` 사전순)로 최대 15개로 잘라 그 후보들만 GPX/SQM 계산. 실측상 거의 안 걸리지만 데이터 성장 대비 바운드.
- **degrade/폴백(절대 raise 금지)**: courseList HTTP 오류/resultCode≠0000/매칭 0건 → `TrailsResponse(region=<시드 권역명>, courses=[], degraded=true)`. 개별 코스의 GPX/노포/적합도 실패는 그 필드만 비우고(해당 코스 스킵 또는 좌표 없음), 전체는 계속. featured 적합도 실패는 `daySuitability=null` 등으로 흡수(degrade 아님).
- **status 정직 표기**: `nightSky.status="approx"`(LightPollution 정적), featured `*.status`는 `SuitabilityResponse.degraded`를 반영("live"/"approx"). 지도 탭과 공유 값(동일 좌표 SQM)은 동일 소스 단일 진실.

### design-lead IA 자문 요지(2026-09-09) — 이 스펙이 따르는 근거
- 트레일·노포 = "선(sequence)/하루 동선" 탭(관찰 지도="점"). 자유 인터랙티브 지도는 이 탭에서 배제 → 관찰 지도로 위임.
- 랜딩=코스 카탈로그(리스트) → 코스 상세(push). featured 리치 카드 + 컴팩트 리스트.
- 노포 = 독립 맛집 카탈로그가 아니라 **코스 종점에 매달린 waypoint**(코스 반경).
- 게이미피케이션(탄소/포인트)·스팟 텔레메트리 4그리드·"관찰 기록" 배제.
- 적합도 = 종점 야간 관측 적합도 + (후속)낮 조석 골든타임. 이 스펙은 featured에 낮/밤 적합도를 실는 것으로 duality 착지, 리스트는 SQM 지표.

## §14 (member.md publish 초안) — GET /api/trails 계약

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

## 후속 flutter consumer UX 요건 (design-lead 검수 GO 조건 — 후속 flutter 스펙이 상속)
> backend 계약(§14)은 이 4개를 데이터로 이미 지원. 렌더는 flutter 조각의 요건.
1. (필수) `nightSky`(SQM/Bortle=**장소의 조건**, 측정 태그 톤)와 `suitability`(day/night score=**지금의 종합 판단**, 점수 게이지 톤)를 **다른 컴포넌트**로 렌더 + `status`(approx/live) 태그 가시화. 같은 시각 언어로 섞으면 "21.8 vs 73점" 비교 불가 혼란(§5-4 단일 진실 위반).
2. (필수) featured 배지에 **정렬 근거 노출**("오늘 밤하늘 가장 어두운 코스"류) — "종합 1등" 오독 방지(근거는 SQM 하나뿐).
3. (확인) featured 카드는 낮+밤 적합도를 **둘 다** 리치하게 보여 코스 duality를 대표 증명. 리스트 카드는 SQM 기반 **동등한 카탈로그 항목**(featured만 점수 얹은 "특권 카드"로 나머지를 열등하게 보이지 말 것 — "발췌/전체" 관계이지 "부족/충분"이 아님).
4. featured 종점 SQM 수치는 지도 탭·리스트·featured에서 **동일 숫자**(동일 소스 단일 진실).

## 후속 UX/기능 부채 (스코프 밖 분리)
1. 코스별 풀 낮/밤 적합도(캐싱·KMA 배치 선행 필요) — 지금은 featured만.
2. 노포 영업시간(opentimefood via detailIntro2) + "골든타임 사이 영업 노포" 로직(design-lead §5-3).
3. 좌표 근접 기반 코스 랭킹(전국 GPX bbox 캐싱) — 지금은 sigun 매칭.
4. 낮 조석 골든타임을 코스 waypoint 타임라인에 앵커(design-lead §5-2).
5. course-shape 썸네일용 GPX 폴리라인 다운샘플 제공.
6. 정렬 축 선택 UI(밤하늘순/가까운순/쉬운순) — 지금은 밤하늘 단일 정렬(정렬 근거 라벨 노출로 자연 확장).

## Amendments (post-build change history, append-only)

- 2026-09-09 (lead): Phase 1/2 완료·`just check`로 그린 확인(89 passed, 4 skipped, 0 failed). Phase 3(featured 적합도 + `GET /api/trails` 엔드포인트 + 라이브 스모크 + §14 계약 publish)는 backend-engineer 멤버 세션에서 Edit/Write 권한이 2회 연속(각기 다른 세션) 전부 거부되어 **파일 변경 0건으로 실패** — Phase 1/2와 동일한 팀/도메인/allowedTools 구성이었음에도 재현되어 스펙 자체의 결함이 아니라 이 실행 환경의 권한 승인 세션 문제로 판단. `just check`로 재확인한 결과 회귀 없음(Phase 1/2 상태 그대로 유지). Phase 3 체크박스는 미완료로 남겨둠 — 재시도 시 두 번째 실패 세션이 준비해 둔 전체 diff(session log `factory/logs/20260909-232315-claude-member.json`의 result 필드에 7개 파일 변경사항 전문 포함: `app/trails/service.py`의 `suitability_service` 파라미터·featured 적합도 계산 블록, `app/routers/trails.py` 신규, `app/main.py` 라우터 등록, `tests/trails/test_trails_endpoint.py`, `tests/suitability/test_live.py` 라이브 스모크 추가, `.env.example` 섹션, `.team/member.md` §19 계약)를 그대로 적용하면 됨 — 재작업 불필요, 권한 승인 세션에서 재실행만 하면 됨.
- 2026-09-09 (lead): 새 세션에서 재개. 착수 시점에 이전 세션이 이미 파일 시스템에 반영해 둔 상태를 재확인한 결과, featured 적합도(`service.py`)는 이미 구현·테스트(§19)되어 있었음 — 해당 체크박스는 구현 확인 후 바로 [x] 처리. 남은 3개 항목을 3회 순차 위임으로 완료: (1) `routers/trails.py`+`main.py` 등록+`test_trails_endpoint.py`(4테스트) 한 번에 성공. (2) `.env.example`(DURUNUBI_BASE_URL/TOURAPI_BASE_URL)+`test_live.py` 라이브 스모크 3건 한 번에 성공. (3) `member.md` §20 계약 publish — 앞의 두 태스크에서도 매번 "이 세션의 다른 Edit은 전부 성공했는데 유독 `.team/member.md` append만 requires-approval로 거부됨"이 반복 관찰됨(같은 파일, 다른 태스크 2회 연속); 원인은 확정 못했으나 "member.md 추가만을 유일 목적으로 하는" 단일 목적 태스크로 3번째 시도해 이번엔 성공. `just check` 최종 그린(95 passed, 7 skipped, 0 failed, flutter 58 passed) — Phase 1/2 대비 스킵 3건 증가는 신규 live 테스트가 `RUN_LIVE_TESTS` 미설정으로 정상 스킵된 것. Phase 3 전 체크박스 [x] 처리 완료.
- 2026-09-10 (brain): 2차 런 verdict=FAIL의 실사유 = codex verify 결함 1건(false negative 아님) — `get_trails()`가 top-K slice 전에 매칭 코스 전부의 GPX+SQM를 fetch(스펙 "GPX도 top-K 제한" 문구 위반). **브레인 판정: 스펙 자기모순**(종점 SQM 랭킹은 GPX 선행 불가피 → 랭킹 전 top-K 산정 불가). 브레인 라이브 캡처로 위험 정량화(전국 DNWW 142코스, 시군 매칭 최대 12·강화 2 → 실위험 작음). **브레인 end-to-end 실검증(uvicorn, 강화 37.5921/126.3984)**: `GET /api/trails` 200·region=인천 강화군·degraded=false·2코스, featured=서해랑길 101코스(SQM 20.15 approx, day 67/night 64 live, 노포 3=강화어부네꽃게탕 377m 등), 비-featured=DMZ평화의길 1코스(SQM 16.0, day/night=null) — 기능·실데이터·featured-only·SQM tie-break 전부 정상 확인. **정정**: "GPX 바운딩" 문구를 "매칭 후보 전부 GPX(랭킹용) + 명시적 상한 `CANDIDATE_LIMIT=15`"로 교체(위 설계/제약·Phase 4). 오너 결정=스펙 수정+상한 추가 후 3차 재발사(clean PASS+팩토리 커밋 목표).
- 2026-09-10 (lead): Phase 4 완료. `apps/backend/app/trails/service.py`에 모듈 상수 `CANDIDATE_LIMIT=15`(`TOP_K=5` 옆) 추가하고, `match_region()` 결과를 GPX fetch 루프 진입 **전에** `crsIdx` 사전순 정렬 후 상위 15개로 슬라이스(`candidates = sorted(matched, key=lambda c: c["crsIdx"])[:CANDIDATE_LIMIT]`)하도록 변경 — GPX fetch 루프는 `matched` 대신 `candidates`를 순회. 랭킹/tie-break/top-K=5 slice/featured 적합도 로직은 무변경(§14 응답 계약 불변). `tests/trails/test_trails_service.py`에 `test_candidate_limit_bounds_gpx_fetch_count`(가짜 매칭 코스 20건 → GPX fetch 정확히 15회) 신규 추가, 기존 6코스 케이스는 무변경으로 계속 통과. 단일 태스크 위임 1회로 코드+테스트 성공(one-shot). `just check` 브레인 직접 재확인: 96 passed, 7 skipped, 0 failed(Phase 3 대비 +1건은 신규 테스트). `member.md` §22 publish는 별도 단일 목적 태스크로 위임 성공(첫 시도 `light` 프로필 미지원으로 실패 — backend.yaml에 `modelProfiles` 자체가 없어 `standard` 외 프로필은 즉시 exit 1, 재시도 `standard`로 성공). Phase 4 전 체크박스 [x] 처리 완료.
