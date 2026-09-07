#!/usr/bin/env bash
# Provider Adapter v0 dispatcher — spawn 계약의 진입점
# 사용법: spawn.sh <adapter: claude|codex|agy> <role> "<prompt>"
# 출력: 정규화 JSON 한 줄 { ok, adapter, role, result, sessionLog, sessionId, usage, durationMs[, rotatedFrom] }
# 옵션(환경변수): MODEL, ALLOWED_TOOLS(claude), SANDBOX(codex), APPROVAL_MODE(gemini)
#   FALLBACKS="adapter2 adapter3" — 1차 어댑터 실패(비정상 종료 또는 ok:false) 시
#   순서대로 재시도 (Phase 4: 레이트리밋 폴백 로테이션). 폴백 어댑터는 MODEL을
#   상속하지 않는다 (claude용 sonnet이 codex로 새면 400 — 2026-07-05 실측 함정).
#   주의: 로테이션은 "레이트리밋"만 골라내지 않고 모든 실패에 반응한다(v0 트레이드오프).
#   실패 원인은 각 시도의 sessionLog와 usage-ledger(ok:false 줄)로 추적한다.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
adapter="${1:?usage: spawn.sh <adapter> <role> <prompt>}"
role="${2:?role required}"
prompt="${3:?prompt required}"

mkdir -p "$here/logs"

# 전역 원장 (멀티 프로젝트 윈도우노믹스): 구독 윈도우는 계정 단위인데 원장이 리포별로
# 쪼개지면 집계가 불완전해진다 → 프로젝트 필드를 붙여 ~/.factory/에도 이중 기록한다.
global_dir="${FACTORY_GLOBAL_DIR:-$HOME/.factory}"
project="$(basename "$(dirname "$here")")"
mkdir -p "$global_dir" 2>/dev/null || true
ledger_append() {  # $1 = usage 요약 JSON 한 줄
  printf '%s\n' "$1" >> "$here/logs/usage-ledger.jsonl"
  # 전역 기록은 best-effort: 샌드박스 안(예: codex 리드가 멤버 스폰)에서는 $HOME 쓰기가
  # 막힐 수 있고, 그때 set -e로 스폰 전체가 죽으면 안 된다 (2026-07-15 실측). 로컬 원장이 원본.
  jq -c --arg project "$project" '. + {project: $project}' <<< "$1" 2>/dev/null >> "$global_dir/usage-ledger.jsonl" || true
}

chain=("$adapter")
if [[ -n "${FALLBACKS:-}" ]]; then
  read -ra _fb <<< "$FALLBACKS"
  chain+=(${_fb[@]+"${_fb[@]}"})
fi

rotated="[]"   # 이번 호출에서 실패해 건너뛴 어댑터들
out=""
ok=false
last_err="adapter failed"

for a in "${chain[@]}"; do
  if [[ ! -x "$here/adapters/$a.sh" ]]; then
    last_err="unknown adapter: $a"
    rotated="$(jq -c --arg a "$a" '. + [$a]' <<< "$rotated")"
    continue
  fi

  ts="$(date +%Y%m%d-%H%M%S)"
  export LOG_FILE="$here/logs/$ts-$a-$role.json"
  start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  rc=0
  if [[ "$a" == "$adapter" ]]; then
    out="$("$here/adapters/$a.sh" "$role" "$prompt")" || rc=$?
  else
    # 폴백은 MODEL·RESUME_SESSION을 상속하지 않는다 — 다른 어댑터의 모델명/세션 id는 무효 (R0)
    out="$(env -u MODEL -u RESUME_SESSION "$here/adapters/$a.sh" "$role" "$prompt")" || rc=$?
  fi
  end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  wall=$((end_ms - start_ms))

  if [[ $rc -eq 0 ]] && jq -e '.ok == true' >/dev/null 2>&1 <<< "$out"; then
    ok=true
  else
    # 실패한 시도도 원장에 남긴다 (레이트리밋 관찰의 기반)
    ledger_append "$(jq -cn --arg ts "$ts" --arg adapter "$a" --arg role "$role" --argjson wall "$wall" \
      '{ts: $ts, adapter: $adapter, role: $role, ok: false, usage: null, durationMs: $wall}')"
    rotated="$(jq -c --arg a "$a" '. + [$a]' <<< "$rotated")"
    last_err="adapter failed: $a (exit $rc, log: $LOG_FILE)"
    continue
  fi

  # durationMs가 비어 있으면 dispatcher가 측정한 벽시계 시간으로 채움
  out="$(jq -c --argjson wall "$wall" --argjson rot "$rotated" \
    '.durationMs //= $wall | if ($rot | length) > 0 then . + {rotatedFrom: $rot} else . end' <<< "$out")"

  # 옵저버빌리티 최소 단위: 호출 1건당 요약 한 줄을 usage 원장에 누적
  ledger_append "$(jq -c --arg ts "$ts" '{ts: $ts} + {adapter, role, ok, usage, durationMs, rotatedFrom}
    | if .rotatedFrom == null then del(.rotatedFrom) else . end' <<< "$out")"
  break
done

if [[ "$ok" != "true" ]]; then
  jq -cn --arg adapter "$adapter" --arg role "$role" --arg err "$last_err" --argjson rot "$rotated" \
    '{ok: false, adapter: $adapter, role: $role, error: $err}
     | if ($rot | length) > 0 then . + {rotatedFrom: $rot} else . end'
  exit 1
fi

printf '%s\n' "$out"
