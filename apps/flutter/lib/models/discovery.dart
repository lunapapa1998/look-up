import 'package:flutter/widgets.dart' show IconData;

/// Contract seam for the future fitness/suitability engine: a 0-100 score
/// plus supporting evidence fields. Currently populated from mock data in
/// the UI layer; a backend API will produce these values later.
enum ObsMode { day, night }

extension ObsModeQueryValue on ObsMode {
  String toQueryValue() {
    switch (this) {
      case ObsMode.day:
        return 'day';
      case ObsMode.night:
        return 'night';
    }
  }
}

ObsMode obsModeFromApiValue(String value) {
  return value == 'night' ? ObsMode.night : ObsMode.day;
}

class SuitabilityIndex {
  final int score;
  final String label;
  final double sqmValue;
  final String skyClass;

  const SuitabilityIndex({
    required this.score,
    required this.label,
    required this.sqmValue,
    required this.skyClass,
  });

  factory SuitabilityIndex.fromJson(Map<String, dynamic> json) {
    return SuitabilityIndex(
      score: json['score'] as int,
      label: json['label'] as String,
      sqmValue: (json['sqmValue'] as num).toDouble(),
      skyClass: json['skyClass'] as String,
    );
  }
}

class GoldenHour {
  final ObsMode mode;
  final String label;
  final String timeRange;
  final String description;

  const GoldenHour({
    required this.mode,
    required this.label,
    required this.timeRange,
    required this.description,
  });

  factory GoldenHour.fromJson(Map<String, dynamic> json) {
    return GoldenHour(
      mode: obsModeFromApiValue(json['mode'] as String),
      label: json['label'] as String,
      timeRange: json['timeRange'] as String,
      description: json['description'] as String,
    );
  }
}

class TelemetryReading {
  final String kind;
  final String label;
  final String value;

  const TelemetryReading({
    required this.kind,
    required this.label,
    required this.value,
  });

  factory TelemetryReading.fromJson(Map<String, dynamic> json) {
    return TelemetryReading(
      kind: json['kind'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }
}

class Moon {
  final int illumination;
  final String phaseName;
  final String? moonrise;
  final String? moonset;
  final String status;

  const Moon({
    required this.illumination,
    required this.phaseName,
    this.moonrise,
    this.moonset,
    required this.status,
  });

  factory Moon.fromJson(Map<String, dynamic> json) {
    return Moon(
      illumination: json['illumination'] as int,
      phaseName: json['phaseName'] as String,
      moonrise: json['moonrise'] as String?,
      moonset: json['moonset'] as String?,
      status: json['status'] as String,
    );
  }
}

/// Bundles the suitability index, golden hours, and telemetry readings
/// shown on the discovery screen.
class DiscoveryOverview {
  final SuitabilityIndex suitabilityIndex;
  final List<GoldenHour> goldenHours;
  final List<TelemetryReading> telemetry;
  final bool degraded;
  final Moon? moon;

  const DiscoveryOverview({
    required this.suitabilityIndex,
    required this.goldenHours,
    required this.telemetry,
    required this.degraded,
    this.moon,
  });

  factory DiscoveryOverview.fromJson(Map<String, dynamic> json) {
    return DiscoveryOverview(
      suitabilityIndex: SuitabilityIndex.fromJson(json),
      goldenHours: (json['goldenHours'] as List)
          .map((e) => GoldenHour.fromJson(e as Map<String, dynamic>))
          .toList(),
      telemetry: (json['telemetry'] as List)
          .map((e) => TelemetryReading.fromJson(e as Map<String, dynamic>))
          .toList(),
      degraded: json['degraded'] as bool,
      moon: json['moon'] == null
          ? null
          : Moon.fromJson(json['moon'] as Map<String, dynamic>),
    );
  }
}

class HotspotMeta {
  final IconData icon;
  final String label;

  const HotspotMeta({
    required this.icon,
    required this.label,
  });
}

class Hotspot {
  final ObsMode mode;
  final List<String> badges;
  final int suitabilityScore;
  final IconData scoreIcon;
  final IconData overlayIcon;
  final String overlayHeadline;
  final String overlayTimestamp;
  final String title;
  final String subtitle;
  final String description;
  final List<HotspotMeta> metas;
  final String ctaLabel;

  const Hotspot({
    required this.mode,
    required this.badges,
    required this.suitabilityScore,
    required this.scoreIcon,
    required this.overlayIcon,
    required this.overlayHeadline,
    required this.overlayTimestamp,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.metas,
    required this.ctaLabel,
  });
}
