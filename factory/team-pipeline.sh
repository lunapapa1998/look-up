#!/usr/bin/env bash
# Phase 2 팀 파이프라인 (3계층, 리드 방식 A):
#   scout(읽기전용 조사) → lead(위임 전용, 헤드리스 claude) → 검증 커맨드 → verifier(교차 모델)
# 사용법: team-pipeline.sh <spec.md> [team.yaml|팀이름 (기본 factory/teams/docs.yaml)]
# 출력: 정규화 JSON 한 줄 { ok, spec, team, attempts, scout, lead, validation, verdict, durationMs }
# 옵션(환경변수): MAX_ATTEMPTS(기본 2) / VERIFIER2(어댑터명 — high 티어 이중 교차 검증, 기본 없음)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
spec="${1:?usage: team-pipeline.sh <spec.md> [team.yaml]}"
team="${2:-$here/teams/docs.yaml}"
# 짧은 팀 이름(web·qa 등, 슬래시 없음)은 factory/teams/<이름>.yaml로 해석한다
[[ -f "$team" || "$team" == */* ]] || team="$here/teams/$team.yaml"
[[ -f "$spec" ]] || { echo "{\"ok\":false,\"error\":\"spec not found: $spec\"}"; exit 1; }
[[ -f "$team" ]] || { echo "{\"ok\":false,\"error\":\"team not found: $team\"}"; exit 1; }

cfg="$(python3 "$here/teamcfg.py" "$team")"
team_name="$(jq -r '.name' <<< "$cfg")"
max_attempts="${MAX_ATTEMPTS:-2}"
ts="$(date +%Y%m%d-%H%M%S)"
start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

role_field() { jq -r ".roles.$1.$2 // empty" <<< "$cfg"; }
# Phase 4: 역할별 폴백 로테이션(팀 YAML fallbacks) + expertise 파일(09편) 로드
role_fallbacks() { jq -r ".roles.$1.fallbacks // [] | join(\" \")" <<< "$cfg"; }
# 팀별 리드 부록: roles.lead.appendix가 있으면 도메인 분해 플레이북(.claude/agents/<팀>-lead.md)을
# 공유 코어(prompt) 뒤에 주입 — YAML frontmatter는 제거하고 본문만 (delegate.sh 멤버 주입과 동일 패턴)
lead_appendix_block() {
  local p body
  p="$(role_field lead appendix)"
  [[ -z "$p" || ! -f "$root/$p" ]] && return 0
  body="$(awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$root/$p")"
  printf '\n\n%s\n' "$body"
}
expertise_block() {
  local body
  body="$(python3 "$here/expertise.py" load "$team_name" "$1" 2>/dev/null || true)"
  [[ -z "$body" ]] && return 0
  printf '\n\nAccumulated team expertise for your role (lessons from past runs — apply them):\n%s\n' "$body"
}

# ── Validation Commands 추출·실행 (pipeline.sh와 동일한 화이트리스트 원칙) ──
extract_validation() {
  awk '/^## Validation Commands$/{f=1;next} /^## /{f=0} f' "$spec" \
    | grep -E '^just( |$)' || true
}

run_validation() {
  val_output=""
  local line rc
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      *';'*|*'&'*|*'|'*|*'$'*|*'`'* ) val_output="unsafe validation line rejected: $line"; return 1;;
    esac
    rc=0
    out="$(cd "$root" && $line 2>&1)" || rc=$?
    val_output="${val_output}\$ ${line} (exit ${rc})
${out}
"
    [[ $rc -ne 0 ]] && return 1
  done <<< "$(extract_validation)"
  return 0
}

join_feedback() {
  local prefix="$1" body="$2"
  if [[ -n "$prefix" ]]; then
    printf '%s\n%s' "$prefix" "$body"
  else
    printf '%s' "$body"
  fi
}

# ── 병렬 런 안전성 (Phase 3 ④): git 조작을 팀 도메인 경로로 스코핑 + 락 직렬화 ──
# 도메인 스코핑: 동시 런의 diff에 다른 팀의 진행 중 변경이 섞이는 것을 방지.
# specs 도메인은 팀 공유 디렉토리이므로 "이 런의 스펙 파일"로 대체한다.
git_paths=()
while IFS= read -r d; do
  [[ -z "$d" || "$d" == "specs" ]] && continue
  git_paths+=("$d")
done <<< "$(jq -r '.domains[]?' <<< "$cfg")"
git_paths+=("$spec")
# expertise 파일은 런 끝(PASS)에만 갱신되므로 diff에는 안 잡히고, 체크포인트 커밋에 포함된다
[[ -d "$here/teams/expertise/$team_name" ]] && git_paths+=("factory/teams/expertise/$team_name")

# index.lock 경합 방지: git index를 만지는 구간은 mkdir 락으로 직렬화
git_lock="$root/.git/factory.lock"
with_git_lock() {
  local n=0
  until mkdir "$git_lock" 2>/dev/null; do
    n=$((n + 1)); (( n > 90 )) && break
    sleep 2
  done
  "$@" || true
  rmdir "$git_lock" 2>/dev/null || true
}

# ── diff 캡처: 검증자에게 "이번 런의 누적 변경"(도메인 스코프)을 보여준다 ──
diff_file="$here/logs/$ts-run.diff"
do_capture() {
  git -C "$root" add -N -- "${git_paths[@]}" 2>/dev/null || true   # 신규 파일도 diff에 포함
  git -C "$root" diff -- "${git_paths[@]}" > "$diff_file" 2>/dev/null || true
  git -C "$root" reset -q -- "${git_paths[@]}" 2>/dev/null || true # intent-to-add 원복
}
capture_diff() { with_git_lock do_capture; }

# ── 1) Scout: 읽기 전용 조사 → 리포트를 리드에게 주입 ──
scout_adapter="$(role_field scout adapter)"
scout_json='null'
scout_report="(scout stage skipped)"
if [[ -n "$scout_adapter" ]]; then
  scout_prompt="$(cat "$root/$(role_field scout prompt)")$(expertise_block scout)

Spec file: ${spec}"
  scout_json="$(FALLBACKS="$(role_fallbacks scout)" "$here/spawn.sh" "$scout_adapter" scout "$scout_prompt")" || true
  scout_report="$(jq -r '.result // "(scout failed)"' <<< "$scout_json")"
fi

# ── 2) Lead 루프: 위임 전용 리드 → 검증 커맨드 → 교차 검증. 실패는 리드에게 되먹임 ──
lead_adapter="$(role_field lead adapter)"
lead_model="$(role_field lead model)"
lead_tools="$(role_field lead allowedTools)"
verifier_adapter="$(role_field verifier adapter)"
lead_base="$(cat "$root/$(role_field lead prompt)")$(lead_appendix_block)$(expertise_block lead)

Team file: ${team}
Spec file: ${spec}

Scout report (read-only investigation done for you):
${scout_report}"

verify_prompt="Verify that the spec at ${spec} was actually implemented. The cumulative unified diff of this run's changes is saved at ${diff_file} — read the spec and that diff first; the diff is your primary review target, the real files are your ground truth. Assume the implementation is wrong until proven otherwise: hunt for bugs, spec deviations, and missing cases. Do not trust checked boxes, builder notes, or amendments — confirm everything against the diff and the real files (read-only). Check each deliverable and each checked checkbox as an atomic claim. Do not fix anything. IMPORTANT — deterministic validation (the spec's Validation Commands, e.g. 'just check': lint/typecheck/tests/build) was already executed by the pipeline in the real environment and PASSED before you were spawned; treat that as established fact. Your sandbox is read-only: do NOT re-run tests, builds, or any state-changing commands — they fail with sandbox EPERM/permission errors, which are environment artifacts and MUST NOT be reported as implementation FAILs. Judge purely by reading the spec, the diff, and the files. For each claim print one line: PASS/FAIL + evidence. The very last line of your reply must be exactly 'VERDICT: PASS' if every claim holds, otherwise 'VERDICT: FAIL'.$(expertise_block verifier)"

# R0 재검증 프롬프트: 재개된 세션은 스펙·규칙·이전 지적을 이미 알고 있다 — 갱신분 재검증만 지시
reverify_prompt="The lead has since attempted a fix. Re-verify with the same rules against the updated diff at ${diff_file} and the real files: check whether each issue you reported is now resolved, and re-check every claim from scratch — assume wrong until proven. For each claim print one line: PASS/FAIL + evidence. The very last line of your reply must be exactly 'VERDICT: PASS' or 'VERDICT: FAIL'."

attempt=0
val_ok=false
val_output=""   # 리드 spawn 실패 시 run_validation을 안 거치므로 초기화 필수 (set -u 크래시 방지, 2026-07-05 실측)
verdict="SKIPPED"
lead_json='null'
verify_json='null'
verify2_json='null'
feedback=""
lead_failure=""   # 백오프 판단용: 직전 시도의 리드 spawn 실패 여부 (루프 안에서 매 시도 갱신)
verify_resume=""   # R0: 직전 시도의 codex verifier 세션 id — 재검증 콜드 스타트 제거
while (( attempt < max_attempts )); do
  attempt=$((attempt + 1))
  # 리드 재시도 백오프 (pet-town 실측: lead#1 사망 2.3초 뒤 lead#2가 같은 rate-limit에
  # 즉시 재돌진해 즉사). 가용성 실패(리드 spawn 실패)만 대기가 의미 있다 — 품질 FAIL
  # (validation·verifier)은 시간이 해결하지 않으므로 즉시 재시도 유지.
  # LEAD_RETRY_BACKOFF: 대기 초 (기본 90, 0이면 비활성). 윈도우 소진이면 90초로도 안
  # 살아나지만 그건 2회 FAIL 에스컬레이션의 영역 — 백오프는 일시 블립(429/5xx)용.
  if (( attempt > 1 )) && [[ -n "$lead_failure" ]]; then
    backoff="${LEAD_RETRY_BACKOFF:-90}"
    [[ "$backoff" =~ ^[0-9]+$ ]] || backoff=90
    if (( backoff > 0 )); then
      echo "[lead backoff] previous lead spawn failed — waiting ${backoff}s before attempt ${attempt}" >&2
      sleep "$backoff"
    fi
  fi
  prompt="$lead_base"
  [[ -n "$feedback" ]] && prompt="${lead_base}

Previous attempt failed. Diagnose, then re-delegate the fix to members (surgically). Failure report:
${feedback}"

  # 리드의 Bash 안에서 멤버 빌드(수 분)가 돌므로 리드 세션의 Bash 타임아웃을 늘린다
  # A′ 변형: 팀 YAML에 experimentalTeams: true면 네이티브 Agent Teams 활성화
  lead_env=()
  [[ "$(role_field lead experimentalTeams)" == "true" ]] && lead_env=(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
  # FACTORY_TEAM: 리드의 just member-build가 올바른 팀 파일을 기본값으로 쓰도록 주입
  lead_json="$(env ${lead_env[@]+"${lead_env[@]}"} \
    ALLOWED_TOOLS="$lead_tools" MODEL="${lead_model:-sonnet}" FACTORY_TEAM="$team" \
    SANDBOX=workspace-write \
    BASH_DEFAULT_TIMEOUT_MS=600000 BASH_MAX_TIMEOUT_MS=900000 \
    "$here/spawn.sh" "$lead_adapter" lead "$prompt")" || true
  lead_ok="$(jq -r '.ok // false' <<< "$lead_json")"
  lead_failure=""
  if [[ "$lead_ok" != "true" ]]; then
    lead_failure="[lead failed] $(jq -r '.error // "lead returned ok:false before final report"' <<< "$lead_json")"
  fi

  val_ok=false
  if ! run_validation; then
    feedback="$(join_feedback "$lead_failure" "[validation commands] ${val_output}")"
    verdict="SKIPPED"
    continue
  fi
  val_ok=true

  # 교차 모델 검증 (14편: 원자적 주장 검증, 빌더 계열과 다른 모델) — diff 기반
  # R0: 2차 시도부터는 직전 verifier의 codex 세션을 재개(exec resume) — 코드베이스 재독해 생략
  capture_diff
  # salvage 빈 diff 가드: 리드가 spawn 실패했고 이번 런의 누적 diff도 비어 있으면 구제할
  # 산출물이 없다 — verifier 헛콜 방지 + "무변경 salvage PASS" 엣지 차단 (validation이
  # 원래부터 통과하는 스펙에서 즉사 리드가 오탐 PASS로 새는 것을 막는다. 2026-07-07 리뷰)
  if [[ -n "$lead_failure" && ! -s "$diff_file" ]]; then
    feedback="$(join_feedback "$lead_failure" "[salvage guard] lead spawn failed and the run produced no changes (empty diff) — nothing to salvage or verify")"
    verdict="SKIPPED"
    continue
  fi
  v_env=()
  v_prompt="$verify_prompt"
  [[ -n "$verify_resume" ]] && { v_env=(RESUME_SESSION="$verify_resume"); v_prompt="$reverify_prompt"; }
  verify_json="$(env ${v_env[@]+"${v_env[@]}"} FALLBACKS="$(role_fallbacks verifier)" \
    "$here/spawn.sh" "$verifier_adapter" verifier "$v_prompt")" || true
  # 다음 시도용 세션 id 갱신 — 폴백 로테이션으로 어댑터가 바뀌었으면(≠codex) 재개 무효화
  if [[ "$(jq -r '.adapter // ""' <<< "$verify_json")" == "codex" ]]; then
    verify_resume="$(jq -r '.sessionId // empty' <<< "$verify_json")"
  else
    verify_resume=""
  fi
  verdict="$(jq -r '.result // ""' <<< "$verify_json" | grep -Eo 'VERDICT: (PASS|FAIL)' | tail -1 | sed 's/VERDICT: //')"
  [[ -z "$verdict" ]] && verdict="UNKNOWN"
  if [[ "$verdict" != "PASS" ]]; then
    feedback="$(join_feedback "$lead_failure" "[cross-model verifier report] $(jq -r '.result // ""' <<< "$verify_json")")"
    continue
  fi

  # high 티어 이중 검증 (19편 리스크 티어링): 다른 어댑터의 2차 검증자도 PASS해야 통과
  if [[ -n "${VERIFIER2:-}" ]]; then
    verify2_json="$("$here/spawn.sh" "$VERIFIER2" verifier "$verify_prompt")" || true
    verdict2="$(jq -r '.result // ""' <<< "$verify2_json" | grep -Eo 'VERDICT: (PASS|FAIL)' | tail -1 | sed 's/VERDICT: //')"
    if [[ "$verdict2" != "PASS" ]]; then
      verdict="FAIL"
      feedback="$(join_feedback "$lead_failure" "[second verifier report (${VERIFIER2})] $(jq -r '.result // ""' <<< "$verify2_json")")"
      continue
    fi
  fi
  break
done

end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
overall=false
[[ "$val_ok" == "true" && "$verdict" == "PASS" ]] && overall=true

# ── 런 원장 기록 (run-ledger는 Phase 1 파이프라인과 공유, team 필드로 구분) ──
result="$(jq -cn \
  --argjson ok "$overall" --arg spec "$spec" --arg team "$team_name" \
  --argjson attempts "$attempt" \
  --argjson scout "$scout_json" --argjson lead "$lead_json" \
  --argjson valOk "$([[ "$val_ok" == "true" ]] && echo true || echo false)" \
  --arg verdict "$verdict" --argjson verify "$verify_json" --argjson verify2 "$verify2_json" \
  --argjson wall "$((end_ms - start_ms))" --arg ts "$ts" \
  '{ok: $ok, ts: $ts, spec: $spec, team: $team, attempts: $attempts,
    scout: {adapter: $scout.adapter, ok: $scout.ok},
    lead: {adapter: $lead.adapter, ok: $lead.ok, sessionId: $lead.sessionId, durationMs: $lead.durationMs},
    validation: $valOk, verdict: $verdict,
    salvaged: ($lead.ok != true and $valOk == true and $verdict == "PASS"),
    verify: {adapter: $verify.adapter, sessionId: $verify.sessionId, durationMs: $verify.durationMs},
    verify2: {adapter: $verify2.adapter, sessionId: $verify2.sessionId, durationMs: $verify2.durationMs},
    durationMs: $wall}')"
printf '%s\n' "$result" >> "$here/logs/run-ledger.jsonl"
# 전역 원장 이중 기록 (멀티 프로젝트 윈도우노믹스 — spawn.sh와 동일 원칙)
global_dir="${FACTORY_GLOBAL_DIR:-$HOME/.factory}"
mkdir -p "$global_dir"
jq -c --arg project "$(basename "$root")" '. + {project: $project}' <<< "$result" >> "$global_dir/run-ledger.jsonl"

# ── expertise 갱신 (09편): PASS 런의 리드 보고에서 'EXPERTISE:' 교훈 1줄을 추출해 축적 ──
if [[ "$overall" == "true" ]]; then
  # grep 무매치 exit 1 + pipefail 조합은 set -e 크래시 (2026-07-05 실측: 체크포인트·stdout 유실) — || true 필수
  lesson="$(jq -r '.result // ""' <<< "$lead_json" | grep -E '^EXPERTISE: ' | tail -1 | sed 's/^EXPERTISE: //' || true)"
  [[ -n "$lesson" ]] && python3 "$here/expertise.py" append "$team_name" lead "$lesson" 2>/dev/null || true
fi

# ── 체크포인트: PASS 런 = 커밋 1개 (다음 런의 diff 기준점 유지). GIT_CHECKPOINT=0로 비활성 ──
# 커밋도 도메인 스코프 + 락: 동시 런이 서로의 미완성 변경을 쓸어 담지 않도록.
do_checkpoint() {
  git -C "$root" add -- "${git_paths[@]}" 2>/dev/null && \
    git -C "$root" commit -q -m "factory: $(basename "$spec") PASS (team=$team_name, attempts=$attempt)" -- "${git_paths[@]}" 2>/dev/null || true
}
if [[ "$overall" == "true" && "${GIT_CHECKPOINT:-1}" == "1" ]]; then
  with_git_lock do_checkpoint
fi

printf '%s\n' "$result"
[[ "$overall" == "true" ]]
