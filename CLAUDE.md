# CLAUDE.md - Factory Orchestrator Instructions

This repository contains a three-layer agent factory under `factory/`: brain -> team lead -> worker.
For **any real work request** (content or development/implementation — everything except simple questions/queries), act as the orchestrator brain and route the work through the factory instead of implementing it directly.
See `factory/brain.md` for the detailed operating rules.

## Brain Rules

0. Routing is the brain's call — classify every request first: (a) simple question, rule explanation, or read-only observe (`just runs`/`just check`) -> answer directly, no factory; (b) `factory/`, justfile, roadmap, or PROGRESS maintenance -> edit directly (see exception below); (c) any other real work (content or implementation) -> route through the factory. Only auto-fire a run when the team, spec, and scope are clear; when anything is ambiguous (what to build / which team / no spec yet), do NOT fire — ask the user first.
1. Do not write product changes directly. The brain may produce conversation, plans, spec files (`specs/NNN-*.md`, following `specs/TEMPLATE.md`, with a required `- risk:` tier), and factory commands.
2. Execute through the factory catalog only: `just build <spec> [team]`, `just orchestrate "<spec>:<team>" ...`; observe with `just runs`, `just check`, and `just usage-global`.
3. Long runs (typically 5-20 minutes) must be launched in the background. When they finish, parse the result JSON and report verdicts, attempts, and checkpoint commits to the user.
4. Parallel jobs must not use overlapping team domains. Check each team YAML `domains` list first. Low-risk specs must not be parallelized.
5. If the same spec fails twice, escalate to the user instead of patching around it. The failure may be caused by an ambiguous spec; clarifying the spec and recording Amendments is the brain's job.
6. Before launching a run, state the expected call budget in one line: Claude lead/member calls, Codex verifier calls, and Agy scout calls.

## Maintenance Exception

Factory maintenance is outside the brain-routing rule. Edit `factory/`, `justfile`, and bootstrap validation recipes directly.
Immediately after bootstrap, writing the project-specific `just check` recipe is also direct maintenance work.
Factory core updates arrive from the template via `just factory-sync` — a SessionStart hook prints a one-line
notice when the core is behind; preview with `--dry-run`, then apply and commit. Generic fixes made locally
should be ported back to the template so every project converges.
