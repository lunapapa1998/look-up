import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/region.dart';

/// Thrown by [RegionsApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class RegionsApiException implements Exception {
  final int statusCode;
  final String message;

  RegionsApiException(this.statusCode, this.message);

  @override
  String toString() => 'RegionsApiException($statusCode): $message';
}

/// Contract for the `/api/regions` backend. JSON bodies, no auth.
abstract class RegionsApi {
  Future<RegionsResponse> fetchRegions({required double lat, required double lng});
}

/// HTTP implementation of [RegionsApi] against a FastAPI-style backend.
class HttpRegionsApi implements RegionsApi {
  final String baseUrl;
  final http.Client client;

  HttpRegionsApi(this.baseUrl, {http.Client? client})
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
    throw RegionsApiException(response.statusCode, message);
  }

  @override
  Future<RegionsResponse> fetchRegions({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/api/regions').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );
    final response = await client.get(uri);
    _checkStatus(response, 200);
    return RegionsResponse.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [RegionsApi] for widget/unit tests. No HTTP.
class FakeRegionsApi implements RegionsApi {
  final RegionsResponse? response;
  final bool shouldThrow;

  FakeRegionsApi({
    this.response,
    this.shouldThrow = false,
  });

  @override
  Future<RegionsResponse> fetchRegions({
    required double lat,
    required double lng,
  }) async {
    if (shouldThrow) {
      throw RegionsApiException(500, 'fake failure');
    }
    return response ??
        const RegionsResponse(
          nearestId: 'ganghwa',
          regions: [
            RegionSummary(
              id: 'ganghwa',
              label: '인천 강화군',
              distanceKm: 0.0,
              center: RegionCenter(lat: 37.7469, lng: 126.4878),
              hasStarSpot: true,
            ),
          ],
        );
  }
}
