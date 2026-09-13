# 종 정보(Wikipedia) + 탐방로 리치 상세(두루누비) backend

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- refs: `specs/014-observation-map-backend.md`·`specs/018-...names-backend.md`(관찰지도/조류), `specs/012-trails-heritage-backend.md`(`app/trails/*`·두루누비/TourAPI 연동·`GET /api/trails` 계약), `apps/backend/.team/member.md` §20/§25, 오너 피드백(2026-09-13, 종 상세=사진/특징 필요·탐방로 정보 풍부하게)
- risk: high - 신규 외부 통합(Wikipedia REST) + 두루누비 코스 상세 확장 + 신규 엔드포인트 2개. backend publisher(flutter 021이 소비). 기존 계약(`/api/observation-map`,`/api/trails`,`/api/suitability`) 무변경.
- ⚠️ design-lead 검수: 오너 지시로 이번 조각 **생략**(설계 판단은 브레인이 §설계 결정에 명시).

## Purpose

관찰 지도에서 조류 개체를 탭하면 종 사진·설명을, 탐방로를 탭하면 거리 외 풍부한 코스 정보를 보여줄 수 있도록, (1) Wikipedia 종 정보 프록시와 (2) 두루누비 코스 리치 상세를 backend에 추가한다.

## Problem

1. eBird recent-obs엔 종 사진·특징이 없다(관측 로그만). 조류 종 상세를 채울 데이터원이 없다.
2. `/api/trails` 코스는 거리/시간/난이도/밤하늘/노포까지 있으나, 두루누비의 **코스 설명·테마·편의시설·고도** 등 풍부한 필드를 안 담아, 지도 탐방로 상세가 빈약하다.

## Solution

(1) `GET /api/species?sci=<학명>&ko=<한국어명>` — Wikipedia REST summary(한국어 위키 우선, 학명 영문 위키 폴백)를 프록시해 **사진 썸네일·요약 설명·위키 링크**(가능 시 보전상태)를 반환. (2) `GET /api/trails/detail?crsIdx=<코스ID>` — 두루누비 코스 상세 API로 **코스 설명·테마·편의시설·화장실·교통·시점/종점명·고도 프로파일·대표 이미지**를 반환(기존 `/api/trails` 목록은 무변경, 상세는 탭 시 on-demand). 둘 다 실패/미존재 방어(부분 degrade), 정직 표기(없는 필드는 null·미노출).

## Relevant Files

### New Files

- `apps/backend/app/species/__init__.py`, `wikipedia.py`, `service.py`, `models.py` - Wikipedia 프록시 패키지(trails 동형).
  - `wikipedia.py`: `fetch_species_summary(nameKo, sciName, client=None) -> dict|None`. 한국어 위키 REST `https://ko.wikipedia.org/api/rest_v1/page/summary/{title}`(title=nameKo) 우선, 404/빈 결과면 영문 위키(title=sciName) 폴백. 추출: `title`, `extract`(요약), `thumbnail.source`(사진), `content_urls.desktop.page`(링크). **모든 예외 흡수→None**(client 소유권 패턴은 trails durunubi와 동일). 캐싱 권장(종은 잘 안 변함).
  - `models.py`: `SpeciesInfo(nameKo, nameSci, summary:str|None, thumbnailUrl:str|None, wikiUrl:str|None, source:str)`. 보전상태(IUCN 등)는 위키 요약에 구조화되어 오지 않으므로 **이번 스코프 제외**(§설계 결정).
- `apps/backend/app/routers/species.py` - `GET /api/species?sci&ko`(둘 중 하나 필수). 결과 없으면 200 + 빈 필드(null)로 정직 반환(404 아님 — 컨슈머가 placeholder 렌더).
- `apps/backend/app/trails/durunubi_detail.py` (또는 기존 `tourapi.py`/durunubi 모듈 확장) - `fetch_course_detail(crsIdx, client=None) -> dict` : 두루누비 코스 상세(설명/테마/편의시설/화장실/교통/시점종점명/대표이미지) + GPX 고도(gpxUrl 파싱 or 상세 API). 예외 흡수→부분 필드.
- `apps/backend/app/routers/trails_detail.py` (또는 `routers/trails.py` 확장) - `GET /api/trails/detail?crsIdx`.
- 테스트: `tests/species/`(위키 파서 순수함수·픽스처·엔드포인트 fake), `tests/trails/test_course_detail.py`, `tests/suitability/test_live.py`에 위키·두루누비상세 라이브 스모크(`RUN_LIVE_TESTS` 게이트).

### Existing Files

- `apps/backend/app/main.py` - `species`, `trails_detail` 라우터 등록(알파벳 순).
- `apps/backend/app/suitability/config.py` - 필요 시 `get_wikipedia_config()`(base url, lang) — 키 불필요(위키 공개 API). 두루누비는 기존 `DATA_GO_KR` 키 재사용.
- `apps/backend/.env.example` - 위키 base url(선택, 기본 하드코딩). 두루누비 키는 기존.
- `apps/backend/.team/member.md` - §27: `GET /api/species`, `GET /api/trails/detail` 계약 publish(flutter 021 consumer 핸드오프).

## Phases

### Phase 1: Wikipedia 종 정보 (`GET /api/species`)
- [ ] `species/wikipedia.py` 파서(순수) + `fetch_species_summary`(ko 우선·영문 폴백·예외흡수) + 픽스처(저어새 실캡처).
- [ ] `models.SpeciesInfo` + `routers/species.py`(sci/ko 쿼리, 결과없음=null 정직) + main 등록.
- [ ] 테스트(파서·엔드포인트 fake) + 라이브 스모크(게이트).

**Phase validation**: `just check` green. 발사 후 브레인 uvicorn 라이브(저어새/Platalea minor → 사진·요약 확인).

### Phase 2: 두루누비 코스 리치 상세 (`GET /api/trails/detail`)
- [ ] `fetch_course_detail(crsIdx)`(설명/테마/편의시설/화장실/교통/시점종점명/이미지/고도, 예외흡수 부분필드).
- [ ] `models` 상세 스키마 + `routers/trails_detail.py` + main 등록.
- [ ] 테스트(fake·픽스처) + 라이브 스모크(게이트).

**Phase validation**: `just check` green. 발사 후 브레인 라이브(강화 코스 crsIdx → 리치 필드 확인).

### Phase 3: 계약 publish
- [ ] `.team/member.md` §27 두 계약 문서화.

**Phase validation**: 아래 Validation Commands.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 설계 결정 (design-lead 생략 — 브레인 판단, 정직표기 원칙 계승)
- **Wikipedia 종 상세 = 사진·요약만**(위키 REST summary). Figma 62-35의 울음소리 AI·출현예측%·성조/유조·안전거리·리워드 배지 등은 **데이터원 없음/가공불가 → 이번 backend 스코프 제외**(flutter가 없는 데이터로 가짜 UI 만들지 않게 명시). 보전상태(IUCN/천연기념물)도 구조화 소스 없어 제외(후속: 별도 보전상태 DB).
- **결과 없음 = 200 + null 필드**(404 아님). 컨슈머가 "사진 준비 중" placeholder로 정직 렌더(019 원칙 계승).
- 탐방로 상세는 **on-demand 엔드포인트**(목록 `/api/trails` 무변경 — 성능·계약 안정). 두루누비 상세 필드는 실제 응답에 있는 것만(없으면 null·미노출).

### 라이브 근거 (2026-09-13)
- 종: eBird 레코드에 `sciName`(Platalea minor)·`comName`(저어새) 존재 → 위키 조회 키. ko.wikipedia "저어새" 페이지 존재.
- 탐방로: 두루누비 코스 API는 목록 외 상세(코스설명·테마·편의시설·고도) 제공(012에서 목록만 사용).

### 불변 원칙
- 기존 계약 무변경. 순수 프록시(가공 최소). 외부 실패 방어(예외흡수·부분 degrade). 정직표기(없는 필드 null). `.env` 실키 커밋 금지.

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
