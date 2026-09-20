# Flutter API endpoint switching

The Flutter client receives `API_BASE_URL` through `--dart-define`. The value is
compiled into the app, so changing servers always requires a new build.

## Local development on a physical iPhone

1. Connect the Mac and iPhone to the same LAN.
2. From the repository root, start the backend with `just backend-dev`.
   This is mandatory: it validates and explicitly loads the repository-root
   `.env`. Do not start `uvicorn` directly from `apps/backend` because the live
   provider keys will be absent and the API may return `degraded=true`.
3. Find the device ID with `flutter devices`.
4. Run `just ios-run-dev DEVICE_ID`.
5. Confirm that the printed endpoint is the Mac LAN address, never `localhost`
   or `127.0.0.1`. On a physical phone those loopback addresses refer to the
   phone itself.

## Deployed backend

1. Obtain the current Cloud Run HTTPS service URL.
2. Run `just ios-run-prod DEVICE_ID HTTPS_SERVICE_URL`.
3. The command rejects non-HTTPS URLs and verifies `/api/health` before build.

## Switching checklist

- Rebuild and reinstall after every endpoint change. A relaunch is insufficient.
- Read the endpoint echoed by the command before accepting the build.
- Local mode must use the Mac LAN IP and a backend started by `just backend-dev`.
- Production mode must use an explicit HTTPS URL.
- If the UI says some data is unavailable, inspect `/api/suitability`: check
  `degraded` and each `layers[].status`. A `200 OK` response can still contain a
  degraded provider.
- Never put API secrets in `--dart-define`; only the backend base URL belongs in
  the client build.
