# PROGRESS — 위를 봐요(Look Up)

> 이 리포의 세션 인수인계 진입점. 새 세션은 여기부터 읽는다.
> 이 리포는 factory 소비 레포다 (본사: `~/dev/pi-agent-expert`, 템플릿: `~/dev/factory-template`).
> 두뇌 규칙은 `CLAUDE.md` / 절차는 `factory/brain.md`.

## 이 앱은 뭔가

**"위를 봐요(Look Up)"** — 2026 관광 데이터 활용 공모전 제안서 기반 앱.
원 제안서: `~/Downloads/2026_관광데이터_공모전_제안서.pdf`.

새(낮·탐조)와 별(밤·천체관측)을 매개로 지역의 낮과 밤을 재발견하는 저탄소 로컬 관광 플랫폼("수직적 여행"). 공모전 핵심 차별성은 기상·천문·조석·빛공해 등 공공 OpenAPI를 융합한 **0~100 적합도 점수 엔진**.

- **스택:** backend = FastAPI(계약 publisher) / flutter = Riverpod(consumer). 풀스택 확정.
- **팀:** `backend`, `flutter` (init.sh로 부트스트랩, `factory/teams/*.yaml`).

## MVP 커팅 (2026-09-07)

전체 5기능(실시간 생태 가이드 / 에코 도보 큐레이션 / 디지털 생태 일기 / 낮-밤 패키지 / 그린 마일리지) 중 **외부 API 의존이 가장 낮은 '디지털 생태 일기 CRUD'** 부터.

- `specs/001-ecolog-backend.md` — FastAPI 스캐폴딩(Phase 0) + 관찰 기록 CRUD + 배지 도출, in-memory 저장소. **계약 publisher.** risk: medium. Validation: `just backend-check`.
- `specs/002-ecolog-flutter.md` — Flutter 스캐폴딩 + 목록/작성/배지 3화면, Riverpod, 001 계약(`apps/backend/.team/member.md`) consume. risk: medium. Validation: `just flutter-check`.

**후속 조각 예약** (각 스펙 Notes 참조): 적합도 점수 엔진(실제 OpenAPI 융합), 인증·멀티유저, 에코 도보 큐레이션(두루누비·위치기반관광 API), SQLite 영속화, '수직적 여행' 브랜딩 디자인 패스.

## 지금까지 한 것

- `~/dev/factory-template/init.sh ~/dev/lookup backend flutter` 로 부트스트랩 (커밋 `df732ca`)
- justfile `check` TODO → `backend-check`(uv pytest)·`flutter-check`(flutter analyze+test) + 빈 레인 skip + `check-teams` 배선 (커밋 `a9a439c`). 현재 `just check` = exit 0
- 스펙 001·002 작성, `check-specs` 통과 (커밋 `953374d`)

## MVP 조각 1 (디지털 생태 일기) 완성 (2026-09-07) ✅✅

- **001 backend** PASS, 커밋 `218efc5`. FastAPI CRUD + 배지, pytest 32건. 계약 published: `apps/backend/.team/member.md`.
  - 빌드 #1 검증 FAIL(codex): PATCH `observedAt:null`이 응답 스키마(non-null 필수)와 모순. 사용자 결정 "422 거부" → Amendment 명문화 후 재발사 PASS. required-non-null 3필드(speciesType·speciesName·observedAt)는 PATCH 명시적 null 불가.
- **flutter 스캐폴딩** (A안, 두뇌 선심기) 커밋 `0431c52`.
- **002 flutter** PASS, 커밋 `0f9aa3a`. Riverpod + 3화면(목록·작성폼·배지그리드) + API 클라이언트(HTTP/Fake) + 위젯테스트. flutter test 15건.
  - 빌드 #1 FAIL=claude 세션 한도(용량, 스펙 아님) → 리셋 후 재개. 빌드 #2 품질 FAIL 2건(배지 name 영어→한국어 계약 미러 위반, diary 카드 사진 썸네일 누락) → 스펙 002 Amendment로 못 박고 재발사 PASS.
- `just check` 전체 green: backend pytest 32 + flutter analyze 무경고 + flutter test 15.
- **크로스모델 검증(claude 빌드 ↔ codex 검증)이 실제 결함 3건을 전부 잡음** — 셋 다 `validation:true`(테스트 통과)였으나 verify가 FAIL. 상세 부검: [`docs/verification-postmortem-mvp1.md`](docs/verification-postmortem-mvp1.md).

## 다음 세션 시작점 (후속 조각)

1. **미커밋 factory 유지보수 3파일** — `factory/adapters/agy.sh`(모델 `3.5→3.6 Flash Low`), `factory/build.sh`·`factory/team-pipeline.sh`(팀 이름→`teams/<name>.yaml` 해석). 커밋 필요.
2. **`just factory-sync` 검토** — 로컬 core가 factory-template보다 뒤처짐(팀 이름 해석이 템플릿엔 이미 canonical). sync로 로컬 임시패치를 정본으로 대체 권장.
3. **후속 조각 스펙화** (각 001/002 Notes의 예약분): (a) 적합도 점수 엔진(기상·천문·조석·빛공해 OpenAPI 융합 → 0~100), (b) 인증·멀티유저, (c) 에코 도보 큐레이션(두루누비·위치기반관광 API), (d) SQLite 영속화, (e) '수직적 여행' 브랜딩 디자인 패스.

## 크레딧 감각

- medium 스펙 1개 ≈ claude 2~4콜(리드+멤버) + codex 1~2콜(검증) + agy 1콜(정찰), 5~10분. 발사 전 예상 콜 수 고지.
- 긴 런은 백그라운드로 발사 후 결과 JSON 파싱해 보고.

## 참고 (본사 세션에서 한 작업)

이 준비(부트스트랩·스펙·justfile)는 `pi-agent-expert` 세션에서 두뇌 역할로 수행했다. 관련 메모리는 본사 memory에 있음(`lookup-app-project`, `factory-repo-lineage-and-sync`). 앞으로 lookup 프로덕트 작업은 **이 폴더에서 세션을 열어** 진행한다.
