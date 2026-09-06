#!/usr/bin/env bash
# Provider Adapter: codex (ChatGPT 구독)
# 입력: $1=role $2=prompt / 환경: MODEL(선택), SANDBOX(기본 read-only), LOG_FILE,
#   RESUME_SESSION(선택, R0) — 이전 codex 세션 id(UUID)를 주면 exec resume으로 컨텍스트를 이어간다
# 출력: stdout에 정규화 JSON 한 줄 {result, sessionLog, usage, ...}
set -euo pipefail

role="$1"; prompt="$2"
sandbox="${SANDBOX:-read-only}"   # damage control: 기본 읽기 전용
log="${LOG_FILE:?LOG_FILE required}"

model_args=()
[[ -n "${MODEL:-}" ]] && model_args=(-m "$MODEL")

full_prompt="Role: ${role}. Do only the assigned task.

${prompt}"

# --skip-git-repo-check: cwd가 git 밖(스크래치 테스트 등)이어도 동작하도록 유지 / </dev/null: stdin 대기 방지
if [[ -n "${RESUME_SESSION:-}" ]]; then
  # R0 세션 재개: exec resume에는 --sandbox 플래그가 없어 -c sandbox_mode로 강제 (damage control 유지)
  codex exec resume "$RESUME_SESSION" -c "sandbox_mode=\"$sandbox\"" --skip-git-repo-check --json \
    ${model_args[@]+"${model_args[@]}"} "$full_prompt" </dev/null > "$log" 2>/dev/null
else
  codex exec --sandbox "$sandbox" --skip-git-repo-check --json ${model_args[@]+"${model_args[@]}"} \
    "$full_prompt" </dev/null > "$log" 2>/dev/null
fi

jq -cs --arg adapter codex --arg role "$role" --arg log "$log" --arg resume "${RESUME_SESSION:-}" '
  (map(select(.type == "item.completed" and .item.type == "agent_message")) | last) as $msg |
  (map(select(.type == "turn.completed")) | last) as $turn |
  {
    ok: ($msg != null and $turn != null),
    adapter: $adapter, role: $role,
    result: ($msg.item.text // null),
    sessionLog: $log,
    sessionId: ((map(select(.type == "thread.started")) | last | .thread_id)
                // (if $resume != "" then $resume else null end)),
    usage: { input: $turn.usage.input_tokens, output: $turn.usage.output_tokens,
             cacheRead: $turn.usage.cached_input_tokens },
    durationMs: null
  }
  | if $resume != "" then . + {resumedFrom: $resume} else . end' "$log"
