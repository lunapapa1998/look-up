import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/models/starlight_forecast.dart';

void main() {
  group('StarlightForecast Model & API', () {
    const mockJson = '''
    {
      "title": "야간 전환 별빛 예보",
      "summary": "오늘 20:45 일몰 및 박명 종료 후 남동쪽 방위에서 페르세우스자리 은하수 육안 관측이 시작됩니다.",
      "location": {
        "lat": 37.7,
        "lng": 126.4
      },
      "timing": {
        "date": "2026-09-18",
        "sunset": "18:39",
        "civil_twilight_end": "19:05",
        "nautical_twilight_end": "19:36",
        "astronomical_twilight_end": "20:45",
        "forecast_reference_time": "20:45"
      },
      "target": {
        "id": "perseus_milky_way",
        "name": "페르세우스자리 은하수",
        "constellation": "페르세우스자리",
        "target_type": "milky_way",
        "altitude_deg": 28.5,
        "azimuth_deg": 135.0,
        "direction": "남동쪽",
        "observation_mode": "육안 관측",
        "description": "가을과 겨울 밤하늘을 가로지르는 은하수의 북쪽 줄기"
      },
      "conditions": {
        "lunar_age_days": 4.5,
        "moon_illumination_pct": 18,
        "moon_phase_name": "초승달",
        "sqm_value": 21.5,
        "sky_class": "Class 3",
        "milky_way_visible": true
      },
      "all_visible_targets": [],
      "degraded": false
    }
    ''';

    test('fromJson parses full payload correctly', () {
      final decoded = json.decode(mockJson) as Map<String, dynamic>;
      final forecast = StarlightForecast.fromJson(decoded);

      expect(forecast.title, '야간 전환 별빛 예보');
      expect(
        forecast.summary,
        '오늘 20:45 일몰 및 박명 종료 후 남동쪽 방위에서 페르세우스자리 은하수 육안 관측이 시작됩니다.',
      );
      expect(forecast.target.name, '페르세우스자리 은하수');
      expect(forecast.target.direction, '남동쪽');
      expect(forecast.target.observationMode, '육안 관측');
      expect(forecast.conditions.milkyWayVisible, isTrue);
      expect(forecast.conditions.moonIlluminationPct, 18);
    });

    test('HttpStarlightApi fetches and returns forecast', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/starlight-forecast');
        expect(request.url.queryParameters['lat'], '37.7');
        expect(request.url.queryParameters['lng'], '126.4');
        expect(request.url.queryParameters['target'], 'perseus_milky_way');

        return http.Response(
          mockJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = HttpStarlightApi('http://localhost:8000', client: mockClient);
      final result = await api.fetchForecast(
        lat: 37.7,
        lng: 126.4,
        target: 'perseus_milky_way',
      );

      expect(result.target.id, 'perseus_milky_way');
      expect(result.target.direction, '남동쪽');
      expect(result.summary, contains('페르세우스자리 은하수 육안 관측이 시작됩니다.'));
    });
  });
}
