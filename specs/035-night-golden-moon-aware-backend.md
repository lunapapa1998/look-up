# 밤 골든타임 달 위상 반영 (실제 암천 창 계산)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 brain/session
- refs: 005-suitability-engine-backend.md, 027-golden-hours-both-modes-backend.md, apps/backend/app/suitability/providers/astronomy.py
- risk: medium
- modified: 2026-09-18, lead: claude-sonnet-5
- modified: 2026-09-18, lead: claude-sonnet-5 (cross-model fix round)

## Purpose

밤 · 천체 골든타임을 "천문박명 + 고정 3시간 40분" 휴리스틱에서, KASI 응답에 이미 들어있는 월출·월몰·아침 박명을 이용한 실제 암천(dark-sky) 창 계산으로 개선한다.

## Problem

현재 `astronomy.py`는 저녁 천문박명(`aste`)에 상수 220분을 더한 고정 창만 만든다. 달이 밤새 떠 있는 보름 무렵이나 계절별 밤 길이 차이를 전혀 반영하지 못해, 밝은 달빛으로 천체 관측이 불가능한 시간도 "골든타임"으로 표기된다.

## Solution

같은 riseset 응답의 `moonrise`·`moonset`·아침 천문박명(`astm`)을 파싱해 실제 암천 구간(저녁 박명~아침 박명)을 구하고, 광도가 높을 때 달이 떠 있는 구간을 제외한 가장 긴 무월광 창을 골든타임으로 산출한다. 필요한 필드가 없으면 기존 고정 창 휴리스틱으로 degrade하며, `golden_hours` 계약(mode/label/timeRange/description) 형태는 그대로 유지한다.

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/astronomy.py` - `parse()`의 밤 골든타임 산출부를 달·박명 인지 로직으로 교체, `moonrise`/`moonset`/`astm` 파싱 추가, 결측 시 폴백
- `apps/backend/tests/suitability/test_astronomy_provider.py` - 신규 케이스(무월광 창·달 상시존재·자정 넘김·필드 결측 폴백) 테스트 추가

### New Files

- (없음 — 단일 provider 로직 개선. 필요 시 순수 헬퍼는 astronomy.py 내부에 둔다)

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 추가 필드 파싱 + 암천 창

riseset 응답에서 월출·월몰·아침 박명을 파싱하고, 저녁 박명~아침 박명의 암천 창(자정 넘김 처리)을 계산한다.

- [x] `moonrise`·`moonset`·`astm`(아침 천문박명) 파싱 헬퍼 추가 (기존 `aste`와 동일한 HHMM 파서 재사용)
- [x] 암천 창 = `aste` → 다음날 `astm` 로 구성, 자정 넘김을 분(minute) 축으로 정규화해 계산
- [x] 파싱 실패/필드 결측 시 기존 고정 창(aste + 220분)으로 폴백하고 그 사실을 evidence에 기록

**Phase validation**: 대표 fixture로 암천 창 길이가 계절에 따라 달라지고, 자정 넘김 케이스가 올바른 분 구간으로 나옴을 단위 테스트로 확인.

### Phase 2: 달 위상 인지 창 산출

광도에 따라 달이 떠 있는 구간을 제외하고 가장 긴 무월광 창을 골든타임으로 선택한다.

- [x] 암천 창 내에서 달-존재 구간(moonrise~moonset, 자정 넘김 포함)을 뺀 잔여 구간들 계산
- [x] 광도 임계값(config 상수, 예: `_MOON_BRIGHT_PCT`)로 분기: 저광도면 암천 창 전체, 고광도면 최장 무월광 구간을 golden으로 채택
- [x] 달이 암천 창 내내 떠 있고 고광도면 → "관측 제한" 성격을 description에 명시(무월광 창 없음), 창은 축소/생략 규칙 정의
- [x] `description`에 달 맥락 부가(예: "월령 N일 · 광도 M% · 무월광 HH:MM~HH:MM")

**Phase validation**: (a) 저광도 초승 무렵=암천 창 전체, (b) 보름 상시존재=무월광 없음 처리, (c) 부분 월출입=최장 무월광 구간 선택이 각각 테스트로 검증.

### Phase 3: 계약 안정성·회귀 확인

`golden_hours` 항목 스키마(mode/label/timeRange/description)를 유지해 flutter 소비자 무변경을 보장한다.

- [x] `mode="night"`, `label="밤 · 천체 골든타임"` 유지, `timeRange`는 "HH:MM - HH:MM" 포맷 유지
- [x] 기존 통과 테스트가 여전히 녹색인지 확인, 폴백 경로가 이전 동작과 동치인지 회귀 테스트
- [x] 낮 골든타임(tide) 및 sub_score 로직은 미변경 확인

**Phase validation**: `just check` 통과, golden_hours 계약 필드/포맷 불변.

## Non-Goals

- **낮 골든타임(tide) 로직 변경** — 이번 범위 아님(만조−2h 유지).
- **밤 sub_score 공식(`100 - illuminationPct`) 변경** — 골든타임 창만 개선, 점수 산정은 별도.
- 구름/시상(seeing)·행성 가시성 등 추가 천문 변수 도입 — 후속.
- 새 외부 API 도입 — 기존 KASI riseset 응답의 미사용 필드만 활용.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just check
```

## Notes (agent scratchpad)

- KASI `getLCRiseSetInfo`는 sun/moon rise·set·transit과 civil/nautical/astronomical twilight을 한 응답에 반환. 현재 `aste`만 사용 중 → `moonrise`·`moonset`·`astm` 등 동일 응답에서 확보 가능(신규 호출 불필요). 실 응답 필드명은 builder가 fixture/실호출로 확정할 것.
- 시간 계산은 전부 분(minute-of-day) 축으로 정규화하고 자정 넘김은 +1440으로 처리하면 구간 연산이 단순해짐. 순수 헬퍼로 분리해 테스트.
- 광도(illuminationPct)는 기존 `100*(1-|lunAge-14.75|/14.75)` 재사용.
- 무월광 창이 아예 없는 경우(보름+상시존재)의 UX 표기는 문구만으로 처리(별도 UI 스펙 불필요) — degrade가 아니라 "제한" 성격 설명.

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). 밤 골든타임을 달·박명 인지 실암천 창 계산으로 개선, 계약/낮로직/점수 불변 유지.
- 2026-09-18: 구현 완료 (backend-lead, member 1회 위임). `astronomy.py`에 `_MOON_BRIGHT_PCT=50` 상수, `_format_minute_of_day`/`_moonless_segments` 헬퍼 추가; `parse()`를 darkSky(aste~astm 정규화)/fixedFallback(astm 결측 시 기존 aste+220분) 2경로로 분기하고, darkSky 경로에서 광도<50%면 창 전체, ≥50%면 moonrise~moonset 정규화 구간을 빼고 남은 무월광 구간 중 최장 구간을 채택(전부 덮이면 창 전체 유지 + "관측 제한" 문구)하도록 구현. evidence에 `windowSource`/`astm`/`moonrise`/`moonset` 4개 키 추가. 픽스처 5개·테스트 5개 신규(기존 4개 테스트 무변경). member는 Bash 미가용으로 손 트레이스만 하고 DONE 라인만 남겼으나, lead가 직접 `just check` 실행해 backend 161 passed/12 skipped, flutter suite 전부 green으로 최종 검증함(스펙 규칙 7 — 클레임을 신뢰하지 않고 직접 확인).
- 2026-09-18: 크로스모델 검증(FAIL) 대응 수정 완료 (backend-lead, member 1회 재위임). 검증기가 지적한 실결함 확인: moonrise/moonset을 각각 `dark_start`와 독립 비교해 1440분을 더하던 정규화가, 달이 저녁 박명 시작 전에 이미 떠서(moonrise<aste) 박명 이후에 지는(moonset>aste) 경우 겹침을 전혀 감지하지 못해 창 전체를 오답으로 "무월광"/"관측 제한" 처리하는 버그였음. 수정: `moonrise_norm`은 절대 보정하지 않고, `moonset_norm`은 (raw)moonset이 moonrise_norm보다 크지 않을 때만(moonrise 기준 자정 넘김) +1440. 부가로 moonrise/moonset 필드 자체가 결측인데 광도≥50%인 경우 기존엔 "무월광"을 잘못 단언했던 것을, "월출몰 정보 없음 · 전체 암천 HH:MM~HH:MM" 문구로 교체(windowSource 라우팅은 무변경 — astm 결측만 fixedFallback을 트리거하는 기존 회귀 테스트 유지). 픽스처 2개(`kasi_riseset_moon_risen_before_twilight.json`, `kasi_riseset_moon_allnight_offset.json`)·테스트 3개 신규 추가. member는 Bash 미가용으로 손 트레이스만 하고 DONE 라인만 남겼으나, lead가 직접 파일 diff 검사 + `just check` 실행해 backend 164 passed/12 skipped(신규 3건 포함, 회귀 없음) 확인. flutter suite의 `trails_wiring_test.dart` IndexError 1건은 apps/flutter 미변경·astronomy.py와 무관한 기존 실패로 이번 스펙 범위 밖(별도 flutter 팀 확인 필요).
