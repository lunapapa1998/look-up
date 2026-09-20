class StarlightTarget {
  final String id;
  final String name;
  final String constellation;
  final String targetType;
  final double altitudeDeg;
  final double azimuthDeg;
  final String direction;
  final String observationMode;
  final String description;

  const StarlightTarget({
    required this.id,
    required this.name,
    required this.constellation,
    required this.targetType,
    required this.altitudeDeg,
    required this.azimuthDeg,
    required this.direction,
    required this.observationMode,
    required this.description,
  });

  factory StarlightTarget.fromJson(Map<String, dynamic> json) {
    return StarlightTarget(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      constellation: json['constellation'] as String? ?? '',
      targetType: json['target_type'] as String? ?? '',
      altitudeDeg: (json['altitude_deg'] as num?)?.toDouble() ?? 0.0,
      azimuthDeg: (json['azimuth_deg'] as num?)?.toDouble() ?? 0.0,
      direction: json['direction'] as String? ?? '',
      observationMode: json['observation_mode'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class StarlightConditions {
  final double lunarAgeDays;
  final int moonIlluminationPct;
  final String moonPhaseName;
  final double sqmValue;
  final String skyClass;
  final bool milkyWayVisible;

  const StarlightConditions({
    required this.lunarAgeDays,
    required this.moonIlluminationPct,
    required this.moonPhaseName,
    required this.sqmValue,
    required this.skyClass,
    required this.milkyWayVisible,
  });

  factory StarlightConditions.fromJson(Map<String, dynamic> json) {
    return StarlightConditions(
      lunarAgeDays: (json['lunar_age_days'] as num?)?.toDouble() ?? 0.0,
      moonIlluminationPct: json['moon_illumination_pct'] as int? ?? 0,
      moonPhaseName: json['moon_phase_name'] as String? ?? '',
      sqmValue: (json['sqm_value'] as num?)?.toDouble() ?? 0.0,
      skyClass: json['sky_class'] as String? ?? '',
      milkyWayVisible: json['milky_way_visible'] as bool? ?? false,
    );
  }
}

class StarlightForecast {
  final String title;
  final String summary;
  final double lat;
  final double lng;
  final String date;
  final String sunset;
  final String astronomicalTwilightEnd;
  final StarlightTarget target;
  final List<StarlightTarget> allVisibleTargets;
  final StarlightConditions conditions;
  final bool degraded;

  const StarlightForecast({
    required this.title,
    required this.summary,
    required this.lat,
    required this.lng,
    required this.date,
    required this.sunset,
    required this.astronomicalTwilightEnd,
    required this.target,
    required this.allVisibleTargets,
    required this.conditions,
    required this.degraded,
  });

  factory StarlightForecast.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final timing = json['timing'] as Map<String, dynamic>? ?? {};
    final target = json['target'] as Map<String, dynamic>? ?? {};
    final conditions = json['conditions'] as Map<String, dynamic>? ?? {};

    return StarlightForecast(
      title: json['title'] as String? ?? '야간 전환 별빛 예보',
      summary: json['summary'] as String? ?? '',
      lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
      date: timing['date'] as String? ?? '',
      sunset: timing['sunset'] as String? ?? '',
      astronomicalTwilightEnd: timing['astronomical_twilight_end'] as String? ?? '',
      target: StarlightTarget.fromJson(target),
      allVisibleTargets: (json['all_visible_targets'] as List<dynamic>? ?? const [])
          .map((e) => StarlightTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      conditions: StarlightConditions.fromJson(conditions),
      degraded: json['degraded'] as bool? ?? false,
    );
  }
}
