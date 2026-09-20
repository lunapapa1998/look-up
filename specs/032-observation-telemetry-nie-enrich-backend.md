# 관측 텔레메트리 NIE 보강 (보호종·안전거리·서식지·조석·생태노트)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 brain/session
- refs: 014-observation-map-backend.md, 016-observation-map-figma-parity-flutter.md, 020-species-wiki-rich-trails-backend.md, 008-tide-live-backend.md, 027-golden-hours-both-modes-backend.md
- risk: medium

## Purpose

피그마 "최근 관측 텔레메트리" 카드를 실데이터로 채우기 위해, eBird 관측에 국립생태원(NIE/에코뱅크) 보호종·서식지 정보와 기존 조석·생태 정보를 결합한 텔레메트리 페이로드를 백엔드에서 제공한다.

## Problem

현재 `ObservationMapResponse`는 eBird 기반의 위치명·좌표·시각·종수만 제공한다. 피그마 카드가 요구하는 보호종 여부, 안전 관찰 거리, 서식지, 조석 피크, 종 생태 서술은 응답에 없고, 특히 "성조/유조 연령 구성"과 "섭식 행동"은 어떤 공개 API로도 실측되지 않는다.

## Solution

NIE data.go.kr 데이터셋(기존 `DATA_GO_KR_SERVICE_KEY` 재사용)으로 보호종·서식지를 보강하고, 그로부터 안전거리 규칙을 결정론적으로 산출하며, 기존 조석 provider와 species 생태정보를 관측 지점에 결합한다. 실측 불가 필드(연령·행동 서술)는 날조하지 않고 프로비넌스 라벨과 함께 "종 일반 생태" 또는 명시적 미제공으로 처리한다.

## Relevant Files

### Existing Files

- `apps/backend/app/observation/models.py` - `BirdObservation`에 텔레메트리 보강 필드 추가, 신규 `ObservationTelemetry` 모델 편입
- `apps/backend/app/observation/service.py` - bird spot 생성 시 NIE·조석·생태 결합 로직 추가
- `apps/backend/app/suitability/config.py` - `get_nie_config()` 추가 (data.go.kr 서비스키 재사용)
- `apps/backend/app/routers/observation_map.py` - 응답 모델 변경 반영(스키마만, 시그니처 유지)
- `apps/backend/app/suitability/providers/tide.py` - 조석 피크/오프셋 산출 로직 재사용(가능하면 추출)
- `apps/backend/app/species/wikipedia.py` - 종 일반 생태 노트 소스로 재사용

### New Files

- `apps/backend/app/observation/nie.py` - NIE 보호종/서식지 조회·정규화 클라이언트 (network-optional, 실패 시 빈 결과)
- `apps/backend/app/observation/safe_distance.py` - 보호종 등급 → 권장 관찰 거리 결정론적 규칙
- `apps/backend/tests/test_observation_nie.py` - NIE 파서·안전거리 규칙·프로비넌스 라벨 단위 테스트

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: NIE 보호종·서식지 보강

NIE data.go.kr 데이터셋으로 관측 종의 법적 보호종 여부(멸종위기·천연기념물)와 서식지 유형을 조회한다.

- [ ] `get_nie_config()` 추가 — base_url은 env, 서비스키는 `DATA_GO_KR_SERVICE_KEY(_DECODED)` 재사용
- [ ] `nie.py`에 조회·파싱 함수 구현 (`parse_*`는 순수함수, `fetch_*`는 예외 삼킴 후 빈 결과)
- [ ] 보호종 결과에 `source="nie"`, `status="live"|"unavailable"` 프로비넌스 부여
- [ ] 키 미설정/네트워크 실패 시 degrade (빈 보강, 기존 eBird 카드는 유지)

**Phase validation**: `parse_*` 단위 테스트가 대표 응답을 정규화하고, 키 없을 때 `status="unavailable"`로 안전 degrade됨을 검증.

### Phase 2: 안전 관찰 거리 결정론적 규칙

보호종 등급 → 권장 관찰 거리(m)와 규칙 문구를 코드로 산출한다. 임의값 금지, 규칙 테이블 기반.

- [ ] `safe_distance.py`에 등급→거리 매핑 테이블과 `recommend(protected) -> {distanceM, rule, source="rule"}` 구현
- [ ] 비보호종 기본값과 보호종 상향 규칙 정의 (예: 멸종위기 I급 ≥ Nm)
- [ ] 규칙 근거를 `evidence`에 기록 (어떤 등급으로 어떤 거리가 나왔는지)

**Phase validation**: 등급별 입력에 대해 기대 거리·문구가 나오는 단위 테스트 통과.

### Phase 3: 조석 피크·서식지 결합

기존 조석 provider의 만조 피크/오프셋과 서식지 유형을 관측 지점 텔레메트리에 결합한다.

- [ ] 조석 피크 시각·현재 대비 오프셋(±h) 산출을 provider에서 재사용 가능한 형태로 노출/추출
- [ ] observation service에서 지점 텔레메트리에 `tidePhase{label, peakOffsetH, status}` 채움
- [ ] 서식지 라벨(NIE, 없으면 null)을 텔레메트리에 포함

**Phase validation**: 조석 데이터 유무 두 경우 모두에서 응답이 유효하고 `status`가 정확히 반영됨.

### Phase 4: 종 일반 생태 노트(프로비넌스 라벨)

연령 구성·섭식 행동을 "이번 관측 실측"으로 만들지 않는다. 종 대표값에 대해 species 생태정보(위키 등)를 "종 일반 생태"로 라벨링해 선택 제공하거나 생략한다.

- [ ] `ecologyNote{text, source="curated"|"wikipedia", status}` 필드 추가 (관측이 아닌 종 일반 생태임을 소스로 명시)
- [ ] 연령 구성(성조/유조)·행동 서술은 **카드에서 완전 제거** — 스키마·페이로드·UI 어디에도 넣지 않음 (사용자 결정, Non-Goals 참조)
- [ ] 생태 노트 소스 실패 시 `status="unavailable"`로 생략

**Phase validation**: 노트가 제공될 때 소스 라벨이 반드시 붙고, 소스 없을 때 카드가 노트 없이도 유효.

## Non-Goals

- 성조/유조 **연령 구성**과 **섭식 행동 서술("Sweeping" 등)** — 공개 API에 실데이터 없음. 사용자 결정으로 **카드에서 완전히 제거**한다(순화 표시·큐레이션 대체 모두 하지 않음). 백엔드 스키마·flutter UI 어디에도 포함하지 않는다.
- 실시간 GPS 위치추적(텔레메트리 원의미) 연동 — NIBR(생물자원관) 소관·과거 데이터라 이 스펙 범위 밖.
- Flutter 카드 UI 구현 — 본 스펙은 백엔드 페이로드까지.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just check
```

## Notes (agent scratchpad)

- 프로비넌스 원칙: 모든 텔레메트리 필드는 기존 `status` 패턴("live"/"approx"/"community"/"stub"/"unavailable")을 따르고, 관측 실측이 아닌 값은 `source`로 종 일반 생태/규칙임을 드러낸다. 생성 콘텐츠를 실측으로 오인시키지 않는 것이 이 스펙의 무결성 핵심.
- 키 재사용: astronomy/tide/trails가 이미 `DATA_GO_KR_SERVICE_KEY(_DECODED)`를 공유. Cloud Run 배포 시 data.go.kr egress는 기존 Cloud NAT 고정 IP(메모리 lookup-cloudrun-datagokr-nat) 경유가 필요할 수 있음 — 배포 전 확인.
- 연령/행동은 카드에서 완전 제거 확정(2026-09-18 사용자 결정). design-lead 자문·후속 flutter 스펙 대상 아님.

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). eBird+NIE+생태/조석 3소스 하이브리드, 연령·행동 날조 배제.
- 2026-09-18: 사용자 결정 반영 — 연령/행동 필드를 카드에서 완전 제거(순화·큐레이션 대체 없음)로 확정.
