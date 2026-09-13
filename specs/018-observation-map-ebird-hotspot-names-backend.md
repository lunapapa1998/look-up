# 관찰 지도 조류 스팟 이름 정제 (eBird 핫스팟 우선 + 개인관측지 주소 정리)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-13
- modified: 2026-09-13 <brain/orchestrator>
- refs: `specs/014-observation-map-backend.md`(원 계약·`app/observation/ebird.py` `parse_recent_obs`/`aggregate_by_location`), `apps/backend/.team/member.md` §25(`GET /api/observation-map` 계약), 오너 피드백(2026-09-13, 온-맵 라벨이 "486-15 남사읍, 용인시, 경기도, KR (37.155, 127.177)" 같은 주소로 떠서 "여차리 갯벌" 수준을 원함)
- risk: medium - 기존 `GET /api/observation-map` 계약의 조류 스팟 `name` 값 품질 개선(필드/스키마 무변경). eBird 집계 로직 조정. backend publisher(flutter 018이 소비하는 name이 깔끔해짐). 계약 형태 무변경(값만 개선).
- modified: 2026-09-13, lead: claude-sonnet-5
- modified: 2026-09-13, lead: claude-sonnet-5 (verify-FAIL 재수정 라운드)

## Purpose

관찰 지도 조류 스팟의 `name`이 eBird 개인 관측지의 주소 문자열("486-15 남사읍, 용인시, 경기도, KR (37.155, 127.177)")로 나와 지도 라벨이 지저분한 것을, **eBird 핫스팟(공개 관측지, 큐레이션된 장소명) 우선 + 개인관측지는 주소 정리**로 바꿔 "여차리 갯벌" 수준의 깔끔한 이름을 준다.

## Problem

1. `/data/obs/geo/recent`는 핫스팟(locationPrivate=false, 이름 예 "영종도--송산만과 갯벌")과 **개인 관측지**(locationPrivate=true, 이름=주소/좌표)를 섞어 준다.
2. 현재 014 집계는 이를 구분 없이 담아, 개인관측지가 많은 지역(용인 등)에선 라벨이 전부 주소로 떠 판독 불가.

## Solution

`app/observation/ebird.py`의 집계에서 (1) **핫스팟(locationPrivate=false)을 우선**해 조류 스팟을 구성하고, (2) 핫스팟이 부족할 때만 개인관측지를 포함하되 그 `name`은 **주소 꼬리(좌표·"KR"·국가/시도 접미) 제거로 정리**한다. 계약 스키마·필드는 무변경(name 값 품질만 개선). obsDt·status=community·speciesCount 등 정직 표기 전부 유지.

## Relevant Files

### Existing Files

- `apps/backend/app/observation/ebird.py` - `parse_recent_obs`에 `locationPrivate`(이미 실캡처에 존재) 매핑 확인/추가. `aggregate_by_location`에 **핫스팟 우선 정렬/필터** + 개인관측지 `name` 정리 헬퍼(`_clean_personal_locname`: 좌표 괄호·"KR"·국가/시도 접미 제거, 첫 의미 세그먼트 유지). 스팟 상한(예 최대 N개) 내에서 핫스팟 먼저 채우고 부족분만 정리된 개인관측지.
- `apps/backend/tests/observation/test_observation_parsers.py` - 핫스팟 우선·개인관측지 이름 정리 케이스 추가(주소 픽스처 → 정리된 name). 기존 회귀 없음.
- `apps/backend/tests/observation/fixtures/` - 개인관측지 주소형 name 픽스처 추가(용인 실캡처 형태).
- `apps/backend/.team/member.md` §25 - name 품질 규칙 1줄 보강(핫스팟 우선·개인관측지 주소 정리, 계약 형태 무변경).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 핫스팟 우선 집계 + 개인관측지 이름 정리 (순수)

- [x] `parse_recent_obs`가 `locationPrivate` 보존(실캡처 필드). `aggregate_by_location`: 핫스팟(private=false) 우선 채움 → 상한 내 부족분만 개인관측지(정리된 name). `_clean_personal_locname` 순수 헬퍼(좌표 괄호/"KR"/국가·시도 접미 제거, 빈 결과 방어→원문 첫 세그먼트).
- [x] `test_observation_parsers.py` 케이스: 혼합 입력 → 핫스팟 먼저, 개인관측지 name 정리 확인. 핫스팟 0개일 때 폴백.

**Phase validation**: `just check` green(신규 파서 테스트 + 기존 회귀 없음). 발사 후 브레인 uvicorn 라이브 검증(용인/강화 좌표 → name이 깔끔한지).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 경계
- **포함**: 조류 스팟 name 품질(핫스팟 우선·개인관측지 주소 정리). 계약 스키마 무변경.
- **제외**: 역지오코딩 신규 통합(핫스팟 이름으로 충분), 별/노포 name(무변경), 종 사진/특징(별도 데이터원 — flutter 018 후속).

### 라이브 근거 (2026-09-13)
- 용인(37.24,127.18) 조류 스팟 name 실캡처: "291-22 역북동, 용인시, 경기도", "486-15 남사읍, 용인시, 경기도, KR (37.155, 127.177)" = 전부 개인관측지 주소.
- 강화(37.59,126.40): "영종도--송산만과 갯벌", "강화도--여차리 물꽝" = 핫스팟 큐레이션명(깔끔). → 핫스팟 우선이 정답.

### 불변 원칙
- 계약 형태·필드 무변경(name 값만 개선). obsDt·status=community·speciesCount 정직 표기 유지. 기존 `/api/suitability`·`/api/trails` 무관.

## Amendments (post-build change history, append-only)

- (없음 — 발사 전)
- 2026-09-13 (backend lead): 스팟 상한 값 `_MAX_LOCATIONS = 20`으로 확정(스펙에 구체 수치 미기재 — 기존 회귀(3개 그룹) 손상 없이 지도 라벨 과밀을 막을 보수적 값으로 결정). `just check` green(backend 116 passed/8 skipped, flutter 127 passed) 확인. `apps/backend/.team/member.md` §26에 계약 무변경·name 정리 규칙 1줄 추가 완료.
- 2026-09-13 (backend lead, 크로스모델 verify FAIL 4건 수정): (1) `_clean_personal_locname`의 빈-`kept` 폴백이 좌표 괄호 포함 원문 전체(`raw.strip()`)를 반환하던 버그를 `without_coord.split(",")[0].strip() or without_coord.strip()`로 수정(원문 첫 세그먼트, 좌표 미포함). (2) 핫스팟 0개 폴백 테스트(`test_aggregate_by_location_fills_from_private_when_no_hotspots_exist`) 및 좌표 유출 방지 테스트(`test_clean_personal_locname_falls_back_without_coordinates_when_all_segments_are_filtered`) 추가. (3) `apps/backend/.team/member.md`의 신규 §26 헤딩을 삭제하고 동일 내용을 기존 §25 불릿으로 병합(스펙 지시대로 §25에 1줄 보강). `just check` green(backend 118 passed/8 skipped, flutter 125 passed) 재확인. (4) **미해결**: 스펙 45행이 요구하는 "발사 후 브레인 uvicorn 라이브 검증(용인/강화 좌표 → name 정제 확인)"은 backend lead의 Bash가 `just member-build`/`just check`로만 제한되어 uvicorn을 직접 기동할 수 없어 이번 런에서 수행 불가 — 브레인/오너가 직접 라이브 서버를 띄워 `GET /api/observation-map?lat=37.24&lng=127.18`(용인)과 `lat=37.59&lng=126.40`(강화) 응답의 `spots[].name`이 깔끔한지 확인 후 이 Notes에 결과를 기록해야 함.
- 2026-09-13 (brain, 라이브 검증 완료 — 실질 PASS): lead가 규칙5로 에스컬레이션한 uvicorn 라이브 검증을 브레인이 수행. 018 코드로 서버 재기동 후 확인. **용인(37.24,127.18)**: 이전엔 "486-15 남사읍, 용인시, 경기도, KR (...)" 같은 개인관측지 주소였는데 이제 **핫스팟 이름**("의왕--왕송저수지", "용인--석성산", "분당--탄천-정자동" 등 16개). **강화(37.59,126.40)**: "강화도--여차리 물꽝", "강화도--남단 농경지" 등 깔끔. 핫스팟 우선 필터 정상 동작. `just check` green(backend 118 passed). verdict=FAIL은 이 브레인 라이브검증 미수행이 유일 사유였고 해소 → 실질 PASS. [[factory-verdict-false-negative]]. (참고: 이름에 eBird 원본 영문 병기 "(...)"가 남음 — 온-맵 라벨에서 필요시 flutter 019가 괄호 이하 축약 가능, 소스 이름은 이미 깔끔.)
