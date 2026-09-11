import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/utils/bird_scatter.dart';

BirdSpecies _species(String code, int? count, {String nameKo = ''}) {
  return BirdSpecies(
    nameKo: nameKo.isEmpty ? code : nameKo,
    nameSci: code,
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
    test('never emits more than maxIndividuals individuals', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 280), _species('B', 2), _species('C', 1)],
        seed: 'spot-1',
      );

      expect(result.individuals.length, lessThanOrEqualTo(25));
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
        seed: 'spot-42',
      );
      final second = scatterBirds(
        center: center,
        topSpecies: topSpecies,
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
        seed: 'spot-radius',
        radiusMeters: radiusMeters,
      );

      for (final individual in result.individuals) {
        final distance = _distanceMeters(center, individual.coord);
        expect(distance, lessThanOrEqualTo(radiusMeters + 0.5));
      }
    });

    test('treats a null count as 1 without crashing or dropping the species', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', null), _species('B', 3)],
        seed: 'spot-null',
      );

      final codes = result.individuals.map((b) => b.speciesCode).toSet();
      expect(codes.contains('A'), isTrue);
      expect(result.totalCount, 4);
    });

    test('rare-species case: every species keeps at least 1 individual when reduced', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 280), _species('B', 2), _species('C', 1)],
        seed: 'spot-rare',
      );

      final countsBySpecies = <String, int>{};
      for (final individual in result.individuals) {
        countsBySpecies[individual.speciesCode] =
            (countsBySpecies[individual.speciesCode] ?? 0) + 1;
      }

      expect(countsBySpecies['A'], greaterThanOrEqualTo(1));
      expect(countsBySpecies['B'], greaterThanOrEqualTo(1));
      expect(countsBySpecies['C'], greaterThanOrEqualTo(1));
      expect(result.individuals.length, lessThanOrEqualTo(25));
      expect(result.wasReduced, isTrue);
    });

    test('below-cap case emits the exact real total and is not reduced', () {
      final result = scatterBirds(
        center: center,
        topSpecies: [_species('A', 3), _species('B', 2), _species('C', 1)],
        seed: 'spot-below-cap',
      );

      expect(result.wasReduced, isFalse);
      expect(result.individuals.length, 6);
    });
  });
}
