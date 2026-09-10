# Project execution catalog. Repo-specific validation lives here;
# generic factory recipes are imported from factory/recipes.just (synced from the template).
# TODO: replace the validation recipes for this project and wire them into `check`.

set positional-arguments

# Default team for build / build-team / member-build / team-up when not specified.
default_team := "factory/teams/backend.yaml"

import 'factory/recipes.just'

default:
    @just --list

# ── Validation Commands (verifier allowlist) ──────────────────
# Each app lane owns a team-scoped check; specs use these directly so a blank
# sibling lane never fails a run. `check` aggregates whatever has been scaffolded.

# backend lane: FastAPI unit/integration tests.
backend-check:
    cd apps/backend && uv run pytest -q

# suitability engine live smoke: hits real OWM/KASI APIs (needs repo-root .env keys + network).
# Excluded from `check`/`backend-check` (marker-gated) so the pipeline stays deterministic/offline.
suitability-live:
    cd apps/backend && RUN_LIVE_TESTS=1 uv run pytest -m live -q -s

# flutter lane: fetch deps (so pubspec dependency changes self-resolve in-pipeline) + static analysis + widget/unit tests.
flutter-check:
    cd apps/flutter && flutter pub get && flutter analyze && flutter test

# Aggregate validation — runs each lane check that has been scaffolded, skips blank lanes.
# This is the default for lead self-checks; individual specs pin their own lane check.
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just check-teams
    ran=0
    if [ -f apps/backend/pyproject.toml ]; then just backend-check; ran=1; fi
    if [ -f apps/flutter/pubspec.yaml ]; then just flutter-check; ran=1; fi
    if [ "$ran" = 0 ]; then echo "check: no scaffolded lanes yet (nothing to validate)"; fi
