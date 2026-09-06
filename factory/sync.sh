#!/usr/bin/env bash
# Sync factory core files from the factory template into this consumer repo.
# Source of truth: the template repo path recorded in factory/.factory-source.
# Usage (from the repo root):  just factory-sync [--check|--dry-run|--force]
#   --check    quiet mode for the SessionStart hook: prints a one-line notice when
#              the core is behind the template, prints nothing (exit 0) otherwise.
#              Never fails: a missing template path degrades silently.
#   --dry-run  list files that would change, change nothing.
#   --force    apply even when synced files have uncommitted local changes.
#   (no flag)  apply: copy manifest files + regenerate factory/brain.md, then
#              summarize. Review with `git diff` before committing.
# brain.md is NOT copied: it is regenerated from the template's brain.template.md
# with this repo's {{TEAMS}} block derived from factory/teams/*.yaml — local team
# declarations always win. Root justfile, CLAUDE.md, teams/*.yaml, expertise/ are
# never touched (repo-local by design; see factory/sync-manifest.txt).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
mode="${1:-}"

quiet_bail() { [[ "$mode" == "--check" ]] && exit 0; echo "factory-sync: $1" >&2; exit 1; }

src_file="$here/.factory-source"
[[ -f "$src_file" ]] || quiet_bail "no factory/.factory-source file (write the template repo path into it)"
src="$(head -1 "$src_file")"
src="${src/#\~/$HOME}"
[[ -d "$src/factory" ]] || quiet_bail "template not found at: $src"

manifest="$src/factory/sync-manifest.txt"
[[ -f "$manifest" ]] || quiet_bail "template has no sync-manifest.txt (too old?): $manifest"

# ── Collect drift ──────────────────────────────────────────────
drifted=()   # manifest files that differ or are missing locally
while IFS= read -r path; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  [[ -f "$src/$path" ]] || continue   # listed but absent in template: skip
  if ! diff -q "$src/$path" "$root/$path" >/dev/null 2>&1; then
    drifted+=("$path")
  fi
done < "$manifest"

# brain.md: regenerate into a temp file and compare.
regen_brain() {  # $1 = output file
  local teams_block=""
  local y name domains
  for y in "$root"/factory/teams/*.yaml; do
    [[ -f "$y" ]] || continue
    cfg="$(python3 "$root/factory/teamcfg.py" "$y" 2>/dev/null)" || continue
    name="$(jq -r '.name // empty' <<< "$cfg")"
    [[ -n "$name" ]] || continue
    domains="$(jq -r '[.domains[]? | select(. != "specs")] | join(", ")' <<< "$cfg")"
    teams_block="${teams_block}   - factory/teams/${name}.yaml  -> write domains: ${domains}
"
  done
  python3 - "$src/factory/brain.template.md" "$1" "$teams_block" <<'PYEOF'
import sys
src, dst, teams = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src, encoding="utf-8").read().replace("{{TEAMS}}", teams.rstrip("\n"))
open(dst, "w", encoding="utf-8").write(text)
PYEOF
}

brain_drift=""
if [[ -f "$src/factory/brain.template.md" ]]; then
  tmp_brain="$(mktemp)"
  if regen_brain "$tmp_brain" && ! diff -q "$tmp_brain" "$root/factory/brain.md" >/dev/null 2>&1; then
    brain_drift="factory/brain.md"
  fi
fi

total=$(( ${#drifted[@]} + ${brain_drift:+1} + 0 ))

# ── Report / apply ─────────────────────────────────────────────
if [[ "$mode" == "--check" ]]; then
  if (( total > 0 )); then
    echo "factory core is ${total} file(s) behind the template ($src). Run 'just factory-sync --dry-run' to inspect, 'just factory-sync' to apply."
  fi
  exit 0
fi

if (( total == 0 )); then
  echo "factory-sync: up to date with $src"
  exit 0
fi

echo "factory-sync: ${total} file(s) differ from template ($src):"
for p in ${drifted[@]+"${drifted[@]}"}; do echo "  $p"; done
[[ -n "$brain_drift" ]] && echo "  $brain_drift (regenerated: template protocol + local team list)"

if [[ "$mode" == "--dry-run" ]]; then
  echo "(dry-run: nothing changed)"
  exit 0
fi

# Guard: refuse to clobber uncommitted local changes in the files we are about to write.
if [[ "$mode" != "--force" ]] && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  dirty=""
  for p in ${drifted[@]+"${drifted[@]}"} $brain_drift; do
    if ! git -C "$root" diff --quiet -- "$p" 2>/dev/null || ! git -C "$root" diff --cached --quiet -- "$p" 2>/dev/null; then
      dirty="${dirty}  $p
"
    fi
  done
  if [[ -n "$dirty" ]]; then
    echo "factory-sync: ABORT — these files have uncommitted local changes (commit/stash them, or rerun with --force):"
    printf '%s' "$dirty"
    exit 1
  fi
fi

for p in ${drifted[@]+"${drifted[@]}"}; do
  mkdir -p "$root/$(dirname "$p")"
  cp "$src/$p" "$root/$p"
done
[[ -n "$brain_drift" ]] && cp "$tmp_brain" "$root/factory/brain.md"

echo "factory-sync: applied. Review with 'git diff' before committing."
