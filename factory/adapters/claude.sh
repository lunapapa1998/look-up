#!/usr/bin/env bash
# Provider Adapter: claude (Claude 구독, OAuth)
# 입력: $1=role $2=prompt / 환경: MODEL(기본 sonnet), ALLOWED_TOOLS, LOG_FILE
# 출력: stdout에 정규화 JSON 한 줄 {result, sessionLog, usage, ...}
set -euo pipefail

role="$1"; prompt="$2"
model="${MODEL:-sonnet}"
# 멤버 기본 도구 화이트리스트 (damage control): 쓰기성 bash 금지
allowed="${ALLOWED_TOOLS:-Read Grep Glob}"
log="${LOG_FILE:?LOG_FILE required}"

# ALLOWED_TOOLS 쉼표 구분 지원: `Bash(just member-build:*)`처럼 공백을 포함하는
# 패턴은 쉼표로 구분해야 한다 (공백 구분은 패턴이 쪼개짐). 쉼표가 없으면 기존 공백 구분.
if [[ "$allowed" == *,* ]]; then
  IFS=',' read -ra allowed_arr <<< "$allowed"
else
  read -ra allowed_arr <<< "$allowed"
fi

# 구독 OAuth 보장: API 키가 있으면 OAuth를 덮어써 API 과금됨 (roadmap 결정 사항)
# --permission-mode default 강제: 유저 전역 설정이 bypassPermissions면 allowedTools
# 가드가 통째로 무효가 된다 (2026-07-05 실측). 공장 스폰은 항상 최소 권한.
# 진단 캡처 (2026-07-07): CLI 비정상 종료라도 원인을 보존한다. 과거엔 set -e 가
# raw="$(...)" 실패에서 곧장 죽어 line "printf > log" 전에 원인 텍스트를 유실했다
# (--output-format json 은 에러도 stdout JSON 으로 냄). rc 를 잡고 stderr 는 .err
# 사이드카로, stdout 은 항상 로그로 기록해 재발 시 진단(429/타임아웃/turns)이 가능하게 한다.
rc=0
raw="$(env -u ANTHROPIC_API_KEY claude -p "$prompt" \
  --output-format json \
  --model "$model" \
  --permission-mode default \
  --allowedTools "${allowed_arr[@]}" \
  --append-system-prompt "You are acting as role: ${role}. Do only the assigned task." \
  </dev/null 2>"${log}.err")" || rc=$?

printf '%s\n' "$raw" > "$log"

# CLI 비정상 종료 또는 파싱 불가 → 로그·사이드카를 남긴 채 진단 가능한 ok:false 방출
if [[ $rc -ne 0 ]] || ! jq -e . >/dev/null 2>&1 <<< "$raw"; then
  err_text="$(tail -c 2000 "${log}.err" 2>/dev/null || true)"
  jq -cn --arg adapter claude --arg role "$role" --arg log "$log" --argjson rc "$rc" \
    --arg err "$err_text" --arg raw "$(printf '%s' "$raw" | tail -c 2000)" \
    '{ok: false, adapter: $adapter, role: $role,
      error: ("claude cli exit \($rc)" + (if $err != "" then ": \($err)" elif $raw != "" then ": \($raw)" else "" end)),
      sessionLog: $log}'
  exit 1
fi
[[ -s "${log}.err" ]] || rm -f "${log}.err"   # 성공 시 빈 사이드카는 정리

jq -c --arg adapter claude --arg role "$role" --arg log "$log" '{
  ok: (.is_error == false),
  adapter: $adapter, role: $role,
  result: .result,
  sessionLog: $log, sessionId: .session_id,
  usage: { input: .usage.input_tokens, output: .usage.output_tokens,
           cacheRead: .usage.cache_read_input_tokens, cacheWrite: .usage.cache_creation_input_tokens },
  durationMs: .duration_ms
}' <<< "$raw"
