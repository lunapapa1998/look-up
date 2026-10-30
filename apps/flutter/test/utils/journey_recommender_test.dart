import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/utils/journey_recommender.dart';

ObservationSpot _bird(String id, int count, String recent) => ObservationSpot(
  id: id,
  kind: 'bird',
  name: '새 장소 $id',
  coord: const Coordinate(lat: 37.6, lng: 126.4),
  nightSky: null,
  birds: BirdObservation(
    speciesCount: count,
    topSpecies: const [],
    mostRecentObsDt: recent,
    status: 'community',
  ),
  heritage: null,
);

ObservationSpot _star(String id, double sqm) => ObservationSpot(
  id: id,
  kind: 'star',
  name: '별 장소 $id',
  coord: const Coordinate(lat: 37.7, lng: 126.4),
  nightSky: NightSky(
    sqmValue: sqm,
    bortleClass: 3,
    skyClass: 'Class 3',
    status: 'approx',
  ),
  birds: null,
  heritage: null,
);

const _heritage = ObservationSpot(
  id: 'h1',
  kind: 'heritage',
  name: '노포',
  coord: Coordinate(lat: 37.6, lng: 126.4),
  nightSky: null,
  birds: null,
  heritage: HeritageInfo(addr: '강화', distanceM: 100, contentId: '1'),
);

const _goldenHours = [
  GoldenHour(
    mode: ObsMode.day,
    label: '낮 · 탐조 골든타임',
    timeRange: '14:00 - 17:30',
    description: '',
  ),
  GoldenHour(
    mode: ObsMode.night,
    label: '밤 · 천체 골든타임',
    timeRange: '21:40 - 01:20',
    description: '',
  ),
];

void main() {
  group('recommendJourneySpot', () {
    test('day picks the bird spot with the most recorded species', () {
      final rec = recommendJourneySpot(ObsMode.day, [
        _bird('a', 5, '2026-09-09 07:00'),
        _bird('b', 12, '2026-09-01 07:00'),
        _star('s', 21.9),
        _heritage,
      ]);
      expect(rec, isNotNull);
      expect(rec!.spot.id, 'b');
      expect(rec.reason, '최근 14일 시민과학 데이터(eBird) 기준 12종 기록');
      expect(rec.reason, isNot(contains('볼 수 있어요')));
    });

    test('day breaks species-count ties by the most recent observation', () {
      final rec = recommendJourneySpot(ObsMode.day, [
        _bird('old', 8, '2026-09-01 07:00'),
        _bird('new', 8, '2026-09-09 06:00'),
      ]);
      expect(rec!.spot.id, 'new');
    });

    test('night picks the star spot with the highest SQM', () {
      final rec = recommendJourneySpot(ObsMode.night, [
        _star('dim', 19.2),
        _star('dark', 21.64),
        _bird('b', 30, '2026-09-09 07:00'),
      ]);
      expect(rec!.spot.id, 'dark');
      expect(rec.reason, 'SQM 21.6 · 빛공해 참고 데이터');
    });

    test('no qualifying data returns null', () {
      expect(recommendJourneySpot(ObsMode.day, const []), isNull);
      expect(recommendJourneySpot(ObsMode.night, const []), isNull);
      expect(
        recommendJourneySpot(ObsMode.day, [_star('s', 21.0), _heritage]),
        isNull,
      );
      expect(
        recommendJourneySpot(ObsMode.day, [_bird('zero', 0, '2026-09-09')]),
        isNull,
      );
      expect(
        recommendJourneySpot(ObsMode.night, [
          _bird('b', 5, '2026-09-09 07:00'),
        ]),
        isNull,
      );
    });
  });

  group('goldenTimeLine', () {
    test('before the day window shows the next start time', () {
      expect(
        goldenTimeLine(_goldenHours, ObsMode.day, DateTime(2026, 9, 9, 10)),
        '다음 관찰 시간 14:00',
      );
    });

    test('inside the day window shows now', () {
      expect(
        goldenTimeLine(
          _goldenHours,
          ObsMode.day,
          DateTime(2026, 9, 9, 15, 10),
        ),
        '지금 관찰 시간 · 17:30까지',
      );
    });

    test('night window wrapping past midnight', () {
      expect(
        goldenTimeLine(_goldenHours, ObsMode.night, DateTime(2026, 9, 9, 23)),
        '지금 관찰 시간 · 01:20까지',
      );
      expect(
        goldenTimeLine(_goldenHours, ObsMode.night, DateTime(2026, 9, 10, 0, 30)),
        '지금 관찰 시간 · 01:20까지',
      );
      expect(
        goldenTimeLine(_goldenHours, ObsMode.night, DateTime(2026, 9, 9, 10)),
        '다음 관찰 시간 21:40',
      );
    });

    test('unparseable range falls back to the original text', () {
      const odd = [
        GoldenHour(
          mode: ObsMode.day,
          label: '',
          timeRange: '오후 내내',
          description: '',
        ),
      ];
      expect(
        goldenTimeLine(odd, ObsMode.day, DateTime(2026, 9, 9, 10)),
        '관찰 시간 오후 내내',
      );
    });

    test('no golden hour for the mode returns null', () {
      expect(
        goldenTimeLine(const [], ObsMode.day, DateTime(2026, 9, 9, 10)),
        isNull,
      );
    });
  });
}
