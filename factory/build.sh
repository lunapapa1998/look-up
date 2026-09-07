#!/usr/bin/env bash
# Phase 4 ①: 리스크 티어 디스패처 — "오타 수정에 드림팀을 보내지 마라" (19편)
# 스펙 메타데이터의 `- risk: low|medium|high` 선언에 따라 팀 규모(파이프라인)를 조정한다.
#   low    → pipeline.sh      (2계층 Builder–Verifier. scout·lead 없음 — 소형/단일 파일 변경)
#   medium → team-pipeline.sh (3계층 scout→lead→member→verifier. 기본값)
#   high   → team-pipeline.sh + MAX_ATTEMPTS=3 + 이중 교차 검증(VERIFIER2, 기본 agy)
# 사용법: build.sh <spec.md> [team.yaml|팀이름]   (= just build <spec.md> [team])
#         팀은 yaml 경로 또는 짧은 이름(web·qa 등 — team-pipeline.sh가 factory/teams/<이름>.yaml로 해석)
# 옵션(환경변수): DRY_RUN=1 → 실행 없이 디스패치 결정만 JSON 출력
# 주의: low 티어의 체크포인트 커밋은 도메인 스코프가 아니다(add -A) — orchestrate 병렬에 섞지 말 것.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec="${1:?usage: build.sh <spec.md> [team.yaml]}"
team="${2:-$here/teams/docs.yaml}"
[[ -f "$spec" ]] || { echo "{\"ok\":false,\"error\":\"spec not found: $spec\"}"; exit 1; }

# 메타데이터 섹션의 마지막 `- risk:` 선언을 읽는다 (append-only — 나중 선언이 이긴다)
# 티어 값은 첫 토큰만 — 템플릿 관례상 뒤에 `— 설명`이 붙는다 (예: `- risk: medium — 다중 파일`)
risk="$(awk '/^## 메타데이터/{f=1;next} /^## /{f=0} f' "$spec" \
  | grep -E '^- risk:' | tail -1 | sed 's/^- risk:[[:space:]]*//' | awk '{print $1}' | tr -d '[:space:]' || true)"
risk="${risk:-medium}"

case "$risk" in
  low)    pipeline="pipeline.sh";      env_desc="MAX_ATTEMPTS=2" ;;
  medium) pipeline="team-pipeline.sh"; env_desc="MAX_ATTEMPTS=2" ;;
  high)   pipeline="team-pipeline.sh"; env_desc="MAX_ATTEMPTS=3 VERIFIER2=${VERIFIER2:-agy}" ;;
  *) echo "{\"ok\":false,\"error\":\"invalid risk tier in spec (want low|medium|high): $risk\",\"spec\":\"$spec\"}"; exit 1 ;;
esac

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  jq -cn --arg spec "$spec" --arg team "$team" --arg risk "$risk" \
    --arg pipeline "$pipeline" --arg env "$env_desc" \
    '{ok: true, dryRun: true, spec: $spec, team: $team, risk: $risk, pipeline: $pipeline, env: $env}'
  exit 0
fi

case "$risk" in
  low)    exec "$here/pipeline.sh" "$spec" ;;
  medium) exec "$here/team-pipeline.sh" "$spec" "$team" ;;
  high)   MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}" VERIFIER2="${VERIFIER2:-agy}" \
            exec "$here/team-pipeline.sh" "$spec" "$team" ;;
esac
