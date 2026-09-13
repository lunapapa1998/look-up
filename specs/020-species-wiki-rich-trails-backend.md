# 종 정보(Wikipedia) + 탐방로 리치 상세(두루누비) backend

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- modified: 2026-09-13, lead: claude-sonnet-5
- modified: 2026-09-13, lead: claude-sonnet-5 (크로스모델 검증 FAIL 재수정, §Amendments 참고)
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

### Phase 1: Wikipedia 종 정보 (`GET /api/species`) — ✅ 완료 (2026-09-13)
- [x] `species/wikipedia.py` 파서(순수) + `fetch_species_summary`(ko 우선·영문 폴백·예외흡수) + 픽스처(MediaWiki REST 공개 스키마 기반, 실캡처 불가 사유는 Amendments 참고).
- [x] `models.SpeciesInfo` + `routers/species.py`(sci/ko 쿼리, 결과없음=null 정직) + main 등록.
- [x] 테스트(파서·엔드포인트 fake) + 라이브 스모크(게이트).

**Phase validation**: `just check` green(리드가 직접 실행, 124 passed·9 skipped). 라이브 uvicorn 확인(저어새 실사진·요약)은 `RUN_LIVE_TESTS=1` 실행 권한이 있는 오너/후속 세션 몫으로 남음(샌드박스 네트워크 제약, Amendments 참고).

### Phase 2: 두루누비 코스 리치 상세 (`GET /api/trails/detail`) — ✅ 완료 (2026-09-13, Amendment로 스코프 축소)
- [x] `fetch_course_detail(crsIdx)`(설명/테마ID/시점종점명/GPX 고도프로파일, 예외흡수 부분필드). 편의시설/화장실/교통/대표이미지는 Amendments 근거로 v1 스코프 제외(모델에 필드 자체 없음).
- [x] `models` 상세 스키마(`ElevationPoint`/`TrailDetailResponse`, 기존 `trails/models.py` 끝에 추가) + `routers/trails_detail.py`(신규 파일, 기존 `routers/trails.py` 무변경) + main 등록.
- [x] 테스트(fake·픽스처) + 라이브 스모크(게이트).

**Phase validation**: `just check` green(리드가 직접 실행, 132 passed·10 skipped). 라이브 확인(실제 crsIdx → 리치 필드)은 `RUN_LIVE_TESTS=1` 실행 권한이 있는 오너/후속 세션 몫으로 남음(샌드박스 네트워크 제약).

### Phase 3: 계약 publish — ✅ 완료 (2026-09-13)
- [x] `.team/member.md` §26(species)·§27(trails/detail) 두 계약 문서화.

**Phase validation**: 아래 Validation Commands — `just check` 리드가 직접 실행, green.

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

- 2026-09-13 (lead, 크로스모델 검증 FAIL 재수정): 배포 전 크로스모델 검증에서 `app/species/wikipedia.py:fetch_species_summary()`가 `get_wikipedia_config()`/`httpx.Client(timeout=10.0)` 호출을 `try` 블록 진입 전에 실행해, 스펙이 요구하는 "모든 예외 흡수→None"을 어기는 FAIL 1건이 나옴. member에게 정확한 재구조화(두 호출을 `try` 안으로 이동, `finally`의 `client.close()`를 `owns_client and client is not None` 가드로 보강)를 위임해 1회 수정으로 해결. `.team/member.md` §28에 문서화(계약 무변경). 리드가 `just check` 직접 실행해 132 passed·10 skipped·0 failed 재확인.
- 2026-09-13 (lead, 발사 전 계약 확정): 이번 세션의 Bash 샌드박스가 네트워크 요청 도구를 전부 승인거부(scout jetski와 동일 증상 — lead 세션도 예외 없음)해 Wikipedia/두루누비 라이브 재확인이 불가능했다. 대신 `specs/012-trails-heritage-backend.md` Notes의 **기존 실측 캡처**(브레인이 2026-09-09에 이미 라이브로 캡처한 두루누비 courseList 원본, `crsContents`/`crsSummary`/`crsTourInfo`/`travelerinfo`/`routeIdx` 필드 확인됨)를 근거로 Phase 2 계약을 아래와 같이 확정한다:
  - **두루누비에 "상세" 전용 엔드포인트는 없다.** `courseList` 응답 item 자체에 목록 파서(`parse_course_list`)가 버리는 필드(`crsContents`/`crsSummary`/`crsTourInfo`=코스설명, `travelerinfo`=시점·종점 텍스트, `routeIdx`=테마ID)가 이미 있다. `fetch_course_detail(crsIdx)`는 **같은 courseList 엔드포인트를 재호출**해 crsIdx로 raw item을 찾아 이 필드들을 노출한다(신규 엔드포인트 없음, `DURUNUBI_BASE_URL` 그대로 재사용).
  - **화장실/교통/편의시설/대표이미지는 v1 스코프에서 제외한다.** 012의 실측 캡처(2 item)에 이 필드들의 실제 키가 전혀 없어 키 이름을 추측하면 "정직 표기" 원칙(§설계 결정)에 위배된다. Purpose/Solution 문구의 "편의시설·화장실·교통" 언급은 이 Amendment로 무효화되고, `TrailDetailResponse`에는 해당 필드를 아예 만들지 않는다(있지도 않은 걸 항상 null로 내리는 죽은 필드 금지). 후속 세션이 라이브로 실제 courseList 전체 필드를 재확인하면 별도 스펙으로 추가한다.
  - **고도 프로파일은 GPX `<ele>` 태그에서 뽑는다**(012에서 이미 실측 확인된 GPX 구조). 코스 전체 거리(`crsDstnc`, `/api/trails` 목록 응답)와 별도로 이 엔드포인트가 자체 haversine 거리를 재계산하면 두 값이 어긋날 위험이 있어, x축은 절대 km가 아니라 **`positionRatio`(0.0~1.0, 트랙포인트 인덱스 비율)** 로 낸다 — 컨슈머(021)가 필요하면 `/api/trails`의 `distanceKm`을 곱해 근사 km로 환산.
  - 확정 계약: `GET /api/trails/detail?crsIdx=<코스ID>` → `{crsIdx, found, description, themeId, startName, endName, elevationProfile:[{positionRatio,elevationM}], degraded}`. `found=false`=그 crsIdx가 courseList에 없음(정상 200), `degraded=true`=두루누비 자체 실패(키/네트워크) — 두 실패 사유를 구분해 정직 표기.
  - Wikipedia 쪽도 동일한 사유로 저어새 실캡처가 불가능해, 픽스처는 MediaWiki REST 공개 스키마(`https://ko.wikipedia.org/api/rest_v1/page/summary/{title}` — title/extract/thumbnail.source/content_urls.desktop.page/type)를 손으로 구성한 스키마 정확 픽스처로 대체하고, `RUN_LIVE_TESTS` 게이트 라이브 스모크로 실제 내용 검증을 후속(오너/브레인 실행)에 위임한다.
- 2026-09-13 (**브레인 라이브 검증 — 021 발사 전 계약 확정**): uvicorn 기동 후 실 API로 두 엔드포인트를 검증, **실 결함 3건을 확정·수정**했다. lead/codex 오프라인 파이프라인(133 green)이 못 잡은 것들:
  1. **Wikipedia 403(근본 결함, 라이브만 잡음)** — `fetch_species_summary`가 `httpx.Client`를 User-Agent 헤더 없이 만들어 Wikipedia REST가 전부 **403 Forbidden** 반환 → 코드가 예외를 삼켜 모든 종이 `source:"none"`(저어새 포함 전멸). httpx 직접 재현으로 no-UA=403 / with-UA=200 확정. `wikipedia.py`에 `_USER_AGENT` 상수 추가해 클라이언트 생성 시 헤더 부여. 수정 후 저어새·알락꼬리마도요=ko.wikipedia(요약+썸네일), 황로(sci만)=en.wikipedia 폴백 실동작 확인.
  2. **empty-extract 폴백 누락(codex 지적 FAIL)** — 한국어 위키에 페이지는 있으나 `extract`가 빈 200 응답을 한국어 히트로 오인해 영문 폴백을 안 함. `_fetch_summary`가 파싱 후 `summary` 없으면 `ValueError`를 던져 폴백을 유도하도록 수정 + `test_empty_extract_on_korean_falls_back_to_english` 회귀 테스트 추가.
  3. **교통·주변관광 필드 복원(Amendment 94가 예견한 후속을 이 세션에서 직접 반영)** — 브레인이 두루누비 `courseList` item **전체 필드를 라이브로 재확인**: `travelerinfo`(교통편·시점/종점 텍스트)와 `crsTourInfo`(주변 관광)가 실재. Amendment 94는 라이브 재확인 불가로 이를 제외했으나, 재확인이 된 지금 **`travelerInfo`/`tourInfo` 두 필드를 `TrailDetailResponse`에 추가**(원문 HTML `<br>` 포함, 없으면 null). 스펙 Purpose의 "교통" 요구 충족. **편의시설·화장실·대표이미지는 courseList item에 실제로 필드가 없음을 라이브로 재확인**했으므로 Amendment 94대로 계속 제외(정직·죽은 필드 금지). 테스트 3건(parse full/endpoint contract/not-found) 새 필드로 갱신, 계약 `.team/member.md` §GET /api/trails/detail 반영.
  - 최종: `just backend-check` 133 passed·10 skipped. 라이브 저어새 요약/썸네일·강화(부산 예시) 코스 travelerInfo/tourInfo/elevationProfile 실데이터 확인. 021(flutter consumer)이 소비할 계약 확정 완료.
