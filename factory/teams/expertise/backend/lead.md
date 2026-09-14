# expertise: backend/lead - lessons accumulated after successful runs.
#
# English only: this file is injected into LLM prompts on every run.
# Keep at most 40 concise, reusable lessons.

- seed: For single-file append tasks, explicitly tell the worker to preserve all existing content unchanged.
- 2026-09-07: When a member reports it cannot run Bash (no execution permission) but claims a fix works, the lead must run `just check` itself before checking off — static review from the member is not sufficient verification of test-passing claims.
- 2026-09-08: When a cross-model verifier FAILs specific line ranges with concrete before/after behavior expectations (e.g. "picks first, spec wants max"), quoting those exact expectations plus the precise code restructuring (which lines move inside try, what exception to raise) in the member task prompt lets a single delegation fix all findings correctly on the first attempt — no need to split into multiple rounds.
- 2026-09-10: In backend.yaml (and likely other team YAMLs without an explicit `roles.member.modelProfiles` block), only the `standard` member profile resolves via the backward-compat default — passing any other profile name (e.g. `light`) to `just member-build` fails silently with exit 1 and no visible output (the error JSON is swallowed inside a `set -e` command substitution in delegate.sh). Check the team YAML for `modelProfiles` before using a non-standard profile, or just default to `standard`.
- 2026-09-14: When a member reports "no Bash execution permission" twice across different runs in the same session, treat it as a persistent session-level constraint (not per-task) — the lead should plan to always self-verify via `just check` for that session rather than re-prompting the member to run tests each time.
