import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lookup/api/demo/fallback_apis.dart';
import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/regions_api.dart';
import 'package:lookup/api/species_api.dart';
import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/api/tide_api.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/models/starlight_forecast.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/state/sample_data_provider.dart';

const _base = 'http://test';
const _timeout = Duration(milliseconds: 10);

/// A client whose every response arrives well after [_timeout].
MockClient _slowClient() => MockClient((_) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return http.Response('{}', 200);
});

/// Reporter backed by a plain set: sampled sources are added, sources whose
/// real call succeeded are removed — mirroring `SampleSourcesNotifier`.
({Set<SampleSource> sampled, SampleSourceReporter reporter}) _recorder() {
  final sampled = <SampleSource>{};
  return (
    sampled: sampled,
    reporter: SampleSourceReporter(
      onSample: sampled.add,
      onReal: sampled.remove,
    ),
  );
}

/// There is no `FakeStarlightApi` in lib/, so tests use this minimal one.
class _TestStarlightApi implements StarlightApi {
  _TestStarlightApi({this.shouldThrow = false});

  bool shouldThrow;

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
  }) async {
    if (shouldThrow) throw Exception('fake starlight failure');
    return StarlightForecast.fromJson({
      'title': 'real forecast',
      'location': {'lat': lat, 'lng': lng},
    });
  }
}

/// `FakeEcologApi` has no failure switch, so tests use this always-failing
/// primary instead.
class _ThrowingEcologApi implements EcologApi {
  Never _fail() => throw EcologApiException(503, 'fake ecolog failure');

  @override
  Future<List<Observation>> listObservations({SpeciesType? speciesType}) async =>
      _fail();

  @override
  Future<Observation> getObservation(int id) async => _fail();

  @override
  Future<Observation> createObservation(ObservationCreate body) async =>
      _fail();

  @override
  Future<Observation> updateObservation(int id, ObservationUpdate body) async =>
      _fail();

  @override
  Future<void> deleteObservation(int id) async => _fail();

  @override
  Future<List<BadgeProgress>> listBadges() async => _fail();
}

/// Suitability primary whose failure can be switched off mid-test.
class _ToggleSuitabilityApi implements SuitabilityApi {
  bool fail = true;
  final _real = FakeSuitabilityApi();

  @override
  Future<DiscoveryOverview> fetchSuitability({
    required double lat,
    required double lng,
    required ObsMode mode,
  }) {
    if (fail) throw SuitabilityApiException(503, 'down');
    return _real.fetchSuitability(lat: lat, lng: lng, mode: mode);
  }
}

/// Trails primary whose failure can be switched off mid-test.
class _ToggleTrailsApi implements TrailsApi {
  bool fail = true;
  final _real = FakeTrailsApi();

  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
    String? region,
  }) async {
    if (fail) throw TrailsApiException(503, 'down');
    return _real.fetchTrails(lat: lat, lng: lng, region: region);
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({required String crsIdx}) async {
    if (fail) throw TrailsApiException(503, 'down');
    return _real.fetchTrailDetail(crsIdx: crsIdx);
  }
}

ObservationCreate _create() =>
    ObservationCreate(speciesType: SpeciesType.bird, speciesName: '저어새');

void main() {
  group('runWithFallback', () {
    test('catches a synchronous throw and reports asynchronously', () async {
      final r = _recorder();
      final future = runWithFallback<int>(
        source: SampleSource.regions,
        reporter: r.reporter,
        primary: () => throw StateError('sync'),
        sample: () => 7,
      );
      // Nothing reported synchronously (providers may call this in build).
      expect(r.sampled, isEmpty);
      expect(await future, 7);
      expect(r.sampled, {SampleSource.regions});
    });
  });

  group('FallbackSuitabilityApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackSuitabilityApi(
        primary: FakeSuitabilityApi(),
        reporter: r.reporter,
      );
      final result =
          await api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.day);
      expect(result.suitabilityIndex.score, 88);
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackSuitabilityApi(
        primary: FakeSuitabilityApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result =
          await api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.day);
      expect(result.suitabilityIndex.label, contains('예시'));
      expect(result.degraded, isFalse);
      expect(result.weatherRefreshing, isFalse);
      expect(r.sampled, {SampleSource.suitability});
    });

    test('timeout returns sample data', () async {
      final r = _recorder();
      final api = FallbackSuitabilityApi(
        primary: HttpSuitabilityApi(
          _base,
          client: _slowClient(),
          timeout: _timeout,
        ),
        reporter: r.reporter,
      );
      final result =
          await api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.night);
      expect(result.suitabilityIndex.label, contains('예시'));
      expect(r.sampled, {SampleSource.suitability});
    });

    test('a later real success removes the source', () async {
      final r = _recorder();
      final primary = _ToggleSuitabilityApi();
      final api = FallbackSuitabilityApi(primary: primary, reporter: r.reporter);

      await api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.day);
      expect(r.sampled, {SampleSource.suitability});

      primary.fail = false;
      final result =
          await api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.day);
      expect(result.suitabilityIndex.score, 88);
      expect(r.sampled, isEmpty);
    });
  });

  group('FallbackStarlightApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackStarlightApi(
        primary: _TestStarlightApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchForecast(lat: 37.6, lng: 126.4);
      expect(result.title, 'real forecast');
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackStarlightApi(
        primary: _TestStarlightApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result = await api.fetchForecast(lat: 37.6, lng: 126.4);
      expect(result.title, contains('예시'));
      expect(result.target.id, startsWith('sample-'));
      expect(result.lat, 37.6);
      expect(result.degraded, isFalse);
      expect(r.sampled, {SampleSource.starlight});
    });

    test('a later real success removes the source', () async {
      final r = _recorder();
      final primary = _TestStarlightApi(shouldThrow: true);
      final api = FallbackStarlightApi(primary: primary, reporter: r.reporter);

      await api.fetchForecast(lat: 37.6, lng: 126.4);
      expect(r.sampled, {SampleSource.starlight});

      primary.shouldThrow = false;
      await api.fetchForecast(lat: 37.6, lng: 126.4);
      expect(r.sampled, isEmpty);
    });
  });

  group('FallbackObservationMapApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackObservationMapApi(
        primary: FakeObservationMapApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchObservationMap(lat: 37.6, lng: 126.4);
      expect(result.spots.first.id, 'bird-001');
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackObservationMapApi(
        primary: FakeObservationMapApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result = await api.fetchObservationMap(lat: 37.6, lng: 126.4);
      expect(result.region, contains('예시'));
      expect(result.spots, isNotEmpty);
      expect(result.spots.every((s) => s.id.startsWith('sample-')), isTrue);
      expect(
        result.spots.map((s) => s.kind).toSet(),
        {'bird', 'star', 'heritage'},
      );
      expect(r.sampled, {SampleSource.observationMap});
    });

    test('timeout returns sample data', () async {
      final r = _recorder();
      final api = FallbackObservationMapApi(
        primary: HttpObservationMapApi(
          _base,
          client: _slowClient(),
          timeout: _timeout,
        ),
        reporter: r.reporter,
      );
      final result = await api.fetchObservationMap(lat: 37.6, lng: 126.4);
      expect(result.region, contains('예시'));
      expect(r.sampled, {SampleSource.observationMap});
    });
  });

  group('FallbackTrailsApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackTrailsApi(
        primary: FakeTrailsApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchTrails(lat: 37.6, lng: 126.4);
      expect(result.courses.first.crsIdx, 'T_CRS_MNG0000009999');
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample courses and records the source', () async {
      final r = _recorder();
      final api = FallbackTrailsApi(
        primary: FakeTrailsApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result = await api.fetchTrails(lat: 37.6, lng: 126.4);
      expect(result.courses, hasLength(3));
      expect(
        result.courses.every((c) => c.crsIdx.startsWith('SAMPLE_')),
        isTrue,
      );
      expect(result.courses.every((c) => c.gpxUrl.isEmpty), isTrue);
      expect(r.sampled, {SampleSource.trails});
    });

    test('detail failure returns a sample detail for sample courses', () async {
      final r = _recorder();
      final api = FallbackTrailsApi(
        primary: FakeTrailsApi(trailDetailShouldThrow: true),
        reporter: r.reporter,
      );
      final sample = await api.fetchTrailDetail(crsIdx: 'SAMPLE_CRS_1');
      expect(sample.found, isTrue);
      expect(sample.description, contains('예시'));
      expect(r.sampled, {SampleSource.trails});

      final other = await api.fetchTrailDetail(crsIdx: 'T_CRS_MNG0000009999');
      expect(other.found, isFalse);
    });

    test('timeout returns sample data', () async {
      final r = _recorder();
      final api = FallbackTrailsApi(
        primary: HttpTrailsApi(
          _base,
          client: _slowClient(),
          timeout: _timeout,
        ),
        reporter: r.reporter,
      );
      final result = await api.fetchTrails(lat: 37.6, lng: 126.4);
      expect(result.courses.first.crsIdx, 'SAMPLE_CRS_1');
      expect(r.sampled, {SampleSource.trails});
    });

    test('a later real success removes the source', () async {
      final r = _recorder();
      final primary = _ToggleTrailsApi();
      final api = FallbackTrailsApi(primary: primary, reporter: r.reporter);

      await api.fetchTrails(lat: 37.6, lng: 126.4);
      expect(r.sampled, {SampleSource.trails});

      primary.fail = false;
      final result = await api.fetchTrails(lat: 37.6, lng: 126.4);
      expect(result.courses.first.crsIdx, 'T_CRS_MNG0000009999');
      expect(r.sampled, isEmpty);
    });
  });

  group('FallbackRegionsApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackRegionsApi(
        primary: FakeRegionsApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchRegions(lat: 37.6, lng: 126.4);
      expect(result.regions, hasLength(1));
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackRegionsApi(
        primary: FakeRegionsApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result = await api.fetchRegions(lat: 37.6, lng: 126.4);
      expect(result.regions, hasLength(2));
      expect(result.nearestId, 'ganghwa');
      expect(r.sampled, {SampleSource.regions});
    });
  });

  group('FallbackTideApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackTideApi(
        primary: FakeTideApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchTodayTides(lat: 37.6, lng: 126.4);
      expect(result.found, isFalse);
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackTideApi(
        primary: FakeTideApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result = await api.fetchTodayTides(lat: 37.6, lng: 126.4);
      expect(result.found, isTrue);
      expect(result.stationName, '예시 관측소');
      expect(result.extremes.map((e) => e.kind), ['high', 'low']);
      expect(r.sampled, {SampleSource.tide});
    });
  });

  group('FallbackSpeciesApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final api = FallbackSpeciesApi(
        primary: FakeSpeciesApi(),
        reporter: r.reporter,
      );
      final result = await api.fetchSpecies(ko: '저어새');
      expect(result.source, 'none');
      expect(r.sampled, isEmpty);
    });

    test('failure returns sample data and records the source', () async {
      final r = _recorder();
      final api = FallbackSpeciesApi(
        primary: FakeSpeciesApi(shouldThrow: true),
        reporter: r.reporter,
      );
      final result =
          await api.fetchSpecies(sci: 'Platalea minor', ko: '저어새');
      expect(result.source, 'sample');
      expect(result.nameKo, '저어새');
      expect(result.nameSci, 'Platalea minor');
      expect(result.summary, contains('예시'));
      expect(r.sampled, {SampleSource.species});
    });
  });

  group('FallbackEcologApi', () {
    test('success returns real data and records nothing', () async {
      final r = _recorder();
      final primary = FakeEcologApi();
      await primary.createObservation(_create());
      final api = FallbackEcologApi(primary: primary, reporter: r.reporter);

      final list = await api.listObservations();
      expect(list, hasLength(1));
      expect(api.isLocalOnly(list.first.id), isFalse);
      expect(r.sampled, isEmpty);
    });

    test('failure falls back to the local store and records ecolog', () async {
      final r = _recorder();
      final api = FallbackEcologApi(
        primary: _ThrowingEcologApi(),
        reporter: r.reporter,
      );
      final list = await api.listObservations();
      expect(list, isEmpty);
      final badges = await api.listBadges();
      expect(badges, isNotEmpty);
      expect(r.sampled, {SampleSource.ecolog});
    });

    test('create on failure is stored locally and marked local-only', () async {
      final r = _recorder();
      final api = FallbackEcologApi(
        primary: _ThrowingEcologApi(),
        reporter: r.reporter,
      );
      final created = await api.createObservation(_create());
      expect(api.isLocalOnly(created.id), isTrue);
      expect(r.sampled, {SampleSource.ecolog});

      final list = await api.listObservations();
      expect(list.map((o) => o.id), contains(created.id));

      final updated = await api.updateObservation(
        created.id,
        ObservationUpdate(note: '메모'),
      );
      expect(updated.note, '메모');

      await api.deleteObservation(created.id);
      expect(api.isLocalOnly(created.id), isFalse);
      expect(await api.listObservations(), isEmpty);
    });

    test('update of an unknown id on failure propagates the 404', () async {
      final api = FallbackEcologApi(
        primary: _ThrowingEcologApi(),
        reporter: _recorder().reporter,
      );
      expect(
        api.updateObservation(999, ObservationUpdate(note: 'x')),
        throwsA(
          isA<EcologApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });

  test('sampleReporterFor updates sampleSourcesProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reporterProvider = Provider<SampleSourceReporter>(sampleReporterFor);
    final reporter = container.read(reporterProvider);

    expect(container.read(sampleSourcesProvider), isEmpty);

    reporter.onSample(SampleSource.trails);
    reporter.onSample(SampleSource.tide);
    expect(
      container.read(sampleSourcesProvider),
      {SampleSource.trails, SampleSource.tide},
    );

    reporter.onReal(SampleSource.trails);
    expect(container.read(sampleSourcesProvider), {SampleSource.tide});
  });
}
