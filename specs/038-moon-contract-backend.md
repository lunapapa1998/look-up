# 오늘의 달 계약 노출 + 골든타임 문구 정리 (backend)

> Lightweight plan-f3 spec. 밤 골든타임 줄에서 달 정보를 빼 "달빛 방해 없는 시간대"로 정리하고, 달 위상·조명도·월출·월몰을 담은 `moon` 객체를 suitability 응답 계약에 새로 노출한다(flutter "오늘의 달" 섹션의 publisher).

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/035-night-golden-moon-aware-backend.md, specs/037-golden-desc-simplify-backend.md, design-lead 자문(2026-09-18, 오늘의 달 IA)
- risk: medium
- modified: 2026-09-18, lead: claude-sonnet-5

## Purpose

밤 골든타임 `description`에서 달 밝기 표기를 제거해 창(window) 설명만 남기고, 달 위상 정보(위상 이름·조명도·월출·월몰)를 별도 `moon` 계약 객체로 노출해 flutter "오늘의 달" 섹션이 소비할 수 있게 한다.

## Problem

037에서 golden `description`이 `달빛 방해 적은 시간대 · 달 밝기 N%`로 순화됐지만, (1) 골든타임은 로직상 항상 무월광이라 "달 밝기 N%"가 "달빛 방해 없음"과 모순돼 사용자 혼동을 일으키고, (2) 달 위상 정보를 담을 계약 필드가 없어 "오늘의 달" 섹션을 만들 수 없다.

## Solution

golden `description` 4분기에서 "· 달 밝기 N%"를 제거해 창 설명만 남기고("달빛 방해 없는 시간대" 등), astronomy evidence에 이미 있는 lunarAge/illumination/moonrise/moonset로 `moon` 객체(위상 이름·조명도·월출·월몰·status)를 조립해 `SuitabilityResponse`에 추가한다. golden_hours 스키마·시간계산·windowSource·sub_score·낮로직은 불변.

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/astronomy.py` - golden description 4분기 "· 달 밝기 N%" 제거; `_moon_phase_name(lun_age)` 헬퍼 + evidence→`moon` dict 헬퍼 추가
- `apps/backend/app/suitability/models.py` - `Moon` 모델 신설 + `SuitabilityResponse.moon: Moon | None` 추가
- `apps/backend/app/suitability/service.py` - astronomy reading evidence로 `moon` 조립해 응답에 포함(astronomy unavailable 시 moon=null)
- `apps/backend/tests/suitability/test_astronomy_provider.py` - description assert 갱신(4분기) + 위상이름·월출몰 포맷 테스트
- `apps/backend/tests/suitability/test_endpoint.py` - 응답에 `moon` 필드 존재/모양 검증 추가
- `apps/backend/.team/member.md` - §계약에 `moon` 객체 스키마 publish(consumer=flutter)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: golden description에서 달 밝기 제거

각 분기가 "창(window)"만 설명하도록 "· 달 밝기 N%"를 뗀다.

- [x] 정상(무월광): `달빛 방해 적은 시간대 · 달 밝기 N%` → **`달빛 방해 없는 시간대`**
- [x] 달 밤새 떠있음: `달이 밤새 떠 있어 … · 달 밝기 N%` → **`달이 밤새 떠 있어 어두운 별은 보기 어려워요`**
- [x] 월출몰 결측: `하늘이 완전히 어두운 시간 · 달 정보 확인 중` → **`하늘이 완전히 어두운 시간`**
- [x] 고정폴백: `달 밝기 N%` → **`하늘이 어두운 시간대`**

**Phase validation**: 4분기 모두 달 밝기 % 표기가 description에서 사라지고 창 설명만 남음.

### Phase 2: `moon` 계약 객체 노출

astronomy evidence(lunarAgeDays/illuminationPct/moonrise/moonset)로 `moon`을 조립한다.

- [x] `Moon` 모델: `illumination:int(0~100)`, `phaseName:str`, `moonrise:str|None`("HH:MM"), `moonset:str|None`("HH:MM"), `status:str`("live"|"approx"|"unavailable")
- [x] `_moon_phase_name(lun_age)` — 월령→위상이름(차오름/기움을 월령으로 구분): `[0,1.85)삭 · [1.85,5.54)초승달 · [5.54,9.23)상현 반달 · [9.23,12.92)차오르는 달 · [12.92,16.61)보름달 · [16.61,20.30)기우는 달 · [20.30,23.99)하현 반달 · [23.99,27.68)그믐달 · [27.68,29.53]삭`
- [x] 월출/월몰 raw("1328  ")를 기존 `_parse_hhmm`/`_format_hhmm`으로 "HH:MM" 변환, 파싱 실패 시 null
- [x] service에서 astronomy reading이 `unavailable`이면 `moon=null`(또는 status="unavailable"), live면 채움
- [x] `SuitabilityResponse.moon` 추가(Optional, 기존 필드/소비자 하위호환)

**Phase validation**: `GET /api/suitability?...&mode=night` 응답에 `moon` 객체가 위상이름·조명도·월출몰 HH:MM으로 포함되고, astronomy unavailable 케이스에서 null/unavailable로 안전.

### Phase 3: 테스트·계약 문서

- [x] description 4분기 assert 갱신, 위상이름 경계값·월출몰 포맷·unavailable 테스트 추가
- [x] endpoint 테스트에 `moon` 필드 검증
- [x] `.team/member.md`에 `moon` 스키마 publish(consumer=flutter 039)
- [x] timeRange·sub_score·windowSource·낮 골든타임 무변경 회귀 확인

**Phase validation**: `just check` 통과, 계약에 moon 추가·description 정리 반영, 회귀 없음.

## Non-Goals

- flutter "오늘의 달" 섹션 UI — 별도 스펙(039).
- 시간계산·무월광 구간 산출·sub_score·낮 골든타임 변경.
- `goldenStartDriver`(월몰이 시작을 결정했는지) 플래그 — 인과 카피 안 쓰므로 이번엔 제외(후속).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 달 데이터는 신규 API 호출 불필요 — 035에서 이미 KASI riseset로 evidence에 lunarAgeDays/illuminationPct/moonrise/moonset 확보됨. 이 스펙은 그걸 계약으로 승격만 함.
- phaseName은 illumination만으론 상현/하현 구분 불가 → 반드시 lunarAge 기준으로 산출(backend 단일 소스).
- 격리 worktree(feat/038-moon-contract, base=feat/037 ff20f5a)에서 빌드 — 공유 트리 flutter 혼란 회피, `just check` 신뢰 가능.
- design-lead 근거: golden 줄은 "창" 설명, 달은 별도 섹션. "달 밝기"→표기는 섹션에서 "달빛 N%"로(밝다=좋다 오독 방지) — 그 카피는 flutter 039에서.

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). golden 문구 달밝기 제거 + moon 계약 노출, 계산/점수/낮로직 불변. flutter 039의 publisher.
- 2026-09-18 (lead): 전 3단계 완료. `just check` 실행해 backend 167 passed/12 skipped, flutter 전체 통과 확인(회귀 없음). member는 Bash 미가용으로 매 태스크마다 정적 검증만 했다고 보고했으나, lead가 직접 `just check`로 실제 테스트 그린을 재검증함.
- 2026-09-18 (lead): 크로스모델 검증 FAIL 4건 수정 재위임 및 완료. (1) `models.py`: `Moon.illumination`→`Field(ge=0,le=100)`, `Moon.status`→`Literal["live","approx","unavailable"]`로 제약. (2) `test_astronomy_provider.py`: all-night 분기 2개 assertion을 substring→exact-match로 강화(달밝기 접미사 잔존해도 통과하던 허점 제거). (3) `test_endpoint.py`: astronomy `status="unavailable"` → `moon=None` 경로 전용 테스트 신규 추가. (4) `.team/member.md` §43에 flutter 039 consumer용 `Moon` 계약 표 신규 publish. `just check` 재실행해 backend 168 passed/12 skipped(신규 테스트 1건 포함), flutter 168 tests 전체 통과 확인(회귀 없음).
- modified: 2026-09-18, lead: claude-sonnet-5
