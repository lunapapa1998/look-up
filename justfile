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
# TODO: replace this with project validation such as test/lint/build. Pipelines and specs only run just recipes.

# Aggregate validation. This is the default for spec Validation Commands and lead self-checks.
check:
    @echo "TODO: replace this project's validation recipe in justfile: check" && exit 1
