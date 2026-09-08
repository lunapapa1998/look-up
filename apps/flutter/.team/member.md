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

## `lib/screens/placeholder_screen.dart` — reusable "coming soon" screen

- New file only, nothing else touched. `PlaceholderScreen({super.key, required IconData icon,
  required String title})` — `StatelessWidget`, const constructor, no other params.
- `Scaffold` with `AppBar(title: Text(title))`; body is a centered `Column` (icon at size 64,
  `colorScheme.outline`; `title` styled `textTheme.headlineSmall`; fixed Korean copy
  `준비 중이에요` styled `textTheme.bodyMedium` + `colorScheme.onSurfaceVariant`). All colors/text
  styles read from `Theme.of(context)` per `app_theme.dart` — no hardcoded colors, no
  `google_fonts` import.
- Usable directly inside `Navigator.push`/`IndexedStack`, e.g.
  `const PlaceholderScreen(icon: Icons.map_outlined, title: '지도')`.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — statically re-checked field names against `app_theme.dart`
  (`colorScheme.outline`/`.onSurfaceVariant`, `textTheme.headlineSmall`/`.bodyMedium`). Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/app_shell.dart` — bottom-nav shell wiring the 5 top-level tabs

```dart
class AppShell extends StatefulWidget {
  const AppShell({super.key});
}
```

- New file only, nothing else touched. `Scaffold(body: IndexedStack(index: _selectedIndex,
  children: [...5 screens...]), bottomNavigationBar: NavigationBar(...))` — `IndexedStack` (not
  route replacement) so tabs preserve their state when switching. Default `_selectedIndex = 0`
  (발견·큐레이션 active on launch).
- Tabs 1–4 use the existing `PlaceholderScreen(icon:, title:)` (`Icons.radar`/`Icons.map`/
  `Icons.hiking`/`Icons.route`); tab 5 uses the existing `DiaryListScreen()`. `NavigationBar` has 5
  matching `NavigationDestination`s (same icons + Korean labels), `onDestinationSelected` calls
  `setState` to update `_selectedIndex`.
- **TODO left in code** (`lib/screens/app_shell.dart`, tab 1 of `_tabs`): tab 1 is a temporary
  `PlaceholderScreen` stand-in — a later task should replace it with the real home/discovery
  screen (`lib/screens/discovery_providers.dart`/`lib/models/discovery.dart` already exist as a
  mock data seam for that screen, per the entry below).
- `AppShell` is not yet wired into `lib/main.dart` (`MaterialApp.home` still points at
  `DiaryListScreen()` directly) — out of scope for this task, left for whoever wires navigation.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — statically re-checked constructors: `PlaceholderScreen({icon:, title:})`
  and `DiaryListScreen()` both confirmed against their source files. Pipeline validate stage should
  run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/state/discovery_providers.dart` — new discovery/suitability mock-data provider file (separate from `providers.dart`)

- **Fully new, separate file** — did not touch `lib/models/observation.dart` or
  `lib/state/providers.dart`. Only imports `flutter/material.dart` (for `IconData`/`Icons`),
  `flutter_riverpod`, and `../models/discovery.dart` (models untouched, consumed as-is).
- `obsModeProvider` — `StateProvider<ObsMode>`, default `ObsMode.day`.
- `DiscoveryOverview` (new wrapper class, this file only): `{ SuitabilityIndex suitabilityIndex;
  List<GoldenHour> goldenHours; List<TelemetryReading> telemetry; }`.
- `discoveryProvider` — `Provider<DiscoveryOverview>`. Mock `SuitabilityIndex(score: 88, label:
  '매우 쾌적 · 프라임 등급', sqmValue: 21.6, skyClass: 'Class 2 · 최적 암흑 하늘')`; two `GoldenHour`s
  (day `14:00 - 17:30`, night `21:40 - 01:20`); 4 `TelemetryReading`s using `Icons.waves` (조수),
  `Icons.visibility` (가시거리), `Icons.air` (바람), `Icons.cloud_queue` (구름량).
- `hotspotsProvider` — `Provider<List<Hotspot>>`, exactly 2 mock `Hotspot`s: one `ObsMode.day`
  (탐조/갯벌 copy), one `ObsMode.night` (별자리/다크스카이 copy). Icons for `Hotspot` fields
  (`scoreIcon`/`overlayIcon`/`HotspotMeta.icon`) are placeholders not specified by the models
  contract — free to restyle.
- No new pubspec dependency (`flutter_riverpod` already present).
- Doc comment at top of file marks all providers as a mock seam for the future
  fitness/suitability engine backend API (forward-design note only, no override mechanism yet).
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — statically re-checked every field name/type against
  `lib/models/discovery.dart` (all constructors are `const` with named required params; matched
  exactly). Pipeline validate stage should run
  `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `test/screens/app_shell_test.dart` — new widget test for `AppShell` nav

- New test file only, nothing else touched. Two `testWidgets`, both pump
  `ProviderScope(child: MaterialApp(home: AppShell()))` with no provider overrides (no
  `FakeEcologApi`): (1) asserts 5 `NavigationDestination`s and that `발견·큐레이션` renders
  (`findsWidgets`, not `findsOneWidget` — it's simultaneously the nav label and the initial
  `PlaceholderScreen`'s AppBar/body title); (2) taps `Icons.auto_stories`, `pumpAndSettle`s, and
  asserts `관찰 일지` (the `DiaryListScreen` AppBar title) becomes visible. Deliberately no
  `findsNothing` check on the discovery label — `AppShell` uses `IndexedStack` (all 5 tabs stay
  mounted), and the label also lives permanently in the bottom `NavigationBar`.
- No `ecologApiProvider` override needed for test 2: `DiaryListScreen`'s `AppBar` title renders
  synchronously regardless of `observationsProvider`'s loading/error state, and the real
  `HttpEcologApi` call to `localhost:8000` fails fast (connection refused, not a hang) in the test
  sandbox, so `pumpAndSettle` doesn't time out.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — statically re-checked constructors/strings against
  `lib/screens/app_shell.dart` and `lib/screens/diary_list_screen.dart` (`관찰 일지` AppBar title
  confirmed at `diary_list_screen.dart:19`). Pipeline validate stage should run
  `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/main.dart` — wired `AppShell` as the entry screen

- `lib/main.dart` now imports `screens/app_shell.dart` (was `screens/diary_list_screen.dart`) and
  `MaterialApp.home` is `const AppShell()` (was `const DiaryListScreen()`); no other line touched
  (`ProviderScope`, title, theme/darkTheme/themeMode untouched). Could not run `flutter analyze`/
  `flutter test` in this harness (Bash requires approval) — statically re-checked `AppShell({super.key})`
  is a const-constructible `StatefulWidget` (`lib/screens/app_shell.dart`). Pipeline validate stage
  should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/state/discovery_providers.dart:1` — fixed `unused_shown_name` analyzer warning

- `import 'package:flutter/material.dart' show IconData, Icons;` → `show Icons;` — `IconData` was
  never referenced by name in the file (only `Icons.*` constants, which are typed `IconData` but
  don't require importing the type name itself). One-line change, nothing else touched. Statically
  re-confirmed via grep: no `IconData` reference remains in the file, `Icons.*` usage intact.

## `test/screens/app_shell_test.dart` — fixed real-HTTP-call flake by overriding `ecologApiProvider`

- Both `testWidgets` now pump `ProviderScope(overrides: [ecologApiProvider.overrideWithValue(FakeEcologApi())], child: const MaterialApp(home: AppShell()))`
  (was unoverridden `const ProviderScope(...)`), matching the pattern in
  `test/screens/diary_list_screen_test.dart`. Tab 5's `DiaryListScreen` reads `observationsProvider`
  → `ecologApiProvider` → `HttpEcologApi` by default, which was making a real network call in the
  test sandbox. Added imports `package:lookup/api/ecolog_api.dart` and
  `package:lookup/state/providers.dart`; test names/assertions unchanged (still 2 tests, no
  `findsNothing` added). Could not run `flutter analyze`/`flutter test` in this harness (Bash
  requires approval) — statically confirmed `FakeEcologApi` (`lib/api/ecolog_api.dart:128`) and
  `ecologApiProvider` (`lib/state/providers.dart:12`) exist and match the import paths used.

## `lib/widgets/score_gauge.dart` — new `ScoreGauge` widget (circular score ring)

- New file only, nothing else touched. `ScoreGauge({super.key, required int score, double size = 120})`
  — `StatelessWidget`, const constructor. Usage: `ScoreGauge(score: 88)` or `ScoreGauge(score: 88, size: 160)`.
- Renders via `Stack` (`CustomPaint(size: Size.square(size), painter: _ScoreGaugePainter(...))` +
  centered `Text('$score')`): a full-circle track ring (`colorScheme.surfaceContainerHighest`,
  10px stroke, round cap) then a clockwise progress arc from -pi/2 proportional to `score/100`
  (`colorScheme.secondary`, same stroke/cap). Center text uses
  `textTheme.labelMedium` (JetBrains Mono per `app_theme.dart`) `.copyWith(fontSize: 32,
  fontWeight: FontWeight.bold, color: colorScheme.secondary)`. No new colors, no backend contract
  (pure presentational widget, caller passes `score`).
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  isn't available here) — statically re-checked field names against `app_theme.dart`
  (`colorScheme.surfaceContainerHighest`/`.secondary`, `textTheme.labelMedium`). Pipeline validate
  stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`.

## `lib/screens/home_discovery_screen.dart` — new home/discovery screen (sections 1-3, header + greeting + suitability card)

```dart
class HomeDiscoveryScreen extends ConsumerWidget {
  const HomeDiscoveryScreen({super.key, required this.onViewMapPressed});
  final VoidCallback onViewMapPressed; // stored only, not wired to any button yet
}
```

- New file only. Watches `discoveryProvider` (`DiscoveryOverview`) for the suitability card (`ScoreGauge`
  + label/SQM/sky class + 2 golden-hour tiles keyed off `ObsMode` + horizontal-scroll telemetry row).
  `hotspotsProvider`/`obsModeProvider` are imported (per spec) alongside `discoveryProvider` but not
  yet referenced — reserved for the mode-switcher/hotspot sections a later task appends after the
  trailing `// TODO(phase2-followup): ...` comment at the end of the body `Column`.
- All styling reads `Theme.of(context).colorScheme`/`.textTheme` (per `lib/theme/app_theme.dart`) —
  no raw `Color(...)`, no `google_fonts` import, no `Image.network`.
- Not yet wired into `AppShell`/`main.dart` — out of scope for this task; a later task should swap
  `app_shell.dart`'s tab-1 `PlaceholderScreen` for `HomeDiscoveryScreen(onViewMapPressed: ...)`.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that isn't
  available here) — statically re-checked every field/type against `lib/models/discovery.dart`,
  `lib/state/discovery_providers.dart`, and `lib/widgets/score_gauge.dart`'s `ScoreGauge({score:,
  size:})` constructor. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## `lib/state/discovery_providers.dart` — mock copy aligned to mockup reference

- Content-only pass: replaced the literal Korean/value strings inside `discoveryProvider`'s
  `SuitabilityIndex`/`GoldenHour`s/`TelemetryReading`s and `hotspotsProvider`'s two `Hotspot`s to
  match the mockup reference exactly (강화도 동막갯벌 day hotspot, 영월 별마로 night hotspot). No
  types/fields/structure/imports/icon set changed — same 4 telemetry icons in the same order, same
  2 `HotspotMeta` icons per hotspot. Could not run `flutter analyze` in this harness (Bash requires
  approval); statically re-checked every literal against `lib/models/discovery.dart`'s field types.
  Pipeline validate stage should run `cd apps/flutter && flutter analyze && flutter test`.

## `lib/screens/home_discovery_screen.dart` — section 4: mode switcher (replaced `mode switcher` half of the phase2 TODO)

- Added `final currentMode = ref.watch(obsModeProvider);` right after `overview`, and replaced the
  old `// TODO(phase2-followup): mode switcher + hotspot sections...` comment with the mode-switcher
  UI: a header `Row` (`지금 시선의 초점` + `필터 맞춤 설정` hint) then a pill-shaped `Container` holding two
  `GestureDetector` segments (day/night) that set `ref.read(obsModeProvider.notifier).state`, styled
  off `currentMode == ObsMode.day/night` (`colorScheme.tertiary`/`.secondary` fill,
  `Icons.flutter_dash`/`Icons.star`). Only that one comment line was touched; the trailing
  `// TODO(phase2-followup): hotspot section appended by a later task.` comment remains for the next
  task. Built against the already-imported `../state/discovery_providers.dart` (`obsModeProvider`)
  and `../models/discovery.dart` (`ObsMode`) — no new imports/deps. Could not run `flutter analyze`/
  `flutter test` in this harness (Bash requires approval that isn't available here) — statically
  re-checked brace/comma balance and confirmed `obsModeProvider`/`ObsMode` are already imported.
  Pipeline validate stage should run `cd apps/flutter && flutter analyze && flutter test`.

## `lib/screens/home_discovery_screen.dart:526` — fixed `prefer_interpolation_to_compose_strings` lint

- Replaced `'적합도 ' + hotspot.suitabilityScore.toString() + '점'` with a single interpolated
  literal `'적합도 ${hotspot.suitabilityScore}점'` — same displayed text, no `.toString()` needed
  (interpolation calls it implicitly; keeping it would trigger `unnecessary_string_interpolations`).
  One line changed, nothing else touched. Could not run `flutter analyze` in this harness (Bash
  requires approval that wasn't granted) — pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## `lib/screens/home_discovery_screen.dart` — section 5: hotspot cards (final section, TODO removed)

- Added `final hotspots = ref.watch(hotspotsProvider);` next to `overview`/`currentMode`, and
  replaced the trailing `// TODO(phase2-followup): hotspot section appended by a later task.`
  comment with the "INTEGRATED RADAR" header (`headlineMedium` title + `onViewMapPressed`
  `TextButton` "지도에서 보기 →") followed by a `Column` of one `Card` per `hotspots` entry
  (`AnimatedOpacity` dimmed to 0.45 when `hotspot.mode != currentMode`, else 1.0): 140px gradient
  image block (mode icon, badge `Wrap`, suitability-score chip, bottom overlay strip) + a text body
  (title/subtitle/description, `HotspotMeta` `Wrap`, right-aligned `FilledButton(hotspot.ctaLabel)`,
  `onPressed: () {}` — no navigation wired, out of scope). Cards are wrapped in
  `Padding(bottom: 16)` instead of interleaved `SizedBox`s (equivalent visual gap, trailing 16px
  after the last card is harmless as it's the screen's bottom padding).
- **This completes `HomeDiscoveryScreen(onViewMapPressed)` per spec** — sections 1–5 all present,
  no remaining TODOs. Only this one comment line replaced; sections 1–4 untouched. Built entirely
  against already-imported `../state/discovery_providers.dart` (`hotspotsProvider`) and
  `../models/discovery.dart` (`Hotspot`/`HotspotMeta` field names/types) — no new imports/deps.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  wasn't granted) — statically re-checked every `hotspot.*`/`m.*` field against the `Hotspot`/
  `HotspotMeta` constructors in `lib/models/discovery.dart`, and re-read the full diff for
  brace/paren/comma balance. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## `lib/screens/app_shell.dart` — wired tab 1 to the real `HomeDiscoveryScreen`

- Added `import 'home_discovery_screen.dart';`. Converted `_tabs` from `static const List<Widget>`
  to an instance getter `List<Widget> get _tabs => [...]` (required since the first entry now
  builds a non-const closure). Replaced the old `PlaceholderScreen(icon: Icons.radar, ...)` + its
  preceding TODO comment with `HomeDiscoveryScreen(onViewMapPressed: () => setState(() =>
  _selectedIndex = 1))` — pressing "지도에서 보기" on the home screen now switches to tab index 1 (관찰
  지도). The other 4 entries (`PlaceholderScreen` map/hiking/route + `DiaryListScreen`) are
  unchanged, just individually marked `const` (required since the list literal itself is no longer
  const). `build()`'s `children: _tabs` needed no edit — Dart resolves it to the getter call
  automatically, and `IndexedStack` still preserves all 5 tabs' state across switches.
- Built against `HomeDiscoveryScreen({super.key, required this.onViewMapPressed})` (`ConsumerWidget`,
  `VoidCallback onViewMapPressed`), confirmed by reading `lib/screens/home_discovery_screen.dart:8-11`.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  wasn't granted) — statically re-checked import path, getter conversion (no remaining `const`
  keyword on the list literal itself), and per-item `const` on the 4 unchanged entries. Pipeline
  validate stage should run `cd apps/flutter && flutter analyze && flutter test`.

## `test/screens/home_discovery_screen_test.dart` — new widget test for `HomeDiscoveryScreen`

- New test file only, nothing else touched. Three `testWidgets`, each building its own
  `ProviderContainer` (`addTearDown(container.dispose)`) and pumping
  `UncontrolledProviderScope(container:, child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})))`
  (no `ecologApiProvider` override needed — this screen only reads `discoveryProvider`/
  `hotspotsProvider`/`obsModeProvider`, no `EcologApi`/`observationsProvider` dependency).
- Test 1: asserts `find.text('88')` (score), `'매우 쾌적 (Prime)'` (suitability label), and both
  golden-hour `timeRange`s `'14:00 - 17:30'`/`'21:40 - 01:20'` — all copied verbatim from
  `lib/state/discovery_providers.dart`'s current mock data.
- Test 2: asserts both hotspot `title`s render — `'강화도 동막갯벌 & 여차리 도래지'` (day) and
  `'영월 별마로 & 봉래산 다크스카이'` (night).
- Test 3: reads `container.read(obsModeProvider)` starts `ObsMode.day`, taps
  `find.text('밤의 별을 보러 (천체관측)')` (the night segment's `Flexible` `Text`, confirmed at
  `lib/screens/home_discovery_screen.dart:383`), `pump()`s, then asserts the provider flips to
  `ObsMode.night`.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  wasn't granted) — statically re-checked every literal against the three source files
  (`home_discovery_screen.dart`, `discovery_providers.dart`, `discovery.dart`) rather than
  recalling them from memory. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — model layer for `GET /api/suitability` (data models only, providers/widgets untouched)

- `lib/models/discovery.dart`: added `fromJson` factories to `SuitabilityIndex` (score/label/sqmValue/
  skyClass, no alias), `GoldenHour` (mode via new `obsModeFromApiValue(String)` top-level parser,
  label/timeRange/description), and moved `DiscoveryOverview` here from `discovery_providers.dart`
  (now also `fromJson`, plus a new `degraded` (`bool`) field). Added `ObsModeQueryValue` extension
  with `ObsMode.toQueryValue()` (`'day'`/`'night'`) for building the query string later.
  **Breaking**: `TelemetryReading.icon` (`IconData`) removed, replaced with `kind` (`String`) +
  `fromJson`; `Hotspot`/`HotspotMeta` untouched (still use `IconData`, out of scope).
- `lib/state/discovery_providers.dart`: only the `DiscoveryOverview` class definition (and its doc
  comment) was deleted — it's now imported from `../models/discovery.dart`. Providers themselves
  untouched, so `discoveryProvider`'s mock `TelemetryReading(..., icon: Icons.waves)` calls are now
  a **known, expected compile error** (`icon` param no longer exists) — leave for the next task that
  converts these providers to async/API-backed.
- `lib/config.dart`: added `defaultObservationLat = 37.5921` / `defaultObservationLng = 126.3984`
  (fixed 강화 갯벌 coordinates, pending real GPS integration).
- Built against `apps/backend/.team/member.md` Section 8 (`GET /api/suitability`) — response is flat
  (score/label/sqmValue/skyClass at top level, not nested), `telemetry[].kind` values are
  `sky`/`humidity`/`wind`/`precip`/`tide`, `goldenHours[].mode`/query `mode` param are `"day"`/`"night"`.
- **Known fallout beyond the two files above** (not fixed here, out of this task's lane):
  `lib/screens/home_discovery_screen.dart:302` and `:706` also reference `.icon` on
  `TelemetryReading`/`HotspotMeta` — line 302 (`overview.telemetry[i].icon`) will now fail to compile
  too; line 706 is `HotspotMeta.icon` (still valid, untouched type). The next task wiring this screen
  to live data needs to replace line 302's `Icon(overview.telemetry[i].icon, ...)` with something
  keyed off the new `kind` string.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted) — statically re-checked every field/type against `apps/backend/.team/member.md` Section 8's
  JSON example and re-read the full diff for brace/comma balance. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test` (expect the two known-fallout compile errors
  above until the provider/widget follow-up task lands).

## 2026-09-08 — `lib/api/suitability_api.dart` — new `SuitabilityApi` client (mirrors `ecolog_api.dart`'s abstract+Http+Fake pattern)

```dart
class SuitabilityApiException implements Exception {
  final int statusCode; final String message; // thrown on any non-2xx response
}

abstract class SuitabilityApi {
  Future<DiscoveryOverview> fetchSuitability({required double lat, required double lng, required ObsMode mode});
}
```

- `HttpSuitabilityApi(String baseUrl, {http.Client? client})` — `baseUrl`/`client` fields (same ctor
  shape as `HttpEcologApi`). `fetchSuitability` calls `GET {baseUrl}/api/suitability?lat=<lat.toString()>&lng=<lng.toString()>&mode=<mode.toQueryValue()>`
  (built via `Uri.replace(queryParameters:)`, no manual string concat), `_checkStatus(response, 200)`
  copied verbatim from `ecolog_api.dart` (throws `SuitabilityApiException` with the JSON `detail`
  field or raw body as `message`), then `DiscoveryOverview.fromJson(json.decode(response.body) as Map<String, dynamic>)`.
- `FakeSuitabilityApi({bool degraded = false, bool shouldThrow = false})` — both named, default
  `false`. No HTTP. `fetchSuitability` (still genuinely `async`/`Future`): if `shouldThrow`, throws
  `SuitabilityApiException(500, 'fake failure')`; otherwise returns a deterministic
  `DiscoveryOverview` keyed off the `mode` param — day: `SuitabilityIndex(score: 88, label: '매우
  쾌적 (Prime)', sqmValue: 21.6, skyClass: 'Class 2 최적 다크스카이')`; night: `SuitabilityIndex(score:
  92, label: '천체관측 최적 (Prime)', sqmValue: 21.9, skyClass: 'Class 1 최고 다크스카이')`.
  `goldenHours` is always both entries (day `14:00 - 17:30` / night `21:40 - 01:20`, copied from
  `discovery_providers.dart`'s existing mock strings), regardless of `mode`. `telemetry` is always
  exactly 5 `TelemetryReading`s covering `kind` `sky`/`humidity`/`wind`/`precip`/`tide` (different
  `value` strings per mode). `degraded` echoes the constructor's `degraded` param unchanged.
- Built directly against `lib/models/discovery.dart`'s existing `DiscoveryOverview.fromJson`,
  `SuitabilityIndex`/`GoldenHour`/`TelemetryReading` constructors, and `ObsMode.toQueryValue()`
  extension — no field-name translation, no new model changes.
- New file only; nothing else touched, no new pubspec dependency (`http` already present).
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that
  wasn't granted) — statically re-checked every constructor/field name against
  `lib/models/discovery.dart` and the `_checkStatus`/ctor pattern against `lib/api/ecolog_api.dart`.
  Pipeline validate stage should run `cd apps/flutter && flutter analyze lib/api/suitability_api.dart`
  (isolated) then the full `flutter analyze && flutter test` once the known-fallout compile errors
  in `discovery_providers.dart`/`home_discovery_screen.dart` (noted in the 2026-09-08 model-layer
  entry above) are fixed by the next task.

## 2026-09-08 — verifier fix pass: theme-token literals, telemetry separators, placeholder comments

- `lib/screens/home_discovery_screen.dart`: replaced 4 hardcoded color literals with `colorScheme`
  tokens — mode-switcher day/night segment `Colors.transparent` → `colorScheme.surfaceContainerHigh`
  (matches the parent pill's own fill, visually identical); hotspot bottom overlay strip
  `Colors.black.withValues(alpha: 0.35)` → `colorScheme.scrim.withValues(alpha: 0.35)`, overlay
  `Icon`/`overlayHeadline` `Colors.white` → `colorScheme.onSurface`, `overlayTimestamp`
  `Colors.white70` → `colorScheme.onSurface.withValues(alpha: 0.7)`. File now has zero literal
  `Colors.transparent`/`.black`/`.white`/`.white70` references.
- Same file: telemetry row changed from `overview.telemetry.map(...).toList()` to a `for` loop
  over the index inside `Row.children`, inserting a 1×24 `colorScheme.outlineVariant` divider
  `Container` (4px horizontal margin) between consecutive entries only (`if (i > 0)` guard, none
  before the first or after the last). Every icon/label/value widget per entry unchanged.
- `lib/screens/app_shell.dart`: added one Korean line comment above each of the 3 remaining
  `PlaceholderScreen` tabs (map/hiking/route) noting they're temporary pending mockups 03/04/05
  respectively — no logic/widget changes.
- No other lines touched in either file. Could not run `flutter analyze`/`flutter test` in this
  harness (Bash requires approval that wasn't granted) — statically re-checked both files in full
  for brace/comma balance and confirmed no leftover `Colors.*` literals via grep. Pipeline validate
  stage should run `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — `discoveryProvider` switched from hardcoded `Provider` to live `AsyncNotifierProvider`

- `lib/state/discovery_providers.dart`: added `suitabilityApiProvider = Provider<SuitabilityApi>((ref) => HttpSuitabilityApi(defaultApiBaseUrl))`;
  deleted the hardcoded `discoveryProvider = Provider<DiscoveryOverview>(...)` block and replaced it with:
  ```dart
  class DiscoveryNotifier extends AsyncNotifier<DiscoveryOverview> {
    @override
    Future<DiscoveryOverview> build() async {
      final mode = ref.watch(obsModeProvider);
      final api = ref.watch(suitabilityApiProvider);
      return api.fetchSuitability(lat: defaultObservationLat, lng: defaultObservationLng, mode: mode);
    }
  }
  final discoveryProvider = AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>(DiscoveryNotifier.new);
  ```
  `discoveryProvider` is now `AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>` — `ref.watch(discoveryProvider)`
  returns `AsyncValue<DiscoveryOverview>`, not a bare `DiscoveryOverview`. It re-fetches automatically whenever
  `obsModeProvider` changes (via `ref.watch` inside `build()`). `obsModeProvider`/`hotspotsProvider` untouched —
  same `StateProvider<ObsMode>` / `Provider<List<Hotspot>>` as before.
- Built against `lib/api/suitability_api.dart`'s existing `SuitabilityApi`/`HttpSuitabilityApi` contract
  (`Future<DiscoveryOverview> fetchSuitability({required double lat, required double lng, required ObsMode mode})`)
  and `lib/config.dart`'s `defaultApiBaseUrl`/`defaultObservationLat`/`defaultObservationLng` — no new files, no pubspec changes.
- **Known fallout, out of this task's lane**: `lib/screens/home_discovery_screen.dart:17` does
  `final overview = ref.watch(discoveryProvider);` then reads `overview.suitabilityIndex`/`.goldenHours`/`.telemetry`
  directly — this now fails to compile since `overview` is `AsyncValue<DiscoveryOverview>`, not `DiscoveryOverview`.
  This is on top of the pre-existing `.icon`/`TelemetryReading.kind` fallout already noted in the 2026-09-08
  model-layer entry above. The next widget task needs `overview.when(data: ..., loading: ..., error: ...)`
  (or `.value`) to unwrap it, plus the `kind`-based icon fix.
- `test/screens/home_discovery_screen_test.dart` (noted earlier in this file) builds its own
  `ProviderContainer` without overriding `discoveryProvider`/`suitabilityApiProvider`, so it will now try a real
  `HttpSuitabilityApi` HTTP call against `localhost:8000` instead of reading the old mock — will fail/hang
  without a test override. Next task should override `suitabilityApiProvider` with `FakeSuitabilityApi` (already
  defined in `lib/api/suitability_api.dart`) in that test's `ProviderContainer`.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't granted;
  this role's tool set is Read/Grep/Glob/Edit/Write only, no Bash) — statically re-checked the diff (imports,
  class/provider syntax, brace balance) and traced every other reference to `discoveryProvider` in the repo via
  grep. Pipeline validate stage should run `cd apps/flutter && flutter analyze && flutter test`
  (expect the `home_discovery_screen.dart`/its test to fail until the next widget-wiring task lands).

## 2026-09-08 — `lib/screens/home_discovery_screen.dart` — render `AsyncValue<DiscoveryOverview>` (loading/error/data) + `kind`→icon mapping

- Line 17: `final overview = ref.watch(discoveryProvider);` → `final overviewAsync = ref.watch(discoveryProvider);`
  (unwrapped type is now `AsyncValue<DiscoveryOverview>`, per the previous entry's known fallout).
  `currentMode`/`hotspots` watches untouched.
- Added new private top-level function `IconData _iconForTelemetryKind(String kind)` at the bottom of
  the file (below the class): switches on `kind` (`'sky'`→`Icons.wb_sunny`, `'humidity'`→
  `Icons.water_drop`, `'wind'`→`Icons.air`, `'precip'`→`Icons.grain`, `'tide'`→`Icons.waves`,
  **`default`→`Icons.help_outline`**). Telemetry row's `Icon(overview.telemetry[i].icon, ...)` →
  `Icon(_iconForTelemetryKind(overview.telemetry[i].kind), ...)`.
- The suitability-card `Container`'s `child` is now `overviewAsync.when(data:, loading:, error:)`:
  - `data: (overview)` — unchanged ScoreGauge/golden-hour/telemetry `Column` content (just the icon
    fix above), plus a new degraded-only warning banner **prepended above the ScoreGauge row**: only
    rendered `if (overview.degraded)` (else `const SizedBox.shrink()`), fixed Korean copy exactly
    **`'일부 데이터를 불러오지 못했어요'`**, `Container` (8/12 padding, `colorScheme.errorContainer` bg, 8px
    radius) with `Icons.warning_amber_rounded` + `Text` both in `colorScheme.onErrorContainer`,
    12px bottom margin before the score row.
  - `loading: ()` — `SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))`, no
    other content.
  - `error: (err, st)` — fixed Korean copy exactly **`'적합도 정보를 불러오지 못했어요'`** (raw
    `err`/exception message is never interpolated into the UI), then a retry
    `ElevatedButton(onPressed: () => ref.invalidate(discoveryProvider), child: Text('다시 시도'))`
    (retry button label exactly **`'다시 시도'`**).
- Header/greeting/mode-switcher/hotspot-cards sections untouched — none of them read `overview`.
- **Known fallout, out of this task's lane**: `test/screens/home_discovery_screen_test.dart` still
  builds its `ProviderContainer` without overriding `suitabilityApiProvider`, so it will attempt a
  real `HttpSuitabilityApi` HTTP call instead of using `FakeSuitabilityApi` — needs
  `suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi(...))` per test, plus updated
  assertions for the loading/error/degraded states this task added (exact strings to reuse are
  quoted above: warning banner `'일부 데이터를 불러오지 못했어요'`, error text `'적합도 정보를 불러오지
  못했어요'`, retry button `'다시 시도'`, icon fallback function name `_iconForTelemetryKind`).
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted; this role's tool set is Read/Grep/Glob/Edit/Write only, no Bash) — statically re-checked
  the diff (imports already present: `flutter/material.dart` for `Icons`/`IconData`/
  `CircularProgressIndicator`/`ElevatedButton`; `AsyncValue.when` signature `data`/`loading`/`error`
  matches `flutter_riverpod`'s API used elsewhere in this repo, e.g. `diary_list_screen.dart`) and
  traced every `overview.*` reference inside the `data:` branch to confirm none escaped outside the
  `when(...)`. Pipeline validate stage should run `cd apps/flutter && flutter analyze && flutter test`
  (expect `home_discovery_screen_test.dart` to fail/hang until the fallout above is fixed).

## 2026-09-08 — `test/screens/home_discovery_screen_test.dart` — fixed the async-`discoveryProvider` fallout noted above

- Fixes exactly the fallout flagged in the previous two entries: `discoveryProvider` is now
  `AsyncNotifierProvider<DiscoveryNotifier, DiscoveryOverview>` (real `HttpSuitabilityApi` call by
  default), so the test's `ProviderContainer` needed an override plus a `pump()` to await the async
  `build()`.
- Added `import 'package:lookup/api/suitability_api.dart';`. All three `ProviderContainer(...)`
  constructions now pass `overrides: [suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi())]`
  (`suitabilityApiProvider` imported from `discovery_providers.dart`, already imported in the file).
- Added one `await tester.pump();` right after each `await tester.pumpWidget(...)` in all three tests,
  so the `AsyncNotifier.build()` Future (no real delay in `FakeSuitabilityApi`, resolves on the next
  microtask) completes before assertions run. Test 3 (tap → mode switch) needed a second `pump()`
  after the tap's `pump()`: the tap flips `obsModeProvider`, which `discoveryProvider.build()` watches,
  triggering a re-fetch that needs its own frame to resolve.
- Same 3 `testWidgets`, same assertions, no new test cases added (per task scope) — `find.text('88')`/
  `'매우 쾌적 (Prime)'`/`'14:00 - 17:30'`/`'21:40 - 01:20'` (test 1), both hotspot titles (test 2,
  `hotspotsProvider` still sync mock, untouched), `obsModeProvider` day→night after tap (test 3).
  Values verified against `FakeSuitabilityApi`'s day-mode branch in `lib/api/suitability_api.dart`
  (score 88/label/golden-hours are mode-independent constants) rather than assumed from memory.
- Could not run `flutter test` in this harness (Bash requires approval that wasn't granted; this
  role's tool set is Read/Grep/Glob/Edit/Write only, no Bash) — statically re-checked every literal/
  override against `lib/api/suitability_api.dart` and `lib/state/discovery_providers.dart`, and
  reasoned through the microtask timing (`FakeSuitabilityApi.fetchSuitability` has no `Future.delayed`,
  so a single `pump()` flushes it). Pipeline validate stage should run
  `cd apps/flutter && flutter test test/screens/home_discovery_screen_test.dart`.

## 2026-09-08 — `test/suitability_wiring_test.dart` — new dedicated test file, 5 wiring states + kind→icon coverage

- New file only, nothing else touched. Private helper `_pumpHome(tester, {required SuitabilityApi api})`
  builds a `ProviderContainer(overrides: [suitabilityApiProvider.overrideWithValue(api)])`, pumps
  `UncontrolledProviderScope(container:, child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})))`
  (same pattern as `home_discovery_screen_test.dart`), returns the container.
- 5 independent `testWidgets` + 1 `group` test for icon coverage:
  1. **data**: `FakeSuitabilityApi()` + one `pump()` → asserts `'88'`/`'매우 쾌적 (Prime)'`/
     `'14:00 - 17:30'`/`'21:40 - 01:20'` render, plus `find.byIcon(Icons.wb_sunny)` (sky telemetry icon).
  2. **mode toggle**: starts day (`'88'`/`'매우 쾌적 (Prime)'`), taps `'밤의 별을 보러 (천체관측)'`, 3×
     `pump()` (one extra beyond the existing 2-pump pattern, as safety margin since this harness
     couldn't execute the suite to confirm exact settle timing), asserts day text is gone
     (`findsNothing`) and night values `'92'`/`'천체관측 최적 (Prime)'` render. Confirmed no text
     collision: `ScoreGauge` renders the score as a standalone `Text('$score')`
     (`lib/widgets/score_gauge.dart:33`), distinct from the hotspot card's `'적합도 92점'` string, so
     `find.text('92')` only matches the score gauge.
  3. **loading**: `_pumpHome` only (no extra `pump()` after the implicit pumpWidget pump) → asserts
     `find.byType(CircularProgressIndicator)` before the fake fetch's microtask resolves.
  4. **error**: `FakeSuitabilityApi(shouldThrow: true)` + `pump()` → asserts fixed copy
     `'적합도 정보를 불러오지 못했어요'` and `'다시 시도'` button render, and raw exception strings
     (`'fake failure'`, `'SuitabilityApiException'`) do **not** appear anywhere
     (`find.textContaining(...)`, `findsNothing`).
  5. **degraded**: `FakeSuitabilityApi(degraded: true)` + `pump()` → asserts banner
     `'일부 데이터를 불러오지 못했어요'` renders.
  6. **kind→icon coverage** (`group`): day-mode `FakeSuitabilityApi()` + `pump()` → asserts all 5
     mapped icons render exactly once: `Icons.wb_sunny` (sky), `Icons.water_drop` (humidity),
     `Icons.air` (wind), `Icons.grain` (precip), `Icons.waves` (tide) — confirms
     `FakeSuitabilityApi`'s telemetry list covers all 5 `kind`s `_iconForTelemetryKind` handles
     (`lib/screens/home_discovery_screen.dart:811-826`). `_iconForTelemetryKind` itself is a private
     top-level function so it's verified indirectly through rendered icons, not called directly, per
     task instructions.
- All literals (score/label/golden-hour times, Korean copy, icon mappings) copied verbatim from
  `lib/api/suitability_api.dart` (`FakeSuitabilityApi`), `lib/screens/home_discovery_screen.dart`
  (banner/error/retry copy, `_iconForTelemetryKind` switch), and `lib/state/discovery_providers.dart`
  (`suitabilityApiProvider`) — read directly from source, not recalled from memory.
- Could not run `flutter test` in this harness — this role's tool set is Read/Grep/Glob/Edit/Write
  only (no Bash access; every `Bash` call in this session returned "requires approval" with no way
  to grant it). Statically re-verified every string/type/signature against the 4 source files above.
  Pipeline validate stage (or the user) should run:
  `cd apps/flutter && flutter test test/suitability_wiring_test.dart`

## 2026-09-08 — `test/suitability_wiring_test.dart:6` — fixed `unused_import` analyzer warning

- Removed `import 'package:lookup/models/discovery.dart';` — no symbol from that file (e.g.
  `ObsMode`, `DiscoveryOverview`) is referenced by name anywhere in this test file; they're only
  exercised indirectly through `HomeDiscoveryScreen`'s rendering. One line deleted, nothing else
  touched. Could not run `flutter analyze` in this harness (Bash requires approval that wasn't
  granted) — grepped the file for `discovery.dart`/`DiscoveryOverview`/`ObsMode` and confirmed no
  remaining references. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze test/suitability_wiring_test.dart`.

## 2026-09-08 — `lib/screens/home_discovery_screen.dart` — fixed `RangeError` when `goldenHours` has fewer than 2 entries

- Golden-hours `Row` previously did `List.generate(2, (i) { final gh = overview.goldenHours[i];
  ... })` — hardcoded exactly 2 entries, so it threw a `RangeError` whenever the real backend
  returned fewer than 2 `goldenHours`. Per `apps/backend/.team/member.md` section 8, the array can
  be empty or have just 1 entry depending on `mode` (astronomy emits no golden hours in day mode;
  only tide emits day golden hours).
- Changed to `List.generate(overview.goldenHours.length, (i) { ... })`, keeping the existing margin
  logic (`left: i == 0 ? 0 : 8`, `right: i == overview.goldenHours.length - 1 ? 0 : 8`) unchanged —
  it already derived from the list length rather than the hardcoded `2`, so it now safely renders
  0, 1, or more golden-hour entries.
- No other lines touched in this section; no model/provider/API changes.

## 2026-09-08 — `lib/services/location_service.dart` — new `LocationService` abstraction (phase 1 of GPS spec, scaffolding only)

- New file only. Also touched: `pubspec.yaml` (two new deps, added right after `flutter_riverpod:
  ^2.6.1`), `ios/Runner/Info.plist` (one new key pair after `LSRequiresIPhoneOS`), `lib/config.dart`
  (one new const appended). **Did not touch** `lib/state/discovery_providers.dart` or
  `lib/screens/home_discovery_screen.dart` — wiring this into the discovery flow is a later phase.
- New pubspec dependencies: `geolocator: ^13.0.0`, `geocoding: ^3.3.1`.
- `ios/Runner/Info.plist`: added `NSLocationWhenInUseUsageDescription` = `관측 적합도를 현재 위치 기준으로
  계산하기 위해 위치를 사용합니다`. No Android manifest touched (out of scope for this task — Android
  permission wiring is not part of the 4 deliverables).
- `lib/config.dart`: added `const String fallbackPlaceName = '강화·서해안';` below
  `defaultObservationLng`; the two existing constants are byte-for-byte unchanged.
- Verbatim contract for later phases to quote:
  ```dart
  class ObservationLocation {
    const ObservationLocation({
      required double lat,
      required double lng,
      required String? placeName,
      required bool isFallback,
    });
    final double lat;
    final double lng;
    final String? placeName;
    final bool isFallback;
  }

  abstract class LocationService {
    Future<ObservationLocation> currentLocation();
  }

  class FakeLocationService implements LocationService {
    FakeLocationService(this.location); // positional, required
    final ObservationLocation location;
  }
  ```
- `GeolocatorLocationService implements LocationService`: `currentLocation()` never throws — every
  failure path (`Geolocator.isLocationServiceEnabled()` false; `checkPermission()`/
  `requestPermission()` resolving to `denied`/`deniedForever`; any exception from
  `Geolocator.getCurrentPosition()`) returns the fixed fallback `ObservationLocation(lat:
  defaultObservationLat, lng: defaultObservationLng, placeName: null, isFallback: true)` from
  `config.dart`. On a successful position fix, `placemarkFromCoordinates(lat, lng)` is wrapped in its
  own try/catch; on failure or an empty placemark list, returns `ObservationLocation(lat:
  position.latitude, lng: position.longitude, placeName: null, isFallback: false)`. On success,
  `placeName` is built by joining, with `·`, whichever of `administrativeArea`/`locality`/
  `subLocality` (checked in that priority order) are non-null/non-empty on the first placemark —
  `null` if none qualify — returned as `ObservationLocation(lat: position.latitude, lng:
  position.longitude, placeName: <built>, isFallback: false)`.
- Could not run `flutter pub get`/`flutter analyze`/`flutter test` in this harness (Read/Grep/Glob/
  Edit/Write only, no Bash) — statically re-checked the `geolocator` 13.x API (`Position.latitude`/
  `.longitude`, `LocationPermission.denied`/`.deniedForever`, `Geolocator.getCurrentPosition()` takes
  no required args) and `geocoding` 3.x API (`placemarkFromCoordinates(lat, lng) ->
  Future<List<Placemark>>`, `Placemark.administrativeArea`/`.locality`/`.subLocality`) against the
  package docs/pattern already used by `SuitabilityApi` in `lib/api/suitability_api.dart`. Pipeline
  validate stage should run `cd apps/flutter && flutter pub get && flutter analyze && flutter test`
  (new deps require `pub get` before `analyze` will resolve `package:geolocator`/`package:geocoding`).

## 2026-09-08 — `pubspec.yaml` — version-pin fix: `geocoding: ^3.3.1` → `^5.0.0`

- `flutter pub get` failed (`geocoding ^3.3.1` doesn't resolve). Bumped the pin to `^5.0.0` per
  `flutter pub add geocoding:^5.0.0`'s suggestion; `geolocator: ^13.0.0` and everything else in the
  file untouched. The `placemarkFromCoordinates`/`Placemark.administrativeArea`/`.locality`/
  `.subLocality` API consumed in `lib/services/location_service.dart` is unchanged across this bump,
  so no other file needed edits.

## 2026-09-08 — `lib/services/location_service.dart` — fixed compile error from geocoding v3→v5 API shape change

- The previous entry's version bump (`geocoding ^3.3.1` → `^5.0.0`) silently broke
  `currentLocation()`: v5 removed the top-level `placemarkFromCoordinates(lat, lng)` function that
  v3 exported — reverse geocoding now goes through an instance method on a new `Geocoding` class.
  `await placemarkFromCoordinates(position.latitude, position.longitude)` → `await
  Geocoding().placemarkFromCoordinates(position.latitude, position.longitude)` (one-line change,
  constructed inline, no new field). `Placemark.administrativeArea`/`.locality`/`.subLocality` (all
  `String?`) are unchanged in the v5 platform-interface type, so the fallback-building logic right
  below needed no edits.
- Verified against the installed package source (not memory):
  `~/.pub-cache/hosted/pub.dev/geocoding-5.0.0/lib/geocoding.dart` (`Geocoding.placemarkFromCoordinates
  (double, double, {Locale? locale}) -> Future<List<pi.Placemark>>`, `Placemark` re-exported via
  `export 'package:geocoding_platform_interface/...'`, so the existing
  `import 'package:geocoding/geocoding.dart';` stays live/used — no `unused_import` once the call
  site references `Geocoding`) and
  `~/.pub-cache/hosted/pub.dev/geocoding_platform_interface-5.0.0/lib/src/types/placemark.dart`
  (confirms `administrativeArea`/`locality`/`subLocality` field names/types unchanged).
- Could not run `flutter analyze`/`flutter test` in this harness (Read/Grep/Glob/Edit/Write only, no
  Bash access). Pipeline validate stage should run
  `cd apps/flutter && flutter analyze lib/services/location_service.dart` (expect 0 issues) then the
  full `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — `lib/state/discovery_providers.dart` — phase 2a: wired `locationProvider` into `discoveryProvider` (spec 007, GPS location)

- Only this file touched (per task scope) — `lib/screens/home_discovery_screen.dart` deliberately
  left untouched, a later task wires the location label there. Added
  `import '../services/location_service.dart';`.
- New, verbatim (next task should quote these, not re-derive):
  ```dart
  final locationServiceProvider = Provider<LocationService>((ref) {
    return GeolocatorLocationService();
  });

  class LocationNotifier extends AsyncNotifier<ObservationLocation> {
    @override
    Future<ObservationLocation> build() async {
      final service = ref.watch(locationServiceProvider);
      return service.currentLocation();
    }

    Future<void> refresh() async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref.read(locationServiceProvider).currentLocation(),
      );
    }
  }

  final locationProvider =
      AsyncNotifierProvider<LocationNotifier, ObservationLocation>(
    LocationNotifier.new,
  );
  ```
  `ref.watch(locationProvider)` returns `AsyncValue<ObservationLocation>`;
  `ref.read(locationProvider.notifier).refresh()` forces a re-fetch (sets `AsyncLoading` first, then
  `AsyncValue.guard`s a fresh `currentLocation()` call — mirrors `ObservationsNotifier._refresh()`'s
  `AsyncValue.guard` pattern in `lib/state/providers.dart:47`).
- `DiscoveryNotifier.build()` changed from the hardcoded `defaultObservationLat`/`defaultObservationLng`
  to `final location = await ref.watch(locationProvider.future);` then
  `api.fetchSuitability(lat: location.lat, lng: location.lng, mode: mode)` — `discoveryProvider` now
  transitively re-fetches whenever `locationProvider`'s resolved value changes (GPS fix arrives, or
  `refresh()` is called), in addition to the existing `obsModeProvider` dependency.
  `obsModeProvider`/`suitabilityApiProvider`/`hotspotsProvider` bodies/signatures untouched.
  `defaultObservationLat`/`defaultObservationLng` are no longer referenced in this file (still used
  internally by `GeolocatorLocationService`'s fallback in `location_service.dart`), but the
  `../config.dart` import stays — `defaultApiBaseUrl` (used by `suitabilityApiProvider`) is still
  imported from it.
- Built directly against `lib/services/location_service.dart`'s existing contract (read, not
  redefined): `ObservationLocation({required lat, required lng, required placeName, required
  isFallback})`, `abstract class LocationService { Future<ObservationLocation> currentLocation(); }`,
  `GeolocatorLocationService()` (no-arg, never throws), `FakeLocationService(location)` (positional —
  for the next task's tests, override via
  `locationServiceProvider.overrideWithValue(FakeLocationService(ObservationLocation(...)))`).
- **Known fallout, out of this task's lane**: `test/suitability_wiring_test.dart` and
  `test/screens/home_discovery_screen_test.dart` build `ProviderContainer`s that override
  `suitabilityApiProvider` but not `locationServiceProvider` — `discoveryProvider.build()` now also
  awaits `locationProvider.future`, which by default resolves via the real
  `GeolocatorLocationService` (falls back safely to `defaultObservationLat/Lng` rather than throwing
  in a headless test environment, so tests likely still pass, but this is unverified without running
  the suite). The next task touching those test files should add
  `locationServiceProvider.overrideWithValue(FakeLocationService(...))` to each `ProviderContainer`
  for determinism.
- Could not run `flutter analyze`/`flutter test` in this harness (Read/Grep/Glob/Edit/Write only, no
  Bash access) — statically re-checked every field/type against `lib/services/location_service.dart`
  and matched the `AsyncNotifier`/`AsyncValue.guard` syntax exactly against `DiscoveryNotifier` (same
  file) and `ObservationsNotifier._refresh()` (`lib/state/providers.dart:46-51`). Pipeline validate
  stage should run `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — test fix: `locationServiceProvider` override added to all 3 test files broken by Phase 2

- Closes the "known fallout" flagged in the entry directly above. Test-only pass, no `lib/` file
  touched. Added `import 'package:lookup/services/location_service.dart';` plus a
  `locationServiceProvider.overrideWithValue(FakeLocationService(const ObservationLocation(lat:
  37.5921, lng: 126.3984, placeName: null, isFallback: true)))` entry to every
  `ProviderContainer`/`ProviderScope` that builds `HomeDiscoveryScreen` directly or via `AppShell`:
  `test/suitability_wiring_test.dart` (the shared `_pumpHome` helper — covers all 6 `testWidgets`),
  `test/screens/home_discovery_screen_test.dart` (all 3 `ProviderContainer`s), and
  `test/screens/app_shell_test.dart` (both `ProviderScope`s — this file also needed a new
  `package:lookup/state/discovery_providers.dart` import since it didn't previously import the file
  that defines `locationServiceProvider`).
- No test names or `expect(...)` assertions changed anywhere.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted, tried repeatedly) — statically re-checked: `locationServiceProvider` is
  `Provider<LocationService>` in `lib/state/discovery_providers.dart:22`; `FakeLocationService`/
  `ObservationLocation` constructors confirmed against `lib/services/location_service.dart:8-19,94-101`.
  Pipeline validate stage should run `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — `lib/screens/home_discovery_screen.dart` — phase 2b: dynamic top-right location label (spec 007, GPS location)

- Only this file touched. Added `import '../config.dart';` (for `fallbackPlaceName`) and, alongside
  the existing `overviewAsync`/`currentMode`/`hotspots` watches, `final locationAsync =
  ref.watch(locationProvider);` then computed the label as:
  ```dart
  final locationLabel = locationAsync.when(
    data: (loc) => loc.placeName ?? fallbackPlaceName,
    loading: () => '위치 확인 중',
    error: (_, __) => fallbackPlaceName,
  );
  ```
  The error branch never renders the raw exception — it always resolves to the `fallbackPlaceName`
  string (`'강화·서해안'`).
- Replaced the old `const Text('강화·서해안')` in the top-right pill `Row` with
  `Flexible(child: Text(locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis))`, keeping the
  surrounding `Icon(Icons.explore)`/`Icon(Icons.keyboard_arrow_down)` and `Row` structure unchanged.
  Subtitle text `' | 강화 · 영월 실시간 기상망'` (line ~95, LIVE FIELD TELEMETRY row) was left untouched
  as instructed — out of this task's scope.
- **For Phase 3's widget test**: assert against `locationLabel`'s three possible rendered strings —
  `loc.placeName` when non-null, else `'위치 확인 중'` while `locationProvider` is loading, else
  `fallbackPlaceName` (`'강화·서해안'`, from `../config.dart`) on error. The screen now watches
  `locationProvider` (`AsyncNotifierProvider<LocationNotifier, ObservationLocation>` from
  `lib/state/discovery_providers.dart`), so tests must override `locationServiceProvider` (see the
  two entries directly above) for deterministic `placeName` values.
- Could not run `flutter analyze`/`flutter test` in this harness (Read/Grep/Glob/Edit/Write only, no
  Bash access) — statically re-checked `locationProvider`'s `AsyncValue<ObservationLocation>` type and
  `ObservationLocation.placeName` (`String?`) against `lib/state/discovery_providers.dart:41` and
  `lib/services/location_service.dart`, and confirmed `fallbackPlaceName` exists at
  `lib/config.dart:11`. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — `test/location_wiring_test.dart` — phase 3: new widget test for the location label (spec 007, GPS location)

- New test file only, nothing else touched. Local `_pumpHome(tester, {required ObservationLocation
  location})` helper mirrors `suitability_wiring_test.dart`'s pattern (`ProviderContainer(overrides:
  [suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
  locationServiceProvider.overrideWithValue(FakeLocationService(location))])`,
  `addTearDown(container.dispose)`, `pumpWidget(UncontrolledProviderScope(container:, child:
  MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {}))))`).
- Three `testWidgets`: (1) `placeName: '해운대구'` + one `pump()` → asserts `find.text('해운대구')`
  (`findsOneWidget`) and `find.text(fallbackPlaceName)` (`findsNothing`), proving the real place name
  wins over the fallback; (2) `placeName: null, isFallback: true` + one `pump()` → asserts
  `find.text(fallbackPlaceName)` (imported from `package:lookup/config.dart`, not hardcoded)
  `findsOneWidget`; (3) same location as test 1 but **no** `pump()` call after the implicit
  `pumpWidget` pump (mirrors `suitability_wiring_test.dart`'s loading-state test) → asserts
  `find.text('위치 확인 중')` findsOneWidget.
- Built against `home_discovery_screen.dart:22-25`'s `locationLabel = locationAsync.when(data: (loc)
  => loc.placeName ?? fallbackPlaceName, loading: () => '위치 확인 중', error: (_, _) =>
  fallbackPlaceName)` (confirmed by reading the file, not from memory) and the
  `locationServiceProvider`/`FakeLocationService`/`ObservationLocation` contracts noted in the two
  entries above.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted, tried repeatedly) — statically re-checked every import path, constructor, and string
  literal against the four source files read for this task
  (`suitability_wiring_test.dart`, `location_service.dart`, `discovery_providers.dart`, `config.dart`,
  `home_discovery_screen.dart`). Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — `lib/services/location_service.dart` — review fix: two never-throw violations in `GeolocatorLocationService.currentLocation()`

- Defect 1: the `isLocationServiceEnabled()` / `checkPermission()` / `requestPermission()` block
  (previously bare, before the existing `getCurrentPosition()` try/catch) is now wrapped in its own
  `try { ... } catch (_) { return _fallback; }`, matching the pattern already used for
  `getCurrentPosition()` and the geocoding call — any exception from those three Geolocator calls
  now resolves to `_fallback` instead of propagating out of `currentLocation()`.
- Defect 2: the reverse-geocoding catch block (`Geocoding().placemarkFromCoordinates(...)`) no
  longer does `placeName = null;` and falls through to the real-GPS success return — it now does
  `return _fallback;` directly, so a geocoding failure returns the fixed fallback coordinates with
  `isFallback: true` instead of leaking real GPS coordinates with `isFallback: false`.
- Only `lib/services/location_service.dart` touched (2 blocks); `ObservationLocation`,
  `LocationService`, `FakeLocationService`, and the geocoding success-path return are untouched.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted) — statically re-checked the diff (brace balance, `_fallback` still resolves as the
  existing static field, no unused locals introduced). Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.

## 2026-09-08 — test-coverage fix: `FakeSuitabilityApi.onFetchSuitability` hook + `location_wiring_test.dart` coordinate assertions

- `lib/api/suitability_api.dart`: added `final void Function(double lat, double lng)? onFetchSuitability`
  field to `FakeSuitabilityApi` (new optional named ctor param, default `null`). `fetchSuitability()`
  now calls `onFetchSuitability?.call(lat, lng);` as the unconditional first line, before the
  `shouldThrow` check, so callers can observe the coordinates on every call including the throwing
  path. Fully backward-compatible — `FakeSuitabilityApi()` / `FakeSuitabilityApi(degraded: true)` at
  existing call sites (`suitability_wiring_test.dart`, `home_discovery_screen_test.dart`, both
  untouched) keep compiling/behaving identically since the field defaults to `null`.
- `test/location_wiring_test.dart`: `_pumpHome` gained an optional
  `void Function(double lat, double lng)? onFetchSuitability` param, forwarded into the
  `FakeSuitabilityApi` it constructs. The two location-resolution tests (`permission granted with
  place name...` / `permission denied falls back...`) now pass a closure capturing `lat`/`lng` into
  local nullable doubles, add a second `tester.pump()` for the async `discoveryProvider` chain to
  resolve, and assert the captured coordinates equal the test's `ObservationLocation` (35.1/129.0 and
  37.5921/126.3984 respectively) — closing the gap where only rendered label text was asserted, never
  that the resolved/fallback coordinates actually reached suitability fetching. Third test (loading
  placeholder) and all existing `find.text(...)` assertions untouched.
- No backend contract involved — this is a test-observability-only change to the in-memory fake.
- Could not run `flutter analyze`/`flutter test` in this harness (Bash requires approval that wasn't
  granted, tried repeatedly) — statically re-checked the diff: new field/param types match, default
  `null` preserves existing call-site behavior, `onFetchSuitability?.call(lat, lng)` placement is
  before `shouldThrow`, and the two edited tests' closures/assertions align with the `ObservationLocation`
  literals already in each test. Pipeline validate stage should run
  `cd apps/flutter && flutter analyze && flutter test`.
