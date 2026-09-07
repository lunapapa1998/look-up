# flutter handoff note

## `lib/theme/app_theme.dart` — design-token dark theme (read this before styling any new screen)

- New dependency: `google_fonts: ^6.2.1` (added to `pubspec.yaml`, alongside `http`/`flutter_riverpod`).
- `AppTheme.dark()` — static, no args, returns a `ThemeData` (`useMaterial3: true`). Wired into
  `lib/main.dart`: `theme: AppTheme.dark(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.dark`
  (old `ColorScheme.fromSeed(seedColor: Colors.green)` removed). Use this for any new
  screen/widget — do not hardcode colors, read them off `Theme.of(context).colorScheme` /
  `.textTheme`.
- `AppTheme.telemetryStyle(...)` has been **removed**. JetBrains Mono now lives directly in the
  `TextTheme`: `labelSmall`/`labelMedium` are sourced from `GoogleFonts.jetBrainsMonoTextTheme()`
  (all other roles still Space Grotesk for display/headline, Inter for the rest). For
  numeric/telemetry display (dates, counts), use `Theme.of(context).textTheme.labelSmall`
  (`.copyWith(...)` for size/color overrides) instead of calling a helper directly.
- `ColorScheme` tokens available via `Theme.of(context).colorScheme` (built from `ColorScheme.dark()`
  + `.copyWith`, only the fields below are overridden — everything else is `ColorScheme.dark()`
  default, do not assume other fields are themed):
  - `surface` / `surfaceContainerLowest` / `surfaceContainerLow` / `surfaceContainer` /
    `surfaceContainerHigh` / `surfaceContainerHighest` — navy background scale, darkest to
    lightest (`#030c28` → `#2b3450`). (`background` was intentionally left unset —
    `ColorScheme.background` is deprecated in this Flutter SDK and falls back to `surface`
    automatically, so it still resolves to the same navy.)
  - `secondary` (`#42e1be`, teal) / `onSecondary` (`#00382d`) — star/night accent; also the
    `FilledButton` background/foreground.
  - `tertiary` (`#f5bc7e`, gold) / `onTertiary` (`#482900`) — bird/day accent (not wired into any
    component theme yet, available for screens to use directly).
  - `primary` (`#bec5e5`), `onSurface` (`#dbe1ff`), `onSurfaceVariant` (`#c6c6ce`),
    `outline` (`#909098`), `error` (`#ffb4ab`).
- `TextTheme`: display*/headline* roles use `GoogleFonts.spaceGroteskTextTheme()`, `labelSmall`/
  `labelMedium` use `GoogleFonts.jetBrainsMonoTextTheme()` (numeric/telemetry look), all remaining
  roles (body*/labelLarge/title*) use `GoogleFonts.interTextTheme()`; every role's `color` is
  `onSurface`.
- Component themes set: `cardTheme` (`surfaceContainer` fill, 12px radius), `appBarTheme`
  (`surface` background, `onSurface` foreground, `headlineSmall` title style),
  `inputDecorationTheme` (filled, `surfaceContainerHigh` fill, 8px radius, no border side),
  `filledButtonTheme` (`secondary`/`onSecondary`, fully pill-shaped radius 9999).
- Lane: only `pubspec.yaml`, `lib/theme/app_theme.dart`, `lib/main.dart` touched this task — no
  screens/tests/api/models/providers changed.
- Could not run `flutter analyze`/`flutter test` in this harness (no Bash access to the `flutter`
  binary — confined to Read/Grep/Glob/Edit/Write). Statically re-checked against the installed
  Flutter SDK source (`/opt/homebrew/share/flutter/packages/flutter/lib/src/material/color_scheme.dart`
  and `theme_data.dart`) for every field/type used (`ColorScheme.dark().copyWith` field names,
  `CardThemeData` vs old `CardTheme`, `TextTheme.apply(bodyColor:, displayColor:)`,
  `FilledButton.styleFrom`). Pipeline validate stage should run
  `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

- Status: added `Observation` DTOs (manual JSON, no code-gen) + round-trip unit tests; added `EcologApi` (Http + Fake) client; added `flutter_riverpod` dependency
- Last update: 2026-09-07
- Files: `lib/models/observation.dart`, `test/models/observation_test.dart`, `lib/api/ecolog_api.dart`
- New pubspec dependency: `flutter_riverpod: ^2.6.1` (providers + `ConsumerWidget` state management, not yet wired into any widget).

## `lib/main.dart` — app entry point wired up

- `main()` now does `runApp(const ProviderScope(child: MyApp()))`. `MyApp` is a `MaterialApp`
  (title `'위를 봐요'`, `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), useMaterial3: true)`)
  with `home: const DiaryListScreen()`. All counter demo code (`MyHomePage`, `_MyHomePageState`,
  `_counter`, `_incrementCounter`) removed.
- **Deviation**: `test/widget_test.dart` (the obsolete counter smoke test) could not be physically
  deleted — this worker's tool set is Read/Grep/Glob/Edit/Write only, no Bash/`rm`. Replaced its
  content with a no-op `void main() {}` plus a comment explaining why, so `flutter test` doesn't
  fail on it. The pipeline/lead should run `git rm apps/flutter/test/widget_test.dart` (or
  equivalent) to remove the file entirely — real coverage already lives in `test/screens/` and
  `test/models/`.
- Could not run `flutter analyze`/`flutter test` in this harness (no Bash access) — statically
  re-checked against `DiaryListScreen({super.key})` (`ConsumerWidget`, no-arg constructor, confirmed
  by reading `lib/screens/diary_list_screen.dart`). Pipeline validate stage should run
  `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## Contract mirrored (exact field names/types — future consumers should read this, not the original doc)

```dart
enum SpeciesType { bird, star } // JSON string 'bird'/'star'; SpeciesType.fromJson(String), .toJson() -> String

class Observation { // response object, all fields always present in JSON
  int id;
  SpeciesType speciesType;
  String speciesName;
  String? note;
  String? photoUrl;
  DateTime observedAt;   // ISO 8601, always non-null
  double? lat;
  double? lng;
  DateTime createdAt;    // ISO 8601, always non-null
  // Observation.fromJson(Map<String,dynamic>), toJson() -> Map<String,dynamic> (always includes all keys, note/photoUrl/lat/lng may be JSON null)
}

class ObservationCreate { // POST request body
  SpeciesType speciesType;   // required
  String speciesName;       // required
  String? note;             // optional
  String? photoUrl;         // optional
  DateTime? observedAt;     // optional; if null, omitted so server defaults to current UTC time
  double? lat;              // optional
  double? lng;              // optional
  // toJson() OMITS a key entirely when its value is null (never sends explicit null)
}

class ObservationUpdate { // PATCH request body, partial-update semantics
  SpeciesType? speciesType;  // set-if-non-null; no way to clear
  String? speciesName;       // set-if-non-null; no way to clear
  DateTime? observedAt;      // set-if-non-null; no way to clear
  // note/photoUrl/lat/lng use named ctor params `note`/`noteSet`, `photoUrl`/`photoUrlSet`,
  // `lat`/`latSet`, `lng`/`lngSet`: passing a non-null value always marks it "set";
  // to explicitly clear one to null, pass e.g. `note: null, noteSet: true`.
  // toJson(): omits unset fields entirely; sends explicit JSON null for note/photoUrl/lat/lng
  // when their set-flag is true and value is null; never sends null for speciesType/speciesName/observedAt.
}

class Badge {
  String id;          // one of: first_step, explorer, master, bird_watcher, star_gazer (plain String, not an enum)
  String name;
  String description;
  int targetCount;
  // Badge.fromJson / toJson
}

class BadgeProgress {
  Badge badge;
  bool achieved;
  int currentCount;
  // BadgeProgress.fromJson / toJson
}
```

## `lib/api/ecolog_api.dart` — EcologApi client (mirrors `/api` backend contract)

```dart
class EcologApiException implements Exception {
  final int statusCode; final String message; // thrown on any non-2xx response
}

abstract class EcologApi {
  Future<List<Observation>> listObservations({SpeciesType? speciesType});
  Future<Observation> getObservation(int id);
  Future<Observation> createObservation(ObservationCreate body);
  Future<Observation> updateObservation(int id, ObservationUpdate body);
  Future<void> deleteObservation(int id);
  Future<List<BadgeProgress>> listBadges(); // GET /api/badges
}
```

- `HttpEcologApi(String baseUrl, {http.Client? client})` — real implementation; hits
  `GET/POST/PATCH/DELETE /api/observations[/:id]` and `GET /api/badges`, decodes JSON via the
  `Observation`/`BadgeProgress` DTOs, throws `EcologApiException` on non-2xx (message = response
  body, or JSON `detail` field when present).
- `FakeEcologApi({List<Observation>? seed})` — in-memory implementation of the same interface for
  tests, no HTTP. Badge derivation logic mirrors the backend exactly: `first_step`/`explorer`/
  `master` count all observations (targets 1/5/20), `bird_watcher`/`star_gazer` count only
  matching `speciesType` (target 5 each).

## Verification

Could not run `flutter pub get` / `flutter analyze` / `flutter test` in this harness (command
required approval that wasn't available). `flutter_riverpod: ^2.6.1` requires Dart `>=2.17.0`,
well under this project's `sdk: ^3.12.2`, so it should resolve cleanly alongside `http: ^1.2.0`
and `flutter_lints: ^6.0.0`. Pipeline validate stage should run:
```
cd apps/flutter && flutter pub get && flutter analyze && flutter test
```

## State layer (`lib/config.dart`, `lib/state/providers.dart`) — Riverpod providers for screen-building tasks

Added on top of the `EcologApi` client above; none of `lib/main.dart`, `lib/models/`, `lib/api/`,
or `test/` were touched. Could not run `flutter analyze`/`flutter test` in this harness (same
approval restriction as above) — statically re-checked against `flutter_riverpod: ^2.6.1`'s
`AsyncNotifierProvider`/`AsyncNotifier`/`FutureProvider` API (no code-gen).

- `lib/config.dart`: `const String defaultApiBaseUrl = 'http://localhost:8000';` — override
  per-platform as needed (e.g. Android emulator needs `10.0.2.2` instead of `localhost`).

- `ecologApiProvider` — `Provider<EcologApi>`, returns `HttpEcologApi(defaultApiBaseUrl)` by
  default. Override in tests via
  `ProviderScope(overrides: [ecologApiProvider.overrideWithValue(FakeEcologApi(...))])`.

- `observationsProvider` — `AsyncNotifierProvider<ObservationsNotifier, List<Observation>>`.
  `build()` calls `listObservations()` (no species filter — screens filtering by `SpeciesType`
  should filter the resolved `List<Observation>` client-side, or add a param later if needed).
  Public methods on `ObservationsNotifier`, all `Future<void>`, call the API then re-fetch the
  list via `AsyncValue.guard` and invalidate `badgesProvider`:
  - `createObservation(ObservationCreate body)`
  - `updateObservation(int id, ObservationUpdate body)`
  - `deleteObservation(int id)`
  These call the API directly (not wrapped in `AsyncValue.guard`), so an `EcologApiException`
  thrown by the API call propagates to the caller (e.g. a screen's `try`/`catch` around the
  button handler) — only the subsequent list refresh is captured into the provider's
  `AsyncValue` state. Consume with `ref.watch(observationsProvider)` (returns
  `AsyncValue<List<Observation>>` — `.when(data:, loading:, error:)`) and
  `ref.read(observationsProvider.notifier)` for the methods.

- `badgesProvider` — `FutureProvider<List<BadgeProgress>>`, calls `listBadges()`. Automatically
  invalidated (and thus re-fetched on next watch) whenever `ObservationsNotifier`'s
  create/update/delete methods succeed, so badge progress stays in sync with the observation
  list without screens having to invalidate it manually.

## `lib/screens/observation_form_screen.dart` — observation create/edit form (for the list screen task to consume)

```dart
class ObservationFormScreen extends ConsumerStatefulWidget {
  const ObservationFormScreen({super.key, Observation? existing});
}
```

- Navigate with `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ObservationFormScreen()))`
  for create mode, or pass `existing: someObservation` for edit mode (pre-fills all fields).
- Fields: species type `SegmentedButton<SpeciesType>` (bird/star), required species name
  `TextFormField` (validated non-empty), optional multi-line note, optional photo URL
  (placeholder text field — no real image picker in this MVP), optional lat/lng numeric fields.
- On save: calls `ref.read(observationsProvider.notifier).createObservation(...)` (create mode)
  or `.updateObservation(id, ...)` (edit mode, `ObservationUpdate` always passes `noteSet`/
  `photoUrlSet`/`latSet`/`lngSet: true` so blank fields explicitly clear those values), then
  `Navigator.of(context).pop()` on success. On `EcologApiException`, shows the error message in
  a `SnackBar` and stays on the form (does not pop).
- Test: `test/screens/observation_form_screen_test.dart` — pumps the screen inside a
  `ProviderScope` with `ecologApiProvider` overridden to `FakeEcologApi()`, pushed via a
  `navigatorKey` so `pop()` is observable, fills the species name field, taps Save, and asserts
  the fake API now holds one observation and the screen has popped.

Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
above) — statically re-checked against the `providers.dart`/`observation.dart`/`ecolog_api.dart`
contracts. Pipeline validate stage should run
`cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/diary_list_screen.dart` — observation list / app home screen

```dart
class DiaryListScreen extends ConsumerWidget {
  const DiaryListScreen({super.key});
}
```

- **This is the intended app home widget** — no arguments, drop straight into `MaterialApp.home`
  (or a route) once `lib/main.dart` is wired up.
- Watches `observationsProvider`; `AsyncValue.when` covers `loading` (spinner), `error` (message +
  "Retry" `FilledButton` calling `ref.invalidate(observationsProvider)`), `data` (list or empty
  state).
- `AppBar` action icon (`emoji_events_outlined`) pushes `BadgesScreen()`. `FloatingActionButton`
  pushes `ObservationFormScreen()` (create mode). Each card (`ListTile` in a `Card`) shows
  `speciesName`, a bird/star-distinguishing icon (`flutter_dash`/`star`), the `note` when present,
  and `observedAt` formatted as `yyyy-MM-dd HH:mm` via manual `DateTime` field padding (no date
  package); tapping a card pushes `ObservationFormScreen(existing: observation)`.
- Empty state (`observations.isEmpty`): centered icon + message, no list/illustration asset.
- Test: `test/screens/diary_list_screen_test.dart` — two `testWidgets`, one seeding
  `FakeEcologApi(seed: [...])` with a bird + a star observation and asserting both `speciesName`s
  render, one seeding zero observations and asserting the empty-state text renders.

Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
above) — statically re-checked against the `providers.dart`/`observation.dart`/`badges_screen.dart`/
`observation_form_screen.dart` contracts. Pipeline validate stage should run
`cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `_ObservationCard` — photo thumbnail (spec-compliance fix, `diary_list_screen.dart`)

- `ListTile.leading` is now a fixed 56x56 `SizedBox`: when `observation.photoUrl` is non-null/
  non-empty, renders `Image.network(photoUrl, width: 56, height: 56, fit: BoxFit.cover)` in a
  `ClipRRect`, with `loadingBuilder` (small `CircularProgressIndicator`) and `errorBuilder`
  (falls back to the species icon) so a bad URL can't throw uncaught; otherwise renders the
  existing bird/star icon via new private `_SpeciesIconPlaceholder` widget (same 56x56 box, so
  layout doesn't jump between photo/no-photo cards).
- Title/subtitle/`onTap` unchanged. No new backend contract — reuses `Observation.photoUrl`
  already in `lib/models/observation.dart`.
- Added two `testWidgets` to `diary_list_screen_test.dart`: one seeds a `photoUrl` and asserts
  `find.byType(Image)` finds widgets; one omits `photoUrl` and asserts `find.byIcon(Icons.star)`.
  Could not run `flutter analyze`/`flutter test` in this harness — statically re-checked.

## `lib/screens/badges_screen.dart` — badges grid screen (for the list/nav screen task to consume)

```dart
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});
}
```

- Navigate with `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen()))`
  — no arguments needed.
- Watches `badgesProvider` (`FutureProvider<List<BadgeProgress>>`) and renders a 2-column
  `GridView.builder`, one `Card` per `BadgeProgress`: badge name, description, an
  `emoji_events`/`emoji_events_outlined` icon + `Opacity`/`primaryContainer` color to distinguish
  achieved vs unachieved, a `LinearProgressIndicator` + `currentCount / targetCount` text.
- `AsyncValue` states: `loading` → `CircularProgressIndicator`; `error` → error text + a "Retry"
  `FilledButton` that calls `ref.invalidate(badgesProvider)`; `data` → the grid.
- Test: `test/screens/badges_screen_test.dart` — pumps `BadgesScreen` in a `ProviderScope` with
  `ecologApiProvider` overridden to `FakeEcologApi()`, sets a tall test surface
  (`tester.binding.setSurfaceSize(Size(800, 1600))`, torn down after) so all 5 grid items are
  built (`GridView` is lazy and the default 800x600 test viewport doesn't fit 3 rows), then
  asserts all 5 badge names render (Korean, mirroring backend contract): 첫 관찰, 탐험가, 관찰 마스터, 새 관찰자, 별 관찰자.

Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
above) — statically re-checked against the `providers.dart`/`observation.dart`/`ecolog_api.dart`
contracts. Pipeline validate stage should run
`cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/diary_list_screen.dart` — reskinned with `AppTheme.dark` + Korean copy

- Copy-and-styling-only pass, no logic/provider/navigation changes: AppBar title `관찰 일지`,
  badges `IconButton` tooltip `배지`, error-state `FilledButton` text `다시 시도`, empty-state
  strings `아직 관찰 기록이 없어요.` / `+ 버튼을 눌러 첫 새 또는 별 관찰을 기록해보세요.`.
- `_SpeciesIconPlaceholder` no longer hardcodes `Colors.brown`/`Colors.indigo` — reads
  `Theme.of(context).colorScheme.tertiary` (gold, bird) / `.secondary` (teal, star).
- `_ObservationCard`'s date/time `Text` now styled with
  `AppTheme.telemetryStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)` (relative import
  `../theme/app_theme.dart`) for the JetBrains Mono timestamp look.
- `test/screens/diary_list_screen_test.dart`: updated the empty-state assertion to
  `'아직 관찰 기록이 없어요.'`; the other three tests (species names, image/icon types) untouched.
- Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
  above) — statically re-checked field names against `app_theme.dart`
  (`AppTheme.telemetryStyle`, `colorScheme.tertiary`/`.secondary`/`.onSurfaceVariant`). Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/observation_form_screen.dart` — reskinned with Korean copy

- Copy-only pass, no logic/provider/navigation changes: `AppBar` title `관찰 수정`/`새 관찰 기록`
  (edit/create mode), `SegmentedButton` segment labels `새`/`별` (bird/star), `TextFormField`
  labels 종 이름/메모/사진 URL/위도/경도, species-name validator error `종 이름을 입력해주세요`,
  save button text `저장`/`저장 중...` (saving state).
- `test/screens/observation_form_screen_test.dart`: updated the tap-target string from `Save` to
  `저장` to match.
- Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
  above) — statically re-checked the changed strings against the widget/test source. Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/badges_screen.dart` — reskinned with `AppTheme.dark` + Korean copy (contrast fix)

- Copy-and-styling-only pass, no logic/provider/grid-layout/model changes: `AppBar` title `배지`,
  error-state `FilledButton` text `다시 시도`. `badge.name`/`badge.description` left untouched
  (existing Korean backend contract).
- `_BadgeCard`: replaced the plain `Colors.amber`/`Colors.grey` trophy icon colors with
  `Theme.of(context).colorScheme.tertiary` (achieved) / `.outline` (unachieved) for stronger
  contrast against the `Opacity` dimming already in place; `Card` `color` (`primaryContainer` when
  achieved) unchanged. Added explicit `shape: RoundedRectangleBorder(borderRadius:
  BorderRadius.circular(12))` on the `Card` to match the theme's card radius token.
- `test/screens/badges_screen_test.dart`: read but not touched — it only asserts on the 5 Korean
  badge names (`find.text('첫 관찰')` etc.), no `find.text('Badges')`/`'Retry'` assertions present.
- Could not run `flutter analyze`/`flutter test` in this harness (same approval restriction as
  above) — statically re-checked field names against `app_theme.dart` (`colorScheme.tertiary`/
  `.outline`/`.primaryContainer`) and the unchanged `Badge`/`BadgeProgress` models. Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## Lint fix: `unnecessary_underscores` in `AsyncValue.error` callbacks

- `lib/screens/diary_list_screen.dart:32` and `lib/screens/badges_screen.dart:19`: changed
  `error: (_, __) => Center(` to `error: (_, _) => Center(` — Dart's `unnecessary_underscores`
  lint wants repeated bare `_` for multiple unused positional params, not `_`/`__`. One-token
  change per file, nothing else touched.
- Built against no new backend contract (pure lint fix, no logic/DTO change).
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — grepped the whole `apps/flutter/lib` tree for `error: (_, _+)` and
  confirmed only these two matches, both now single-underscore. Pipeline validate stage should
  run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## Cross-model-verifier fix pass: JetBrains Mono into `TextTheme`, no raw error text in UI

- `lib/theme/app_theme.dart`: `telemetryStyle()` static helper **removed**. `labelSmall`/
  `labelMedium` are now sourced from `GoogleFonts.jetBrainsMonoTextTheme()` inside the
  `textTheme.copyWith(...)` call (alongside the existing Space Grotesk display/headline overrides),
  still passed through the same `.apply(bodyColor: onSurface, displayColor: onSurface)`, so no
  extra color wiring was needed.
- `lib/screens/diary_list_screen.dart`: observation timestamp now uses
  `Theme.of(context).textTheme.labelSmall?.copyWith(color: onSurfaceVariant, fontSize: 12)` instead
  of the removed `AppTheme.telemetryStyle(...)`; dropped the now-unused `../theme/app_theme.dart`
  import. Error state no longer interpolates the raw error object — replaced with fixed Korean
  copy `관찰 기록을 불러오지 못했어요.` (unused `error`/`stackTrace` callback params renamed to `_`/`__`).
- `lib/screens/badges_screen.dart`: badge count `Text` (`currentCount / targetCount`) now styled
  with `Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)` (was
  unstyled). Error state fixed Korean copy `배지 정보를 불러오지 못했어요.` (same `_`/`__` param rename).
- No API/model/provider files touched — copy/style only, per lane rules.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that isn't
  available here) — statically re-checked: `GoogleFonts.jetBrainsMonoTextTheme()` mirrors the
  existing `spaceGroteskTextTheme()`/`interTextTheme()` calls already used in this file;
  `TextTheme.labelSmall`/`.labelMedium` are `TextStyle?` in the installed Flutter SDK
  (`/opt/homebrew/share/flutter/packages/flutter/lib/src/material/text_theme.dart`), so `?.copyWith`
  is correct. Grepped the whole `apps/flutter` tree for `telemetryStyle` and raw `$error`/`'$error'`
  interpolation in `test/` — no remaining references, so no test fallout expected. Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.
