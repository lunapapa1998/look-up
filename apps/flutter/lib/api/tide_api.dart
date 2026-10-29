import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tide.dart';

/// Thrown by [TideApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class TideApiException implements Exception {
  final int statusCode;
  final String message;

  TideApiException(this.statusCode, this.message);

  @override
  String toString() => 'TideApiException($statusCode): $message';
}

/// Contract for the `/api/tide/today` backend. JSON bodies, no auth.
abstract class TideApi {
  Future<TodayTides> fetchTodayTides({required double lat, required double lng});
}

/// HTTP implementation of [TideApi] against a FastAPI-style backend.
class HttpTideApi implements TideApi {
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  HttpTideApi(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client();

  /// Awaits [request], mapping a [timeout] overrun to a 408
  /// [TideApiException].
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw TideApiException(408, '서버 응답 시간이 초과됐어요');
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
    throw TideApiException(response.statusCode, message);
  }

  @override
  Future<TodayTides> fetchTodayTides({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tide/today').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );
    final response = await _send(client.get(uri));
    _checkStatus(response, 200);
    return TodayTides.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [TideApi] for widget/unit tests. No HTTP.
class FakeTideApi implements TideApi {
  final TodayTides? response;
  final bool shouldThrow;

  FakeTideApi({
    this.response,
    this.shouldThrow = false,
  });

  @override
  Future<TodayTides> fetchTodayTides({
    required double lat,
    required double lng,
  }) async {
    if (shouldThrow) {
      throw TideApiException(500, 'fake failure');
    }
    return response ??
        const TodayTides(
          found: false,
          degraded: false,
          stationName: null,
          extremes: [],
        );
  }
}
