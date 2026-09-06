#!/usr/bin/env bash
# Phase 1 파이프라인: 스펙 1개 → Builder(claude) 빌드 → 검증 커맨드 → Verifier(codex) 교차 검증
# 사용법: pipeline.sh <spec.md 경로>
# 출력: 정규화 JSON 한 줄 { ok, spec, attempts, build, validation, verdict, durationMs }
# 옵션(환경변수): BUILDER(기본 claude), VERIFIER(기본 codex), MAX_ATTEMPTS(기본 2)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
spec="${1:?usage: pipeline.sh <spec.md>}"
[[ -f "$spec" ]] || { echo "{\"ok\":false,\"error\":\"spec not found: $spec\"}"; exit 1; }

builder="${BUILDER:-claude}"
verifier="${VERIFIER:-codex}"
max_attempts="${MAX_ATTEMPTS:-2}"
ts="$(date +%Y%m%d-%H%M%S)"
start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

# ── Validation Commands 추출 (justfile 레시피만 — 화이트리스트 원칙) ──
extract_validation() {
  awk '/^## Validation Commands$/{f=1;next} /^## /{f=0} f' "$spec" \
    | grep -E '^just( |$)' || true
}

run_validation() {
  # 반환: 0=전부 통과 / 1=실패. 실패 출력은 $val_output에 남김
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

# ── diff 캡처: 검증자에게 "이번 런의 누적 변경"을 보여준다 (diff 기반 검증) ──
diff_file="$here/logs/$ts-run.diff"
capture_diff() {
  git -C "$root" add -N . 2>/dev/null || true    # 신규 파일도 diff에 포함 (intent-to-add)
  git -C "$root" diff > "$diff_file" 2>/dev/null || true
  git -C "$root" reset -q 2>/dev/null || true    # intent-to-add 원복
}

# ── 빌드 → 검증 루프 (닫힌 루프, 21편: 통과 전 진행 금지) ──
build_prompt="Build the spec file at: ${spec}

Workflow (build-plan):
1. Read the spec file fully first.
2. Execute the Phases top-to-bottom. Do not start a phase before the previous one is complete.
3. Update the spec file as you work (living artifact): checkbox states [ ] -> [~] -> [x], or [F] if truly blocked (write the reason under Notes).
4. Append one line to the spec metadata (modified: today + builder) and to Amendments if anything deviated from the plan.
5. Be surgical. Do only what the spec asks for. No extra styling, refactors, or files."

# 시도 1회 = 빌드 → 검증 커맨드 → 교차 검증. 어느 단계든 실패하면
# 실패 출력을 다음 시도의 빌더에게 되먹임한다 (검증자 FAIL도 닫힌 루프에 포함).
verify_prompt="Verify that the spec at ${spec} was actually implemented. The cumulative unified diff of this run's changes is saved at ${diff_file} — read the spec and that diff first; the diff is your primary review target, the real files are your ground truth. Assume the implementation is wrong until proven otherwise: hunt for bugs, spec deviations, and missing cases. Do not trust checked boxes, builder notes, or amendments — confirm everything against the diff and the real files (read-only). Check each deliverable and each checked checkbox as an atomic claim. Do not fix anything. IMPORTANT — deterministic validation (the spec's Validation Commands, e.g. 'just check': lint/typecheck/tests/build) was already executed by the pipeline in the real environment and PASSED before you were spawned; treat that as established fact. Your sandbox is read-only: do NOT re-run tests, builds, or any state-changing commands — they fail with sandbox EPERM/permission errors, which are environment artifacts and MUST NOT be reported as implementation FAILs. Judge purely by reading the spec, the diff, and the files. For each claim print one line: PASS/FAIL + evidence. The very last line of your reply must be exactly 'VERDICT: PASS' if every claim holds, otherwise 'VERDICT: FAIL'."

# R0 재검증 프롬프트: 재개된 세션은 스펙·규칙·이전 지적을 이미 알고 있다 — 갱신분 재검증만 지시
reverify_prompt="The builder has since attempted a fix. Re-verify with the same rules against the updated diff at ${diff_file} and the real files: check whether each issue you reported is now resolved, and re-check every claim from scratch — assume wrong until proven. For each claim print one line: PASS/FAIL + evidence. The very last line of your reply must be exactly 'VERDICT: PASS' or 'VERDICT: FAIL'."

attempt=0
val_ok=false
val_output=""   # 빌더 spawn 실패 시 run_validation을 안 거치므로 초기화 필수 (set -u 크래시 방지)
verdict="SKIPPED"
build_json='null'
verify_json='null'
feedback=""
verify_resume=""   # R0: 직전 시도의 codex verifier 세션 id — 재검증 콜드 스타트 제거
while (( attempt < max_attempts )); do
  attempt=$((attempt + 1))
  prompt="$build_prompt"
  [[ -n "$feedback" ]] && prompt="${build_prompt}

Previous attempt failed. Fix the cause, surgically. Failure report:
${feedback}"

  build_json="$(ALLOWED_TOOLS="Read Edit Write Grep Glob" "$here/spawn.sh" "$builder" builder "$prompt")" || true
  build_ok="$(jq -r '.ok // false' <<< "$build_json")"

  val_ok=false
  if [[ "$build_ok" != "true" ]] || ! run_validation; then
    feedback="[validation commands] ${val_output}"
    verdict="SKIPPED"
    continue
  fi
  val_ok=true

  # 교차 모델 검증 (14편: 원자적 주장 검증, 빌더와 다른 모델) — diff 기반
  # R0: 2차 시도부터는 직전 verifier의 codex 세션을 재개(exec resume) — 코드베이스 재독해 생략
  capture_diff
  v_env=()
  v_prompt="$verify_prompt"
  [[ -n "$verify_resume" ]] && { v_env=(RESUME_SESSION="$verify_resume"); v_prompt="$reverify_prompt"; }
  verify_json="$(env ${v_env[@]+"${v_env[@]}"} "$here/spawn.sh" "$verifier" verifier "$v_prompt")" || true
  if [[ "$(jq -r '.adapter // ""' <<< "$verify_json")" == "codex" ]]; then
    verify_resume="$(jq -r '.sessionId // empty' <<< "$verify_json")"
  else
    verify_resume=""
  fi
  verdict="$(jq -r '.result // ""' <<< "$verify_json" | grep -Eo 'VERDICT: (PASS|FAIL)' | tail -1 | sed 's/VERDICT: //')" || true
  [[ -z "$verdict" ]] && verdict="UNKNOWN"
  [[ "$verdict" == "PASS" ]] && break
  feedback="[cross-model verifier report] $(jq -r '.result // ""' <<< "$verify_json")"
done

end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
overall=false
[[ "$val_ok" == "true" && "$verdict" == "PASS" ]] && overall=true

# ── 런 원장 기록 (윈도우노믹스 Level 2의 기반: 윈도우당 on-spec 산출 측정) ──
result="$(jq -cn \
  --argjson ok "$overall" --arg spec "$spec" --argjson attempts "$attempt" \
  --argjson build "$build_json" --argjson valOk "$([[ "$val_ok" == "true" ]] && echo true || echo false)" \
  --arg verdict "$verdict" --argjson verify "$verify_json" \
  --argjson wall "$((end_ms - start_ms))" --arg ts "$ts" \
  '{ok: $ok, ts: $ts, spec: $spec, attempts: $attempts,
    build: {adapter: $build.adapter, ok: $build.ok, sessionId: $build.sessionId, durationMs: $build.durationMs},
    validation: $valOk, verdict: $verdict,
    verify: {adapter: $verify.adapter, sessionId: $verify.sessionId, durationMs: $verify.durationMs},
    durationMs: $wall}')"
printf '%s\n' "$result" >> "$here/logs/run-ledger.jsonl"
# 전역 원장 이중 기록 (멀티 프로젝트 윈도우노믹스 — spawn.sh와 동일 원칙)
global_dir="${FACTORY_GLOBAL_DIR:-$HOME/.factory}"
mkdir -p "$global_dir"
jq -c --arg project "$(basename "$root")" '. + {project: $project}' <<< "$result" >> "$global_dir/run-ledger.jsonl"

# ── 체크포인트: PASS 런 = 커밋 1개 (다음 런의 diff 기준점 유지). GIT_CHECKPOINT=0로 비활성 ──
if [[ "$overall" == "true" && "${GIT_CHECKPOINT:-1}" == "1" ]]; then
  git -C "$root" add -A 2>/dev/null && \
    git -C "$root" commit -q -m "factory: $(basename "$spec") PASS (builder=$builder, attempts=$attempt)" 2>/dev/null || true
fi

printf '%s\n' "$result"
[[ "$overall" == "true" ]]
