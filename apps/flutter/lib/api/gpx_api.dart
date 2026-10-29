import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/gpx_parser.dart';

/// Contract for fetching a GPX trail track as a list of points. A network
/// failure just means no trail line is drawn -- the rest of the map stays
/// fine -- so implementations must never throw; they resolve to an empty
/// list instead.
abstract class GpxApi {
  Future<List<LatLng>> fetchGpxTrack(String gpxUrl);
}

/// HTTP implementation of [GpxApi]. GETs [gpxUrl] and parses the body with
/// [parseGpxTrack]. Any exception from the GET, or a non-200 status code,
/// is caught internally and resolves to an empty list.
class HttpGpxApi implements GpxApi {
  final http.Client client;
  final Duration timeout;

  HttpGpxApi({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client();

  @override
  Future<List<LatLng>> fetchGpxTrack(String gpxUrl) async {
    try {
      final response = await client.get(Uri.parse(gpxUrl)).timeout(timeout);
      if (response.statusCode != 200) return [];
      return parseGpxTrack(response.body);
    } catch (_) {
      return [];
    }
  }
}

/// In-memory implementation of [GpxApi] for widget/unit tests.
class FakeGpxApi implements GpxApi {
  final List<LatLng>? track;
  final bool shouldThrow;

  FakeGpxApi({this.track, this.shouldThrow = false});

  static const _defaultTrack = [
    LatLng(37.60, 126.40),
    LatLng(37.61, 126.41),
    LatLng(37.62, 126.42),
  ];

  @override
  Future<List<LatLng>> fetchGpxTrack(String gpxUrl) async {
    if (shouldThrow) return [];
    return track ?? _defaultTrack;
  }
}
