import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/gpx_api.dart';
import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/regions_api.dart';
import 'package:lookup/api/species_api.dart';
import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/api/tide_api.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/observation.dart';

const _base = 'http://test';
const _timeout = Duration(milliseconds: 10);

/// A client whose every response arrives well after [_timeout].
MockClient _slowClient() => MockClient((_) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return http.Response('{}', 200);
});

void main() {
  test('HttpSuitabilityApi throws 408 on timeout', () {
    final api = HttpSuitabilityApi(
      _base,
      client: _slowClient(),
      timeout: _timeout,
    );
    expect(
      api.fetchSuitability(lat: 37.6, lng: 126.4, mode: ObsMode.day),
      throwsA(
        isA<SuitabilityApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpObservationMapApi throws 408 on timeout', () {
    final api = HttpObservationMapApi(
      _base,
      client: _slowClient(),
      timeout: _timeout,
    );
    expect(
      api.fetchObservationMap(lat: 37.6, lng: 126.4),
      throwsA(
        isA<ObservationMapApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpTrailsApi throws 408 on timeout', () {
    final api = HttpTrailsApi(_base, client: _slowClient(), timeout: _timeout);
    expect(
      api.fetchTrails(lat: 37.6, lng: 126.4),
      throwsA(
        isA<TrailsApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpRegionsApi throws 408 on timeout', () {
    final api = HttpRegionsApi(_base, client: _slowClient(), timeout: _timeout);
    expect(
      api.fetchRegions(lat: 37.6, lng: 126.4),
      throwsA(
        isA<RegionsApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpTideApi throws 408 on timeout', () {
    final api = HttpTideApi(_base, client: _slowClient(), timeout: _timeout);
    expect(
      api.fetchTodayTides(lat: 37.6, lng: 126.4),
      throwsA(
        isA<TideApiException>().having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpSpeciesApi throws 408 on timeout', () {
    final api = HttpSpeciesApi(_base, client: _slowClient(), timeout: _timeout);
    expect(
      api.fetchSpecies(ko: '저어새'),
      throwsA(
        isA<SpeciesApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpEcologApi.createObservation throws 408 on timeout', () {
    final api = HttpEcologApi(_base, client: _slowClient(), timeout: _timeout);
    expect(
      api.createObservation(
        ObservationCreate(speciesType: SpeciesType.bird, speciesName: '저어새'),
      ),
      throwsA(
        isA<EcologApiException>()
            .having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('HttpStarlightApi throws on timeout', () {
    final api = HttpStarlightApi(
      _base,
      client: _slowClient(),
      timeout: _timeout,
    );
    expect(
      api.fetchForecast(lat: 37.6, lng: 126.4),
      throwsA(isA<Exception>()),
    );
  });

  test('HttpGpxApi resolves to an empty list on timeout', () async {
    final api = HttpGpxApi(client: _slowClient(), timeout: _timeout);
    expect(await api.fetchGpxTrack('$_base/track.gpx'), isEmpty);
  });
}
