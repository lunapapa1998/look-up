# 위를 봐요(Look Up) — 디지털 생태 일기 CRUD 백엔드 (MVP 조각 1)

> plan-f3(youtube-insights 21편) 경량화 템플릿. 플랜은 살아있는 아티팩트 — 빌더가 작업하며 체크리스트와 Amendments를 직접 갱신한다.
> 독자 트라이펙타: 사람(나) / 팀 문서 / AI 에이전트 셋 다 읽는다.

## 메타데이터 (append-only — 줄을 지우지 말고 아래에 추가만)

- created: 2026-09-07
- modified: 2026-09-07 두뇌 세션 — 공모전 제안서 "위를 봐요" MVP 첫 조각(생태 일기 CRUD) 스펙화. lookup 백지 레포 기준(스캐폴딩 포함)
- refs: `(원 제안서 PDF — 저장소 미포함)`(원 제안서), [002-ecolog-flutter.md](002-ecolog-flutter.md)(소비 팀 스펙)
- risk: medium
- modified: 2026-09-07, lead: claude sonnet (backend-lead)
- modified: 2026-09-07, lead: claude sonnet (backend-lead) — PATCH null 계약 결함 수정
- modified: 2026-09-07, lead: claude sonnet (backend-lead) — observedAt PATCH null 거부 확장 반영

## Purpose

관광 데이터 공모전 서비스 "위를 봐요"의 5개 핵심 기능 중 외부 공공 API 의존이 가장 낮은 **디지털 생태 일기**를 첫 조각으로, apps/backend에 FastAPI 서비스를 세우고 관찰 기록 CRUD + 배지 도출 API를 만든다. 이 백엔드는 flutter 팀(002)이 소비할 **계약을 먼저 publish**한다.

## Problem

apps/backend 레인은 README 한 줄만 있는 백지 상태로, FastAPI 앱·의존성·테스트 셋업조차 없다. 생태 일기(사진·글·관찰 종 기록 + 배지 수집)는 데이터 융합 없이 독립적으로 동작하는 최소 조각인데, 이를 담을 서비스·엔티티·엔드포인트·저장소가 전무하다.

## Solution

apps/backend에 FastAPI 프로젝트를 스캐폴드하고(pyproject·`/api/health`·pytest), 관찰 기록(observation) 엔티티와 CRUD 엔드포인트, 관찰 종 누적에 따른 배지 도출 로직을 저장소 추상화 뒤 in-memory 구현으로 만든다. 인증·외부 공공 API·데이터 융합 점수는 이 조각 범위 밖(후속 스펙)이며, `.team/member.md`에 API 계약을 명문화해 flutter 팀이 diff 대신 노트로 소비하게 한다.

## 설계 제약 (후속 조각이 깨지지 않도록)

1. **계약 우선**: 이 스펙의 산출 계약(엔드포인트 시그니처·스키마)은 002 flutter가 그대로 소비한다. 필드명·타입은 `.team/member.md` 인계 노트에 확정 기록하고, 이후 변경 시 노트를 먼저 갱신한다.
2. **저장소 추상화**: 영속화는 MVP에서 in-memory(모듈 레벨 dict)지만, `ObservationRepository` 인터페이스 뒤에 두어 후속 SQLite 전환이 엔드포인트 코드를 건드리지 않게 한다.
3. **단일 사용자 가정**: 인증은 이 조각 범위 밖. userId·소유권 개념을 도입하지 않는다(후속 인증 스펙에서). 스키마에 user 필드를 넣지 않는다 — 넣으면 후속 인증 설계를 선점하게 됨.
4. **외부 API 금지**: 기상·천문·조석·조류 공공 OpenAPI는 이 조각에서 호출하지 않는다. 관찰 종은 사용자 자유 입력(`speciesName` 문자열) + 종류 토글(`bird`|`star`)로만 받는다. 실제 API 연동은 후속 '적합도 점수 엔진' 스펙에서 살린다.
5. **`/api` 프리픽스**: 모든 엔드포인트는 `/api` 하위로 둔다(프론트 base URL 관례 고정).

## Relevant Files

### 새 파일

- `apps/backend/pyproject.toml` — 프로젝트 메타 + 의존성(fastapi, uvicorn, pytest, httpx). Python >=3.12
- `apps/backend/app/__init__.py` / `apps/backend/app/main.py` — FastAPI 앱 + `/api/health` + 라우터 등록
- `apps/backend/app/models.py` — Pydantic 스키마: `SpeciesType`(Enum: bird|star), `ObservationCreate`, `ObservationUpdate`, `Observation`(id·observedAt·createdAt 포함), `Badge`, `BadgeProgress`
- `apps/backend/app/repository.py` — `ObservationRepository` 프로토콜 + `InMemoryObservationRepository`(dict 기반, id 자동 증가)
- `apps/backend/app/badges.py` — 관찰 목록 → 획득 배지·진행도 도출 순수 함수(결정론적 마일스톤 규칙)
- `apps/backend/app/routers/observations.py` — CRUD 라우터
- `apps/backend/app/routers/badges.py` — 배지 조회 라우터
- `apps/backend/tests/test_health.py` — 헬스체크·404 테스트
- `apps/backend/tests/test_observations.py` — CRUD 해피패스 + 검증 실패(400/422) + 404 + 배지 도출 테스트
- `apps/backend/README.md` — 엔드포인트 표·실행법·테스트법 (현재 한 줄 README를 본문으로 대체)
- `apps/backend/.team/member.md` — flutter 팀용 API 계약 인계 노트(엔드포인트·스키마·예시 JSON·base URL 관례)

## Phases

> 상태 4종: `[ ]` 미착수 / `[~]` 진행중 / `[x]` 완료 / `[F]` 실패(막힘 — 사유를 Notes에 남기고 진행).
> 규칙: 한 페이즈의 모든 박스가 체크되고 페이즈 검증이 통과하기 전에는 다음 페이즈 금지.

### Phase 0: FastAPI 스캐폴딩

백지 레인에 최소 동작하는 FastAPI 서비스를 세운다.

- [x] `pyproject.toml`(fastapi·uvicorn·pytest·httpx, requires-python >=3.12) + `app/` 패키지
- [x] `app/main.py`: FastAPI 앱 + `GET /api/health` → `{"status":"ok"}`
- [x] `tests/test_health.py`: health 200 + 미지정 경로 404
- [x] `README.md`를 실행법(`uv run uvicorn app.main:app`)·테스트법(`uv run pytest -q`) 포함 본문으로 대체

**페이즈 검증**: `cd apps/backend && uv run pytest -q tests/test_health.py` 통과

### Phase 1: 도메인 모델 + 저장소

관찰/배지 스키마와 저장소 추상화를 세운다.

- [x] `models.py`: `SpeciesType` Enum, `ObservationCreate`(speciesType·speciesName·note?·photoUrl?·observedAt?·lat?·lng?), `ObservationUpdate`(부분 갱신), `Observation`(+id·createdAt), `Badge`·`BadgeProgress`
- [x] `repository.py`: `ObservationRepository` 프로토콜(list/get/create/update/delete) + `InMemoryObservationRepository`(id 시퀀스, 없는 id는 None)
- [x] `badges.py`: `derive_badges(observations) -> list[BadgeProgress]` 순수 함수 — 결정론적 마일스톤 규칙
- [x] 모델·배지 단위 테스트

**페이즈 검증**: `cd apps/backend && uv run pytest -q -k "badge or model"` 통과

### Phase 2: CRUD + 배지 엔드포인트

라우터를 붙이고 앱에 등록한다.

- [x] `routers/observations.py`: POST(201) / GET 목록(speciesType 쿼리 필터 옵션) / GET {id}(404) / PATCH {id}(부분 갱신·404) / DELETE {id}(204·404)
- [x] 입력 검증: 잘못된 speciesType·빈 speciesName → 422/400, observedAt 미제공 시 서버 시각 기본값
- [x] `routers/badges.py`: GET `/api/badges` → 현재 저장소 관찰 기준 획득/진행 배지 목록
- [x] `main.py`에 두 라우터 include, 저장소 싱글턴 주입
- [x] `README.md` 엔드포인트 표 갱신

**페이즈 검증**: `cd apps/backend && uv run pytest -q` 전체 통과 (CRUD 해피패스·400/422·404·배지 도출)

### Phase 3: 계약 인계

flutter 팀이 소비할 계약을 확정 기록한다.

- [x] `apps/backend/.team/member.md`에 API 계약 작성: 엔드포인트 표 + 각 스키마 필드·타입 + 요청/응답 예시 JSON + base URL 관례
- [x] `just backend-check` 통과 확인

**페이즈 검증**: `just backend-check` 통과

## Validation Commands

> 전체 완료를 증명하는 커맨드. **justfile 레시피만 허용** (화이트리스트 원칙, 15편).
> 파이프라인이 아래 sh 블록의 각 줄을 순서대로 실행하며, 전부 exit 0이어야 통과.

```sh
just backend-check
```

## Notes (에이전트 자유 구역)

- **[선행조건, 두뇌 직접 — 발사 전 완료]** lookup의 `justfile` `check`는 초기 TODO(exit 1)다. 두뇌가 `backend-check`(= `cd apps/backend && uv run pytest -q`) 레시피를 추가하고 `check`에 배선해야 이 스펙의 Validation Commands가 성립한다. justfile은 팀 도메인 밖이라 멤버가 못 고친다.
- **[런 내 실행성 확인 필요]** backend 멤버(claude)는 Bash 미보유 가능성 — 테스트 실행 증거는 파이프라인 validate 단계의 `just backend-check`가 담당. `uv` 가용 여부는 발사 전 확인.
- 배지 규칙은 MVP에서 의도적으로 단순·결정론적으로 둔다. 종별 도감/희귀도 가중 배지는 후속(적합도 점수 엔진이 종-좌표 데이터를 들여온 뒤).
- 후속 조각 예약: (1) 적합도 점수 엔진(기상·천문·조석·빛공해 실제 OpenAPI 융합 → 0~100 점수), (2) 인증·멀티유저, (3) 에코 도보 큐레이션(두루누비·위치기반관광 API), (4) SQLite 영속화.

## Amendments (빌드 후 변경 이력, append-only)

- scout(agy)가 command 권한 문제로 무출력 실패 — 스펙 서술이 이미 충분히 구체적이라 스카우트 리포트 없이 진행함.
- 배지 규칙을 5개 고정 카탈로그로 확정: `first_step`(총 관찰≥1) / `explorer`(총≥5) / `master`(총≥20) / `bird_watcher`(bird 종류≥5) / `star_gazer`(star 종류≥5). `derive_badges`는 항상 5개 전부를 반환(달성 여부와 무관).
- `observedAt` 서버 기본값 로직은 스펙이 routers에 배치했지만, 저장소 계층(`InMemoryObservationRepository.create`)에 단일화해 라우터의 중복 로직을 방지함.
- 저장소 싱글턴은 `app/repository.py`의 `get_repository()` 접근자 + FastAPI `Depends`로 주입, 테스트는 `app.dependency_overrides`로 요청마다 격리.
- Phase 3 1차 위임에서 `.team/member.md` 쓰기가 권한 승인 필요로 실패(무출력, INCOMPLETE) → 동일 프롬프트로 1회 재위임해 성공. 이어서 멤버가 DONE 센티널을 파일 본문 마지막 줄에 실수로 같이 써넣어, 2차 소규모 위임으로 그 줄만 제거.
- 최종: `just check` 기준 27개 테스트 전부 통과, 4개 페이즈 모두 완료.
- **[검증 실패 후 재위임]** 크로스모델 검증기가 PATCH 계약 결함을 지적: `ObservationUpdate`가 `speciesType`/`speciesName`에 명시적 `null`을 허용해, `InMemoryObservationRepository.update()`의 `model_copy(update=...)`가 검증 없이 그대로 적용 → `Observation` 스키마가 두 필드를 non-null로 요구함에도 null이 저장·응답될 수 있었음. `apps/backend/app/models.py`의 `ObservationUpdate`에 `model_validator(mode="after")`를 추가해 두 필드에 명시적 null이 오면 422(ValidationError)로 거부하도록 수정. 다른 nullable 필드(`note`/`photoUrl`/`observedAt`/`lat`/`lng`)의 명시적 null 허용 동작은 그대로 유지. 테스트 4건 추가(모델 2건 + 라우트 422 2건), `.team/member.md` 섹션 3에 예외 규정 반영. `just check` 기준 31개 테스트 전부 통과 확인.
- **2026-09-07 두뇌(빌드 #1 검증 FAIL 후 계약 확정 — 사용자 결정):** 위 재위임이 `speciesType`·`speciesName`만 non-null 처리하고 **`observedAt`을 nullable로 남긴 것이 잘못**이다. 응답 스키마 `Observation.observedAt`은 non-null 필수 datetime이므로, PATCH `{"observedAt": null}`은 `model_copy`로 검증 없이 저장돼 응답 직렬화를 깨뜨린다(= speciesType/speciesName과 완전히 동일한 계열의 버그). **확정 계약: `observedAt`도 PATCH 명시적 null을 422로 거부한다.** 즉 required-non-null 3필드(`speciesType`·`speciesName`·`observedAt`)는 PATCH에서 명시적 `null` 불가; nullable 4필드(`note`·`photoUrl`·`lat`·`lng`)만 `null`로 비울 수 있다. 수정 지시: (1) `ObservationUpdate`의 `@model_validator(mode="after")`에 `observedAt` 명시적 null 거부 추가, (2) `.team/member.md`의 PATCH 표·설명에서 `observedAt`을 "null 불가(422)" 예외 목록으로 이동(현재 nullable로 잘못 기술됨 — 표 line 49 및 하단 문단), (3) `test_observations.py`에 PATCH `observedAt:null → 422` 테스트 추가, (4) `just backend-check` 재통과 확인.
- **2026-09-07 두뇌 — 위 지시 위임 완료:** `apps/backend` 멤버(claude/standard) 1회 위임으로 세 파일 동시 수정. `app/models.py`의 `_reject_explicit_null_species` validator에 `observedAt` 명시적 null 거부 분기 추가(기존 speciesType/speciesName 패턴과 동일). `tests/test_observations.py`에 `test_patch_observation_null_observed_at_returns_422` 추가(기존 `test_patch_observation_null_species_name_returns_422`와 동일 패턴). `.team/member.md`의 ObservationUpdate 표(line 49 Notes)·예외 문단(line 53)·nullable 필드 목록을 `observedAt` 제외로 갱신. 멤버는 Bash 미보유로 테스트 미실행(정적 검토만 완료, DONE 센티널 확인) → 두뇌가 `just check`로 직접 실행해 32개 테스트 전부 통과 확인(기존 31 + 신규 1). 스팟체크로 세 파일 diff 모두 지시대로 반영됨을 확인.
