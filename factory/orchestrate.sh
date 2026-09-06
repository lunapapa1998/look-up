#!/usr/bin/env bash
# Phase 3 ②: 복수 (스펙, 팀) 쌍을 병렬 fan-out — 두뇌의 유일한 멀티팀 실행 통로 (결정론 코드)
# 사용법: orchestrate.sh "<spec.md>:<team.yaml>" ["<spec.md>:<team.yaml>" ...]
#         팀 생략 시(":<team>" 없음) docs 팀. 각 쌍은 team-pipeline.sh로 병렬 실행된다.
# 출력: 취합 JSON 한 줄 { ok, jobs: [런 결과...], durationMs }
# 전제: 쌍들의 팀 도메인이 서로 겹치지 않아야 한다 (diff·커밋이 도메인 스코프라 안전)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $# -ge 1 ]] || { echo '{"ok":false,"error":"usage: orchestrate.sh \"<spec>:<team>\" ..."}'; exit 1; }

# Phase 4 가드: low 티어(2계층)는 커밋 스코프가 전역(add -A)이라 병렬 fan-out 금지
if [[ $# -gt 1 ]]; then
  for pair in "$@"; do
    s="${pair%%:*}"; t="${pair#*:}"; [[ "$t" == "$pair" ]] && t="$here/teams/docs.yaml"
    r="$(DRY_RUN=1 "$here/build.sh" "$s" "$t" 2>/dev/null | jq -r '.risk // empty' || true)"
    if [[ -z "$r" ]]; then
      echo "{\"ok\":false,\"error\":\"pre-flight risk check failed for $s — reproduce with: DRY_RUN=1 factory/build.sh $s $t\"}"
      exit 1
    fi
    if [[ "$r" == "low" ]]; then
      echo "{\"ok\":false,\"error\":\"low-risk spec cannot join a parallel fan-out (global commit scope): $s\"}"
      exit 1
    fi
  done
fi

ts="$(date +%Y%m%d-%H%M%S)"
start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

pids=()
outs=()
specs=()
i=0
for pair in "$@"; do
  spec="${pair%%:*}"
  team="${pair#*:}"
  [[ "$team" == "$pair" ]] && team="$here/teams/docs.yaml"
  out="$here/logs/$ts-orchestrate-$i.json"
  # Phase 4: 티어 디스패처 경유 — 스펙의 risk 선언이 파이프라인을 고른다.
  # 주의: low 티어(2계층)는 커밋 스코프가 전역(add -A)이라 병렬 fan-out에 섞으면 안 된다.
  "$here/build.sh" "$spec" "$team" > "$out" 2>"$out.err" &
  pids+=($!)
  outs+=("$out")
  specs+=("$spec")
  i=$((i + 1))
done

overall=true
results="[]"
for idx in "${!pids[@]}"; do
  rc=0
  wait "${pids[$idx]}" || rc=$?
  [[ $rc -ne 0 ]] && overall=false
  j="$(tail -1 "${outs[$idx]}" 2>/dev/null || true)"
  jq -e . >/dev/null 2>&1 <<< "$j" || j="{\"ok\":false,\"error\":\"no valid output (see ${outs[$idx]}.err)\",\"spec\":\"${specs[$idx]}\"}"
  results="$(jq -c --argjson r "$j" '. + [$r]' <<< "$results")"
done

end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
jq -cn \
  --argjson ok "$overall" --argjson jobs "$results" \
  --argjson wall "$((end_ms - start_ms))" --arg ts "$ts" \
  '{ok: $ok, ts: $ts, jobs: ($jobs | map({spec, team, ok, attempts, verdict, error, durationMs})), durationMs: $wall}'
[[ "$overall" == "true" ]]
