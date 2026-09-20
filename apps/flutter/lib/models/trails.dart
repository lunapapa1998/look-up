class Coordinate {
  final double lat;
  final double lng;

  const Coordinate({
    required this.lat,
    required this.lng,
  });

  factory Coordinate.fromJson(Map<String, dynamic> json) {
    return Coordinate(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class NightSky {
  final double sqmValue;
  final int bortleClass;
  final String skyClass;
  final String? status;

  const NightSky({
    required this.sqmValue,
    required this.bortleClass,
    required this.skyClass,
    required this.status,
  });

  factory NightSky.fromJson(Map<String, dynamic> json) {
    return NightSky(
      sqmValue: (json['sqmValue'] as num).toDouble(),
      bortleClass: json['bortleClass'] as int,
      skyClass: json['skyClass'] as String,
      status: json['status'] as String?,
    );
  }
}

class HeritageEat {
  final String name;
  final String addr;
  final int distanceM;
  final double lat;
  final double lng;
  final String contentId;

  const HeritageEat({
    required this.name,
    required this.addr,
    required this.distanceM,
    required this.lat,
    required this.lng,
    required this.contentId,
  });

  factory HeritageEat.fromJson(Map<String, dynamic> json) {
    return HeritageEat(
      name: json['name'] as String,
      addr: json['addr'] as String,
      distanceM: json['distanceM'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      contentId: json['contentId'] as String,
    );
  }
}

class CourseSuitability {
  final int score;
  final String label;
  final String status;

  const CourseSuitability({
    required this.score,
    required this.label,
    required this.status,
  });

  factory CourseSuitability.fromJson(Map<String, dynamic> json) {
    return CourseSuitability(
      score: json['score'] as int,
      label: json['label'] as String,
      status: json['status'] as String,
    );
  }
}

class TrailCourse {
  final String crsIdx;
  final String name;
  final String sigun;
  final double distanceKm;
  final int durationMin;
  final int level;
  final String cycle;
  final String gpxUrl;
  final Coordinate start;
  final Coordinate end;
  final NightSky nightSky;
  final List<HeritageEat> heritageEats;
  final CourseSuitability? daySuitability;
  final CourseSuitability? nightSuitability;

  const TrailCourse({
    required this.crsIdx,
    required this.name,
    required this.sigun,
    required this.distanceKm,
    required this.durationMin,
    required this.level,
    required this.cycle,
    required this.gpxUrl,
    required this.start,
    required this.end,
    required this.nightSky,
    required this.heritageEats,
    required this.daySuitability,
    required this.nightSuitability,
  });

  factory TrailCourse.fromJson(Map<String, dynamic> json) {
    return TrailCourse(
      crsIdx: json['crsIdx'] as String,
      name: json['name'] as String,
      sigun: json['sigun'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMin: json['durationMin'] as int,
      level: json['level'] as int,
      cycle: json['cycle'] as String,
      gpxUrl: json['gpxUrl'] as String,
      start: Coordinate.fromJson(json['start'] as Map<String, dynamic>),
      end: Coordinate.fromJson(json['end'] as Map<String, dynamic>),
      nightSky: NightSky.fromJson(json['nightSky'] as Map<String, dynamic>),
      heritageEats: (json['heritageEats'] as List)
          .map((e) => HeritageEat.fromJson(e as Map<String, dynamic>))
          .toList(),
      daySuitability: json['daySuitability'] == null
          ? null
          : CourseSuitability.fromJson(
              json['daySuitability'] as Map<String, dynamic>,
            ),
      nightSuitability: json['nightSuitability'] == null
          ? null
          : CourseSuitability.fromJson(
              json['nightSuitability'] as Map<String, dynamic>,
            ),
    );
  }
}

class TrailsResponse {
  final String region;
  final bool degraded;
  final List<TrailCourse> courses;

  const TrailsResponse({
    required this.region,
    required this.degraded,
    required this.courses,
  });

  factory TrailsResponse.fromJson(Map<String, dynamic> json) {
    return TrailsResponse(
      region: json['region'] as String,
      degraded: json['degraded'] as bool,
      courses: (json['courses'] as List)
          .map((e) => TrailCourse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ElevationPoint {
  final double positionRatio;
  final double elevationM;

  const ElevationPoint({
    required this.positionRatio,
    required this.elevationM,
  });

  factory ElevationPoint.fromJson(Map<String, dynamic> json) {
    return ElevationPoint(
      positionRatio: (json['positionRatio'] as num).toDouble(),
      elevationM: (json['elevationM'] as num).toDouble(),
    );
  }
}

class TrailDetailResponse {
  final String crsIdx;
  final bool found;
  final String? description;
  final String? themeId;
  final String? startName;
  final String? endName;
  final String? travelerInfo;
  final String? tourInfo;
  final List<ElevationPoint> elevationProfile;
  final bool degraded;

  const TrailDetailResponse({
    required this.crsIdx,
    required this.found,
    required this.description,
    required this.themeId,
    required this.startName,
    required this.endName,
    required this.travelerInfo,
    required this.tourInfo,
    required this.elevationProfile,
    required this.degraded,
  });

  factory TrailDetailResponse.fromJson(Map<String, dynamic> json) {
    return TrailDetailResponse(
      crsIdx: json['crsIdx'] as String,
      found: json['found'] as bool,
      description: json['description'] as String?,
      themeId: json['themeId'] as String?,
      startName: json['startName'] as String?,
      endName: json['endName'] as String?,
      travelerInfo: json['travelerInfo'] as String?,
      tourInfo: json['tourInfo'] as String?,
      elevationProfile: json['elevationProfile'] == null
          ? const []
          : (json['elevationProfile'] as List)
              .map((e) => ElevationPoint.fromJson(e as Map<String, dynamic>))
              .toList(),
      degraded: json['degraded'] as bool,
    );
  }
}
