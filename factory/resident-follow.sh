#!/usr/bin/env bash
# Follow a resident team until the lead writes its durable completion signal, then
# print a compact handoff report for the outer orchestrator/user.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
teamdir="$root/.team"
timeout="${1:-${RESIDENT_FOLLOW_TIMEOUT:-1800}}"
lines="${2:-${RESIDENT_REPORT_LINES:-100}}"
mux="$root/factory/mux/${FACTORY_MUX:-tmux}.sh"
state="${FACTORY_TEAM_STATE:-}"
if [[ -n "$state" ]]; then
  [[ "$state" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "invalid FACTORY_TEAM_STATE: $state" >&2; exit 1; }
  teamdir="$root/.team/$state"
fi
# 빈 배열은 반드시 ${arr[@]+...} 관용구로 확장한다 — macOS bash 3.2에서 빈 배열 +
# set -u는 unbound variable 크래시 (Phase 0 실측 함정의 재발 방지, spawn.sh와 동일)
mux_env=()
[[ -n "$state" ]] && mux_env=(env FACTORY_TEAM_STATE="$state")

echo "resident follow: team=${state:-default} waiting for lead completion (timeout=${timeout}s)"
lead_done="$(${mux_env[@]+"${mux_env[@]}"} "$mux" wait lead "DONE: lead" "$timeout")"

echo
echo "resident result: $lead_done"

verifier_present=no
verdict_word=NONE
if [[ -f "$teamdir/roster.json" ]]; then
  if jq -e '.roles.verifier != null' "$teamdir/roster.json" >/dev/null; then
    verifier_present=yes
    verdict="$(${mux_env[@]+"${mux_env[@]}"} "$mux" read verifier 200 2>/dev/null | grep -E 'VERDICT: (PASS|FAIL)' | tail -1 || true)"
    if [[ -n "$verdict" ]]; then
      echo "resident verifier: $verdict"
      case "$verdict" in *PASS*) verdict_word=PASS ;; *FAIL*) verdict_word=FAIL ;; *) verdict_word=UNKNOWN ;; esac
    else
      verdict_word=UNKNOWN
    fi
  fi
fi

# ── 런 원장 기록 (레인 2 — run-ledger는 레인 1과 공유, lane 필드로 구분) ────────────
# 사용자 결정(2026-07-08): 상주 런도 같은 run-ledger.jsonl에 기록해 `just runs`·전역
# 윈도우노믹스에서 두 레인 완주를 한 곳에서 본다. 상주 리드는 내부적으로 재시도하므로
# attempts는 항상 1(파이프라인 재시도 개념 없음). ok = 리드 DONE ∧ (verifier 없음 ∨ PASS).
# v0 한계: resident-follow는 "DONE: lead" 신호에만 도달하므로 BLOCKED로 끝난 리드는
# wait 타임아웃으로 여기까지 오지 않는다 — 원장은 완주 런만 남긴다.
if [[ "${RESIDENT_LEDGER:-1}" == "1" ]]; then
  lead_ok=false
  [[ "$lead_done" == *"DONE: lead"* ]] && lead_ok=true
  run_ok=false
  if [[ "$lead_ok" == true ]]; then
    if [[ "$verifier_present" == no || "$verdict_word" == PASS ]]; then run_ok=true; fi
  fi
  team_name="$(jq -r '.team // "unknown"' "$teamdir/roster.json" 2>/dev/null | xargs -I{} basename {} .yaml 2>/dev/null || echo unknown)"
  summary="${lead_done#*| }"
  entry="$(jq -cn \
    --argjson ok "$run_ok" --arg ts "$(date +%Y%m%d-%H%M%S)" \
    --arg spec "resident:${state:-default}" --arg team "$team_name" \
    --arg verdict "$verdict_word" --arg verifier "$verifier_present" \
    --arg summary "$summary" \
    '{ok: $ok, ts: $ts, spec: $spec, team: $team, lane: "resident", attempts: 1,
      validation: null, verdict: $verdict, verifier: $verifier, salvaged: false,
      summary: $summary, durationMs: null}')"
  mkdir -p "$root/factory/logs"   # spawn.sh를 거치지 않는 상주 레인 — logs 디렉토리 자체 보장
  printf '%s\n' "$entry" >> "$root/factory/logs/run-ledger.jsonl"
  global_dir="${FACTORY_GLOBAL_DIR:-$HOME/.factory}"
  mkdir -p "$global_dir"
  jq -c --arg project "$(basename "$root")" '. + {project: $project}' <<< "$entry" >> "$global_dir/run-ledger.jsonl"
  echo "resident ledger: ok=$run_ok team=$team_name verdict=$verdict_word lane=resident"
fi

echo
echo "resident lead report:"
${mux_env[@]+"${mux_env[@]}"} "$mux" read lead "$lines"
