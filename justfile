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

# backend deploy: build the Cloud Run container image locally (needs docker). See docs/deploy/backend-cloudrun.md.
docker-build-backend:
    cd apps/backend && docker build -t lookup-backend:local .

# suitability engine live smoke: hits real OWM/KASI APIs (needs repo-root .env keys + network).
# Excluded from `check`/`backend-check` (marker-gated) so the pipeline stays deterministic/offline.
suitability-live:
    cd apps/backend && RUN_LIVE_TESTS=1 uv run pytest -m live -q -s

# flutter lane: fetch deps (so pubspec dependency changes self-resolve in-pipeline) + static analysis + widget/unit tests.
flutter-check:
    cd apps/flutter && flutter pub get && flutter analyze && flutter test

# flutter lane: regenerate icon sources (tool/gen_icon_sources.dart) + Android/web launcher icons.
flutter-icons:
    cd apps/flutter && dart run tool/gen_icon_sources.dart && dart run flutter_launcher_icons

# Local backend for simulator/physical-device development. Always load the
# repo-root secrets; running uvicorn directly from apps/backend skips them.
backend-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    test -f .env || { echo "error: repo-root .env is missing" >&2; exit 1; }
    grep -Eq '^KMA_APIHUB_KEY=.+$' .env || { echo "error: KMA_APIHUB_KEY is missing from repo-root .env" >&2; exit 1; }
    cd apps/backend
    exec uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --env-file ../../.env

# Run on a physical iPhone against the Mac-hosted backend.
# Example: just ios-run-dev 00008130-0018348E1E90001C
ios-run-dev device:
    #!/usr/bin/env bash
    set -euo pipefail
    lan_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    test -n "$lan_ip" || { echo "error: could not determine the Mac LAN IP from en0" >&2; exit 1; }
    api_url="http://${lan_ip}:8000"
    curl -fsS --max-time 5 "${api_url}/api/health" >/dev/null || {
      echo "error: ${api_url}/api/health is unavailable; start 'just backend-dev' first" >&2
      exit 1
    }
    echo "iOS dev endpoint: ${api_url}"
    cd apps/flutter
    exec flutter run -d "{{device}}" --dart-define="API_BASE_URL=${api_url}"

# Run on a physical iPhone against a deployed backend. Production URLs must
# be explicit HTTPS URLs so a stale local endpoint cannot be reused silently.
# Example: just ios-run-prod DEVICE_ID https://SERVICE.run.app
ios-run-prod device service_url:
    #!/usr/bin/env bash
    set -euo pipefail
    api_url="{{service_url}}"
    case "$api_url" in
      https://*) ;;
      *) echo "error: production API_BASE_URL must start with https://" >&2; exit 1 ;;
    esac
    curl -fsS --max-time 10 "${api_url%/}/api/health" >/dev/null || {
      echo "error: ${api_url%/}/api/health is unavailable" >&2
      exit 1
    }
    echo "iOS production endpoint: ${api_url%/}"
    cd apps/flutter
    exec flutter run -d "{{device}}" --dart-define="API_BASE_URL=${api_url%/}"

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
