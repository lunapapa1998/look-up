# apps/flutter — 위를 봐요 (flutter team lane)

Flutter client for the ecolog observation diary. Riverpod for state, `http` for
networking against the FastAPI backend in `apps/backend`.

## Run

```
cd apps/flutter
flutter pub get
flutter run
```

## Pointing at a backend

`lib/config.dart` defines `defaultApiBaseUrl`, used by `ecologApiProvider`
(`lib/state/providers.dart`) to construct `HttpEcologApi`. It defaults to
`http://localhost:8000`, but physical-device and production runs must use the
mode-specific commands below.

- iOS simulator / desktop / web: `localhost` works as-is.
- Android emulator: the emulator's `localhost` refers to itself, not the host
  machine — inject `http://10.0.2.2:8000` with `API_BASE_URL`.
- Physical iPhone development: start `just backend-dev`, then run
  `just ios-run-dev DEVICE_ID`. The command discovers the Mac LAN IP and checks
  `/api/health` before building.
- Deployed backend: run `just ios-run-prod DEVICE_ID HTTPS_SERVICE_URL`. The
  command rejects non-HTTPS URLs and checks `/api/health` before building.

`API_BASE_URL` is a compile-time value. Switching between development and
production requires rebuilding/reinstalling the app; restarting an already
built app does not change its endpoint. Always read the endpoint printed by the
command before accepting the build.

See [`docs/deploy/endpoint-switching.md`](../../docs/deploy/endpoint-switching.md)
for the development/production checklist.

## Screens

- `DiaryListScreen` (`lib/screens/diary_list_screen.dart`) — home screen,
  lists observations from `observationsProvider`. FAB and tapping a card both
  push `ObservationFormScreen` (create vs. edit); an app bar action pushes
  `BadgesScreen`.
- `ObservationFormScreen` (`lib/screens/observation_form_screen.dart`) —
  create/edit form for a single observation.
- `BadgesScreen` (`lib/screens/badges_screen.dart`) — grid of badge progress
  from `badgesProvider`.

State lives in `lib/state/providers.dart`; the API contract and its `http`-based
implementation live in `lib/api/ecolog_api.dart` (`EcologApi`, `HttpEcologApi`,
and `FakeEcologApi` for tests); DTOs are in `lib/models/observation.dart`.

## Tests

```
cd apps/flutter
flutter analyze
flutter test
```

## Backend contract

This app consumes the API documented in `apps/backend/.team/member.md`
(endpoints, request/response schemas, examples).
