import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/trails.dart';

/// Thrown by [TrailsApi] implementations when the server returns a
/// non-2xx response. [message] is the response body, or the `detail` field
/// of a JSON error body when present.
class TrailsApiException implements Exception {
  final int statusCode;
  final String message;

  TrailsApiException(this.statusCode, this.message);

  @override
  String toString() => 'TrailsApiException($statusCode): $message';
}

/// Contract for the `/api/trails` trails-heritage backend. JSON bodies, no
/// auth. Mode-independent — unlike [SuitabilityApi], there is no `mode`
/// parameter.
abstract class TrailsApi {
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  });

  Future<TrailDetailResponse> fetchTrailDetail({
    required String crsIdx,
  });
}

/// HTTP implementation of [TrailsApi] against a FastAPI-style backend.
class HttpTrailsApi implements TrailsApi {
  final String baseUrl;
  final http.Client client;

  HttpTrailsApi(this.baseUrl, {http.Client? client})
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
    throw TrailsApiException(response.statusCode, message);
  }

  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/api/trails').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );
    final response = await client.get(uri);
    _checkStatus(response, 200);
    return TrailsResponse.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({
    required String crsIdx,
  }) async {
    final uri = Uri.parse('$baseUrl/api/trails/detail').replace(
      queryParameters: {
        'crsIdx': crsIdx,
      },
    );
    final response = await client.get(uri);
    _checkStatus(response, 200);
    return TrailDetailResponse.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}

/// In-memory implementation of [TrailsApi] for widget/unit tests. No HTTP;
/// returns deterministic data with a featured (SQM-highest) course first.
class FakeTrailsApi implements TrailsApi {
  final bool degraded;
  final bool shouldThrow;
  final void Function(double lat, double lng)? onFetch;
  final TrailDetailResponse? trailDetailResponse;
  final bool trailDetailShouldThrow;

  FakeTrailsApi({
    this.degraded = false,
    this.shouldThrow = false,
    this.onFetch,
    this.trailDetailResponse,
    this.trailDetailShouldThrow = false,
  });

  static const _featuredCourse = TrailCourse(
    crsIdx: 'T_CRS_MNG0000009999',
    name: '서해랑길 101코스',
    sigun: '인천 강화군',
    distanceKm: 11.0,
    durationMin: 210,
    level: 1,
    cycle: '비순환형',
    gpxUrl: 'https://www.durunubi.kr/courseInfo/101.gpx',
    start: Coordinate(lat: 37.71, lng: 126.42),
    end: Coordinate(lat: 37.60, lng: 126.41),
    nightSky: NightSky(
      sqmValue: 20.15,
      bortleClass: 3,
      skyClass: 'Class 3 양호한 다크스카이',
      status: 'approx',
    ),
    heritageEats: [
      HeritageEat(
        name: '꽃게와낙지',
        addr: '인천광역시 강화군 화도면 해안남로 123',
        distanceM: 1363,
        lat: 37.601,
        lng: 126.412,
        contentId: '855186',
      ),
      HeritageEat(
        name: '강화도령보리밥',
        addr: '인천광역시 강화군 화도면 해안남로 200',
        distanceM: 1820,
        lat: 37.603,
        lng: 126.415,
        contentId: '855201',
      ),
    ],
    daySuitability: CourseSuitability(
      score: 67,
      label: '쾌적',
      status: 'live',
    ),
    nightSuitability: CourseSuitability(
      score: 64,
      label: '천체관측 양호',
      status: 'live',
    ),
  );

  static const _secondCourse = TrailCourse(
    crsIdx: 'T_CRS_MNG0000008888',
    name: '강화나들길 2코스',
    sigun: '인천 강화군',
    distanceKm: 17.4,
    durationMin: 330,
    level: 2,
    cycle: '순환형',
    gpxUrl: 'https://www.durunubi.kr/courseInfo/88.gpx',
    start: Coordinate(lat: 37.74, lng: 126.45),
    end: Coordinate(lat: 37.69, lng: 126.38),
    nightSky: NightSky(
      sqmValue: 18.2,
      bortleClass: 4,
      skyClass: 'Class 4 도시외곽 다크스카이',
      status: 'approx',
    ),
    heritageEats: [
      HeritageEat(
        name: '나들길메밀국수',
        addr: '인천광역시 강화군 불은면 강화대로 55',
        distanceM: 940,
        lat: 37.691,
        lng: 126.381,
        contentId: '855322',
      ),
    ],
    daySuitability: null,
    nightSuitability: null,
  );

  static const _thirdCourse = TrailCourse(
    crsIdx: 'T_CRS_MNG0000007777',
    name: '강화나들길 4코스',
    sigun: '인천 강화군',
    distanceKm: 14.0,
    durationMin: 270,
    level: 2,
    cycle: '비순환형',
    gpxUrl: 'https://www.durunubi.kr/courseInfo/77.gpx',
    start: Coordinate(lat: 37.78, lng: 126.33),
    end: Coordinate(lat: 37.65, lng: 126.35),
    nightSky: NightSky(
      sqmValue: 16.0,
      bortleClass: 5,
      skyClass: 'Class 5 교외 다크스카이',
      status: 'approx',
    ),
    heritageEats: [
      HeritageEat(
        name: '내가면손두부',
        addr: '인천광역시 강화군 내가면 고천로 12',
        distanceM: 1520,
        lat: 37.651,
        lng: 126.352,
        contentId: '855410',
      ),
    ],
    daySuitability: null,
    nightSuitability: null,
  );

  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  }) async {
    onFetch?.call(lat, lng);
    if (shouldThrow) {
      throw TrailsApiException(500, 'fake failure');
    }
    return TrailsResponse(
      region: '인천 강화군',
      degraded: degraded,
      courses: const [_featuredCourse, _secondCourse, _thirdCourse],
    );
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({
    required String crsIdx,
  }) async {
    if (trailDetailShouldThrow) {
      throw TrailsApiException(500, 'fake trail detail failure');
    }
    if (trailDetailResponse != null) {
      return trailDetailResponse!;
    }
    return TrailDetailResponse(
      crsIdx: crsIdx,
      found: false,
      description: null,
      themeId: null,
      startName: null,
      endName: null,
      travelerInfo: null,
      tourInfo: null,
      elevationProfile: const [],
      degraded: false,
    );
  }
}
