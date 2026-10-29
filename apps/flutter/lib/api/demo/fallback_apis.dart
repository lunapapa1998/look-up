import '../../models/discovery.dart';
import '../../models/observation.dart';
import '../../models/observation_map.dart';
import '../../models/region.dart';
import '../../models/species.dart';
import '../../models/starlight_forecast.dart';
import '../../models/tide.dart';
import '../../models/trails.dart';
import '../ecolog_api.dart';
import '../observation_map_api.dart';
import '../regions_api.dart';
import '../species_api.dart';
import '../starlight_api.dart';
import '../suitability_api.dart';
import '../tide_api.dart';
import '../trails_api.dart';
import 'sample_data.dart';

/// Which API a sample response stood in for. Recorded in Riverpod state by
/// `sampleSourcesProvider` (see `lib/state/sample_data_provider.dart`).
enum SampleSource {
  suitability,
  starlight,
  observationMap,
  trails,
  regions,
  tide,
  species,
  ecolog,
}

/// Callback pair the `Fallback*Api` wrappers use to report whether a call
/// was served by the real API ([onReal]) or by sample data ([onSample]).
/// Plain callbacks so the api layer never imports Riverpod.
class SampleSourceReporter {
  const SampleSourceReporter({required this.onSample, required this.onReal});

  final void Function(SampleSource) onSample;
  final void Function(SampleSource) onReal;
}

/// Calls [primary] first; on any failure (exception, timeout, non-2xx)
/// returns [sample] instead and reports [source] as sampled.
///
/// [primary] runs inside [Future.sync] so a synchronous throw is still
/// caught, and the reporter always fires after an `await` — never
/// synchronously while a provider is building.
Future<T> runWithFallback<T>({
  required SampleSource source,
  required SampleSourceReporter reporter,
  required Future<T> Function() primary,
  required T Function() sample,
}) async {
  try {
    final value = await Future.sync(primary);
    reporter.onReal(source);
    return value;
  } catch (_) {
    reporter.onSample(source);
    return sample();
  }
}

class FallbackSuitabilityApi implements SuitabilityApi {
  FallbackSuitabilityApi({required this.primary, required this.reporter});

  final SuitabilityApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<DiscoveryOverview> fetchSuitability({
    required double lat,
    required double lng,
    required ObsMode mode,
  }) {
    return runWithFallback(
      source: SampleSource.suitability,
      reporter: reporter,
      primary: () => primary.fetchSuitability(lat: lat, lng: lng, mode: mode),
      sample: () => sampleDiscoveryOverview(mode),
    );
  }
}

class FallbackStarlightApi implements StarlightApi {
  FallbackStarlightApi({required this.primary, required this.reporter});

  final StarlightApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<StarlightForecast> fetchForecast({
    required double lat,
    required double lng,
    String? date,
    String? time,
    String? target,
    double? sqm,
    int? moonIllumination,
    String? twilightEnd,
  }) {
    return runWithFallback(
      source: SampleSource.starlight,
      reporter: reporter,
      primary: () => primary.fetchForecast(
        lat: lat,
        lng: lng,
        date: date,
        time: time,
        target: target,
        sqm: sqm,
        moonIllumination: moonIllumination,
        twilightEnd: twilightEnd,
      ),
      sample: () => sampleStarlightForecast(lat: lat, lng: lng),
    );
  }
}

class FallbackObservationMapApi implements ObservationMapApi {
  FallbackObservationMapApi({required this.primary, required this.reporter});

  final ObservationMapApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  }) {
    return runWithFallback(
      source: SampleSource.observationMap,
      reporter: reporter,
      primary: () => primary.fetchObservationMap(lat: lat, lng: lng),
      sample: sampleObservationMap,
    );
  }
}

/// Both [fetchTrails] and [fetchTrailDetail] report [SampleSource.trails].
class FallbackTrailsApi implements TrailsApi {
  FallbackTrailsApi({required this.primary, required this.reporter});

  final TrailsApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
    String? region,
  }) {
    return runWithFallback(
      source: SampleSource.trails,
      reporter: reporter,
      primary: () => primary.fetchTrails(lat: lat, lng: lng, region: region),
      sample: sampleTrails,
    );
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({required String crsIdx}) {
    return runWithFallback(
      source: SampleSource.trails,
      reporter: reporter,
      primary: () => primary.fetchTrailDetail(crsIdx: crsIdx),
      sample: () => sampleTrailDetail(crsIdx),
    );
  }
}

class FallbackRegionsApi implements RegionsApi {
  FallbackRegionsApi({required this.primary, required this.reporter});

  final RegionsApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<RegionsResponse> fetchRegions({
    required double lat,
    required double lng,
  }) {
    return runWithFallback(
      source: SampleSource.regions,
      reporter: reporter,
      primary: () => primary.fetchRegions(lat: lat, lng: lng),
      sample: sampleRegions,
    );
  }
}

class FallbackTideApi implements TideApi {
  FallbackTideApi({required this.primary, required this.reporter});

  final TideApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<TodayTides> fetchTodayTides({
    required double lat,
    required double lng,
  }) {
    return runWithFallback(
      source: SampleSource.tide,
      reporter: reporter,
      primary: () => primary.fetchTodayTides(lat: lat, lng: lng),
      sample: sampleTodayTides,
    );
  }
}

class FallbackSpeciesApi implements SpeciesApi {
  FallbackSpeciesApi({required this.primary, required this.reporter});

  final SpeciesApi primary;
  final SampleSourceReporter reporter;

  @override
  Future<SpeciesInfo> fetchSpecies({String? sci, String? ko}) {
    return runWithFallback(
      source: SampleSource.species,
      reporter: reporter,
      primary: () => primary.fetchSpecies(sci: sci, ko: ko),
      sample: () => sampleSpecies(sci: sci, ko: ko),
    );
  }
}

/// Ecolog wrapper that keeps writes working offline: when [primary] fails,
/// the call is served by an in-memory [local] store (a reused
/// [FakeEcologApi]) and [SampleSource.ecolog] is reported. Observations
/// created that way are "this device only" — see [isLocalOnly].
class FallbackEcologApi implements EcologApi {
  FallbackEcologApi({
    required this.primary,
    required this.reporter,
    FakeEcologApi? local,
  }) : local = local ?? FakeEcologApi();

  final EcologApi primary;
  final SampleSourceReporter reporter;
  final FakeEcologApi local;

  final Set<int> _localIds = {};

  /// Whether observation [id] exists only in the on-device [local] store.
  bool isLocalOnly(int id) => _localIds.contains(id);

  /// Tries [primaryCall]; on failure reports a sample and runs [localCall].
  /// Errors from [localCall] (e.g. a 404 for an unknown id) propagate.
  Future<T> _withLocal<T>(
    Future<T> Function() primaryCall,
    Future<T> Function() localCall,
  ) async {
    try {
      final value = await Future.sync(primaryCall);
      reporter.onReal(SampleSource.ecolog);
      return value;
    } catch (_) {
      reporter.onSample(SampleSource.ecolog);
      return localCall();
    }
  }

  @override
  Future<List<Observation>> listObservations({SpeciesType? speciesType}) {
    return _withLocal(
      () => primary.listObservations(speciesType: speciesType),
      () => local.listObservations(speciesType: speciesType),
    );
  }

  @override
  Future<Observation> getObservation(int id) {
    return _withLocal(
      () => primary.getObservation(id),
      () => local.getObservation(id),
    );
  }

  @override
  Future<Observation> createObservation(ObservationCreate body) {
    return _withLocal(
      () => primary.createObservation(body),
      () async {
        final created = await local.createObservation(body);
        _localIds.add(created.id);
        return created;
      },
    );
  }

  @override
  Future<Observation> updateObservation(int id, ObservationUpdate body) async {
    if (_localIds.contains(id)) {
      // Never reached the server — don't send it there now.
      final updated = await local.updateObservation(id, body);
      reporter.onSample(SampleSource.ecolog);
      return updated;
    }
    return _withLocal(
      () => primary.updateObservation(id, body),
      () => local.updateObservation(id, body),
    );
  }

  @override
  Future<void> deleteObservation(int id) async {
    if (_localIds.contains(id)) {
      await local.deleteObservation(id);
      _localIds.remove(id);
      reporter.onSample(SampleSource.ecolog);
      return;
    }
    return _withLocal(
      () => primary.deleteObservation(id),
      () => local.deleteObservation(id),
    );
  }

  @override
  Future<List<BadgeProgress>> listBadges() {
    return _withLocal(primary.listBadges, local.listBadges);
  }
}
