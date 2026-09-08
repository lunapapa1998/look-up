# 적합도 점수 엔진 (Suitability Score Engine) — backend

> plan-f3 spec. 공모전 핵심 차별성(공공 OpenAPI 융합 0~100 관찰 적합도 지수)의 backend 계약 publisher 슬라이스.
> 정본 근거: `docs/PRD-look-up.md` 3장(5-Layer Data Model → 0~100), flutter 계약 씨앗 `apps/flutter/lib/models/discovery.dart`.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-08
- modified: 2026-09-08 <brain/claude-code>
- modified: 2026-09-08, lead: claude-sonnet-5 — Phase 1-4 전부 위임·검증 완료, `GET /api/suitability` 계약 publish
- refs: docs/PRD-look-up.md (3장 5-Layer), docs/api-keys-status.md, apps/flutter/lib/models/discovery.dart, apps/flutter/lib/state/discovery_providers.dart, apps/backend/.team/member.md (기존 계약)
- risk: high — 신규 외부 통합(라이브 HTTP) + 계약 publisher. 3-layer 파이프라인 + 크로스모델 verify 필수.
- modified: 2026-09-08, lead: claude-sonnet-5 — 크로스모델 verify FAIL 3건(night humidity 미반영/422 테스트 커버리지/WEATHER_PROVIDER=kma 분기) 재위임·수정·검증 완료. 잔여 2건(fixture 실캡처, justfile suitability-live 리시피)은 backend 팀 도메인 밖이라 브레인 에스컬레이션.
- modified: 2026-09-08, lead: claude-sonnet-5 — 브레인 실측 그라운드 트루스 반영 재빌드. KASI 서비스키 디코딩·엔드포인트·필드(aste) 수정, 기상 소스 OWM→KMA 전면 전환, 텔레메트리 계약(sky/humidity/wind/precip)으로 교체, 라이브 스모크·env·핸드오프 동기화. 4단계 위임·검증 완료(`just check` 68 passed, 3 skipped). 실연동 최종 확인은 브레인이 `just suitability-live`로 수행 필요.

## Purpose

주어진 좌표·관찰 모드(낮 탐조 / 밤 천체)에 대해 공공 OpenAPI를 융합한 단일 0~100 적합도 점수·골든타임·텔레메트리를 산출하는 backend 엔진을 만들어, flutter 홈 화면의 mock 적합도 카드를 실제 계약으로 대체할 씨앗을 publish한다.

## Problem

flutter 홈/발견 화면의 적합도 점수(88), 골든타임, 텔레메트리(조위·시정·풍속·운량)는 전부 `discovery_providers.dart`의 하드코딩 mock이며, 이를 채울 backend 계약이 존재하지 않는다. 공모전 심사의 핵심인 "데이터 융합 → 0~100" 로직이 코드에 전혀 없다.

## Solution

`GET /api/suitability?lat&lng&mode` 엔드포인트를 신설한다. 확보된 3개 소스(**기상청 API 허브(KMA) 동네예보 격자** 기상, KASI 천문 출몰·박명·월령, VIIRS 근사 빛공해)를 **실제 HTTP로 라이브 호출**하고, 조석·생물·수요 레이어는 provider 인터페이스 스텁으로 타입만 확정한 뒤, 모드별 이중 가중치로 융합해 flutter `DiscoveryOverview` 계약(score·label·sqm/skyClass·goldenHours·telemetry)에 매핑되는 JSON을 반환한다.

> **2026-09-08 개정**: 기상 소스를 OpenWeatherMap → **기상청 API 허브(KMA)**로 전환(사용자 지시). OWM 관련 원문 기술은 아래 **Amendments(2026-09-08 KMA 전환)**가 덮어쓴다. KMA 격자엔 시정(visibility) 변수가 없어 '대기 시정' 텔레메트리를 KMA 지표(SKY·REH·WSD·PTY)로 교체(사용자 결정).

## 범위 확정 (2026-09-08 사용자 결정)

1. **레이어 범위**: 확보된 3레이어만 실연동 — 환경/기상(OWM), 천체(KASI 출몰시각·월령), 빛공해(VIIRS 근사). 조석(KHOA)·생물(eBird/KOBIS)·수요(관광빅데이터)는 `LayerProvider` 인터페이스 + 정적 스텁으로 타입만 확정하고 `status: "stub"`으로 표기(키 발급 후 교체).
2. **엔드포인트 표면**: 적합도 종합 1개(`GET /api/suitability`)만. 핫스팟 랭킹은 이번 범위 밖(장소 레이어 TourAPI 의존 → 후속 조각).
3. **HTTP 처리**: OWM·KASI를 실제로 라이브 호출한다. 단, 파이프라인 결정성 보장을 위해 **단위/엔드포인트 테스트는 어댑터를 페이크로 주입**(네트워크 0)하고, **실 API를 때리는 라이브 스모크는 별도 `just suitability-live` 리시피 + `@pytest.mark.live`로 분리**한다(키·네트워크 필요, `just backend-check`에서는 자동 skip). 두뇌가 빌드 PASS 후 `just suitability-live`를 수동 실행해 실연동을 최종 확인한다.

## Relevant Files

### Existing Files

- `apps/backend/app/main.py` - 신규 `suitability` 라우터 등록
- `apps/backend/pyproject.toml` - `httpx` 이미 존재. `python-dotenv`(.env 로드) 필요 시 추가
- `apps/backend/.team/member.md` - 계약 publisher 핸드오프에 `GET /api/suitability` 섹션 추가(flutter가 consume)
- `justfile` - `suitability-live` 리시피 추가(두뇌 유지보수 영역; 스펙은 요구만 명시)
- `apps/backend/.env.example` - 필요한 환경변수 목록 문서화(실제 값 없음)

### New Files

- `apps/backend/app/suitability/__init__.py`
- `apps/backend/app/suitability/models.py` - 응답 pydantic 스키마(`SuitabilityResponse`, `GoldenHour`, `TelemetryReading`, `LayerScore`)
- `apps/backend/app/suitability/scoring.py` - **순수 함수** 융합 알고리즘: 정규화된 레이어 sub-score + 모드별 가중치 → 0~100. 외부 의존 0
- `apps/backend/app/suitability/config.py` - env 로드(WEATHER_PROVIDER, KASI/OWM base url·key), 좌표 검증
- `apps/backend/app/suitability/providers/__init__.py`
- `apps/backend/app/suitability/providers/base.py` - `LayerProvider` 프로토콜 + `LayerReading`(sub_score, status, telemetry, evidence)
- `apps/backend/app/suitability/providers/weather.py` - OWM 어댑터(라이브 httpx). 시정·풍속·운량·습도
- `apps/backend/app/suitability/providers/astronomy.py` - KASI 어댑터(라이브 httpx). 출몰·박명·월령 → 골든타임·달 위상
- `apps/backend/app/suitability/providers/light_pollution.py` - VIIRS 근사 → SQM/Bortle/skyClass(키 불필요)
- `apps/backend/app/suitability/providers/tide.py` - 조석 스텁(status=stub, 인터페이스만)
- `apps/backend/app/suitability/service.py` - 프로바이더 오케스트레이션 + scoring 호출 + degrade 처리
- `apps/backend/app/routers/suitability.py` - `GET /api/suitability`
- `apps/backend/tests/suitability/test_scoring.py` - 순수 스코어링 단위 테스트(경계·모드별 가중치·정규화)
- `apps/backend/tests/suitability/test_endpoint.py` - 페이크 프로바이더 주입, 계약·검증·degrade·422 테스트
- `apps/backend/tests/suitability/fixtures/` - OWM/KASI 실 응답 캡처 JSON(페이크 어댑터가 로드)
- `apps/backend/tests/suitability/test_live.py` - `@pytest.mark.live` 실 API 스모크(기본 skip)

## 계약 (flutter consumer 대상 — publisher 핸드오프에 미러)

### `GET /api/suitability`

쿼리: `lat`(float, -90~90), `lng`(float, -180~180), `mode`(`day`|`night`). 셋 다 필수.

성공 200 `SuitabilityResponse` (camelCase, 기존 계약 관례 준수):

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
    { "kind": "tide", "label": "조위 상태", "value": "만조 16:15" },
    { "kind": "visibility", "label": "대기 시정", "value": "25 km" },
    { "kind": "wind", "label": "풍속·풍향", "value": "2.1 m/s (NW)" },
    { "kind": "cloud", "label": "운량", "value": "0% (맑음)" }
  ],
  "layers": [
    { "key": "environment", "weight": 0.40, "subScore": 90, "status": "live" },
    { "key": "astronomy", "weight": 0.20, "subScore": 85, "status": "live" },
    { "key": "lightPollution", "weight": 0.15, "subScore": 80, "status": "approx" },
    { "key": "tide", "weight": 0.25, "subScore": 88, "status": "stub" }
  ]
}
```

- `telemetry[].kind` enum: `tide` | `visibility` | `wind` | `cloud`(추가 가능). flutter는 `kind` → `IconData` 매핑(현재 하드코딩 icon을 kind 기반으로 전환). `label`/`value`는 그대로 표시용 한글 문자열.
- `layers[].status` enum: `live`(실 API) | `approx`(근사) | `stub`(미발급 대체) | `unavailable`(호출 실패로 가중치에서 제외됨).
- **모드별 이중 가중치**(PRD 4장): `day`=시정·풍속·만조 우선 / `night`=운량·습도·SQM·달위상 우선. 가중치 상수는 `scoring.py`에 표로 명시.
- **Graceful degradation**: live 프로바이더 호출 실패 시 5xx 대신 해당 레이어 `status:"unavailable"`로 표기하고 가중치를 남은 레이어로 **재정규화**한 뒤 `degraded:true`로 200 반환. stub 레이어는 항상 결정적 값.
- `score`는 int(반올림). `label`은 점수 구간 매핑(예: 85+ "매우 쾌적 (Prime)", 70+ "쾌적", 50+ "보통", 그 미만 "제한적") — 구간표는 scoring.py에 명시.

에러:
- 422: `lat`/`lng`/`mode` 누락 또는 범위/enum 위반(FastAPI 검증).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed/blocked.

### Phase 1: 순수 스코어링 코어 + 스키마

외부 의존 없는 융합 알고리즘과 응답 스키마부터 확정한다.

- [x] `models.py`: `SuitabilityResponse`/`GoldenHour`/`TelemetryReading`/`LayerScore` pydantic 모델(camelCase alias)
- [x] `providers/base.py`: `LayerProvider` 프로토콜 + `LayerReading` 데이터클래스(sub_score 0~100, status, telemetry 항목, golden hour 기여, evidence)
- [x] `scoring.py`: 모드별 가중치 표 + 정규화 + 재정규화(unavailable 제외) + 0~100 융합 + label 구간 매핑. 전부 순수 함수
- [x] `test_scoring.py`: 경계값(0/100), 모드별 가중치 차이, 레이어 제외 시 재정규화, label 구간

**Phase validation**: `cd apps/backend && uv run pytest tests/suitability/test_scoring.py -q` green.

### Phase 2: 라이브 프로바이더 어댑터

확보된 3소스를 실 httpx로 호출하는 어댑터. 응답 파싱 → `LayerReading`.

- [x] `config.py`: .env 로드(WEATHER_PROVIDER 기본 openweathermap, OWM/KASI base url·key), 좌표 검증 헬퍼
- [x] `providers/weather.py`: OWM 라이브 호출 → 시정·풍속(속도+방위)·운량·습도. **주의: OWM visibility 10km 캡** → "25km+" 판정 불가, evidence에 캡 노출 기록(최종 KMA 교체 여지). night 모드 sub_score에 humidity 반영(2026-09-08 수정, 아래 Amendments) 및 `WEATHER_PROVIDER=kma` 명시적 분기(evidence.reason으로 구분) 완료
- [x] `providers/astronomy.py`: KASI 출몰시각·월령 라이브 호출 → 천문박명 종료 기반 밤 골든타임, 달 위상(%)·삭망
- [x] `providers/light_pollution.py`: VIIRS 근사(정적/근사식, 키 불필요) → SQM 값·Bortle·skyClass 문자열
- [x] `providers/tide.py`: 스텁(status=stub, 결정적 텔레메트리·만조 골든타임 placeholder)
- [x] `fixtures/`: [F-부분] 실 응답 캡처 아님 — 워커에 Bash/네트워크 권한이 없어 라이브 캡처 불가. data.go.kr/OWM 공개 스키마 관례에 기반한 수기 작성 대표 픽스처로 대체(테스트는 이 픽스처에 대해 결정적으로 통과). Phase 4 라이브 스모크로 실제 스키마 검증 필요 — 불일치 시 파서 보정 후속 작업.

**Phase validation**: 페이크 주입 파서 단위 테스트 green(네트워크 0). 실 응답 캡처 fixture 존재.

### Phase 3: 서비스 오케스트레이션 + 엔드포인트

- [x] `service.py`: 프로바이더 실행(병렬/순차), 실패 시 unavailable 처리·degrade, scoring 호출, `SuitabilityResponse` 조립. 프로바이더는 **주입 가능**(테스트가 페이크 교체)
- [x] `routers/suitability.py`: `GET /api/suitability` 쿼리 검증·서비스 호출·200/422
- [x] `main.py`: 라우터 등록(`/api` prefix 유지)
- [x] `test_endpoint.py`: 페이크 프로바이더로 계약 필드 전량·모드별 차이·degrade(1개 실패)·422(누락/범위) 검증

**Phase validation**: `cd apps/backend && uv run pytest -q` 전량 green(기존 32건 + 신규).

### Phase 4: 라이브 스모크 + 계약 publish

- [x] `test_live.py`: `@pytest.mark.live` + 모듈 레벨 `skipif(RUN_LIVE_TESTS != "1")` 이중 안전장치 — 실 KMA·KASI 호출 3건(weather/astronomy/서비스 end-to-end), 기본 `pytest -q`에서 자동 skip(네트워크 0) 확인됨(68 passed, 3 skipped)
- [x] `justfile`: `suitability-live` 리시피 — 브레인이 직접 추가 완료(`suitability-live:` → `cd apps/backend && RUN_LIVE_TESTS=1 uv run pytest -m live -q -s`)
- [x] `.env.example`: 필요한 변수 목록(값 없음, placeholder만) 문서화 — repo-root `.env`를 가리킴을 명시
- [x] `.team/member.md`: `GET /api/suitability` 계약 섹션(§8) + Phase별 핸드오프 노트 전부 추가(flutter consumer 핸드오프용)

**Phase validation**: `just backend-check`에서 live 테스트 자동 skip 확인(네트워크 없이 green). `.team/member.md`에 신규 엔드포인트 표기.

## Validation Commands

> 파이프라인 결정성: 아래는 네트워크 없이 통과해야 한다(live 테스트는 마커로 자동 skip).

```sh
just check
```

## Notes (agent scratchpad)

- **라이브 실연동 확인은 파이프라인 밖**: `just backend-check`(=`pytest -q`)는 live 마커를 수집하되 실행 조건(마커 선택 + 키 존재) 미충족 시 skip해야 한다. 실 API 확인은 두뇌가 `just suitability-live`로 별도 수행. 이렇게 해야 codex verify가 네트워크·키 없이 결정적으로 돈다.
- **키 노출 금지**: 코드/테스트/픽스처에 실 키 하드코딩 금지. `.env`(gitignore)만. fixture는 응답 본문만 캡처하고 키·좌표는 마스킹.
- **OWM visibility 10km 캡**: 탐조 모드 시정 25km+ 판정 불가 → evidence에 캡 사실 남기고, 최종 기상청 단기예보(`WEATHER_PROVIDER=kma`) 교체 여지를 코드 구조로 남길 것(PROGRESS·api-keys-status와 일관).
- **스텁 레이어 정직성**: tide/생물/수요는 `status:"stub"`으로 정직하게 표기. 실 데이터인 척 금지(공모전 심사 신뢰성).
- 후속 조각: 핫스팟 랭킹(TourAPI 장소 레이어), KHOA 조석 실연동(키 발급 후 tide provider 교체), KMA 기상 교체, flutter consumer 배선(`discovery_providers.dart`를 AsyncNotifier로 전환).

## Amendments (post-build change history, append-only)

- 2026-09-08: 초안 작성. 사용자 범위 결정(3레이어 실연동 / suitability 종합만 / 실 HTTP 라이브+테스트는 페이크 주입·live 마커 분리) 반영.
- 2026-09-08: Phase 1-4 위임 실행. 두 가지 계획 대비 편차:
  1. **fixtures가 실제 캡처가 아님** — backend-engineer 워커에 Bash/네트워크 권한이 없어(agent 정의상 Read/Grep/Glob/Edit/Write만 보유) OWM·KASI 실 API를 때려 응답을 캡처할 수 없었다. `tests/suitability/fixtures/*.json`은 OWM 공개 스키마(신뢰도 높음)와 KASI/data.go.kr 통상 관례(response.body.items.item 래핑, HHMM 필드 등 — 신뢰도 낮음, 미검증 추정)에 기반한 수기 작성 대표 픽스처다. KASI 실제 필드명이 추정과 다를 경우 `providers/astronomy.py`의 파서(`_unwrap_item`, `_parse_hhmm` 등)가 실행 시 `unavailable`로 안전하게 degrade하도록 방어적으로 작성되어 있어 500 에러는 나지 않지만, 실제로는 계속 `unavailable`만 반환할 수 있다. **다음 단계**: 사용자가 `just suitability-live`(아래 justfile 항목 참고)를 실 키로 수동 실행해 KASI 응답 스키마를 확인하고, 불일치 시 `astronomy.py` 파서를 보정해야 한다.
  2. **`justfile`의 `suitability-live` 리시피가 추가되지 않음** — backend 팀의 write 도메인(`apps/backend`, `specs`)에 `justfile`이 포함되어 있지 않아 리드/멤버 누구도 쓸 수 없었다(스펙 원문에도 "두뇌 유지보수 영역"으로 명시돼 있었음). 브레인이 직접 다음 레시피를 `justfile`에 추가해야 한다: `suitability-live:` 다음 줄에 `    cd apps/backend && RUN_LIVE_TESTS=1 uv run pytest -m live -q`. 추가 후 실 키로 실행해 Phase 2b/2c의 실연동을 최종 확인할 것.
  3. `WEATHER_PROVIDER=kma` 스위치는 자리만 있고(env 변수는 읽지만) `provider != "openweathermap"`이면 명시적 `NotImplemented`가 아니라 그냥 `status="unavailable"`로 처리됨 — 스펙 원문 요구(명시적 NotImplemented)와 사소한 편차, 동작상 문제는 없음(기능 없음이 정직하게 표기됨).
  - 검증: `just check` 61 passed, 3 skipped(live), 0 network, flutter 20 tests 그대로 green.
- 2026-09-08: 크로스모델 verify 재실행 결과 FAIL 5건 중 backend 도메인 내에서 고칠 수 있는 3건을 재위임·수정·검증:
  1. **night 모드 습도 미반영 수정** — `providers/weather.py` `parse()`의 night 분기가 humidity_pct를 전혀 쓰지 않던 문제를 고쳐 `humidity_score = max(0, 1 - humidity_pct/100) * 100`을 도입, night sub_score를 `visibility*0.15 + wind*0.10 + cloud*0.45 + humidity*0.30`으로 교체(day 모드 불변). 스펙 99행 "night=운량·습도·SQM·달위상 우선" 요구 반영.
  2. **422 테스트 커버리지 보강** — `test_endpoint.py`에 `test_missing_lng_returns_422`/`test_missing_mode_returns_422`/`test_lng_out_of_range_returns_422` 3건 추가.
  3. **`WEATHER_PROVIDER=kma` 명시적 분기** — 기존에는 openweathermap 외 모든 provider 문자열이 동일한 "unsupported" unavailable로 뭉뚱그려졌으나, `kma`를 별도 분기로 분리해 `evidence.reason="KMA provider not yet implemented (see spec Phase 2 note)"`로 명시.
  - 검증: `just check` → 64 passed, 3 skipped(live), 0 network, flutter 20 tests green. `.team/member.md` §10에 핸드오프 기록.
  - **잔여 미해결 2건(backend 팀 도메인 밖, 브레인 조치 필요)**:
    a. Fixture 실캡처 미완료 — backend-engineer는 Read/Grep/Glob/Edit/Write만 보유(Bash/네트워크 없음)해 OWM·KASI 실 응답을 캡처할 수 없다. 현재 `tests/suitability/fixtures/*.json`은 공개 스키마 기반 수기 작성본. 브레인이 직접 `just suitability-live`(아래 항목 추가 후) 또는 별도 방법으로 실 키로 캡처해 교체해야 함.
    b. `justfile`의 `suitability-live` 리시피 미추가 — `justfile`은 backend 팀 write 도메인(`apps/backend`, `specs`)에 없어 리드/멤버가 편집 불가. 브레인이 직접 추가: `suitability-live:` 다음 줄에 `    cd apps/backend && RUN_LIVE_TESTS=1 uv run pytest -m live -q`.

- 2026-09-08: **브레인이 실 API를 직접 호출해 실연동 검증(오프라인 파이프라인이 못 잡던 결함 확정). `just suitability-live` 리시피는 브레인이 justfile에 추가 완료.** 아래는 재빌드 시 반드시 반영할 **실측 그라운드 트루스**다(추정 금지). 이 재빌드는 backend 팀에 다시 위임한다.

  **(1) data.go.kr 서비스키 이중 인코딩 — 전체 KASI 호출 버그.**
  `.env`의 `DATA_GO_KR_SERVICE_KEY`는 **Encoding 형식**(`%` 포함, 끝 `%3D%3D`). 이를 httpx `params=`로 그대로 넘기면 `%`가 재인코딩되어 **403 `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`(returnReasonCode 30)**. → `config.py`에서 `urllib.parse.unquote(service_key)` 후 사용하거나, 이미 `.env`에 존재하는 **`DATA_GO_KR_SERVICE_KEY_DECODED`**를 쓸 것. 디코딩 키로는 200 확인됨.

  **(2) KASI 실제 엔드포인트·파라미터·필드(astronomy.py 파서 전면 교체).**
  - riseset: base_url 뒤에 오퍼레이션 **`/getLCRiseSetInfo`**(좌표형) 붙여야 함. 현재 코드는 오퍼레이션 미부착 → `NO_OPENAPI_SERVICE_ERROR`(코드 12). params: `serviceKey`(디코딩), `locdate`(YYYYMMDD), `longitude`, `latitude`, **`_type=json`**(⚠ `dataType`가 아니라 `_type` — `dataType`이면 XML 반환).
  - lunph: 오퍼레이션 **`/getLunPhInfo`**, params: `serviceKey`(디코딩), **`solYear`/`solMonth`/`solDay`**(⚠ `locdate` 아님), `_type=json`.
  - 응답 래핑은 `response.body.items.item`(코드 가정 맞음). **실측 필드**(끝에 공백 패딩 있음, 반드시 `.strip()`):
    - riseset item: `astm`="0438  ", `aste`="2021  "(천문박명 조/석), `civilm`/`civile`, `nautm`/`naute`, `sunrise`="0608  ", `sunset`="1851  ", `moonrise`, `moonset`, `moontransit`, `suntransit`, `location`. → 밤 골든타임 시작은 **`aste`(천문박명 종료=저녁)**. 코드가 찾던 `astronomicalTwilightEnd`는 **존재하지 않음**.
    - lunph item: `lunAge`(예 26.8, float), `solYear/solMonth/solDay/solWeek`. (코드의 `lunAge` 사용은 맞음.)
  - 실 캡처 예시(서울 2026-09-08):
    - riseset: `{"aste":"2021  ","astm":"0438  ","sunrise":"0608  ","sunset":"1851  ","moonrise":"0224  ","moonset":"1714  ",...}`
    - lunph: `{"lunAge":26.8,"solDay":"08","solMonth":"09","solYear":2026}`

  **(3) 기상 소스 OWM → 기상청 API 허브(KMA)로 전환(사용자 지시). `providers/weather.py` 전면 교체.**
  - 인증: `.env` **`KMA_APIHUB_KEY`**(data.go.kr 키와 별개, 인코딩 이슈 없음), auth 파라미터명 **`authKey`**(⚠ `serviceKey` 아님 → 401). base: **`KMA_APIHUB_BASE_URL`** = `https://apihub.kma.go.kr/api/typ01/cgi-bin/url`.
  - 좌표→격자 변환: **`/nph-dfs_xy_lonlat`** `params={lon,lat,help:1,authKey}` → `#` 주석 헤더 + 데이터행. 서울(126.978,37.5665)→ **nx=61, ny=128**. 응답은 **text/plain**(JSON 아님). 파싱: `#`로 시작하지 않는 라인의 마지막 두 정수가 X,Y.
  - 격자 데이터: 실황 **`/nph-dfs_odam_grd`** `params={tmfc:YYYYMMDDHH00, vars, authKey}`(또는 초단기 `/nph-dfs_vsrt_grd`는 tmfc+tmef). 응답은 **전국 격자 전체를 공백구분 실수 매트릭스 text**로 반환(약 340KB, `-99.00`=무자료/해상). 표준 동네예보 격자 **nx 1..149, ny 1..253**. (nx,ny) 셀을 인덱싱해 추출. `vars`는 콤마구분(예 `SKY,REH,WSD,VEC,PTY`).
  - **KMA 격자엔 시정(visibility) 없음** → telemetry `kind:"visibility"` 제거. 대체: `sky`(하늘상태 SKY: 1맑음/3구름많음/4흐림), `humidity`(REH %), `wind`(WSD+VEC), `precip`(PTY). `scoring.py` 모드별 가중치에서 visibility 항 제거하고 day(탐조)=풍속·SKY(운량 proxy) 중심, night=SKY(운량)·습도 중심으로 재정규화.
  - `WEATHER_PROVIDER` 기본값을 **`kma`**로 전환. OWM 코드/분기·`OPENWEATHERMAP_*` 의존 제거(또는 완전 비활성). `test_live.py`·fixture도 KMA 실측 포맷으로 교체.

  **(4) 계약 변경(flutter consumer 영향).** `telemetry[].kind` enum에서 `visibility` 제거, `sky`/`humidity`/`precip` 추가. `.team/member.md`의 §8 계약과 enum을 갱신하고 flutter는 신규 kind→IconData 매핑 필요(후속 flutter 조각). 나머지 계약 필드(score/label/sqm/skyClass/goldenHours/layers)는 불변.

  **재빌드 범위(backend 팀 재위임)**: 위 (1)~(4)를 apps/backend 레인 안에서 구현·테스트. `just check` 오프라인 green 유지(라이브 마커 skip). 브레인이 재빌드 PASS 후 `just suitability-live`로 KMA·KASI 실연동 최종 확인.

- 2026-09-08: **브레인 실연동 검증에서 KMA 기상 레이어가 `unavailable`로 나와, 사용자 승인 하에 브레인이 `providers/weather.py`를 직접 수정(실 API로만 드러나는 파싱 결함 — 팩토리 구조상 검증 불가). 나머지 레이어는 재빌드 산출물 그대로 정상.**
  1. **좌표 파싱 콤마 버그** — `/nph-dfs_xy_lonlat` 응답이 콤마 구분(`126.978000, 37.566500, 61, 128`)인데 `_parse_xy_response`가 콤마 미제거로 `int('61,')` 실패 → `.replace(",", " ")` 후 split.
  2. **격자 인덱싱 모델 오류** — 실측 결과 격자는 **전국 flatten(총 37697 토큰 = 149×253)**, 물리 라인은 임의 폭으로 래핑되고 값도 콤마 종단. 기존 "1라인=1 ny행" 가정은 틀림. → `_parse_grid_value`를 전체 토큰 평탄화 + `(ny-1)*149+(nx-1)` 인덱싱으로 교체(`nx_max` 파라미터화). 서울(nx=61,ny=128) REH=38.9%가 실측 습도와 일치해 방향(row-major, y 아래→위) 확정.
  3. **SKY 출처 전환** — 실황 `odam`엔 SKY(하늘상태)가 없음(빈 응답) → 초단기예보 **`/nph-dfs_vsrt_grd`**(SKY 포함)로 전환. `tmfc`=직전 :30 발표, `tmef`=다음 정시. SKY/REH/WSD/VEC/PTY 전부 확보.
  - `test_weather_provider.py`의 3×3 격자 테스트를 평탄 인덱싱(`nx_max=3`)·콤마 종단 샘플로 갱신(정확성 동일).
  - **실연동 최종 확인(PASS)**: `.env` `WEATHER_PROVIDER=kma` 전환 후 `just suitability-live` → 3 passed(전부 실 API 도달). end-to-end(서울): `degraded:false`, environment=**live**(하늘상태 맑음/습도 30%/풍속 1.0 m/s SE/강수 없음), astronomy=**live**(밤 골든타임 20:21-00:01·월령 26.8일 광도 18%), lightPollution=approx, tide=stub. `just check` 68 passed·3 skipped(offline green) 유지.
  - **잔여**: 죽은 fixture `owm_weather_sample.json`는 브레인이 삭제 완료. telemetry `kind`가 `visibility`→`sky`/`humidity`/`precip`로 바뀐 계약 변경은 flutter consumer 배선(후속 조각)에서 반영 필요.
  - 이 조각 완료로 판단: 3레이어 실연동(KMA·KASI live, VIIRS approx) + 스텁 정직 표기 + graceful degrade + 계약 publish 전부 달성.

- 2026-09-08: 크로스모델 verify FAIL 9건(그라운드 트루스 미반영)을 4단계로 재위임·수정·검증 완료.
  1. **KASI 서비스키 디코딩 + 엔드포인트 전면 수정** — `config.py.get_astronomy_config()`가 `DATA_GO_KR_SERVICE_KEY_DECODED`를 우선 사용하고 없으면 `DATA_GO_KR_SERVICE_KEY`를 `urllib.parse.unquote()`로 디코딩하도록 수정. `astronomy.py.fetch()`가 `/getLCRiseSetInfo`·`/getLunPhInfo` 오퍼레이션을 base_url에 붙여 호출하고, `dataType` 대신 `_type=json`을 쓰며, lunph 요청은 `locdate` 대신 `solYear`/`solMonth`/`solDay`를 쓰도록 수정. `parse()`가 존재하지 않는 `astronomicalTwilightEnd` 대신 실측 필드 `aste`를 읽도록 수정. 픽스처 2개를 실측 캡처값(서울 2026-09-08, `aste`/`astm`/`sunrise`/`sunset`/`lunAge` 등 공백 패딩 포함)으로 교체.
  2. **기상 소스 OWM → KMA(기상청 API 허브) 전면 전환** — `config.py`에 `KMA_APIHUB_BASE_URL`/`KMA_APIHUB_KEY` 추가, `WEATHER_PROVIDER` 기본값을 `kma`로 전환. `weather.py`를 전면 재작성: `/nph-dfs_xy_lonlat`로 좌표→격자(nx,ny) 변환 후 `/nph-dfs_odam_grd`를 변수(SKY/REH/WSD/VEC/PTY)별로 개별 요청(멀티변수 응답 레이아웃이 그라운드 트루스에 확정돼 있지 않아 단일변수 요청으로 모호성 회피 — 후속 라이브 스모크로 실제 레이아웃 확인 시 배치 요청으로 최적화 여지 있음). telemetry를 `visibility`/`cloud`에서 `sky`/`humidity`/`wind`/`precip` 4종으로 교체, 강수(PTY≠0) 시 sub_score에 0.3배 페널티 적용.
  3. **엔드포인트 계약 테스트 갱신** — `test_endpoint.py`의 FakeProvider telemetry를 새 4종+`tide`로 교체, `telemetry` 길이 검증을 4→5로 수정.
  4. **라이브 스모크·문서·핸드오프 동기화** — `test_live.py`(telemetry 길이 3→4, 문구 KMA로 교체), `.env.example`(OWM 변수 제거, `KMA_APIHUB_*`/`DATA_GO_KR_SERVICE_KEY_DECODED` 추가), `.team/member.md` §8 telemetry 예시를 새 계약으로 갱신.
  - 검증: `just check` → 68 passed, 3 skipped(live), 0 network, flutter 20 tests green. 각 단계마다 변경 파일을 직접 Read로 대조 검증 후 체크오프.
  - **잔여 미해결 (경미, non-blocking)**: `tests/suitability/fixtures/owm_weather_sample.json`이 더 이상 어떤 코드에서도 참조되지 않는 죽은 파일로 남아있음 — 삭제하려면 `rm`이 필요한데 backend-engineer(Bash 없음)도, 리드(파이프라인 규칙상 `just member-build`/`just check`만 허용)도 실행할 수 없었다. 정확성에는 영향 없음(테스트가 더 이상 이 파일을 로드하지 않음). 다음 유지보수 시 Bash 권한이 있는 세션에서 삭제할 것.
  - **다음 단계**: 브레인이 `just suitability-live`로 KMA·KASI 실연동을 최종 확인해야 한다(리드 권한 밖 — 시도 시 command 승인 프롬프트로 차단됨).
