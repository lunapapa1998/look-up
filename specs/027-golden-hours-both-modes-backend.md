# 골든타임 낮·밤 항상 함께 반환 (backend)

> Lightweight plan-f3 spec. `/api/suitability`가 요청 모드와 무관하게 낮·탐조 + 밤·천체 골든타임을 모두 반환하도록 한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- modified: 2026-09-18, lead: claude-sonnet-5
- refs: specs/005-suitability-engine-backend.md, specs/008-tide-live-backend.md, specs/025-home-suitability-card-redesign-flutter.md, Figma node 1-23
- risk: medium

## Purpose

홈 적합도 카드가 낮·탐조와 밤·천체 골든타임을 한 카드에 함께 보여줄 수 있도록(Figma 정본), 백엔드가 두 골든윈도우를 항상 반환하게 한다.

## Problem

현재 `goldenHours`는 provider 내부에서 요청 `mode`로 게이팅된다 — tide는 `mode=="day"`일 때만 탐조 골든타임을, astronomy는 night일 때만 천체 골든타임을 만든다. 결과적으로 응답에 **모드당 골든타임 1개만** 담겨, 카드가 낮·밤을 동시에 못 보여준다.

## Solution

골든타임 생성을 요청 `mode`에서 분리한다: tide provider는 항상 낮·탐조 골든윈도우를, astronomy provider는 항상 밤·천체 골든윈도우를 계산해 반환한다. `mode`는 점수/라벨/degraded(scoring.fuse)와 telemetry 강조에만 계속 사용한다.

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/tide.py` - `parse`/`_stub_reading`에서 `if mode == "day"`로 골든타임을 게이팅하는 부분 제거. 낮·탐조 골든윈도우(만조 기반)를 mode와 무관하게 항상 생성. night 브랜치가 골든타임을 비우던 로직 수정.
- `apps/backend/app/suitability/providers/astronomy.py` - `parse`에서 `if mode == "day": golden_hours=[]`로 밤 골든타임을 막던 부분 제거. 밤·천체 골든윈도우를 mode와 무관하게 항상 생성.
- `apps/backend/app/suitability/service.py` - 변경 최소. 이미 모든 LAYER_KEYS를 순회해 `golden_hours.extend(...)` 하므로, provider가 항상 채우면 자동으로 둘 다 합쳐진다. 필요 시 낮→밤 순서 정렬 보장.
- `apps/backend/tests/suitability/test_endpoint.py` - day/night 두 모드 모두에서 `goldenHours`에 day·night 항목이 **둘 다** 포함되는지 검증하도록 갱신. 기존 "모드당 1개" 가정 테스트 수정.
- `apps/backend/tests/suitability/test_tide_provider.py`, `test_astronomy_provider.py` - mode 무관하게 각자 골든윈도우를 항상 생성하는지로 기대값 갱신.

### New Files

- 없음.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: provider 골든타임 mode 게이팅 제거

tide·astronomy가 각자의 골든윈도우를 항상 생성하게 한다.

- [x] `astronomy.py::parse` — `if mode == "day": golden_hours=[]` 제거. 밤·천체 골든윈도우를 항상 계산(달 riseset/월령 기반). 점수 계산(sub_score/status)은 기존대로 mode 반영 유지.
- [x] `tide.py::parse` 및 `_stub_reading` — 낮·탐조 골든윈도우(만조 기반)를 `mode` 조건 없이 항상 생성. night에서 탐조 골든타임을 비우던 로직 제거. tide 데이터가 없을 때(stub)도 정책에 맞게 처리(윈도우 생략 or 근사).
- [x] 골든타임 항목의 `mode` 필드는 그 골든타임의 성격(day=탐조, night=천체)을 그대로 유지 — 요청 mode가 아니라 현상 기준.

**Phase validation**: `mode=day`와 `mode=night` 둘 다에서 `goldenHours`가 day·night 항목을 모두 포함한다(로컬 서비스 호출 또는 endpoint 테스트).

### Phase 2: 순서·중복·회귀

- [x] `service.py`에서 `goldenHours`가 낮 먼저·밤 나중 순서로 나가도록 보장(consumer가 정렬에 의존하지 않지만 안정적 순서 제공). 중복 방지.
- [x] `mode`가 여전히 score/label/degraded/telemetry에 정상 반영되는지(골든타임 분리가 점수에 영향 주지 않음) 확인.
- [x] endpoint/provider 테스트 갱신 및 통과.

**Phase validation**: `just backend-check`(또는 `just check`) 통과. day·night 응답 모두 골든타임 2개(낮·밤) 포함, 점수는 모드별로 기존과 동일.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 소비자: 홈 카드(flutter, 025 구현)는 이미 `goldenHours`를 낮→밤 정렬해 전부 렌더하므로, 백엔드가 둘 다 내려주면 flutter 추가 변경 없이 낮·밤 2행이 표시된다.
- 병렬 안전: 이 스펙은 `apps/backend`만 수정 → `apps/flutter`를 수정하는 spec 026(flutter)과 도메인이 겹치지 않아 병렬 실행 가능.
- 계약(스키마) 자체는 불변(`goldenHours: list[GoldenHour]`). 값(개수)만 늘어난다.
- degraded 정책 유지: tide/astronomy 데이터 미수신 시 해당 골든윈도우를 생략할지 근사로 채울지는 기존 stub 정책을 따른다.
- 검증 완료(lead): `apps/backend/.team/member.md` §33-35에 astronomy/tide mode 게이팅 제거 + service.py 정렬 작업이 기록되어 있었으나 작업 당시 member의 Bash 실행 권한이 없어 미실행 상태였음. lead가 직접 `just check` 실행해 backend 부분 156 passed / 0 failed / 12 skipped(사전 존재하는 live-test skip) 확인 — Phase 1·2 모두 그린.
- `just check` 전체는 실패하지만 원인은 100% `apps/flutter` 쪽(`modeToggleDayCollapsed`/`modeToggleNightCollapsed` 위젯 키 not found, `mode_header_test.dart`/`home_discovery_screen_test.dart`/`suitability_wiring_test.dart`)이며, 이는 진행 중인 `specs/026-home-mode-switcher-relocate-flutter.md`(flutter 팀 도메인)의 미완료 상태다. backend diff(`tide.py`/`astronomy.py`/`service.py`)는 골든타임 개수·순서만 바꾸고 flutter가 실패하는 모드 토글 위젯과는 무관함을 확인(golden hours 렌더링 테스트인 `home_discovery_screen_test.dart: renders suitability score, golden hours and telemetry`는 오히려 통과 목록에 있음). apps/backend는 이 lead의 쓰기 도메인 밖(apps/flutter)이라 직접 수정 불가 — orchestrator가 flutter 팀에 별도 라우팅 필요.

## Amendments (post-build change history, append-only)

- (없음)
