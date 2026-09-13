import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/utils/bird_scatter.dart';

BirdSpecies _species(String code, int? count, {String nameKo = ''}) {
  return BirdSpecies(
    nameKo: nameKo.isEmpty ? code : nameKo,
    nameSci: 'Sci $code',
    speciesCode: code,
    count: count,
    obsDt: '2026-09-01',
  );
}

/// Same planar approximation `scatterBirds` uses internally, for
/// independently checking the radius bound in tests.
double _distanceMeters(Coordinate center, Coordinate point) {
  final dLat = point.lat - center.lat;
  final dLng = point.lng - center.lng;
  final y = dLat * 111320;
  final x = dLng * 111320 * cos(center.lat * pi / 180);
  return sqrt(x * x + y * y);
}

void main() {
  const center = Coordinate(lat: 37.71, lng: 126.42);

  group('scatterBirds', () {
    test('emits exactly one marker per species, mapped 1:1', () {
      final topSpecies = [
        _species('A', 3, nameKo: '까치'),
        _species('B', null, nameKo: '박새'),
        _species('C', 12, nameKo: '직박구리'),
        _species('D', 1, nameKo: '참새'),
      ];

      final result = scatterBirds(
        center: center,
        topSpecies: topSpecies,
        speciesCount: 4,
        seed: 'spot-1',
      );

      expect(result.individuals.length, 4);
      for (var i = 0; i < topSpecies.length; i++) {
        final expected = topSpecies[i];
        final actual = result.individuals[i];
        expect(actual.nameKo, expected.nameKo);
        expect(actual.nameSci, expected.nameSci);
        expect(actual.speciesCode, expected.speciesCode);
        expect(actual.count, expected.count);
        expect(actual.obsDt, expected.obsDt);
      }
    });

    test('is deterministic for the same seed and inputs', () {
      final topSpecies = [
        _species('A', 10),
        _species('B', 5),
        _species('C', 3),
      ];

      final first = scatterBirds(
        center: center,
        topSpecies: topSpecies,
        speciesCount: 3,
        seed: 'spot-42',
      );
      final second = scatterBirds(
        center: center,
        topSpecies: topSpecies,
        speciesCount: 3,
        seed: 'spot-42',
      );

      expect(first.individuals.length, second.individuals.length);
      for (var i = 0; i < first.individuals.length; i++) {
        expect(first.individuals[i].coord.lat, second.individuals[i].coord.lat);
        expect(first.individuals[i].coord.lng, second.individuals[i].coord.lng);
        expect(first.individuals[i].speciesCode, second.individuals[i].speciesCode);
      }
    });

    test('keeps every individual within radiusMeters of center', () {
      const radiusMeters = 400.0;
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 280), _species('B', 2), _species('C', 1)],
        speciesCount: 3,
        seed: 'spot-radius',
        radiusMeters: radiusMeters,
      );

      for (final individual in result.individuals) {
        final distance = _distanceMeters(center, individual.coord);
        expect(distance, lessThanOrEqualTo(radiusMeters + 0.5));
      }
    });

    test('wasReduced is true and totalSpeciesCount is preserved when '
        'topSpecies is a subset of speciesCount', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 280), _species('B', 2), _species('C', 1)],
        speciesCount: 12,
        seed: 'spot-reduced',
      );

      expect(result.wasReduced, isTrue);
      expect(result.totalSpeciesCount, 12);
      expect(result.individuals.length, 3);
    });

    test('wasReduced is false when topSpecies covers all species', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 3), _species('B', 2), _species('C', 1)],
        speciesCount: 3,
        seed: 'spot-below-cap',
      );

      expect(result.wasReduced, isFalse);
      expect(result.individuals.length, 3);
    });

    test('empty topSpecies yields no individuals, wasReduced false, and '
        'totalSpeciesCount equal to speciesCount', () {
      final result = scatterBirds(
        center: center,
        topSpecies: const [],
        speciesCount: 5,
        seed: 'spot-empty',
      );

      expect(result.individuals, isEmpty);
      expect(result.wasReduced, isFalse);
      expect(result.totalSpeciesCount, 5);
    });
  });
}
