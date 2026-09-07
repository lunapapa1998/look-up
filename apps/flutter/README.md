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
`http://localhost:8000`.

- iOS simulator / desktop / web: `localhost` works as-is.
- Android emulator: the emulator's `localhost` refers to itself, not the host
  machine — use `10.0.2.2` instead (edit `defaultApiBaseUrl` accordingly).

Start the backend first (`cd apps/backend && ...`, see its own README) so the
app has something to talk to.

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
