#!/usr/bin/env bash
# Provider Adapter: codex (ChatGPT 구독)
# 입력: $1=role $2=prompt / 환경: MODEL(선택), REASONING_EFFORT(선택), SANDBOX(기본 read-only), LOG_FILE,
#   RESUME_SESSION(선택, R0) — 이전 codex 세션 id(UUID)를 주면 exec resume으로 컨텍스트를 이어간다
# 출력: stdout에 정규화 JSON 한 줄 {result, sessionLog, usage, ...}
set -euo pipefail

role="$1"; prompt="$2"
sandbox="${SANDBOX:-read-only}"   # damage control: 기본 읽기 전용
log="${LOG_FILE:?LOG_FILE required}"

# macOS seatbelt는 중첩 불가 — 리드 샌드박스 안에서 스폰된 자식 codex가 자기 seatbelt를
# 적용하려 하면 sandbox_apply: Operation not permitted로 모든 명령이 죽는다 (2026-07-15 실측).
# 프로브로 감지되면 자식은 seatbelt 없이 실행하되, 바깥 리드 seatbelt가 계속 격리를 제공한다.
if [[ "$sandbox" != "danger-full-access" ]] && command -v sandbox-exec >/dev/null 2>&1 \
   && ! sandbox-exec -p '(version 1)(allow default)' /usr/bin/true 2>/dev/null; then
  sandbox="danger-full-access"
fi

model_args=()
[[ -n "${MODEL:-}" ]] && model_args=(-m "$MODEL")
reasoning_args=()
[[ -n "${REASONING_EFFORT:-}" ]] && reasoning_args=(-c "model_reasoning_effort=\"$REASONING_EFFORT\"")
# workspace-write 리드는 멤버를 중첩 스폰한다(just member-build → spawn.sh → 자식 CLI).
# 기본 seatbelt는 자식 CLI의 API 네트워크와 벤더 상태 디렉토리(~/.codex, ~/.claude)·전역
# 원장(~/.factory) 쓰기를 막아 위임이 전멸한다 (2026-07-15 spec 031 런 3회 실측, 중첩 테스트로
# network+writable_roots 개방 시 정상 확인). 멤버 자신의 샌드박스는 그대로 유지된다.
sandbox_args=()
if [[ "$sandbox" == "workspace-write" ]]; then
  global_dir="${FACTORY_GLOBAL_DIR:-$HOME/.factory}"
  sandbox_args=(
    -c "sandbox_workspace_write.writable_roots=[\"$global_dir\",\"$HOME/.codex\",\"$HOME/.claude\",\"$HOME/.claude.json\"]"
    -c "sandbox_workspace_write.network_access=true"
  )
fi

full_prompt="Role: ${role}. Do only the assigned task.

${prompt}"

# --skip-git-repo-check: cwd가 git 밖(스크래치 테스트 등)이어도 동작하도록 유지 / </dev/null: stdin 대기 방지
if [[ -n "${RESUME_SESSION:-}" ]]; then
  # R0 세션 재개: exec resume에는 --sandbox 플래그가 없어 -c sandbox_mode로 강제 (damage control 유지)
  codex exec resume "$RESUME_SESSION" -c "sandbox_mode=\"$sandbox\"" --skip-git-repo-check --json \
    ${model_args[@]+"${model_args[@]}"} ${reasoning_args[@]+"${reasoning_args[@]}"} \
    ${sandbox_args[@]+"${sandbox_args[@]}"} \
    "$full_prompt" </dev/null > "$log" 2>/dev/null
else
  codex exec --sandbox "$sandbox" --skip-git-repo-check --json ${model_args[@]+"${model_args[@]}"} \
    ${reasoning_args[@]+"${reasoning_args[@]}"} \
    ${sandbox_args[@]+"${sandbox_args[@]}"} \
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
