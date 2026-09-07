# 위를 봐요(Look Up) — 디지털 생태 일기 CRUD 백엔드 (MVP 조각 1)

> plan-f3(youtube-insights 21편) 경량화 템플릿. 플랜은 살아있는 아티팩트 — 빌더가 작업하며 체크리스트와 Amendments를 직접 갱신한다.
> 독자 트라이펙타: 사람(나) / 팀 문서 / AI 에이전트 셋 다 읽는다.

## 메타데이터 (append-only — 줄을 지우지 말고 아래에 추가만)

- created: 2026-09-07
- modified: 2026-09-07 두뇌 세션 — 공모전 제안서 "위를 봐요" MVP 첫 조각(생태 일기 CRUD) 스펙화. lookup 백지 레포 기준(스캐폴딩 포함)
- refs: `(원 제안서 PDF — 저장소 미포함)`(원 제안서), [002-ecolog-flutter.md](002-ecolog-flutter.md)(소비 팀 스펙)
- risk: medium

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

- [ ] `pyproject.toml`(fastapi·uvicorn·pytest·httpx, requires-python >=3.12) + `app/` 패키지
- [ ] `app/main.py`: FastAPI 앱 + `GET /api/health` → `{"status":"ok"}`
- [ ] `tests/test_health.py`: health 200 + 미지정 경로 404
- [ ] `README.md`를 실행법(`uv run uvicorn app.main:app`)·테스트법(`uv run pytest -q`) 포함 본문으로 대체

**페이즈 검증**: `cd apps/backend && uv run pytest -q tests/test_health.py` 통과

### Phase 1: 도메인 모델 + 저장소

관찰/배지 스키마와 저장소 추상화를 세운다.

- [ ] `models.py`: `SpeciesType` Enum, `ObservationCreate`(speciesType·speciesName·note?·photoUrl?·observedAt?·lat?·lng?), `ObservationUpdate`(부분 갱신), `Observation`(+id·createdAt), `Badge`·`BadgeProgress`
- [ ] `repository.py`: `ObservationRepository` 프로토콜(list/get/create/update/delete) + `InMemoryObservationRepository`(id 시퀀스, 없는 id는 None)
- [ ] `badges.py`: `derive_badges(observations) -> list[BadgeProgress]` 순수 함수 — 결정론적 마일스톤 규칙
- [ ] 모델·배지 단위 테스트

**페이즈 검증**: `cd apps/backend && uv run pytest -q -k "badge or model"` 통과

### Phase 2: CRUD + 배지 엔드포인트

라우터를 붙이고 앱에 등록한다.

- [ ] `routers/observations.py`: POST(201) / GET 목록(speciesType 쿼리 필터 옵션) / GET {id}(404) / PATCH {id}(부분 갱신·404) / DELETE {id}(204·404)
- [ ] 입력 검증: 잘못된 speciesType·빈 speciesName → 422/400, observedAt 미제공 시 서버 시각 기본값
- [ ] `routers/badges.py`: GET `/api/badges` → 현재 저장소 관찰 기준 획득/진행 배지 목록
- [ ] `main.py`에 두 라우터 include, 저장소 싱글턴 주입
- [ ] `README.md` 엔드포인트 표 갱신

**페이즈 검증**: `cd apps/backend && uv run pytest -q` 전체 통과 (CRUD 해피패스·400/422·404·배지 도출)

### Phase 3: 계약 인계

flutter 팀이 소비할 계약을 확정 기록한다.

- [ ] `apps/backend/.team/member.md`에 API 계약 작성: 엔드포인트 표 + 각 스키마 필드·타입 + 요청/응답 예시 JSON + base URL 관례
- [ ] `just backend-check` 통과 확인

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

- (아직 없음 — 빌드 시작 시 리드가 기록)
