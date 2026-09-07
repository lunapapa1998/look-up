import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/models/observation.dart';

void main() {
  group('Observation', () {
    test('round-trips example 1 (photoUrl null, note set)', () {
      final jsonStr = '''
      {
        "id": 1,
        "speciesType": "bird",
        "speciesName": "까치",
        "note": "아파트 단지 나무 위",
        "photoUrl": null,
        "observedAt": "2026-09-07T05:12:34.123456Z",
        "lat": 37.5665,
        "lng": 126.978,
        "createdAt": "2026-09-07T05:12:34.123456Z"
      }
      ''';
      final map = json.decode(jsonStr) as Map<String, dynamic>;

      final observation = Observation.fromJson(map);

      expect(observation.id, 1);
      expect(observation.speciesType, SpeciesType.bird);
      expect(observation.speciesName, '까치');
      expect(observation.note, '아파트 단지 나무 위');
      expect(observation.photoUrl, isNull);
      expect(observation.observedAt, DateTime.parse('2026-09-07T05:12:34.123456Z'));
      expect(observation.lat, 37.5665);
      expect(observation.lng, 126.978);
      expect(observation.createdAt, DateTime.parse('2026-09-07T05:12:34.123456Z'));

      final roundTripped = Observation.fromJson(observation.toJson());
      expect(roundTripped.id, observation.id);
      expect(roundTripped.speciesType, observation.speciesType);
      expect(roundTripped.speciesName, observation.speciesName);
      expect(roundTripped.note, observation.note);
      expect(roundTripped.photoUrl, observation.photoUrl);
      expect(roundTripped.observedAt, observation.observedAt);
      expect(roundTripped.lat, observation.lat);
      expect(roundTripped.lng, observation.lng);
      expect(roundTripped.createdAt, observation.createdAt);
    });

    test('round-trips example 2 (lat/lng null, note null, photoUrl set)', () {
      final map = {
        'id': 2,
        'speciesType': 'star',
        'speciesName': '북두칠성',
        'note': null,
        'photoUrl': 'https://example.com/photos/2.jpg',
        'observedAt': '2026-09-06T20:00:00Z',
        'lat': null,
        'lng': null,
        'createdAt': '2026-09-06T20:05:00Z',
      };

      final observation = Observation.fromJson(map);

      expect(observation.id, 2);
      expect(observation.speciesType, SpeciesType.star);
      expect(observation.speciesName, '북두칠성');
      expect(observation.note, isNull);
      expect(observation.photoUrl, 'https://example.com/photos/2.jpg');
      expect(observation.observedAt, DateTime.parse('2026-09-06T20:00:00Z'));
      expect(observation.lat, isNull);
      expect(observation.lng, isNull);
      expect(observation.createdAt, DateTime.parse('2026-09-06T20:05:00Z'));

      final roundTripped = Observation.fromJson(observation.toJson());
      expect(roundTripped.id, observation.id);
      expect(roundTripped.speciesType, observation.speciesType);
      expect(roundTripped.speciesName, observation.speciesName);
      expect(roundTripped.note, observation.note);
      expect(roundTripped.photoUrl, observation.photoUrl);
      expect(roundTripped.observedAt, observation.observedAt);
      expect(roundTripped.lat, observation.lat);
      expect(roundTripped.lng, observation.lng);
      expect(roundTripped.createdAt, observation.createdAt);
    });
  });

  group('ObservationCreate', () {
    test('toJson omits null optional fields', () {
      final create = ObservationCreate(
        speciesType: SpeciesType.bird,
        speciesName: '참새',
      );

      final result = create.toJson();

      expect(result['speciesType'], 'bird');
      expect(result['speciesName'], '참새');
      expect(result.containsKey('note'), isFalse);
      expect(result.containsKey('photoUrl'), isFalse);
      expect(result.containsKey('observedAt'), isFalse);
      expect(result.containsKey('lat'), isFalse);
      expect(result.containsKey('lng'), isFalse);
    });

    test('toJson includes all fields when provided', () {
      final observedAt = DateTime.parse('2026-09-07T05:12:34.123456Z');
      final create = ObservationCreate(
        speciesType: SpeciesType.star,
        speciesName: '북두칠성',
        note: '맑은 밤',
        photoUrl: 'https://example.com/photos/3.jpg',
        observedAt: observedAt,
        lat: 37.5665,
        lng: 126.978,
      );

      final result = create.toJson();

      expect(result['speciesType'], 'star');
      expect(result['speciesName'], '북두칠성');
      expect(result['note'], '맑은 밤');
      expect(result['photoUrl'], 'https://example.com/photos/3.jpg');
      expect(result['observedAt'], observedAt.toIso8601String());
      expect(result['lat'], 37.5665);
      expect(result['lng'], 126.978);
    });
  });

  group('ObservationUpdate', () {
    test('toJson omits unset fields entirely', () {
      final update = ObservationUpdate();

      final result = update.toJson();

      expect(result, isEmpty);
    });

    test('toJson includes only explicitly-set fields, with explicit null for nullable ones', () {
      final update = ObservationUpdate(
        speciesName: '까치',
        note: null,
        noteSet: true,
        photoUrl: null,
        photoUrlSet: true,
      );

      final result = update.toJson();

      expect(result.containsKey('speciesType'), isFalse);
      expect(result['speciesName'], '까치');
      expect(result.containsKey('observedAt'), isFalse);
      expect(result.containsKey('note'), isTrue);
      expect(result['note'], isNull);
      expect(result.containsKey('photoUrl'), isTrue);
      expect(result['photoUrl'], isNull);
      expect(result.containsKey('lat'), isFalse);
      expect(result.containsKey('lng'), isFalse);
    });

    test('toJson sends non-null values for note/photoUrl/lat/lng when set', () {
      final update = ObservationUpdate(
        lat: 37.0,
        lng: 127.0,
      );

      final result = update.toJson();

      expect(result['lat'], 37.0);
      expect(result['lng'], 127.0);
      expect(result.containsKey('note'), isFalse);
      expect(result.containsKey('photoUrl'), isFalse);
    });

    test('toJson never omits speciesType/speciesName/observedAt as explicit null', () {
      final update = ObservationUpdate(
        speciesType: SpeciesType.star,
        observedAt: DateTime.parse('2026-09-06T20:00:00Z'),
      );

      final result = update.toJson();

      expect(result['speciesType'], 'star');
      expect(result['observedAt'], '2026-09-06T20:00:00.000Z');
      expect(result.containsKey('speciesName'), isFalse);
    });
  });

  group('BadgeProgress', () {
    test('round-trips example', () {
      final map = {
        'badge': {
          'id': 'first_step',
          'name': '첫 관찰',
          'description': '첫 관찰 기록을 남겼어요',
          'targetCount': 1,
        },
        'achieved': true,
        'currentCount': 2,
      };

      final progress = BadgeProgress.fromJson(map);

      expect(progress.badge.id, 'first_step');
      expect(progress.badge.name, '첫 관찰');
      expect(progress.badge.description, '첫 관찰 기록을 남겼어요');
      expect(progress.badge.targetCount, 1);
      expect(progress.achieved, isTrue);
      expect(progress.currentCount, 2);

      final roundTripped = BadgeProgress.fromJson(progress.toJson());
      expect(roundTripped.badge.id, progress.badge.id);
      expect(roundTripped.badge.name, progress.badge.name);
      expect(roundTripped.badge.description, progress.badge.description);
      expect(roundTripped.badge.targetCount, progress.badge.targetCount);
      expect(roundTripped.achieved, progress.achieved);
      expect(roundTripped.currentCount, progress.currentCount);
    });
  });
}
