import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/models/discovery.dart';

void main() {
  group('Moon parsing', () {
    test('parses full moon object from json', () {
      final map = <String, dynamic>{
        'score': 92,
        'label': '매우 쾌적',
        'sqmValue': 21.6,
        'skyClass': 'Class 1',
        'goldenHours': [],
        'telemetry': [],
        'degraded': false,
        'moon': {
          'illumination': 96,
          'phaseName': '보름달',
          'moonrise': '18:32',
          'moonset': '05:12',
          'status': 'live',
        },
      };

      final overview = DiscoveryOverview.fromJson(map);

      expect(overview.moon, isNotNull);
      expect(overview.moon!.illumination, 96);
      expect(overview.moon!.phaseName, '보름달');
      expect(overview.moon!.moonrise, '18:32');
      expect(overview.moon!.moonset, '05:12');
      expect(overview.moon!.status, 'live');
    });

    test('moon null value yields null overview moon', () {
      final map = <String, dynamic>{
        'score': 92,
        'label': '매우 쾌적',
        'sqmValue': 21.6,
        'skyClass': 'Class 1',
        'goldenHours': [],
        'telemetry': [],
        'degraded': false,
        'moon': null,
      };

      final overview = DiscoveryOverview.fromJson(map);

      expect(overview.moon, isNull);
    });

    test('missing moon key yields null overview moon', () {
      final map = <String, dynamic>{
        'score': 92,
        'label': '매우 쾌적',
        'sqmValue': 21.6,
        'skyClass': 'Class 1',
        'goldenHours': [],
        'telemetry': [],
        'degraded': false,
      };

      final overview = DiscoveryOverview.fromJson(map);

      expect(overview.moon, isNull);
    });

    test('Moon fromJson with null moonrise and moonset', () {
      final map = <String, dynamic>{
        'illumination': 40,
        'phaseName': '하현 반달',
        'moonrise': null,
        'moonset': null,
        'status': 'approx',
      };

      final moon = Moon.fromJson(map);

      expect(moon.moonrise, isNull);
      expect(moon.moonset, isNull);
      expect(moon.illumination, 40);
      expect(moon.status, 'approx');
    });
  });
}
