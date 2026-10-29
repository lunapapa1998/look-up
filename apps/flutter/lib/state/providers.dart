import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/demo/fallback_apis.dart';
import '../api/ecolog_api.dart';
import '../config.dart';
import '../models/observation.dart';
import 'sample_data_provider.dart';

/// The [EcologApi] implementation used throughout the app.
///
/// Defaults to [HttpEcologApi] against [defaultApiBaseUrl]. Override via
/// `ProviderScope(overrides: [ecologApiProvider.overrideWithValue(...)])`
/// in tests, e.g. with `FakeEcologApi`. With [demoFallbackEnabled], wrapped
/// in [FallbackEcologApi] so writes fall back to an on-device store.
final ecologApiProvider = Provider<EcologApi>((ref) {
  final api = HttpEcologApi(defaultApiBaseUrl);
  if (!demoFallbackEnabled) return api;
  return FallbackEcologApi(primary: api, reporter: sampleReporterFor(ref));
});

/// Observation list as async state (loading/error/data), backed by
/// [EcologApi.listObservations]. Mutating methods call the API then
/// re-fetch the list, and invalidate [badgesProvider] so badge progress
/// stays in sync.
final observationsProvider =
    AsyncNotifierProvider<ObservationsNotifier, List<Observation>>(
  ObservationsNotifier.new,
);

class ObservationsNotifier extends AsyncNotifier<List<Observation>> {
  @override
  Future<List<Observation>> build() {
    return ref.read(ecologApiProvider).listObservations();
  }

  Future<void> createObservation(ObservationCreate body) async {
    await ref.read(ecologApiProvider).createObservation(body);
    await _refresh();
  }

  Future<void> updateObservation(int id, ObservationUpdate body) async {
    await ref.read(ecologApiProvider).updateObservation(id, body);
    await _refresh();
  }

  Future<void> deleteObservation(int id) async {
    await ref.read(ecologApiProvider).deleteObservation(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(ecologApiProvider).listObservations(),
    );
    ref.invalidate(badgesProvider);
  }
}

/// Badge progress as async state, backed by [EcologApi.listBadges].
/// Invalidated whenever [ObservationsNotifier] creates, updates, or
/// deletes an observation, so it stays in sync with the observation list.
final badgesProvider = FutureProvider<List<BadgeProgress>>((ref) {
  return ref.watch(ecologApiProvider).listBadges();
});
