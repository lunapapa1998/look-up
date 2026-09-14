# 종 상세 실데이터 강화 backend (위키 설명 확장 + 보전상태 + 오늘의 물때)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-14
- modified: 2026-09-14 <brain/orchestrator>
- refs: `specs/020-species-wiki-rich-trails-backend.md`(`GET /api/species`·Wikipedia 프록시·§설계결정 L77-80 보전상태/출현예측 backend 제외 확정 — 이 스펙이 그 후속으로 보전상태를 정직하게 되살림), `specs/008-tide-live-backend.md`(KHOA 조석 `TideProvider`·`tide_stations` 좌표매칭), `apps/backend/app/suitability/providers/tide.py`·`tide_stations.py`, Figma node `62-70`(저어새 종 상세 목업), design-lead 자문(2026-09-14, 종상세 IA), 오너 결정(2026-09-14: 게이지 없음·조석 포함)
- risk: high - 신규 외부 통합(MediaWiki `extracts` API) + 신규 엔드포인트(`/api/tide/today`) + 보전상태 정적 큐레이션 테이블 + `/api/species` 계약 확장. backend publisher(flutter 023이 소비). 기존 계약(`/api/species` 기존 필드·`/api/observation-map`·`/api/suitability`·`/api/trails/detail`) 무변경(필드 추가만, 제거·개명 금지).
- ⚠️ design-lead 자문 반영됨(종상세 = "이 관측의 종 맥락", 사실 블록만·가공 점수 0). 보전상태 값의 정확성은 **브레인 책임**(가짜 금지) — 아래 §보전상태 시드 참조.
- modified: 2026-09-14, lead: claude sonnet (backend-lead) — Phase 1~4 전체 완료.

## Purpose

관찰지도 조류 종 상세("새 정보")가 빈약하다는 오너 피드백을 해소하기 위해, 종 상세에 실제 데이터원이 있는 3종(위키 설명 확장·보전상태 배지·오늘의 물때)을 backend에 추가한다.

## Problem

1. `/api/species`의 `summary`는 Wikipedia REST의 짧은 extract(예: 저어새 384자, 문장 중간 잘림)라 종 특징·서식지가 부족하다.
2. 보전상태(천연기념물/멸종위기/IUCN)는 종 상세의 핵심 정보인데 데이터원이 없어 020에서 제외됐다(Wikipedia REST summary엔 인포박스의 보전상태가 안 옴).
3. 오늘 만조/간조 시각은 갯벌 탐조의 핵심 맥락인데, 기존 조석(`TideProvider`)은 홈 적합도(스팟·모드 단위 골든타임 하나)로만 쓰여 "오늘 전체 물때 배열"을 노출하는 경로가 없다.

## Solution

(1) `GET /api/species` 응답에 `summaryLong`(MediaWiki `extracts` intro 전체, explaintext) + `conservation`(보전상태 3필드, 정적 큐레이션 테이블, nullable) 추가 — 기존 필드 무변경. (2) 신규 `GET /api/tide/today?lat&lng` — 좌표에서 가장 가까운 KHOA 조석 관측소의 **오늘 만조/간조 극값 배열**(시각·고저·조위)을 반환(008 `TideProvider` 파서 재사용, 종 무관·스팟 단위). (3) 관측소 매칭 실패(내륙 등)·API 실패는 `found=false`/`degraded` 정직 표기. 없는 보전상태는 각 필드 null(가짜 금지).

## Relevant Files

### Existing Files

- `apps/backend/app/species/wikipedia.py` - MediaWiki `extracts` intro fetch 추가(`fetch_species_extract` 또는 기존 `fetch_species_summary` 확장). `_USER_AGENT` 재사용. ko우선 en폴백 동일. summary(REST)와 별개로 긴 설명 취득. 실패 시 `summaryLong=null`(부분 degrade).
- `apps/backend/app/species/service.py` - species 조합에 `summaryLong`·`conservation` 병합. 위키 REST(사진/짧은요약)와 extracts(긴설명)는 각각 실패 흡수.
- `apps/backend/app/species/models.py` - `SpeciesInfo`에 `summaryLong: str | None`, `conservation: Conservation | None` 추가. 신규 `Conservation` 모델(`naturalMonument: str | None`, `koreaEndangered: str | None`, `iucn: str | None` — 3필드 전부 null이면 service가 `conservation=None`으로 반환해 flutter가 섹션 숨김).
- `apps/backend/app/routers/species.py` - 무변경(응답 모델 확장으로 자동 반영) 또는 필요 시 소폭.
- `apps/backend/app/main.py` - 신규 tide 라우터 등록(ASCII 정렬 위치 유지, 기존 라우터 줄 무변경).
- `apps/backend/app/suitability/providers/tide.py` - **재사용만**(신규 로직은 tide_today.py로 분리, 기존 `TideProvider`/파서 무변경). `_parse_xml_items`·`_classify_extremes`는 module-level 함수라 import 가능.
- `apps/backend/app/suitability/providers/tide_stations.py` - **재사용만**(좌표→관측소 `obsCode` 매칭 함수 import).

### New Files

- `apps/backend/app/species/conservation.py` - 보전상태 정적 큐레이션 테이블. `{학명 소문자: {naturalMonument, koreaEndangered, iucn}}` dict + `lookup_conservation(sci_name, name_ko) -> Conservation | None`. **아래 §보전상태 시드의 브레인 검증 값만 사용**. 학명 정규화(소문자·공백 trim) 매칭, 미등록 종은 None.
- `apps/backend/app/species/tide_today.py` - `fetch_today_tides(lat, lng, client=None) -> dict`. tide_stations로 좌표→obsCode, KHOA 조석예보 호출, `_parse_xml_items`+`_classify_extremes`로 오늘 극값 배열 산출. 관측소 매칭 실패=`found=false, degraded=false`, API 실패=`found=false, degraded=true`.
- `apps/backend/app/routers/tide.py` - `GET /api/tide/today?lat&lng`(둘 다 required, 없으면 422). `fetch_today_tides` DI 훅(테스트용 오버라이드, 020/008 패턴).
- `apps/backend/tests/species/test_conservation.py`, `tests/species/test_extract.py`, `tests/tide/test_tide_today.py`, `tests/tide/test_tide_today_endpoint.py` - 오프라인 픽스처 + `RUN_LIVE_TESTS` 게이트 라이브 스모크.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 위키 설명 확장 (MediaWiki extracts)

MediaWiki `extracts` API로 종 소개 intro 전체를 취득해 `summaryLong`으로 노출. 기존 REST summary(`summary`)는 그대로 유지(짧은 카드용).

- [x] `wikipedia.py`에 `fetch_species_extract(name_ko, sci_name, client)` — `GET https://{ko|en}.wikipedia.org/w/api.php?action=query&prop=extracts&exintro&explaintext&format=json&titles={title}`. ko우선(결과 없거나 빈 extract면) en폴백. `_USER_AGENT` 헤더 필수(020 교훈). intro가 과도하게 길면 상한(예 1500자) 트림(문장 경계 우선). 실패=None.
- [x] `models.py` `SpeciesInfo.summaryLong: str | None`, `service.py` 병합(위키 REST 실패해도 extracts 시도, 독립 흡수).
- [x] `tests/species/test_extract.py` — MediaWiki JSON 픽스처(pages.*.extract) 파싱 + 빈 extract→폴백 + 상한 트림. 라이브 스모크(RUN_LIVE_TESTS).

**Phase validation**: `just backend-check` green. (브레인 라이브: 저어새 summaryLong이 REST summary보다 길고 서식지/섭식 포함.)

### Phase 2: 보전상태 정적 큐레이션

브레인 검증 시드 테이블로 보전상태 3필드 노출. 팀은 시드 값을 **임의 추가·수정 금지**(가짜 방지), 표에 없는 종은 null.

- [x] `conservation.py` — §보전상태 시드의 dict를 그대로 코드화. `lookup_conservation(sci_name, name_ko)` 학명 소문자 매칭(공백 정규화), 미스=None. 3필드 개별 nullable.
- [x] `models.py` `Conservation`(naturalMonument/koreaEndangered/iucn) + `SpeciesInfo.conservation: Conservation | None`. `service.py`에서 3필드 전부 null이면 `conservation=None`(섹션 숨김 신호).
- [x] `tests/species/test_conservation.py` — 시드 종(저어새) 매칭·미등록 종 None·부분 필드(천연기념물만 있는 종) 케이스.

**Phase validation**: `just backend-check` green. (라이브: 저어새 conservation = 천연기념물 205-1호·멸종위기 I급·IUCN EN.)

### Phase 3: 오늘의 물때 엔드포인트 (008 재사용)

좌표→KHOA 관측소→오늘 만조/간조 배열. 종 무관·스팟 단위. 내륙·실패 정직 표기.

- [x] `tide_today.py` `fetch_today_tides(lat, lng, client)` — tide_stations 매칭 → KHOA 조석예보 호출 → `_parse_xml_items`+`_classify_extremes`로 오늘(KST) 극값만 필터·정렬. 반환 `{found, degraded, stationName, extremes:[{time:"HH:MM", kind:"high"|"low", levelCm:int|null}]}`. 매칭 실패=found:false·degraded:false, KHOA 실패=found:false·degraded:true.
- [x] `routers/tide.py` `GET /api/tide/today?lat&lng`(required, 422 on missing) + DI 훅. `main.py` 등록.
- [x] `tests/tide/` — KHOA XML 픽스처(고저조 4극값) 파싱·정렬·kind 분류, 내륙(매칭 실패)→found:false, 422. 라이브 스모크(강화대교 좌표, RUN_LIVE_TESTS 게이트) 포함.

**Phase validation**: `just backend-check` green. (라이브: 강화 갯벌 좌표 → 오늘 만조/간조 시각 배열, 내륙 좌표 → found:false.)

### Phase 4: 계약 publish

- [x] `apps/backend/.team/member.md`에 확장된 `GET /api/species`(summaryLong·conservation)와 신규 `GET /api/tide/today` 계약 문서화(요청·응답 스키마·nullable·found/degraded 의미). flutter 023이 이 계약을 소비. (섹션 29·30·31에 각각 문서화 완료)

**Phase validation**: `just check` green(backend + flutter 회귀 없음) — lead가 직접 실행해 153 passed, 12 skipped, 0 failed 확인(flutter 154 tests all passed).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 보전상태 시드 (브레인 검증 — 팀은 이 값만 사용, 추가/변경 금지)

공인 목록(문화재청 천연기념물·환경부 멸종위기 야생생물·IUCN Red List)에서 전사한 **확실한 값만**. 학명은 소문자 매칭 키. 불확실하면 넣지 말 것(가짜보다 null이 낫다). 후속 확장은 브레인이 검증해 추가.

| 학명(key) | 한국어 | naturalMonument | koreaEndangered | iucn |
|---|---|---|---|---|
| platalea minor | 저어새 | 천연기념물 제205-1호 | 멸종위기 I급 | EN |
| egretta eulophotes | 노랑부리백로 | 천연기념물 제361호 | 멸종위기 I급 | VU |
| ciconia boyciana | 황새 | 천연기념물 제199호 | 멸종위기 I급 | EN |
| grus japonensis | 두루미 | 천연기념물 제202호 | 멸종위기 I급 | VU |
| grus vipio | 재두루미 | 천연기념물 제203호 | 멸종위기 II급 | VU |
| grus monacha | 흑두루미 | 천연기념물 제228호 | 멸종위기 II급 | VU |
| haematopus ostralegus | 검은머리물떼새 | 천연기념물 제326호 | 멸종위기 II급 | NT |
| numenius madagascariensis | 알락꼬리마도요 | null | 멸종위기 II급 | EN |
| cygnus columbianus | 고니 | 천연기념물 제201-2호 | 멸종위기 II급 | LC |
| cygnus cygnus | 큰고니 | 천연기념물 제201-3호 | 멸종위기 II급 | LC |

- IUCN 코드: EN=위기, VU=취약, NT=준위협, LC=관심대상. flutter는 이 코드를 한국어 라벨로 매핑(023 몫). LC도 양성 데이터라 표기 가능(design-lead: 테이블 레코드 유무가 기준이지 희귀도 아님).
- **naturalMonument 번호의 세부 하위번호(205-1 등)가 불확실한 종은 번호 없이 "천연기념물"만 쓰거나 null** — 정확도 우선. 위 표는 브레인이 확신하는 값. 팀이 표 밖 종을 마주치면 null 반환(추측 금지).

### 설계 메모
- extracts와 REST summary는 **독립 취득**(하나 실패해도 다른 하나 노출). REST summary=사진+짧은요약(카드), extracts=긴 설명(상세 본문).
- 조석은 **종 파라미터 없음**(`/api/tide/today?lat&lng`) — design-lead: "저어새 출현 물때"처럼 종을 주어로 삼지 말 것, "이 갯벌의 오늘 물때". flutter는 스팟 좌표로 호출.
- 보전상태 값 환각 방지: 팀 어댑터가 표 밖 종의 등급을 지어내지 않도록 `conservation.py`는 순수 dict 조회만(외부 호출·추론 없음).

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
- 2026-09-14 (backend-lead): §Relevant Files의 "관측소 매칭 실패(내륙 등)" 조건은 스펙에 구체적 임계값이 없었음(008 `nearest_station()`은 항상 최근접 관측소를 반환하며 원천적으로 "매칭 실패"가 없음). Phase 3 착수 전 lead가 해석: `_haversine_km(lat,lng,station)` 거리가 20km 초과면 "매칭 실패"(내륙/원거리)로 간주해 `found=false, degraded=false` 반환. 20km는 조석 관측소가 해안선을 따라 촘촘히 분포한 점(갯벌 탐조지는 대부분 해안 인접)을 근거로 한 lead 판단이며, 오너가 다른 값을 원하면 후속 조정 가능.
- 2026-09-14 (backend-lead): `SpeciesInfo.summaryLong`·`SpeciesInfo.conservation` 두 신규 필드는 스펙 표기(`str | None`)와 달리 구현에서 `= None` 기본값을 붙였음(작업자 판단, lead 승인) — 기본값이 없으면 이 두 필드를 모르는 기존 픽스처/호출부가 pydantic validation에서 깨지기 때문. 응답 계약(모든 요청에서 필드가 항상 내려옴)은 동일, 순수 구현 디테일.
- 2026-09-14 (backend-lead): Phase 1·2 작업으로 `tests/species/test_species_endpoint.py`의 `test_happy_path_returns_full_contract` 키 집합 assertion에 `summaryLong`·`conservation`을 추가하는 부수 수정이 각각 필요했음(응답 필드 추가에 따른 필연적 회귀, 별도 재위임으로 처리). Phase 3에서는 `tests/tide/test_tide_today.py`의 최초 `FakeClient`가 `.request` 미설정 `httpx.Response`를 반환해 `raise_for_status()`가 `RuntimeError`를 던지는 테스트 전용 버그가 있었음 — `tests/species/test_species_parser.py`의 `httpx.MockTransport` 컨벤션으로 재작성해 해결(프로덕션 코드는 처음부터 정상이었음).
- 2026-09-14 (backend-lead): Phase 3 스펙의 "라이브 스모크(강화 좌표)" 요구사항이 최초 위임에서 누락되어 재위임으로 강화대교 좌표(37.73194, 126.52222) 기반 `RUN_LIVE_TESTS` 게이트 라이브 테스트를 추가 완료.
