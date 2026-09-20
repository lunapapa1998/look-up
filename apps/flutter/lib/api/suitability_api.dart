import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/discovery.dart';

/// Thrown by [SuitabilityApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class SuitabilityApiException implements Exception {
  final int statusCode;
  final String message;

  SuitabilityApiException(this.statusCode, this.message);

  @override
  String toString() => 'SuitabilityApiException($statusCode): $message';
}

/// Contract for the `/api/suitability` suitability-engine backend. JSON
/// bodies, no auth.
abstract class SuitabilityApi {
  Future<DiscoveryOverview> fetchSuitability({
    required double lat,
    required double lng,
    required ObsMode mode,
  });
}

/// HTTP implementation of [SuitabilityApi] against a FastAPI-style backend.
class HttpSuitabilityApi implements SuitabilityApi {
  final String baseUrl;
  final http.Client client;

  HttpSuitabilityApi(this.baseUrl, {http.Client? client})
    : client = client ?? http.Client();

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
    throw SuitabilityApiException(response.statusCode, message);
  }

  @override
  Future<DiscoveryOverview> fetchSuitability({
    required double lat,
    required double lng,
    required ObsMode mode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/suitability').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'mode': mode.toQueryValue(),
      },
    );
    final response = await client.get(uri);
    _checkStatus(response, 200);
    return DiscoveryOverview.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [SuitabilityApi] for widget/unit tests. No
/// HTTP; returns deterministic, mode-dependent data.
class FakeSuitabilityApi implements SuitabilityApi {
  final bool degraded;
  final bool shouldThrow;
  final void Function(double lat, double lng)? onFetchSuitability;
  final Moon? moonOverride;
  final bool includeMoon;
  final bool weatherRefreshing;

  FakeSuitabilityApi({
    this.degraded = false,
    this.shouldThrow = false,
    this.onFetchSuitability,
    this.moonOverride,
    this.includeMoon = true,
    this.weatherRefreshing = false,
  });

  static const _dayMoon = Moon(
    illumination: 62,
    phaseName: '차오르는 달',
    moonrise: '13:42',
    moonset: '01:15',
    status: 'live',
  );

  static const _nightMoon = Moon(
    illumination: 96,
    phaseName: '보름달',
    moonrise: '18:32',
    moonset: '05:12',
    status: 'live',
  );

  static const _goldenHours = [
    GoldenHour(
      mode: ObsMode.day,
      label: '낮 · 탐조 골든타임',
      timeRange: '14:00 - 17:30',
      description: '만조 2시간 전 갯벌 유입 피크',
    ),
    GoldenHour(
      mode: ObsMode.night,
      label: '밤 · 천체 골든타임',
      timeRange: '21:40 - 01:20',
      description: '월령 12% 삭 근처 · 운량 0%',
    ),
  ];

  @override
  Future<DiscoveryOverview> fetchSuitability({
    required double lat,
    required double lng,
    required ObsMode mode,
  }) async {
    onFetchSuitability?.call(lat, lng);
    if (shouldThrow) {
      throw SuitabilityApiException(500, 'fake failure');
    }
    final suitabilityIndex = mode == ObsMode.day
        ? const SuitabilityIndex(
            score: 88,
            label: '매우 쾌적 (Prime)',
            sqmValue: 21.6,
            skyClass: 'Class 2 최적 다크스카이',
          )
        : const SuitabilityIndex(
            score: 92,
            label: '천체관측 최적 (Prime)',
            sqmValue: 21.9,
            skyClass: 'Class 1 최고 다크스카이',
          );
    final telemetry = mode == ObsMode.day
        ? const [
            TelemetryReading(kind: 'sky', label: '하늘 상태', value: '맑음'),
            TelemetryReading(kind: 'humidity', label: '습도', value: '52%'),
            TelemetryReading(
              kind: 'wind',
              label: '풍속·풍향',
              value: '2.1 m/s (NW)',
            ),
            TelemetryReading(kind: 'precip', label: '강수확률', value: '0%'),
            TelemetryReading(kind: 'tide', label: '조위 상태', value: '만조 16:15'),
          ]
        : const [
            TelemetryReading(kind: 'sky', label: '하늘 상태', value: '맑음 · 운량 0%'),
            TelemetryReading(kind: 'humidity', label: '습도', value: '38%'),
            TelemetryReading(
              kind: 'wind',
              label: '풍속·풍향',
              value: '1.4 m/s (N)',
            ),
            TelemetryReading(kind: 'precip', label: '강수확률', value: '0%'),
            TelemetryReading(kind: 'tide', label: '조위 상태', value: '간조 23:10'),
          ];
    final Moon? resolvedMoon = !includeMoon
        ? null
        : moonOverride ?? (mode == ObsMode.day ? _dayMoon : _nightMoon);
    return DiscoveryOverview(
      suitabilityIndex: suitabilityIndex,
      goldenHours: _goldenHours,
      telemetry: telemetry,
      degraded: degraded,
      weatherRefreshing: weatherRefreshing,
      moon: resolvedMoon,
    );
  }
}
