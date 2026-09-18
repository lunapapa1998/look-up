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

  HttpStarlightApi(this.baseUrl, {http.Client? client})
      : client = client ?? http.Client();

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

    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch starlight forecast (${response.statusCode}): ${response.body}');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return StarlightForecast.fromJson(decoded);
  }
}
