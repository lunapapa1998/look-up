import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/tide_api.dart';
import 'package:lookup/models/tide.dart';

void main() {
  group('TodayTides.fromJson', () {
    test('parses a fully-populated example map', () {
      final tides = TodayTides.fromJson({
        'found': true,
        'degraded': false,
        'stationName': '인천',
        'extremes': [
          {'time': '06:00', 'kind': 'high', 'levelCm': 500},
          {'time': '12:00', 'kind': 'low', 'levelCm': 90},
        ],
      });

      expect(tides.found, isTrue);
      expect(tides.degraded, isFalse);
      expect(tides.stationName, '인천');
      expect(tides.extremes, hasLength(2));
      expect(tides.extremes[0].time, '06:00');
      expect(tides.extremes[0].kind, 'high');
      expect(tides.extremes[0].levelCm, 500);
      expect(tides.extremes[1].time, '12:00');
      expect(tides.extremes[1].kind, 'low');
      expect(tides.extremes[1].levelCm, 90);
    });

    test('parses a found-false example map with an empty extremes list', () {
      final tides = TodayTides.fromJson({
        'found': false,
        'degraded': false,
        'stationName': null,
        'extremes': [],
      });

      expect(tides.found, isFalse);
      expect(tides.degraded, isFalse);
      expect(tides.stationName, isNull);
      expect(tides.extremes, isEmpty);
    });
  });

  group('FakeTideApi', () {
    test('shouldThrow true throws TideApiException', () {
      final api = FakeTideApi(shouldThrow: true);

      expect(
        () => api.fetchTodayTides(lat: 37.71, lng: 126.42),
        throwsA(isA<TideApiException>()),
      );
    });

    test('response left null returns the honest found-false default', () async {
      final api = FakeTideApi();

      final tides = await api.fetchTodayTides(lat: 37.71, lng: 126.42);

      expect(tides.found, isFalse);
      expect(tides.degraded, isFalse);
      expect(tides.stationName, isNull);
      expect(tides.extremes, isEmpty);
    });
  });
}
