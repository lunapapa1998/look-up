#!/usr/bin/env bash
# 공장 관전 대시보드 (= just watch) — tmux 4분할로 진행 중인 런을 실시간 관찰한다.
#   ┌─────────────────┬─────────────────┐
#   │ ① 스펙 체크박스  │ ② usage 원장     │   ① 리드가 갱신하는 진행률 바
#   ├─────────────────┼─────────────────┤   ② 콜 1건 끝날 때마다 한 줄
#   │ ③ 최신 세션 로그 │ ④ 프로세스·런    │   ③ codex는 스트리밍이라 거의 실시간
#   └─────────────────┴─────────────────┘   ④ 떠 있는 역할 + 런 결과
# 사용법: watch.sh [스펙파일]  — 스펙 생략 시 specs/에서 최근 수정 파일 자동 추적
# 참고: macOS에 watch(1)가 없어 sh 루프로 갱신한다 (2초 주기).
set -euo pipefail

command -v tmux >/dev/null || { echo "tmux가 필요합니다: brew install tmux"; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
spec="${1:-}"
session="factory-$(basename "$root")"

if tmux has-session -t "$session" 2>/dev/null; then
  exec tmux attach -t "$session"
fi

loop() { printf 'while true; do clear; %s; sleep 2; done' "$1"; }

# ① 스펙 체크박스: 지정 스펙 또는 최근 수정 스펙의 Phases 구역
if [[ -n "$spec" ]]; then
  pane_spec="$(loop "echo '== $spec'; awk '/^## Phases/,/^## Validation/' '$spec' | tail -28")"
else
  pane_spec="$(loop "f=\$(ls -t '$root'/specs/[0-9]*.md 2>/dev/null | head -1); echo \"== \$f\"; awk '/^## Phases/,/^## Validation/' \"\$f\" 2>/dev/null | tail -28")"
fi

# ② usage 원장: 콜 완료마다 append되는 줄
pane_usage="touch '$here/logs/usage-ledger.jsonl'; tail -n 8 -f '$here/logs/usage-ledger.jsonl'"

# ③ 최신 세션 로그 꼬리 (매 주기 최신 파일 재선택 — codex/agy는 진행 중에도 자람)
pane_log="$(loop "f=\$(ls -t '$here'/logs/*-*-*.json 2>/dev/null | head -1); echo \"== \$f\"; tail -c 900 \"\$f\" 2>/dev/null")"

# ④ 떠 있는 세션 프로세스 + 최근 런 결과
pane_ps="$(loop "echo '[프로세스]'; ps aux | grep -E 'claude -p|codex exec|agy -p|team-pipeline|orchestrate' | grep -v grep | awk '{print \$2, \$11, \$12}' | head -8; echo; echo '[최근 런]'; tail -3 '$here/logs/run-ledger.jsonl' 2>/dev/null | jq -c '{spec, team, ok, attempts, verdict}' 2>/dev/null")"

tmux new-session -d -s "$session" "$pane_spec"
tmux split-window -h -t "$session" "$pane_usage"
tmux split-window -v -t "$session:0.0" "$pane_log"
tmux split-window -v -t "$session:0.2" "$pane_ps"
tmux select-pane -t "$session:0.0"

# 터미널에서 직접 실행했으면 attach, 아니면(스크립트/CI) 세션만 만들어 둠
if [[ -t 0 ]]; then
  exec tmux attach -t "$session"
else
  echo "tmux 세션 생성됨: tmux attach -t $session"
fi
