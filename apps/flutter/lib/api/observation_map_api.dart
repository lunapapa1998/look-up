import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/observation_map.dart';
import '../models/trails.dart';

/// Thrown by [ObservationMapApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class ObservationMapApiException implements Exception {
  final int statusCode;
  final String message;

  ObservationMapApiException(this.statusCode, this.message);

  @override
  String toString() => 'ObservationMapApiException($statusCode): $message';
}

/// Contract for the `/api/observation-map` backend. JSON bodies, no auth.
/// Mode-independent — like [TrailsApi], there is no `mode` parameter.
abstract class ObservationMapApi {
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  });
}

/// HTTP implementation of [ObservationMapApi] against a FastAPI-style backend.
class HttpObservationMapApi implements ObservationMapApi {
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  HttpObservationMapApi(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client();

  /// Awaits [request], mapping a [timeout] overrun to a 408
  /// [ObservationMapApiException].
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw ObservationMapApiException(408, '서버 응답 시간이 초과됐어요');
    }
  }

  void _checkStatus(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    var message = response.body;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      }
    } catch (_) {
      // Response body wasn't JSON; fall back to the raw body as the message.
    }
    throw ObservationMapApiException(response.statusCode, message);
  }

  @override
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/api/observation-map').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );
    final response = await _send(client.get(uri));
    _checkStatus(response, 200);
    return ObservationMapResponse.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [ObservationMapApi] for widget/unit tests.
/// No HTTP; returns deterministic data with one bird, one star, and one
/// heritage spot.
class FakeObservationMapApi implements ObservationMapApi {
  final bool degraded;
  final bool shouldThrow;
  final void Function(double lat, double lng)? onFetch;

  FakeObservationMapApi({
    this.degraded = false,
    this.shouldThrow = false,
    this.onFetch,
  });

  static const _birdSpot = ObservationSpot(
    id: 'bird-001',
    kind: 'bird',
    name: '강화도 동막갯벌',
    coord: Coordinate(lat: 37.601, lng: 126.412),
    nightSky: null,
    birds: BirdObservation(
      speciesCount: 12,
      topSpecies: [
        BirdSpecies(
          nameKo: '저어새',
          nameSci: 'Platalea minor',
          speciesCode: 'blbspo1',
          count: 24,
          obsDt: '2026-09-09 07:12',
        ),
        BirdSpecies(
          nameKo: '검은머리물떼새',
          nameSci: 'Haematopus ostralegus',
          speciesCode: 'eurost',
          count: null,
          obsDt: '2026-09-09 06:40',
        ),
      ],
      mostRecentObsDt: '2026-09-09 07:12',
      status: 'community',
    ),
    heritage: null,
  );

  static const _starSpot = ObservationSpot(
    id: 'star-001',
    kind: 'star',
    name: '영월 별마로',
    coord: Coordinate(lat: 37.71, lng: 126.42),
    nightSky: NightSky(
      sqmValue: 20.15,
      bortleClass: 3,
      skyClass: 'Class 3 양호한 다크스카이',
      status: 'approx',
    ),
    birds: null,
    heritage: null,
  );

  static const _heritageSpot = ObservationSpot(
    id: 'heritage-001',
    kind: 'heritage',
    name: '강화도령보리밥',
    coord: Coordinate(lat: 37.603, lng: 126.415),
    nightSky: null,
    birds: null,
    heritage: HeritageInfo(
      addr: '인천광역시 강화군 화도면 해안남로 200',
      distanceM: 1820,
      contentId: '855201',
    ),
  );

  @override
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  }) async {
    onFetch?.call(lat, lng);
    if (shouldThrow) {
      throw ObservationMapApiException(500, 'fake failure');
    }
    return ObservationMapResponse(
      region: '인천 강화군',
      degraded: degraded,
      spots: const [_birdSpot, _starSpot, _heritageSpot],
    );
  }
}
