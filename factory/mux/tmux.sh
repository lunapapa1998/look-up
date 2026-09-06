#!/usr/bin/env bash
# mux 어댑터: tmux — 상주 팀 모드(레인 2)의 5동사 구현 (설계: docs/14-resident-team-mode-design.md §3~5)
# 사용법:
#   tmux.sh up <team.yaml> [role ...]          # 팀 pane 일괄 기동 (기본: lead member; names containing worker = member aliases)
#   tmux.sh add <role ...>                     # 기존 팀 세션에 worker/scout/verifier pane 추가
#   tmux.sh send <role> "<text>"               # 단일 라인 주입 + 제출 (개행은 공백으로 평탄화)
#   tmux.sh read <role> [lines]                # pane 화면 캡처 (기본 40줄)
#   tmux.sh wait <role> "<pattern>" [timeout]  # 완료 대기 (기본 900초, 2초 폴링) — 파일 신호 우선, 화면 폴백
#   tmux.sh down                               # 세션 철거 (미러 로그 .team/panes/는 보존)
# 규약: roster=.team/roster.json / 미러=.team/panes/<role>.log / 역할 프롬프트=.team/prompts/<role>.md
#       팀 보드=.team/shared.md (리드 단일 writer — R4) / 태스크 패킷=.team/tasks/<id>-<role>.md
#       워커 보고=.team/results/<id>-<role>.md (역할·태스크별 파일 = 파일당 writer 1개, 동시 쓰기 없음)
#       완료 신호=.team/signals/<role>-done (R3: claude 역할이 완료 라인을 파일로도 씀 — durable,
#       에코 오탐·렌더링 공백 유실이 구조적으로 없음. send가 디스패치 시 직전 신호를 소진)
# 센티널 에코 함정: 채팅으로 보내는 메시지에 센티널 리터럴("DONE: <role>")을 넣으면 입력 에코가
#   미러 로그에 남아 wait가 오탐한다 — 센티널 정의는 프롬프트 파일에만 두고 메시지에서는 우회 지칭.
# 배관 테스트: RESIDENT_DRY=1 up ... → 에이전트 CLI 대신 bash pane (LLM 비용 0)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$(dirname "$here")")"
state="${FACTORY_TEAM_STATE:-}"
if [[ -n "$state" && ! "$state" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "invalid FACTORY_TEAM_STATE: $state" >&2
  exit 1
fi
teamdir="$root/.team"
[[ -n "$state" ]] && teamdir="$root/.team/$state"
roster="$teamdir/roster.json"
verb="${1:?usage: tmux.sh <up|add|send|read|wait|down> ...}"; shift

strip_ansi() { perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g; s/\e\][^\a]*(\a|\e\\)//g; s/\r//g'; }

role_kind() {
  case "$1" in
    lead|member|scout|verifier) printf '%s' "$1" ;;
    *worker*) printf 'member' ;;
    *) echo "unknown role: $1 (lead|member|scout|verifier|*worker*)" >&2; exit 1;;
  esac
}

lead_adapter() {
  printf '%s' "${RESIDENT_LEAD_ADAPTER:-$(jq -r '.roles.lead.adapter // "claude"' <<< "$cfg")}"
}

lead_model() {
  local adapter_name profile model
  adapter_name="$1"
  profile="${RESIDENT_LEAD_PROFILE:-standard}"
  model="$(jq -r --arg a "$adapter_name" --arg p "$profile" '.roles.lead.modelProfiles[$a][$p] // empty' <<< "$cfg")"
  if [[ -n "$model" ]]; then
    [[ "$model" == "inherit" ]] && model=""
    printf '%s' "$model"
    return
  fi
  [[ "$profile" != "standard" ]] && {
    echo "unknown lead model profile: adapter=$adapter_name profile=$profile" >&2
    exit 1
  }
  case "$adapter_name" in
    claude)
      model="${RESIDENT_LEAD_MODEL:-$(jq -r '.roles.lead.model // "sonnet"' <<< "$cfg")}"
      ;;
    codex)
      model="${RESIDENT_LEAD_MODEL:-gpt-5.5}"
      ;;
    pi)
      # pi has a different model namespace in common use; keep a separate override.
      model="${RESIDENT_PI_LEAD_MODEL:-openrouter/z-ai/glm-5.2}"
      ;;
    *)
      echo "unsupported RESIDENT_LEAD_ADAPTER: $adapter_name (claude|codex|pi)" >&2
      exit 1
      ;;
  esac
  printf '%s' "$model"
}

pane_of() {
  [[ -f "$roster" ]] || { echo "no roster ($roster) — run: just team-up" >&2; exit 1; }
  local p; p="$(jq -r --arg r "$1" '.roles[$r] // empty' "$roster")"
  [[ -n "$p" ]] || { echo "unknown role: $1 (roster: $(jq -c .roles "$roster"))" >&2; exit 1; }
  printf '%s' "$p"
}

load_team_context() {
  team="$1"
  [[ -f "$team" ]] || team="$root/$team"
  [[ -f "$team" ]] || { echo "team not found: $team" >&2; exit 1; }
  cfg="$(python3 "$root/factory/teamcfg.py" "$team")"
  team_name="$(jq -r '.name' <<< "$cfg")"
  session="factory-$team_name"
  domains="$(jq -r '[.domains[]?] | join(", ")' <<< "$cfg")"
}

# 역할 프롬프트 조립: 상주 템플릿 + (리드) appendix / (멤버/worker alias) 페르소나 + expertise + 팀 컨텍스트
# frontmatter 제거는 team-pipeline.sh lead_appendix_block과 동일 패턴
build_prompt() {
  local role="$1" kind out p
  kind="$(role_kind "$role")"
  out="$teamdir/prompts/$role.md"
  rel_teamdir="${teamdir#$root/}"
  {
    sed "s/__ROLE__/$role/g; s#\\.team/#$rel_teamdir/#g" "$root/factory/teams/prompts/${kind}-resident.md"
    if [[ "$kind" == lead ]]; then
      p="$(jq -r '.roles.lead.appendix // empty' <<< "$cfg")"
      [[ -n "$p" && -f "$root/$p" ]] && { echo; awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$root/$p"; }
    elif [[ "$kind" == member ]]; then
      p="$(jq -r '.roles.member.prompt // empty' <<< "$cfg")"
      [[ -n "$p" && -f "$root/$p" ]] && { echo; awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$root/$p"; }
    fi
    local exp; exp="$(python3 "$root/factory/expertise.py" load "$team_name" "$kind" 2>/dev/null || true)"
    [[ -n "$exp" ]] && printf '\nAccumulated team expertise for your role (lessons from past runs — apply them):\n%s\n' "$exp"
    printf '\nYour pane role name: %s\nRole kind: %s\nTeam file: %s\nTeam state directory: %s\nWritable member domains: %s\n' "$role" "$kind" "$team" "$rel_teamdir" "$domains"
  } > "$out"
}

# 역할별 기동 커맨드 — claude 상주 세션도 헤드리스와 같은 가드 원칙:
# --permission-mode default 필수(전역 bypassPermissions가 allowedTools를 무효화하는 함정, Phase 2 실측)
# R1 트레이드오프(설계 §6.4): 멤버 락은 태스크 단위가 아니라 세션 단위 — 팀 도메인 전체에 걸린다
boot_cmd() {
  local role="$1" kind m t d
  kind="$(role_kind "$role")"
  local state_env=""
  [[ -n "$state" ]] && state_env="$(printf 'FACTORY_TEAM_STATE=%q ' "$state")"
  if [[ "${RESIDENT_DRY:-0}" == "1" ]]; then printf '%sbash' "$state_env"; return; fi
  case "$kind" in
    lead)
      local adapter_name
      adapter_name="$(lead_adapter)"
      m="$(lead_model "$adapter_name")"
      case "$adapter_name" in
        claude)
          # RESIDENT_LEAD_MODEL/PROFILE: 실런/스모크에서 YAML 모델을 임시 하향하는 노브
          # .team/** 쓰기: shared.md 보드 + tasks/ 패킷 (R4 — 리드가 보드·패킷의 단일 writer)
          # BASH_*_TIMEOUT_MS: 리드의 `just team-wait`(기본 900초)가 Bash 도구 기본 2분에
          # 끊기지 않도록 배치 리드(team-pipeline.sh)와 동일하게 주입 — 16편 §7.5 갭 해소.
          # 트레이드오프: 긴 wait 블록 중엔 운영자 pane 입력이 큐잉만 된다 (프롬프트 규칙 4에
          # 중간 타임아웃 분할 호출 허용으로 개입 창을 열어둠)
          printf '%sBASH_DEFAULT_TIMEOUT_MS=600000 BASH_MAX_TIMEOUT_MS=900000 claude --permission-mode default --model %q --allowedTools %q' "$state_env" "$m" \
            "Read,Grep,Glob,Edit(specs/**),Edit(.team/**),Write(.team/**),Bash(just team-add:*),Bash(just team-send:*),Bash(just team-read:*),Bash(just team-wait:*),Bash(just check:*)"
          ;;
        codex)
          # Codex has sandbox-level controls, not Claude-style per-tool allowlists.
          # workspace-write is required for specs/.team updates and for driving just team-*;
          # lead-resident.md still forbids implementation edits, and verifier/diff checks catch drift.
          printf '%scodex -s workspace-write -m %q' "$state_env" "$m"
          ;;
        pi)
          printf '%spi --model %q' "$state_env" "$m"
          ;;
      esac
      ;;
    member)
      m="$(jq -r '.roles.member.model // "sonnet"' <<< "$cfg")"
      # Edit(<teamdir>/signals/**): R3 완료 신호 파일 쓰기 허용 — 주의: 자동 승인은 Edit() 규칙이
      # 파일 편집 도구 전체(Write 포함)를 관장하고, Write() 규칙은 효력이 없다 (R3 프로브 실측).
      # 경로는 state 스코프 반영 필수 — 프롬프트는 .team/<state>/signals/에 쓰라고 지시하는데
      # 화이트리스트가 .team/signals/ 고정이면 멀티팀 워커가 승인 대기 스톨 (2026-07-07 리뷰)
      # results/**: R4 워커 보고 파일. shared.md는 의도적으로 제외 — 보드 단일 writer(리드)를
      # 프롬프트 규약이 아니라 권한 레벨에서 강제한다.
      local rel_teamdir="${teamdir#$root/}"
      t="Read,Grep,Glob,Bash(just check:*),Edit($rel_teamdir/signals/**),Edit($rel_teamdir/results/**)"
      while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        t="$t,Edit($d/**),Write($d/**)"
      done <<< "$(jq -r '.domains[]?' <<< "$cfg")"
      printf '%sclaude --permission-mode default --model %q --allowedTools %q' "$state_env" "$m" "$t"
      ;;
    scout)
      # R2: 읽기 전용 조사 상주 — agy 대화형 + sandbox (Antigravity 구독)
      printf '%sagy --sandbox' "$state_env"
      ;;
    verifier)
      # R2: 교차 모델 검증 상주 — codex 대화형 + read-only 샌드박스 (ChatGPT 구독)
      printf '%scodex -s read-only' "$state_env"
      ;;
  esac
}

bootstrap_msg() {
  local rel_teamdir
  rel_teamdir="${teamdir#$root/}"
  printf "You are the '%s' of team %s. Read the file %s/prompts/%s.md fully and follow it from now on, then print your readiness line exactly as that file instructs." "$1" "$team_name" "$rel_teamdir" "$1"
}

case "$verb" in
up)
  team="${1:?usage: up <team.yaml> [role ...]}"; shift
  roles=("$@"); [[ ${#roles[@]} -eq 0 ]] && roles=(lead member)
  if [[ -f "$roster" && "${RESIDENT_REPLACE:-0}" != "1" ]]; then
    echo "roster already exists: $roster — run just team-down first, or set RESIDENT_REPLACE=1" >&2
    exit 1
  fi
  load_team_context "$team"
  tmux has-session -t "$session" 2>/dev/null && { echo "session already up: $session (just team-down first)" >&2; exit 1; }
  mkdir -p "$teamdir/panes" "$teamdir/prompts" "$teamdir/signals" "$teamdir/tasks" "$teamdir/results"
  rm -f "$teamdir/signals/"*   # 이전 세션의 stale 신호 제거
  # 팀 보드(R4): 리드 단일 writer. 없을 때만 스켈레톤 생성 — 이전 세션 보드가 있으면 보존해
  # 재기동 리드가 이어받는다 (restart resilience). 리셋 판단은 리드 프롬프트 규칙 8의 몫.
  if [[ ! -f "$teamdir/shared.md" ]]; then
    printf '# Team Board — sole writer: lead\n\n## Goal\n\n## Queue\n\n## Active\n\n## Done\n\n## Blocked\n' > "$teamdir/shared.md"
  fi

  # 크레딧 고지 (R2): 기동 전 pane 구성과 벤더 배분을 한 줄로 알린다
  plan=""
  for role in "${roles[@]}"; do
    kind="$(role_kind "$role")"
    case "$kind" in
      lead)
        la="$(lead_adapter)"
        plan="$plan lead=$la/$(lead_model "$la")"
        ;;
      member) plan="$plan $role=claude/$(jq -r '.roles.member.model // "sonnet"' <<< "$cfg")";;
      scout)  plan="$plan scout=agy";;
      verifier) plan="$plan verifier=codex";;
    esac
  done
  echo "plan:$plan (상주 세션 ${#roles[@]}개 — idle 무과금, 메시지 단위 과금)"

  role_list=(); pane_list=()
  first=1
  for role in "${roles[@]}"; do
    build_prompt "$role"
    : > "$teamdir/panes/$role.log"
    cmd="$(boot_cmd "$role")"
    if [[ $first -eq 1 ]]; then
      # -x/-y: detached 기본 80x24는 센티널 줄바꿈 절단 위험 — 넓게 기동
      pane="$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$root" -x 220 -y 50 "$cmd")"
      first=0
    else
      pane="$(tmux split-window -d -P -F '#{pane_id}' -t "$session:0" -c "$root" "$cmd")"
    fi
    tmux pipe-pane -o -t "$pane" "cat >> '$teamdir/panes/$role.log'"
    tmux select-pane -t "$pane" -T "$role"
    role_list+=("$role"); pane_list+=("$pane")
  done
  tmux select-layout -t "$session:0" tiled >/dev/null

  ros='{}'
  for i in "${!role_list[@]}"; do
    ros="$(jq -c --arg r "${role_list[$i]}" --arg p "${pane_list[$i]}" '.[$r] = $p' <<< "$ros")"
  done
  jq -cn --arg session "$session" --arg team "$team" --arg mux tmux --argjson roles "$ros" \
    '{session: $session, team: $team, mux: $mux, roles: $roles}' > "$roster"

  # 부트스트랩: 역할 프롬프트 파일을 읽게 한다 (센티널 리터럴은 메시지에 넣지 않음 — 에코 오탐 방지)
  # 준비 전 send는 유실된다(R1 실측: claude 기동이 sleep보다 느리면 키 입력 소실) —
  # 고정 sleep 대신 READY 센티널 대기 + 미도착 시 1회 재전송으로 기동 완료를 보장한다.
  if [[ "${RESIDENT_DRY:-0}" != "1" ]]; then
    sleep "${RESIDENT_BOOT_WAIT:-6}"
    for role in "${roles[@]}"; do
      "$here/tmux.sh" send "$role" "$(bootstrap_msg "$role")"
    done
    for role in "${roles[@]}"; do
      if ! "$here/tmux.sh" wait "$role" "READY: $role" 45 >/dev/null 2>&1; then
        "$here/tmux.sh" send "$role" "$(bootstrap_msg "$role")"
        "$here/tmux.sh" wait "$role" "READY: $role" 90 >/dev/null \
          || echo "warning: $role did not print READY — check: just team-read $role" >&2
      fi
      echo "ready: $role"
    done
  fi
  echo "up: $session (roles: ${roles[*]}) — observe: tmux attach -t $session / teardown: just team-down"
  ;;

add)
  roles=("$@"); [[ ${#roles[@]} -gt 0 ]] || { echo "usage: add <role ...>" >&2; exit 1; }
  [[ -f "$roster" ]] || { echo "no roster ($roster) — run: just team-up first" >&2; exit 1; }
  team="$(jq -r '.team' "$roster")"
  load_team_context "$team"
  tmux has-session -t "$session" 2>/dev/null || { echo "session not found: $session" >&2; exit 1; }
  mkdir -p "$teamdir/panes" "$teamdir/prompts" "$teamdir/signals" "$teamdir/tasks" "$teamdir/results"

  for role in "${roles[@]}"; do
    if jq -e --arg r "$role" '.roles[$r] != null' "$roster" >/dev/null; then
      echo "role already exists: $role" >&2
      continue
    fi
    build_prompt "$role"
    : > "$teamdir/panes/$role.log"
    rm -f "$teamdir/signals/$role-done"
    pane="$(tmux split-window -d -P -F '#{pane_id}' -t "$session:0" -c "$root" "$(boot_cmd "$role")")"
    tmux pipe-pane -o -t "$pane" "cat >> '$teamdir/panes/$role.log'"
    tmux select-pane -t "$pane" -T "$role"
    tmp="$(mktemp)"
    jq --arg role "$role" --arg pane "$pane" '.roles[$role] = $pane' "$roster" > "$tmp"
    mv "$tmp" "$roster"
    echo "added: $role ($pane)"
  done
  tmux select-layout -t "$session:0" tiled >/dev/null

  if [[ "${RESIDENT_DRY:-0}" != "1" ]]; then
    sleep "${RESIDENT_BOOT_WAIT:-6}"
    for role in "${roles[@]}"; do
      "$here/tmux.sh" send "$role" "$(bootstrap_msg "$role")"
    done
    for role in "${roles[@]}"; do
      if ! "$here/tmux.sh" wait "$role" "READY: $role" 45 >/dev/null 2>&1; then
        "$here/tmux.sh" send "$role" "$(bootstrap_msg "$role")"
        "$here/tmux.sh" wait "$role" "READY: $role" 90 >/dev/null \
          || echo "warning: $role did not print READY — check: just team-read $role" >&2
      fi
      echo "ready: $role"
    done
  fi
  ;;

send)
  role="${1:?usage: send <role> \"<text>\"}"; text="${2:?text required}"
  text="${text//$'\n'/ }"   # 단일 라인 강제 (cmux 교훈: 개행 = 미완성 프롬프트 조기 발사)
  pane="$(pane_of "$role")"
  rm -f "$teamdir/signals/$role-done"   # 새 태스크 디스패치 = 직전 완료 신호 소진 (stale 오탐 방지)
  tmux send-keys -t "$pane" -l -- "$text"
  sleep 0.4
  tmux send-keys -t "$pane" Enter
  ;;

read)
  role="${1:?usage: read <role> [lines]}"; lines="${2:-40}"
  tmux capture-pane -p -t "$(pane_of "$role")" -S "-$lines"
  ;;

wait)
  role="${1:?usage: wait <role> \"<pattern>\" [timeout_s]}"
  pattern="${2:?pattern required}"; timeout="${3:-900}"
  pane="$(pane_of "$role")"
  sig="$teamdir/signals/$role-done"
  # R3 파일 신호 우선: claude 역할(lead·member)은 완료 라인을 .team/signals/<role>-done에도
  # 쓴다 (durable — 센티널 화면 폴링의 에코 오탐·렌더링 공백 유실 함정이 구조적으로 없음).
  # 화면 폴링(capture-pane)은 폴백으로 유지: 파일을 못 쓰는 역할(scout=agy 셸 승인 함정,
  # verifier=codex read-only 샌드박스)과 READY 부트스트랩이 이 경로를 쓴다.
  # 미러 로그가 아니라 capture-pane을 폴링한다 (R1 실측 함정): TUI가 커서 이동 이스케이프로
  # 토큰을 나눠 그려서 로그 스트립 결과는 공백이 유실됨("READY:member") — capture-pane은
  # 렌더링된 화면을 재구성하므로 문자열이 온전하다. 스크롤백 포함(-S)으로 지나간 출력도 커버.
  waited=0
  until { [[ -f "$sig" ]] && LC_ALL=C grep -aqF -- "$pattern" "$sig"; } \
     || tmux capture-pane -p -t "$pane" -S -2000 2>/dev/null | LC_ALL=C grep -aqF -- "$pattern"; do
    (( waited >= timeout )) && { echo "wait timeout (${timeout}s): $role / $pattern" >&2; exit 1; }
    sleep 2; waited=$((waited + 2))
  done
  if [[ -f "$sig" ]] && LC_ALL=C grep -aqF -- "$pattern" "$sig"; then
    LC_ALL=C grep -aF -- "$pattern" "$sig" | tail -1
  else
    tmux capture-pane -p -t "$pane" -S -2000 | LC_ALL=C grep -aF -- "$pattern" | tail -1
  fi
  ;;

down)
  [[ -f "$roster" ]] || { echo "no roster — nothing to tear down"; exit 0; }
  session="$(jq -r '.session' "$roster")"
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -f "$roster"
  echo "down: $session (mirror logs kept in ${teamdir#$root/}/panes/)"
  ;;

*) echo "unknown verb: $verb (up|add|send|read|wait|down)" >&2; exit 1;;
esac
