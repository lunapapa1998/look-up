import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/starlight_forecast.dart';

abstract class StarlightApi {
  Future<StarlightForecast> fetchForecast({
    required double lat,
    required double lng,
    String? date,
    String? time,
    String? target,
    double? sqm,
    int? moonIllumination,
    String? twilightEnd,
  });
}

class HttpStarlightApi implements StarlightApi {
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  HttpStarlightApi(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client();

  /// Awaits [request], mapping a [timeout] overrun to a plain [Exception]
  /// like the existing non-200 path.
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'Failed to fetch starlight forecast (timeout after ${timeout.inSeconds}s)',
      );
    }
  }

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
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
    };
    if (date != null) queryParams['date'] = date;
    if (time != null) queryParams['time'] = time;
    if (target != null) queryParams['target'] = target;
    if (sqm != null) queryParams['sqm'] = sqm.toString();
    if (moonIllumination != null) {
      queryParams['moon_illumination'] = moonIllumination.toString();
    }
    if (twilightEnd != null) queryParams['twilight_end'] = twilightEnd;

    final uri = Uri.parse('$baseUrl/api/starlight-forecast').replace(
      queryParameters: queryParams,
    );

    final response = await _send(client.get(uri));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch starlight forecast (${response.statusCode}): ${response.body}');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return StarlightForecast.fromJson(decoded);
  }
}
