import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/regions_api.dart';
import 'package:lookup/models/region.dart';

void main() {
  group('RegionsResponse.fromJson', () {
    test('parses a fully-populated example map', () {
      final response = RegionsResponse.fromJson({
        'nearestId': 'ganghwa',
        'regions': [
          {
            'id': 'ganghwa',
            'label': '인천 강화군',
            'distanceKm': 0.0,
            'center': {'lat': 37.7469, 'lng': 126.4878},
            'hasStarSpot': true,
          },
          {
            'id': 'pyeongchang',
            'label': '강원 평창군',
            'distanceKm': 120.5,
            'center': {'lat': 37.3705, 'lng': 128.39},
            'hasStarSpot': true,
          },
        ],
      });

      expect(response.nearestId, 'ganghwa');
      expect(response.regions, hasLength(2));

      final ganghwa = response.regions[0];
      expect(ganghwa.id, 'ganghwa');
      expect(ganghwa.label, '인천 강화군');
      expect(ganghwa.distanceKm, 0.0);
      expect(ganghwa.center.lat, 37.7469);
      expect(ganghwa.center.lng, 126.4878);
      expect(ganghwa.hasStarSpot, isTrue);

      final pyeongchang = response.regions[1];
      expect(pyeongchang.id, 'pyeongchang');
      expect(pyeongchang.label, '강원 평창군');
      expect(pyeongchang.distanceKm, 120.5);
      expect(pyeongchang.center.lat, 37.3705);
      expect(pyeongchang.center.lng, 128.39);
      expect(pyeongchang.hasStarSpot, isTrue);
    });
  });

  group('FakeRegionsApi', () {
    test('shouldThrow true throws RegionsApiException', () {
      final api = FakeRegionsApi(shouldThrow: true);

      expect(
        () => api.fetchRegions(lat: 37.71, lng: 126.42),
        throwsA(isA<RegionsApiException>()),
      );
    });

    test('response left null returns the default nearestId ganghwa', () async {
      final api = FakeRegionsApi();

      final regions = await api.fetchRegions(lat: 37.71, lng: 126.42);

      expect(regions.nearestId, 'ganghwa');
    });
  });
}
