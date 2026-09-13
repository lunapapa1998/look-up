import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/species.dart';

/// Thrown by [SpeciesApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class SpeciesApiException implements Exception {
  final int statusCode;
  final String message;

  SpeciesApiException(this.statusCode, this.message);

  @override
  String toString() => 'SpeciesApiException($statusCode): $message';
}

/// Contract for the `/api/species` wiki-lookup backend. JSON bodies, no
/// auth. Callers must pass at least one of `sci`/`ko`.
abstract class SpeciesApi {
  Future<SpeciesInfo> fetchSpecies({String? sci, String? ko});
}

/// HTTP implementation of [SpeciesApi] against a FastAPI-style backend.
class HttpSpeciesApi implements SpeciesApi {
  final String baseUrl;
  final http.Client client;

  HttpSpeciesApi(this.baseUrl, {http.Client? client})
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
    throw SpeciesApiException(response.statusCode, message);
  }

  @override
  Future<SpeciesInfo> fetchSpecies({String? sci, String? ko}) async {
    final uri = Uri.parse('$baseUrl/api/species').replace(
      queryParameters: {
        'sci': ?sci,
        'ko': ?ko,
      },
    );
    final response = await client.get(uri);
    _checkStatus(response, 200);
    return SpeciesInfo.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [SpeciesApi] for widget/unit tests. No HTTP.
class FakeSpeciesApi implements SpeciesApi {
  final SpeciesInfo? response;
  final bool shouldThrow;
  final void Function(String? sci, String? ko)? onFetch;

  FakeSpeciesApi({
    this.response,
    this.shouldThrow = false,
    this.onFetch,
  });

  @override
  Future<SpeciesInfo> fetchSpecies({String? sci, String? ko}) async {
    onFetch?.call(sci, ko);
    if (shouldThrow) {
      throw SpeciesApiException(500, 'fake failure');
    }
    return response ??
        SpeciesInfo(
          nameKo: ko,
          nameSci: sci,
          summary: null,
          thumbnailUrl: null,
          wikiUrl: null,
          source: 'none',
        );
  }
}
