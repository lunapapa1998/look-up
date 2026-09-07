#!/usr/bin/env bash
# Provider Adapter: agy (Antigravity CLI — Antigravity 구독. 구 gemini CLI 대체)
# 입력: $1=role $2=prompt / 환경: MODEL(기본 Gemini 3.6 Flash (Low)), LOG_FILE
# 출력: stdout에 정규화 JSON 한 줄 {result, sessionLog, usage, ...}
# 참고: agy -p는 JSON 출력이 없어 usage는 null (옵저버빌리티는 벽시계 시간만)
set -euo pipefail

role="$1"; prompt="$2"
model="${MODEL:-Gemini 3.6 Flash (Low)}"
log="${LOG_FILE:?LOG_FILE required}"

# damage control: --sandbox = 터미널 제한 모드
agy -p "Role: ${role}. Do only the assigned task.

${prompt}" \
  --model "$model" --sandbox </dev/null > "$log" 2>&1

jq -cn --arg adapter agy --arg role "$role" --arg log "$log" \
  --arg model "$model" --rawfile result "$log" '{
  ok: ($result | length > 0),
  adapter: $adapter, role: $role,
  result: ($result | rtrimstr("\n")),
  sessionLog: $log, sessionId: null,
  model: $model,
  usage: null,
  durationMs: null
}'
