# Factory core recipes — SYNCED VERBATIM from the factory template (factory/sync.sh).
# Do NOT add project-specific recipes here; they belong in the root justfile,
# which defines `default_team` and the project `check` recipe, then imports this file.

# Resident team mode (lane 2) mux adapter: tmux (default) | herdr | cmux
mux := env("FACTORY_MUX", "tmux")

# ── Spawn Contract (Provider Adapter) ─────────────────────────

# spawn(adapter, role, prompt) -> one normalized JSON line
spawn adapter role prompt:
    ./factory/spawn.sh "{{adapter}}" "{{role}}" "{{prompt}}"

# Member shortcut. Default guards: claude=Read/Grep/Glob, codex=read-only, agy=sandbox.
member adapter prompt:
    ./factory/spawn.sh "{{adapter}}" member "{{prompt}}"

# Verifier call. Prefer a different adapter from the builder for cross-model verification.
verify adapter prompt:
    ./factory/spawn.sh "{{adapter}}" verifier "{{prompt}}"

# Plumbing status check: ping all three adapters.
ping-all:
    ./factory/spawn.sh claude member "Reply with exactly: pong"
    ./factory/spawn.sh codex member "Reply with exactly: pong"
    ./factory/spawn.sh agy member "Reply with exactly: pong"

# ── Pipelines ─────────────────────────────────────────────────

# Risk-tier dispatcher: the spec's `- risk:` line selects the pipeline.
build spec team=default_team:
    ./factory/build.sh "{{spec}}" "{{team}}"

# Force the 2-layer builder-verifier pipeline.
build-spec spec:
    ./factory/pipeline.sh "{{spec}}"

# Force the 3-layer scout -> lead -> member -> verifier pipeline.
build-team spec team=default_team:
    ./factory/team-pipeline.sh "{{spec}}" "{{team}}"

# Run multiple (spec, team) pairs in parallel and aggregate results. Team domains must not overlap.
orchestrate *pairs:
    ./factory/orchestrate.sh "$@"

# Lead-only delegation recipe: spawn one domain-locked member call.
# profile: light|standard|strong — resolved via team YAML roles.member.modelProfiles (optional).
# specialty: inject .claude/agents/<specialty>.md as the worker persona (optional).
member-build domain prompt adapter="claude" profile="standard" specialty="" team=env("FACTORY_TEAM", default_team):
    ./factory/delegate.sh "{{team}}" "{{adapter}}" "{{domain}}" "{{prompt}}" "{{profile}}" "{{specialty}}"

# Inspect a team declaration as JSON.
team-config team=default_team:
    @python3 factory/teamcfg.py "{{team}}"

# ── Orchestrator Brain (pi + Claude subscription OAuth) ───────

brain *args:
    ANTHROPIC_OAUTH_TOKEN="$(cat ~/.pi/anthropic-oauth-token)" pi --provider anthropic --model "claude-sonnet-4-6" --append-system-prompt factory/brain.md "$@"

# Launch the top-level factory brain as an AI Office sendable pane.
# It appears as team=brain, role=brain and writes Office reply cards to
# .team/brain/replies/<requestId>.json.
office-brain:
    ./factory/office-brain.sh start

office-brain-codex model="gpt-5.5":
    OFFICE_BRAIN_ADAPTER=codex OFFICE_BRAIN_MODEL="{{model}}" ./factory/office-brain.sh start

office-brain-down:
    ./factory/office-brain.sh down

office-brain-read lines="80":
    ./factory/office-brain.sh read "{{lines}}"

office-brain-approve:
    ./factory/office-brain.sh approve

# ── Window Economics (Observability) ──────────────────────────

# Summarize this project's usage ledger.
usage:
    @jq -s 'group_by(.adapter) | map({adapter: .[0].adapter, calls: length, ok: map(select(.ok)) | length, input: (map(.usage.input // 0) | add), output: (map(.usage.output // 0) | add)})' factory/logs/usage-ledger.jsonl

# Summarize run ledger: spec, success/failure, attempts, and verdict.
runs:
    @jq -c '{ts, spec, team, ok, attempts, validation, verdict, salvaged: (.salvaged // false), durationMs}' factory/logs/run-ledger.jsonl

# Calls and output per subscription window for this project.
usage-windows:
    @python3 factory/checks/usage-windows.py

# Global window economics across projects sharing the same subscription windows.
usage-global:
    @python3 factory/usage-global.py

# Watch dashboard: tmux panes for spec progress, usage ledger, latest session log, and processes/runs.
watch spec="":
    ./factory/watch.sh {{spec}}

# Validate team YAML schemas and referenced paths. Recommended inside `check`.
check-teams:
    python3 factory/checks/check-teams.py

# ── Factory Template Sync ─────────────────────────────────────

# Update factory core files from the template repo recorded in factory/.factory-source.
# Flags: --check (quiet drift notice, used by the SessionStart hook) | --dry-run | (none = apply)
factory-sync *flags:
    @bash factory/sync.sh {{flags}}

# ── Lane 2: Resident Team Mode (design: pane-first resident teams) ────────────
# The brain (any of Claude Code / codex / pi) drives resident teams with these
# recipes only — mux-neutral. Routing decisions (which team, mode, budget) are the
# brain's; these recipes only execute. Small (light) requests: the brain handles
# them directly and does not start a team.

# Start a resident team: one interactive CLI per pane + mirror logs (.team/panes/).
# Role names containing "worker" use the member role template and permissions.
# Example: just team-up factory/teams/main.yaml lead worker-1 worker-2 verifier scout
team-up team=default_team *roles:
    ./factory/mux/{{mux}}.sh up "{{team}}" {{roles}}

# Add worker/scout/verifier panes to an existing resident team (lead calls within budget).
team-add *roles:
    ./factory/mux/{{mux}}.sh add {{roles}}

# Start resident team(s) with the brain's chosen mode/budget, hand the goal to each
# lead, and follow to completion. Mode via RESIDENT_MODE=light|standard|full
# (default standard = lead+verifier, budget 1; full adds scout, budget 3-4).
# RESIDENT_FOLLOW=0 returns right after dispatch. team may be comma-separated for multi-team.
resident-start goal team max_workers="":
    ./factory/resident-start.sh "{{goal}}" "{{team}}" "{{max_workers}}"

# Wait for an already-running resident team's lead completion signal and print its report.
resident-follow timeout="1800" lines="100":
    ./factory/resident-follow.sh "{{timeout}}" "{{lines}}"

# Follow a specific team in a multi-team resident run (state dir = team name).
resident-follow-team team timeout="1800" lines="100":
    FACTORY_TEAM_STATE="{{team}}" ./factory/resident-follow.sh "{{timeout}}" "{{lines}}"

# Inject a single-line message into a role's pane and submit (newlines flattened to spaces).
team-send role text:
    ./factory/mux/{{mux}}.sh send "{{role}}" "{{text}}"

team-send-to team role text:
    FACTORY_TEAM_STATE="{{team}}" ./factory/mux/{{mux}}.sh send "{{role}}" "{{text}}"

# Capture a role pane's screen (default 40 lines).
team-read role lines="40":
    ./factory/mux/{{mux}}.sh read "{{role}}" "{{lines}}"

team-read-to team role lines="40":
    FACTORY_TEAM_STATE="{{team}}" ./factory/mux/{{mux}}.sh read "{{role}}" "{{lines}}"

# Block until a fixed string appears in a role pane's output (default 900s) — sentinel detection.
team-wait role pattern timeout="900":
    ./factory/mux/{{mux}}.sh wait "{{role}}" "{{pattern}}" "{{timeout}}"

team-wait-to team role pattern timeout="900":
    FACTORY_TEAM_STATE="{{team}}" ./factory/mux/{{mux}}.sh wait "{{role}}" "{{pattern}}" "{{timeout}}"

# Tear down the resident team (mirror logs are kept).
team-down:
    ./factory/mux/{{mux}}.sh down

team-down-to team:
    FACTORY_TEAM_STATE="{{team}}" ./factory/mux/{{mux}}.sh down
