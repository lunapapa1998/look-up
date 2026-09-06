# [Spec Title]

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: YYYY-MM-DD
- modified: YYYY-MM-DD <agent/session>
- refs: [related specs or documentation links]
- risk: low | medium | high - change size and risk tier. low=small/single-file change using the 2-layer pipeline, medium=normal 3-layer pipeline, high=large/sensitive 3-layer pipeline with extra verification. Defaults to medium when omitted.

## Purpose

[Why this spec exists. Maximum 2 sentences.]

## Problem

[What is currently wrong or missing. Maximum 3 sentences.]

## Solution

[What will be built to solve the problem. Maximum 3 sentences.]

## Relevant Files

### Existing Files

- `path/to/file` - what changes here

### New Files

- `path/to/new` - what this file will contain

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: [Name]

[Phase description in 1-2 sentences.]

- [ ] Task 1
- [ ] Task 2

**Phase validation**: [How to confirm this phase is complete.]

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.
> The pipeline runs each line in the shell block below in order; every command must exit 0.

```sh
just check
```

## Notes (agent scratchpad)

[Builder/verifier findings, failure reasons, assumptions, and follow-up suggestions.]

## Amendments (post-build change history, append-only)

- YYYY-MM-DD: [What changed and why]
