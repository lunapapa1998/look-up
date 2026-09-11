import 'dart:math';

import '../models/observation_map.dart';
import '../models/trails.dart';

class ScatteredBird {
  final Coordinate coord;
  final String nameKo;
  final String speciesCode;

  const ScatteredBird({
    required this.coord,
    required this.nameKo,
    required this.speciesCode,
  });
}

class ScatterResult {
  final List<ScatteredBird> individuals;
  final bool wasReduced;
  final int totalCount;

  const ScatterResult({
    required this.individuals,
    required this.wasReduced,
    required this.totalCount,
  });
}

/// FNV-1a 32-bit hash. Not [String.hashCode], whose stability across Dart
/// versions is undocumented -- this seed must reproduce the same layout
/// forever for a given spot id.
int _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

ScatterResult scatterBirds({
  required Coordinate center,
  required List<BirdSpecies> topSpecies,
  required String seed,
  int maxIndividuals = 25,
  double radiusMeters = 400,
}) {
  if (topSpecies.isEmpty) {
    return const ScatterResult(
      individuals: [],
      wasReduced: false,
      totalCount: 0,
    );
  }

  final effectiveCounts = topSpecies
      .map((species) => species.count ?? 1)
      .toList(growable: false);
  final totalCount = effectiveCounts.fold<int>(0, (a, b) => a + b);

  List<int> allocations;
  bool wasReduced;

  if (totalCount <= maxIndividuals) {
    allocations = effectiveCounts;
    wasReduced = false;
  } else {
    wasReduced = true;
    final speciesTotal = topSpecies.length;
    if (speciesTotal > maxIndividuals) {
      allocations = List<int>.filled(speciesTotal, 0);
      for (var i = 0; i < maxIndividuals; i++) {
        allocations[i] = 1;
      }
    } else {
      final remaining = maxIndividuals - speciesTotal;
      final shares = List<double>.generate(
        speciesTotal,
        (i) => effectiveCounts[i] / totalCount * remaining,
      );
      final floors = shares.map((share) => share.floor()).toList(
        growable: false,
      );
      final allocatedFromFloor = floors.fold<int>(0, (a, b) => a + b);
      final leftover = remaining - allocatedFromFloor;

      final byRemainderDesc = List<int>.generate(speciesTotal, (i) => i)
        ..sort((a, b) {
          final remainderA = shares[a] - floors[a];
          final remainderB = shares[b] - floors[b];
          final cmp = remainderB.compareTo(remainderA);
          if (cmp != 0) return cmp;
          return a.compareTo(b);
        });

      allocations = List<int>.generate(speciesTotal, (i) => 1 + floors[i]);
      for (var i = 0; i < leftover; i++) {
        allocations[byRemainderDesc[i]] += 1;
      }
    }
  }

  final random = Random(_fnv1a32(seed));
  final individuals = <ScatteredBird>[];
  for (var i = 0; i < topSpecies.length; i++) {
    final species = topSpecies[i];
    final count = i < allocations.length ? allocations[i] : 0;
    for (var j = 0; j < count; j++) {
      final angle = random.nextDouble() * 2 * pi;
      final radiusFraction = sqrt(random.nextDouble());
      final actualRadius = radiusFraction * radiusMeters;
      final dLat = actualRadius * cos(angle) / 111320;
      final dLng =
          actualRadius * sin(angle) / (111320 * cos(center.lat * pi / 180));
      individuals.add(
        ScatteredBird(
          coord: Coordinate(lat: center.lat + dLat, lng: center.lng + dLng),
          nameKo: species.nameKo,
          speciesCode: species.speciesCode,
        ),
      );
    }
  }

  return ScatterResult(
    individuals: individuals,
    wasReduced: wasReduced,
    totalCount: totalCount,
  );
}
