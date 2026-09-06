#!/usr/bin/env bash
# Resident team launcher (lane 2) — executes the BRAIN's decisions, it does not decide.
#   The brain (LLM orchestrator) classifies the request and chooses teams, mode, and
#   worker budget, then passes them explicitly. This script only applies presets:
#   start the requested resident panes, hand the goal to each team lead, then follow.
#   Routing judgment does NOT live here — bash keyword matching proved structurally
#   too weak ("modern" matched *rn* -> react-native team, 2026-07-07 review).
#   A "light" request should be handled by the brain directly: just don't call this.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
mux="$root/factory/mux/${FACTORY_MUX:-tmux}.sh"

goal="${1:?usage: resident-start.sh <goal> <team.yaml[,team.yaml...]> [max_workers] [mode]}"
team_arg="${2:?team required — the brain chooses teams; pass factory/teams/<team>.yaml[,<team2>.yaml]}"
max_workers_arg="${3:-}"
mode_arg="${4:-${RESIDENT_MODE:-standard}}"

add_unique_team() {
  local candidate="$1" existing
  for existing in "${chosen_teams[@]:-}"; do
    [[ "$existing" == "$candidate" ]] && return
  done
  chosen_teams+=("$candidate")
}

# 팀 목록 파싱: 명시 인자만 받는다 (쉼표 구분, 공백 트림, 중복 제거)
parse_teams() {
  local raw
  chosen_teams=()
  IFS=',' read -ra requested_teams <<< "$team_arg"
  for raw in "${requested_teams[@]}"; do
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    [[ -n "$raw" ]] && add_unique_team "$raw"
  done
  [[ ${#chosen_teams[@]} -gt 0 ]] || { echo "no valid team in: $team_arg" >&2; exit 1; }
}

resolve_team_file() {
  local team="$1"
  [[ -f "$team" ]] || team="$root/$team"
  [[ -f "$team" ]] || { echo "team not found: $team" >&2; exit 1; }
  printf '%s' "$team"
}

default_worker_budget() {
  local mode="$1" team_name="$2"
  case "$mode:$team_name" in
    full:docs) printf '4' ;;
    full:qa) printf '3' ;;
    full:*) printf '3' ;;
    standard:qa) printf '1' ;;
    standard:*) printf '1' ;;
    light:*) printf '0' ;;
  esac
}

roles_for_mode() {
  case "$1" in
    full) printf 'lead scout verifier' ;;
    standard) printf 'lead verifier' ;;
    light) printf 'lead' ;;
  esac
}

mode="$mode_arg"
case "$mode" in
  light|standard|full) ;;
  *) echo "unknown resident mode: $mode (expected light, standard, or full)" >&2; exit 1 ;;
esac

parse_teams

team_files=()
team_names=()
worker_budgets=()
worker_lists=()
role_lists=()
state_names=()

for team_candidate in "${chosen_teams[@]}"; do
  team_file="$(resolve_team_file "$team_candidate")"
  cfg="$(python3 "$here/teamcfg.py" "$team_file")"
  team_name="$(jq -r '.name' <<< "$cfg")"
  team_files+=("$team_file")
  team_names+=("$team_name")

  max_workers="$max_workers_arg"
  [[ -n "$max_workers" ]] || max_workers="$(default_worker_budget "$mode" "$team_name")"
  [[ "$max_workers" =~ ^[0-9]+$ ]] || { echo "max_workers must be a non-negative integer: $max_workers" >&2; exit 1; }
  worker_budgets+=("$max_workers")

  worker_names=()
  if (( max_workers > 0 )); then
    for i in $(seq 1 "$max_workers"); do
      worker_names+=("${team_name}-worker-${i}")
    done
  fi
  worker_list=""
  if (( ${#worker_names[@]} > 0 )); then
    worker_list="$(printf '%s ' "${worker_names[@]}")"
    worker_list="${worker_list% }"
  fi
  worker_lists+=("$worker_list")
  role_lists+=("$(roles_for_mode "$mode")")
done

multi_team=no
if (( ${#team_files[@]} > 1 )); then
  multi_team=yes
fi

for i in "${!team_files[@]}"; do
  state=""
  if [[ "$multi_team" == "yes" || "${RESIDENT_STATE_PER_TEAM:-0}" == "1" ]]; then
    state="${team_names[$i]}"
  fi
  state_names+=("$state")

  scout_available=no
  verifier_available=no
  case " ${role_lists[$i]} " in *" scout "*) scout_available=yes ;; esac
  case " ${role_lists[$i]} " in *" verifier "*) verifier_available=yes ;; esac
  echo "resident plan: mode=$mode team=${team_names[$i]} state=${state:-default} maxWorkers=${worker_budgets[$i]} optionalWorkers=[${worker_lists[$i]}] scout=$scout_available verifier=$verifier_available roles=[${role_lists[$i]}]"
done

if [[ "${RESIDENT_PLAN_ONLY:-0}" == "1" ]]; then
  exit 0
fi

for i in "${!team_files[@]}"; do
  scout_available=no
  verifier_available=no
  case " ${role_lists[$i]} " in *" scout "*) scout_available=yes ;; esac
  case " ${role_lists[$i]} " in *" verifier "*) verifier_available=yes ;; esac

  env_args=()
  [[ -n "${state_names[$i]}" ]] && env_args=(env FACTORY_TEAM_STATE="${state_names[$i]}")
  ${env_args[@]+"${env_args[@]}"} "$mux" up "${team_files[$i]}" ${role_lists[$i]}

  state_dir=".team"
  [[ -n "${state_names[$i]}" ]] && state_dir=".team/${state_names[$i]}"
  lead_task="Goal: ${goal}. Orchestrator decision: mode ${mode}; assigned team ${team_names[$i]}; all assigned teams: ${team_names[*]}; team state directory ${state_dir}; worker budget max ${worker_budgets[$i]}; scout=${scout_available}; verifier=${verifier_available}. First read ${state_dir}/roster.json, then the team board ${state_dir}/shared.md — resume from the board if it already reflects this goal, otherwise rewrite it fresh and keep it current at every transition. Inspect only your team's domain and choose the simplest sufficient execution path. Your primary job as lead is coordination: decompose work, delegate substantive investigation/implementation to workers when the task is not trivial, answer worker questions, reconcile results, and verify/integrate the final output. You may use zero workers only when this is genuinely lead-only or very small work."
  if (( worker_budgets[$i] > 0 )); then
    lead_task+=" If parallel work is useful, add only the workers you need with just team-add ${worker_lists[$i]}; use fewer workers than the budget when appropriate. In full mode, prefer worker fan-out for substantive reading/building instead of doing that work yourself. Fan out independent work to the workers you add, wait for each worker using its exact role name, and reconcile results."
  fi
  if [[ "$scout_available" == "yes" ]]; then
    lead_task+=" Ask scout for a compact investigation only if it will reduce risk or avoid duplicate reading."
  fi
  lead_task+=" Run just check when files changed or before final delivery."
  if [[ "$verifier_available" == "yes" ]]; then
    lead_task+=" Ask verifier to verify meaningful deliverables before final delivery."
  fi
  lead_task+=" Then finish with your standard completion line."

  ${env_args[@]+"${env_args[@]}"} "$mux" send lead "$lead_task"
done

if [[ "${RESIDENT_FOLLOW:-1}" == "1" ]]; then
  for i in "${!team_files[@]}"; do
    env_args=()
    [[ -n "${state_names[$i]}" ]] && env_args=(env FACTORY_TEAM_STATE="${state_names[$i]}")
    ${env_args[@]+"${env_args[@]}"} "$root/factory/resident-follow.sh" "${RESIDENT_FOLLOW_TIMEOUT:-1800}" "${RESIDENT_REPORT_LINES:-100}"
  done
else
  echo "resident dispatched: follow later with just resident-follow"
fi
