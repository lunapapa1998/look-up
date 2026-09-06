#!/usr/bin/env bash
# 도메인 락킹 멤버 스폰 — 리드의 유일한 위임 통로 (justfile: member-build)
# 사용법: delegate.sh <team.yaml> <adapter> <domain> "<task prompt>" [profile] [specialty]
# 출력: spawn 계약과 동일한 정규화 JSON 한 줄
# 가드: domain은 팀 YAML의 domains 화이트리스트에 있어야 한다 (09편 도메인 락킹)
# profile: light|standard|strong 등 — team YAML roles.member.modelProfiles.<adapter>.<profile>에서 모델 해석
# specialty: .claude/agents/<specialty>.md 전문 워커 agent 정의를 프롬프트 앞에 주입
#            (Claude Code 인터랙티브 세션과 동일 정의 공유 — agents-library 규격)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
team="${1:?usage: delegate.sh <team.yaml> <adapter> <domain> <prompt>}"
adapter="${2:?adapter required}"
domain="${3:?domain required}"
prompt="${4:?prompt required}"
profile="${5:-standard}"
specialty="${6:-}"

cfg="$(python3 "$here/teamcfg.py" "$team")"

jq -e --arg d "$domain" '.domains | index($d) != null' <<< "$cfg" >/dev/null || {
  echo "{\"ok\":false,\"error\":\"domain not in team whitelist: $domain\"}"
  exit 1
}

team_name="$(jq -r '.name' <<< "$cfg")"

resolve_model() {
  local adapter_name="$1" profile_name="$2" model
  profile_name="${profile_name:-standard}"
  model="$(jq -r --arg a "$adapter_name" --arg p "$profile_name" '
    .roles.member.modelProfiles[$a][$p] // empty
  ' <<< "$cfg")"

  if [[ -z "$model" ]]; then
    if [[ "$profile_name" == "standard" ]]; then
      # Backward-compatible default: old team YAML files only had roles.member.model.
      # For non-default adapters, an empty model means "use the adapter CLI default".
      if [[ "$adapter_name" == "$(jq -r '.roles.member.adapter // "claude"' <<< "$cfg")" ]]; then
        model="$(jq -r '.roles.member.model // empty' <<< "$cfg")"
      fi
    else
      echo "{\"ok\":false,\"error\":\"unknown member model profile: adapter=$adapter_name profile=$profile_name\"}"
      exit 1
    fi
  fi

  # `inherit` means do not set MODEL; let the adapter/CLI default decide.
  [[ "$model" == "inherit" ]] && model=""
  printf '%s' "$model"
}

model="$(resolve_model "$adapter" "$profile")"

# 전문 워커 페르소나 주입 (있으면 프롬프트 맨 앞) — 리드 Bash는 한 줄 제약이라 여기서 처리
# 프론트매터(---)를 벗겨 주입 — 프롬프트가 ---로 시작하면 claude CLI(commander)가
# 옵션 플래그로 오인해 결정적 실패 (2026-07-07 리드 실측: unknown option '---')
if [[ -n "$specialty" ]]; then
  persona_file="$root/.claude/agents/${specialty}.md"
  if [[ ! -f "$persona_file" ]]; then
    echo "{\"ok\":false,\"error\":\"unknown specialty (no persona file): $specialty\"}"
    exit 1
  fi
  persona="$(awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$persona_file")"
  prompt="${persona}

Your task:
${prompt}"
else
  # 전문가 멤버 (13편 후보 1): roles.member.prompt가 있으면 그 정의(.claude/agents/*.md 등)를
  # 페르소나로 주입 — YAML frontmatter는 제거하고 본문만. pi/Claude Code와 동일 정의 공유.
  # specialty(태스크 단위 선택)가 명시되면 팀 기본 페르소나보다 우선한다.
  member_def_path="$(jq -r '.roles.member.prompt // empty' <<< "$cfg")"
  if [[ -n "$member_def_path" && -f "$root/$member_def_path" ]]; then
    persona="$(awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$root/$member_def_path")"
    prompt="Your role definition — follow it exactly (lane limits, workflow, handoff note, DONE sentinel):
${persona}

Task:
${prompt}"
  fi
fi

# Phase 4 (09편): 멤버 expertise 파일을 태스크 프롬프트에 주입 — 회차마다 축적된 교훈
member_exp="$(python3 "$here/expertise.py" load "$team_name" member 2>/dev/null || true)"
[[ -n "$member_exp" ]] && prompt="${prompt}

Accumulated team expertise for your role (lessons from past runs — apply them):
${member_exp}"

case "$adapter" in
  claude)
    # 디렉토리 도메인은 재귀 락, 단일 파일 도메인(justfile 등)은 그 파일만
    if [[ -d "$root/$domain" ]]; then
      lock="Edit(${domain}/**),Write(${domain}/**)"
    else
      lock="Edit(${domain}),Write(${domain})"
    fi
    if [[ -n "$model" ]]; then
      ALLOWED_TOOLS="Read,Grep,Glob,${lock}" MODEL="$model" "$here/spawn.sh" claude member "$prompt"
    else
      ALLOWED_TOOLS="Read,Grep,Glob,${lock}" "$here/spawn.sh" claude member "$prompt"
    fi
    ;;
  codex)
    # 디렉토리 도메인 락: codex workspace-write 샌드박스는 쓰기를 작업 디렉토리로
    # 한정하므로(읽기는 어디든 가능), 도메인 디렉토리를 cwd로 스폰하면 락이 성립한다.
    # 단일 파일 도메인(justfile 등)은 락이 불가능하므로 거부 — claude 멤버를 쓸 것.
    [[ -d "$root/$domain" ]] || {
      echo "{\"ok\":false,\"error\":\"codex member needs a directory domain (file-level lock unsupported): $domain\"}"
      exit 1
    }
    prompt="Working directory: ${root}/${domain}. Repo root: ${root} — you can read anywhere, but write ONLY inside the working directory.

${prompt}"
    # env -u MODEL: 리드 세션의 MODEL(claude용 sonnet 등)이 상속되면 codex가 400 에러
    # (2026-07-05 E2E 실측: "The 'sonnet' model is not supported ... Codex")
    if [[ -n "$model" ]]; then
      ( cd "$root/$domain" && MODEL="$model" SANDBOX=workspace-write "$here/spawn.sh" codex member "$prompt" )
    else
      ( cd "$root/$domain" && env -u MODEL SANDBOX=workspace-write "$here/spawn.sh" codex member "$prompt" )
    fi
    ;;
  agy)
    # agy는 sandbox 고정 (v0) — 쓰기 작업 멤버로는 부적합, 조사·요약용. MODEL 상속 차단 동일
    if [[ -n "$model" ]]; then
      MODEL="$model" "$here/spawn.sh" agy member "$prompt"
    else
      env -u MODEL "$here/spawn.sh" agy member "$prompt"
    fi
    ;;
  *)
    echo "{\"ok\":false,\"error\":\"unknown adapter: $adapter\"}"
    exit 1
    ;;
esac
