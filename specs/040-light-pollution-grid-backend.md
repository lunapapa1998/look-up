# 빛공해 실연동 — 번들 SQM 그리드 파이프라인 (backend)

> Lightweight plan-f3 spec. 빛공해 레이어의 합성 스텁을, World Atlas 2015 기반 한국 SQM 그리드를 조회하는 실데이터 파이프라인으로 교체한다. 런타임은 GDAL 의존 없이 번들 그리드만 조회(Cloud Run 친화). 실 그리드 데이터가 아직 없으면 가짜값을 내지 않고 명시적 폴백한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- modified: 2026-09-18, lead: sonnet
- modified: 2026-09-18, lead: sonnet (verify-fix round)
- modified: 2026-09-18, lead: sonnet (verify-fix round 2)
- modified: 2026-09-18, lead: sonnet (verify-fix round 3, final)
- refs: apps/backend/app/suitability/providers/light_pollution.py, World Atlas 2015 (Falchi et al.), design 결정(2026-09-18: 번들 그리드 방식)
- risk: medium

## Purpose

빛공해 SQM/Bortle을 위경도 sin() 합성값이 아니라 실제 관측 기반(World Atlas 2015) 한국 그리드에서 조회하도록, GDAL 런타임 의존 없는 번들 그리드 파이프라인 + 오프라인 생성 스크립트를 구축한다.

## Problem

현재 `LightPollutionProvider`는 `sin(lat,lng)` 합성값으로 SQM/Bortle을 만든다(가짜, status="approx"). 밤 모드에서 이 레이어 가중치가 0.30이라 점수 신뢰도를 크게 떨어뜨린다. 실데이터가 필요하지만, 표준 원본(World Atlas/VIIRS 래스터)은 크고/인증이 필요해 런타임에서 직접 다루기 부적합하다.

## Solution

밝기→SQM→Bortle 변환과 순수 파이썬 그리드 조회(nearest/bilinear)를 구현하고, 오프라인 생성 스크립트(`scripts/gen_light_pollution_grid.py`, rasterio 사용)로 World Atlas 래스터를 한국 영역 그리드 파일로 1회 변환해 리포에 번들한다. 실 그리드 파일이 있으면 실데이터(status="approx"), 없거나 범위 밖이면 **가짜값 대신 명시적 폴백**(status="stub", 기존 합성값을 "그리드 미설치" 라벨로만 유지).

## Relevant Files

### Existing Files

- `apps/backend/app/suitability/providers/light_pollution.py` - 합성 로직을 그리드 조회로 교체; 그리드 없을 때만 기존 합성값을 `status="stub"`(명시 라벨)로 폴백
- `apps/backend/app/suitability/config.py` - 그리드 파일 경로 config(`LIGHT_POLLUTION_GRID_PATH`, 기본 번들 경로) 추가
- `apps/backend/tests/suitability/` - 그리드 조회·변환·폴백 테스트(픽스처 그리드 사용)

### New Files

- `apps/backend/app/suitability/lightpollution/grid.py` - 그리드 파일 로더 + nearest/bilinear 조회(순수 파이썬, numpy 불요)
- `apps/backend/app/suitability/lightpollution/convert.py` - 밝기(mcd/m²)→SQM(`log10(brightness/108000000)/-0.4`, 자연밝기 22.0)→Bortle 변환
- `apps/backend/app/suitability/data/kr_light_pollution_grid.json` - (실데이터 채워지기 전엔 미포함/빈 상태) 한국 영역 SQM 그리드. bbox·resolution·nrows·ncols·values
- `scripts/gen_light_pollution_grid.py` - 오프라인 1회 실행: World Atlas GeoTIFF → 한국 크롭·샘플 → 그리드 JSON 출력. rasterio 사용, `just check` 대상 아님(문서화)
- `apps/backend/tests/suitability/fixtures/lp_grid_sample.json` - 테스트용 소형 픽스처 그리드

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 변환·그리드 조회 (순수 파이썬)

- [x] `convert.py`: 밝기→SQM→Bortle. SQM=`log10(brightness/108000000)/-0.4`; Bortle는 SQM 임계 테이블(기존 _SKY_CLASS_LABELS 톤 유지). 경계값 단위테스트
- [x] `grid.py`: JSON 그리드(bbox/res/nrows/ncols/values) 로드 + `lookup(lat,lng)` nearest(우선) 조회, 범위 밖이면 None. numpy 없이 인덱스 산술로
- [x] 픽스처 그리드로 서울(밝음·낮은 SQM·높은 Bortle) vs 산간(어두움) 순서·값 검증

**Phase validation**: convert/lookup 단위테스트 green, 범위 밖 None 안전. ✅ 확인(`just check` 188 passed 시점)

### Phase 2: provider 교체 + 정직한 폴백

- [x] `LightPollutionProvider.fetch`: 그리드 조회 성공 → 실 SQM/Bortle/sub_score, `status="approx"`, evidence.method="World Atlas 2015 grid"
- [x] 그리드 파일 없음/조회 None → **기존 합성값 유지하되 `status="stub"` + method="grid not installed — synthetic fallback"** (가짜를 실데이터로 위장 금지)
- [x] config로 그리드 경로 주입(테스트가 픽스처 경로 지정 가능)
- [x] sub_score 계산은 SQM 정규화 유지(회귀 없게)

**Phase validation**: 그리드 있음/없음 두 경로 모두 응답 유효, status가 정확히 approx/stub로 갈림. ✅ 확인(`just check` 192 passed, 회귀 없음)

### Phase 3: 생성 스크립트 + 문서 + 테스트

- [x] `scripts/gen_light_pollution_grid.py`: World Atlas GeoTIFF 경로 인자 → 한국 bbox(약 33~39N,124~132E) 크롭·샘플(예 0.05°) → SQM 변환 → 그리드 JSON 저장. rasterio 사용, 실행법 docstring
- [x] README/주석에 데이터 확보 절차 명기(World Atlas 2015 원본 → 스크립트 → 그리드 커밋)
- [x] 픽스처 그리드로 provider 통합 테스트, `just check` green(생성 스크립트는 미실행)

**Phase validation**: `just check` 통과. provider·변환·조회 커버, 생성 스크립트는 정적 확인만. ✅ 확인(`just check` 192 passed, 12 skipped, flutter 172 passed)

## Non-Goals

- **실 한국 그리드 데이터 생성/커밋** — World Atlas 2015 원본 래스터 확보가 선행 필요(별도, 이 스펙은 파이프라인+생성기까지). 원본 확보 후 스크립트 1회 실행으로 `kr_light_pollution_grid.json` 생성·커밋하면 실데이터 활성.
- 밤 sub_score 가중치(0.30)·다른 레이어 변경.
- rasterio를 런타임/`just check`에 도입(오프라인 생성 전용).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 원본 데이터 확보가 이 환경에서 자율로 어려움(World Atlas/VIIRS = 대용량 or 인증). 그래서 이 스펙은 **데이터 없이도 완성되는 파이프라인+생성기**까지. 실 그리드는 원본 확보 후 생성.
- 정직성 핵심: 그리드 없을 때 절대 실데이터인 척 금지 — status="stub" + method 라벨 명시. 기존 합성값은 "임시 폴백"으로만.
- SQM→Bortle 임계: 기존 `_SKY_CLASS_LABELS`(≤2 최적/≤4 양호/≤6 도심근교/그외 심각) 톤 유지, SQM 구간으로 매핑.
- 격리 worktree(feat/040-light-pollution-viirs, base=feat/039)에서 빌드.

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). 번들 그리드 파이프라인+생성기, 실 그리드 데이터는 원본 확보 후(별도). 가짜값 프로덕션 금지·정직 폴백.
- 2026-09-18 (lead, 재시도): 1차 시도는 스펙 파일만 작성되고 구현이 전혀 없었음(크로스모델 검증 FAIL 다수). Phase 1~3을 4회 위임(Phase 3은 1차 시도 때 워커가 새 디렉터리 쓰기 전 Bash 권한을 확인하려다 멈춰 DONE 센티널 없이 실패 — Bash 언급을 제거하고 Write 직접 호출을 명시해 재위임 후 성공)으로 전부 구현·검증 완료. `just check` green(backend 192 passed/12 skipped, flutter 172 passed), 회귀 없음.
- 2026-09-18 (brain): codex verify FAIL 3건 확인 — 전부 **오프라인 생성 스크립트 출력경로 버그**(런타임 파이프라인은 전 항목 PASS). 다음 위임에서 이 3건만 수정할 것:
  1. `scripts/gen_light_pollution_grid.py`(출력 쓰기 직전, 약 L130): 출력 파일 열기 전에 상위 디렉터리를 생성해야 함 — `os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)`. 현재 `app/suitability/data/`가 없어 기본 출력경로가 `FileNotFoundError`로 죽음.
  2. `scripts/README.md`(약 L35-40): 실행 예시가 `apps/backend`에서 `../app/suitability/data/...`로 쓰라고 해 `apps/app/...`(백엔드 밖)으로 잘못 해석됨. 출력경로가 실제 `apps/backend/app/suitability/data/kr_light_pollution_grid.json`으로 떨어지도록 상대경로 또는 실행 cwd 지시를 수정.
  3. 문서의 기본 생성 명령이 잘못된 디렉터리를 타겟 → 위 수정과 일치시킬 것.
  - **런타임/테스트 코드는 이미 PASS이니 건드리지 말 것.** 생성 스크립트·README만 수정, 완료 기준 `just check` green + 생성 스크립트가 clean 리포에서 기본 경로로 출력 디렉터리를 스스로 만들어 동작(정적/드라이런 확인).
- 2026-09-18 (lead, verify-fix round): codex verify가 지적한 3건 모두 1회 위임으로 수정 완료.
  1. `scripts/gen_light_pollution_grid.py`: `import os` 추가, `main()`의 `open(args.output, ...)` 직전에 `os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)` 삽입 — 출력 디렉터리 없는 클린 체크아웃에서도 안전.
  2. `scripts/README.md`: 잘못된 `--output ../app/suitability/data/...` 예시(리포 밖으로 나가는 상대경로) 제거, 스크립트 기본 출력 경로(`app/suitability/data/kr_light_pollution_grid.json`, `apps/backend`에서 실행 시 정확히 resolve)에 의존하도록 예시·설명 수정.
  - 런타임/테스트 코드는 미변경. `just check` green 재확인: backend 192 passed/12 skipped, flutter 전체 통과("All tests passed!"), 회귀 없음.
- 2026-09-18 (lead, verify-fix round 2): 크로스모델 검증에서 FAIL 1건 확인 — `scripts/README.md:21-38`에서 rasterio 설치 절차(`pip install rasterio`)와 실행 절차(`uv run python ...`)가 서로 다른 Python 환경을 가리켜 문서를 그대로 따라가면 `rasterio` import 실패로 이어짐(다른 PASS 항목은 전부 유지, 런타임/테스트 코드 해당 없음). 1회 위임으로 수정 완료: `apps/backend/scripts/README.md` 섹션 2·3을 재작성 — 별도 `pip install rasterio` 단계를 제거하고 `uv run --with rasterio python scripts/gen_light_pollution_grid.py --input ...`로 통합(uv 관리 환경 안에서 rasterio가 ephemeral 의존성으로 실제 로드됨). pyproject.toml·생성 스크립트·인자표·4단계 커밋 안내는 변경 없음. `just check` green 재확인: backend 192 passed/12 skipped, flutter 172 tests "All tests passed!", 회귀 없음.
- 2026-09-18 (brain, verify-fix round 3 지시): codex가 진짜 계약 갭 1건 지목 — marker-gated live 테스트 `apps/backend/tests/suitability/test_live.py:88-99`의 `test_suitability_service_live_end_to_end`가 빛공해 layer `status=="approx"`를 단언하나, 그리드 미번들 상태에선 provider가 `status="stub"`(정직 폴백)을 반환 → live 마커로 돌리면 실패. 이 테스트는 `just check`에서 skip이라 offline green이 못 잡음. **수정: 이 live 테스트의 빛공해 status 기대를 `"stub"`으로 갱신**(그리드 미설치가 현재 정상 상태임을 반영), 실 그리드 번들 후 `"approx"`가 됨을 주석으로 남길 것. 런타임/파이프라인 코드·다른 테스트는 미변경. 완료 기준: 해당 live 테스트가 새 계약과 일치(+ 가능하면 `just suitability-live` 정적/드라이 확인), `just check` 회귀 없음.
- 2026-09-18 (lead, verify-fix round 3): 1회 위임으로 수정 완료. `apps/backend/tests/suitability/test_live.py:98`(어서션 직전 한 줄 주석 추가, 라인번호는 밀림) — `layers_by_key["lightPollution"].status == "approx"`를 `== "stub"`으로 변경, 바로 위에 "실 그리드 번들 후 approx로 전환됨" 주석 추가. 다른 라인/파일 변경 없음(직접 read로 diff 확인). 워커가 이번 세션에서 `.team/member.md` 쓰기 권한을 거부당해 핸드오프 노트를 직접 갱신하지 못함(응답 텍스트로만 보고) — 리드가 대신 본 Amendments에 기록. `just check` 재확인: backend 192 passed/12 skipped, flutter 172 tests "All tests passed!", 회귀 없음. **스펙 전 phase 완료 + 크로스모델 검증 3라운드 모두 해소.**
