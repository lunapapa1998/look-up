# 조석(tide) 레이어 실연동 (KHOA 조석예보 고저조 live)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-08
- modified: 2026-09-08 <brain/orchestrator>
- refs: `specs/005-suitability-engine-backend.md`, `apps/backend/app/suitability/providers/tide.py`(현 stub), `apps/backend/.team/member.md` §8
- risk: high - 외부 실 API 신규 연동(브레인 라이브 캡처 그라운드 트루스 기반) + 낮 골든타임 계산 로직 교체. backend 레인 갇힘, 계약(§8) 형태 불변.
- modified: 2026-09-08, lead: claude sonnet

## Purpose

지금 하드코딩 stub인 조석 레이어를 KHOA 조석예보(고저조) 실 API에 연동해, 낮 탐조 골든타임과 조위 텔레메트리를 사용자 위치 기준 실제 조석 데이터로 산출한다.

## Problem

`app/suitability/providers/tide.py`가 위치·날짜와 무관하게 항상 "14:00-17:30 / 만조 16:15 (스텁 데이터)"를 반환한다(`status="stub"`). 낮 골든타임은 조석 레이어 소유인데 실데이터가 없어, GPS(007)로 위치가 정확해져도 낮 골든타임만 여전히 가짜다.

## Solution

`GET https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService`(기존 `DATA_GO_KR_SERVICE_KEY` 재사용)를 호출하는 live `TideProvider`로 교체한다. GPS 좌표를 정적 관측소 테이블에서 최근접 관측소(`obsCode`)로 매핑해 그날 고저조를 받고, 낮 시간대 만조(최고 조위 극값) 기준으로 "만조 N시간 전 갯벌 유입 피크" 골든타임과 다음 고저조 텔레메트리를 계산한다. 실패 시 기존 stub과 동일한 결정적 폴백으로 degrade하며 절대 raise하지 않는다(astronomy/weather 방어 패턴과 동일).

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/tide.py` - stub → live 전면 재작성. `fetch(lat,lng,mode)`: (1) 최근접 관측소 매핑, (2) API 호출, (3) XML 파싱, (4) 낮 만조 기반 골든타임/텔레메트리/서브스코어 산출, `status="live"`. 네트워크·파싱 예외는 모두 흡수해 stub 폴백(`status="stub"`) 반환. `parse(items, mode, now)`는 네트워크 없는 순수 함수로 분리(단위 테스트 대상).
- `apps/backend/app/suitability/config.py` - `get_tide_config()` 추가(KASI와 동일하게 `DATA_GO_KR_SERVICE_KEY`/`_DECODED`를 `unquote`해 `service_key`로, base_url은 `TIDE_API_BASE_URL` 기본값 `https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService`). **새 API 키 불필요** — 기존 data.go.kr 키 재사용.
- `apps/backend/tests/suitability/test_tide_provider.py` - 기존 stub 테스트가 있으면 live 파서 테스트로 교체/확장(픽스처 기반, 네트워크 0).
- `apps/backend/tests/suitability/test_live.py` - `@pytest.mark.live` 그룹에 `TideProvider().fetch(강화 인근 좌표)` 실 호출 케이스 추가(`status in ("live","stub")` 허용, reason surface).
- `apps/backend/.env.example` - `TIDE_API_BASE_URL` 항목 문서화(선택, 기본값 있음). 키는 기존 `DATA_GO_KR_SERVICE_KEY` 재사용임을 주석.

### New Files

- `apps/backend/app/suitability/providers/tide_stations.py` - 정적 관측소 테이블(`code`,`name`,`lat`,`lng`) 37개 + `nearest_station(lat, lng)` 헬퍼(haversine 최소거리). **아래 Notes의 실측 목록을 그대로 사용**(VIIRS 정적표 내장과 동일 패턴).
- `apps/backend/tests/suitability/fixtures/khoa_tide_sample.xml` - **아래 Notes의 실 캡처 XML**(인천 DT_0001, 2026-09-08 4극값)을 그대로 저장. 손으로 지어내지 말 것.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 관측소 테이블 + config + 파서(순수 코어)

- [x] `tide_stations.py`: Notes의 37개 관측소 정적 테이블 + `nearest_station(lat,lng)`(haversine).
- [x] `config.py`: `get_tide_config()`(키 unquote 재사용, base_url 기본값).
- [x] `tide.py`의 `parse(items, mode, now)` 순수 함수: 극값 리스트 → 낮 만조 판정(조위 대소, extrSe는 순번일 뿐) → 골든타임/텔레메트리/서브스코어. 픽스처(`khoa_tide_sample.xml`)로 단위 테스트.

**Phase validation**: `cd apps/backend && uv run pytest tests/suitability/test_tide_provider.py -q` (네트워크 0).

### Phase 2: fetch 실연동 + 서비스 통합

- [x] `tide.py`의 `fetch(lat,lng,mode)`: 최근접 관측소 → API GET → XML 파싱 → `parse()`. 모든 예외 흡수 → stub 폴백. `get_default_providers()`는 키만 참조하므로 무변경 확인.
- [x] 낮 골든타임을 tide가 소유(mode=day), night는 `golden_hours=[]`(astronomy 소유, 무변경).

**Phase validation**: `just backend-check`(전체 오프라인 green).

### Phase 3: 라이브 스모크 + 계약/문서

- [x] `test_live.py`에 tide 실 호출 케이스 추가. `.env.example` 갱신. `member.md` §8 telemetry `tide` 예시를 live 형태로 갱신(스텁 문구 제거).
- [x] `just check` 전체 green(live 제외 offline).

**Phase validation**: 아래 Validation Commands.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### ⭐ 브레인 라이브 캡처 그라운드 트루스 (2026-09-08, 실 API 실측 — 추정 금지)

- **엔드포인트**: `GET https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService`
- **요청 파라미터**: `serviceKey`(필수, 기존 data.go.kr 키; httpx params 이중인코딩 방지 위해 KASI처럼 `unquote`된 decoded 키 사용), `obsCode`(필수, 예 `DT_0001`). **`resultType=json`을 줘도 XML로 응답**(JSON 미지원). **`date`류 파라미터는 어떤 이름(predcDe/obsDate/baseDate/tideDt/date)도 무시** — 항상 "오늘"만 반환(골든타임은 오늘 기준이라 무방; 날짜 지정 시도 말 것).
- **응답(XML)**: 루트 `<response><header><resultCode>00</resultCode><resultMsg>NORMAL_SERVICE</resultMsg></header><body><items><item>...`. 에러 시 `resultCode` 11(필수 파라미터 누락)/기타. 필수 파라미터 누락·미등록 서비스는 200이되 `resultCode≠00`.
- **item 필드**: `obsvtrNm`(관측소명), `lat`/`lot`(좌표, 오타 아님 — 경도가 `lot`), `predcDt`("YYYY-MM-DD HH:MM"), `predcTdlvVl`(예측 조위 cm, float 문자열), `extrSe`(**그날 극값 순번 1·2·3·4 — 고조/저조 구분값이 아님!**).
- **⚠️ 고조/저조 판정**: `extrSe`는 순번일 뿐이므로 홀짝으로 만조/간조를 판정하면 틀린다. **`predcTdlvVl` 값의 대소로 판정**할 것(인접 극값 대비 국소 최대=고조/만조, 국소 최소=저조/간조). 하루 4극값(반일주조)이 일반적.
- **실 캡처 예시(인천 DT_0001, 2026-09-08)** — 이 값을 `khoa_tide_sample.xml` 픽스처로 그대로 저장:
  - `02:26 extrSe=1 760.0cm`(고조), `08:59 extrSe=2 275.0cm`(저조), `14:46 extrSe=3 685.0cm`(고조), `20:58 extrSe=4 166.0cm`(저조).
  - → 낮 만조 = 14:46(685cm). 낮 골든타임 예: `12:46 - 14:46`("만조 14:46 · 2시간 전 갯벌 유입 피크"). 조위 텔레메트리 예: 현재 시각 기준 다음 극값(예 "만조 14:46").

### 정적 관측소 테이블 (실측 좌표, `tide_stations.py`에 그대로)

```
DT_0001 인천 37.45194 126.59222
DT_0002 평택 36.96694 126.82277
DT_0003 영광 35.42611 126.42055
DT_0004 제주 33.52750 126.54305
DT_0005 부산 35.09638 129.03527
DT_0006 묵호 37.55027 129.11638
DT_0007 목포 34.77972 126.37555
DT_0008 안산 37.19222 126.64722
DT_0010 서귀포 33.24000 126.56166
DT_0011 후포 36.67750 129.45305
DT_0012 속초 38.20722 128.59416
DT_0013 울릉도 37.49138 130.91361
DT_0014 통영 34.82777 128.43472
DT_0016 여수 34.74722 127.76555
DT_0017 대산 37.00750 126.35277
DT_0018 군산 35.97555 126.56305
DT_0020 울산 35.50194 129.38722
DT_0021 추자도 33.96194 126.30027
DT_0022 성산포 33.47472 126.92777
DT_0023 모슬포 33.21444 126.25111
DT_0024 장항 36.00694 126.68750
DT_0025 보령 36.40638 126.48611
DT_0026 고흥발포 34.48111 127.34277
DT_0027 완도 34.31555 126.75972
DT_0028 진도 34.37777 126.30861
DT_0029 거제도 34.80138 128.69916
DT_0031 거문도 34.02833 127.30888
DT_0032 강화대교 37.73194 126.52222
DT_0035 흑산도 34.68416 125.43555
DT_0036 대청도 37.82522 124.71805
DT_0037 어청도 36.11722 125.98472
DT_0038 굴업도 37.19444 125.99500
DT_0039 왕돌초 36.71916 129.73250
DT_0041 복사초 34.09833 126.16833
DT_0042 교본초 34.70472 128.30638
DT_0043 영흥도 37.23861 126.42861
DT_0044 영종대교 37.54555 126.58444
```

### 설계/제약

- **팀 권한 한계 인지**: backend-engineer 워커는 Bash/네트워크 없음 → 라이브 캡처·`uv run pytest` 자체 실행 불가(005 재확인). 그래서 위 그라운드 트루스를 완비했다. 픽스처는 실 캡처 XML을 그대로 쓰고, 파서는 픽스처로만 단위 검증(네트워크 0). **verify가 라이브 사유로 FAIL하면 스펙 결함 아님** — 브레인이 `test_live.py` + 실 호출로 최종 확인.
- **골든타임/서브스코어 로직**: 낮(mode=day) 시간대(대략 주간 관측 가능 시간, 빌더 재량으로 합리적 범위) 만조 극값 하나를 골라 "만조 시각 −Δ ~ 만조 시각" 골든타임 + description. 만조가 낮에 있으면 탐조 서브스코어를 높게(예 stub 70 대비 만조 근접·낮 시간대 여부로 가감), 없으면 낮음. 정확한 공식은 빌더가 정하되 결정적일 것.
- **계약(§8) 형태 불변**: `layers[].key=="tide"`의 `status`가 `stub`→`live`로 바뀌고 `telemetry`/`goldenHours` 값이 실데이터가 될 뿐, 응답 스키마는 그대로. flutter(006/007)는 재배선 불필요.
- **폴백**: 최근접 관측소 없음·HTTP 오류·`resultCode≠00`·XML 파싱 실패·낮 만조 없음 → 기존 stub과 동일한 결정적 값 + `status="stub"`(또는 `unavailable`은 degrade 유발하므로, 조석은 부가 레이어라 `stub` 폴백이 적절). 절대 raise 금지.

## Amendments (post-build change history, append-only)

- 2026-09-08, lead: claude sonnet — 크로스모델 검증(codex) FAIL 3건을 backend-engineer에 재위임해 수정, `just check` 재실행으로 76 passed/4 skipped(live) 확인:
  1. `parse()`가 day 모드에서 낮 만조가 없을 때도 `status="live"`(서브스코어 55)를 반환하던 결함 → 이제 `daytime_highs`가 비면 `ValueError`를 raise해 `fetch()`의 기존 try/except를 통해 결정적 stub(`status="stub"`)으로 degrade.
  2. day 골든타임이 낮 시간대 첫 번째 만조를 고르던 결함(스펙은 "가장 높은" 만조 요구) → `max(daytime_highs, key=lambda e: e.level)`로 교체.
  3. `fetch()`에서 `get_tide_config()`/`httpx.Client()` 생성이 `try` 밖에 있어 예외가 새어나갈 수 있고 `finally`의 `client.close()`도 raise 가능하던 결함 → 둘 다 `try` 안으로 이동, `close()`는 `try/except: pass`로 흡수.
  - `test_tide_provider.py`에 낮 만조 없음(raise 확인)/최고 만조 선택/`fetch()` 예외 흡수(fake client) 3개 테스트 추가, 기존 5개 무변경 통과.

- modified: 2026-09-08, lead: claude sonnet
