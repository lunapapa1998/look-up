import 'dart:math';

import '../models/observation_map.dart';
import '../models/trails.dart';

/// One species' representative marker within a spot's scatter (spec 019 P2):
/// exactly one [ScatteredBird] per species in [scatterBirds]'s `topSpecies`
/// input, never one per observed individual.
class ScatteredBird {
  final Coordinate coord;
  final String nameKo;
  final String nameSci;
  final String speciesCode;
  final int? count;
  final String obsDt;

  const ScatteredBird({
    required this.coord,
    required this.nameKo,
    required this.nameSci,
    required this.speciesCode,
    required this.count,
    required this.obsDt,
  });
}

/// Result of scattering a spot's top species into representative markers.
class ScatterResult {
  /// One entry per species in `topSpecies` -- never one per observed
  /// individual bird.
  final List<ScatteredBird> individuals;

  /// True when `topSpecies` is a strict subset of the spot's total species
  /// (i.e. only the top few species are being shown, and some were omitted).
  final bool wasReduced;

  /// The spot's total observed species count (the `speciesCount` argument
  /// passed to [scatterBirds]) -- `topSpecies` may only cover the top few of
  /// these.
  final int totalSpeciesCount;

  const ScatterResult({
    required this.individuals,
    required this.wasReduced,
    required this.totalSpeciesCount,
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
  required int speciesCount,
  required String seed,
  double radiusMeters = 400,
}) {
  if (topSpecies.isEmpty) {
    return ScatterResult(
      individuals: const [],
      wasReduced: false,
      totalSpeciesCount: speciesCount,
    );
  }

  final random = Random(_fnv1a32(seed));
  final individuals = <ScatteredBird>[];
  for (final species in topSpecies) {
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
        nameSci: species.nameSci,
        speciesCode: species.speciesCode,
        count: species.count,
        obsDt: species.obsDt,
      ),
    );
  }

  return ScatterResult(
    individuals: individuals,
    wasReduced: topSpecies.length < speciesCount,
    totalSpeciesCount: speciesCount,
  );
}
