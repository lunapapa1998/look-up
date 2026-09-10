import 'trails.dart';

class BirdSpecies {
  final String nameKo;
  final String nameSci;
  final String speciesCode;
  final int? count;
  final String obsDt;

  const BirdSpecies({
    required this.nameKo,
    required this.nameSci,
    required this.speciesCode,
    required this.count,
    required this.obsDt,
  });

  factory BirdSpecies.fromJson(Map<String, dynamic> json) {
    return BirdSpecies(
      nameKo: json['nameKo'] as String,
      nameSci: json['nameSci'] as String,
      speciesCode: json['speciesCode'] as String,
      count: json['count'] as int?,
      obsDt: json['obsDt'] as String,
    );
  }
}

class BirdObservation {
  final int speciesCount;
  final List<BirdSpecies> topSpecies;
  final String mostRecentObsDt;
  final String status;

  const BirdObservation({
    required this.speciesCount,
    required this.topSpecies,
    required this.mostRecentObsDt,
    required this.status,
  });

  factory BirdObservation.fromJson(Map<String, dynamic> json) {
    return BirdObservation(
      speciesCount: json['speciesCount'] as int,
      topSpecies: (json['topSpecies'] as List)
          .map((e) => BirdSpecies.fromJson(e as Map<String, dynamic>))
          .toList(),
      mostRecentObsDt: json['mostRecentObsDt'] as String,
      status: json['status'] as String,
    );
  }
}

class HeritageInfo {
  final String addr;
  final int? distanceM;
  final String contentId;

  const HeritageInfo({
    required this.addr,
    required this.distanceM,
    required this.contentId,
  });

  factory HeritageInfo.fromJson(Map<String, dynamic> json) {
    return HeritageInfo(
      addr: json['addr'] as String,
      distanceM: json['distanceM'] as int?,
      contentId: json['contentId'] as String,
    );
  }
}

/// [kind] is one of 'bird', 'star', 'heritage' (raw API value). Exactly one
/// of [nightSky] (star), [birds] (bird), [heritage] (heritage) is non-null.
class ObservationSpot {
  final String id;
  final String kind;
  final String name;
  final Coordinate coord;
  final NightSky? nightSky;
  final BirdObservation? birds;
  final HeritageInfo? heritage;

  const ObservationSpot({
    required this.id,
    required this.kind,
    required this.name,
    required this.coord,
    required this.nightSky,
    required this.birds,
    required this.heritage,
  });

  factory ObservationSpot.fromJson(Map<String, dynamic> json) {
    return ObservationSpot(
      id: json['id'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String,
      coord: Coordinate.fromJson(json['coord'] as Map<String, dynamic>),
      nightSky: json['nightSky'] == null
          ? null
          : NightSky.fromJson(json['nightSky'] as Map<String, dynamic>),
      birds: json['birds'] == null
          ? null
          : BirdObservation.fromJson(json['birds'] as Map<String, dynamic>),
      heritage: json['heritage'] == null
          ? null
          : HeritageInfo.fromJson(json['heritage'] as Map<String, dynamic>),
    );
  }
}

class ObservationMapResponse {
  final String region;
  final bool degraded;
  final List<ObservationSpot> spots;

  const ObservationMapResponse({
    required this.region,
    required this.degraded,
    required this.spots,
  });

  factory ObservationMapResponse.fromJson(Map<String, dynamic> json) {
    return ObservationMapResponse(
      region: json['region'] as String,
      degraded: json['degraded'] as bool,
      spots: (json['spots'] as List)
          .map((e) => ObservationSpot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
