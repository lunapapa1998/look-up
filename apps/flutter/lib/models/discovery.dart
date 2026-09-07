import 'package:flutter/widgets.dart' show IconData;

/// Contract seam for the future fitness/suitability engine: a 0-100 score
/// plus supporting evidence fields. Currently populated from mock data in
/// the UI layer; a backend API will produce these values later.
enum ObsMode { day, night }

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
}

class GoldenHour {
  final ObsMode mode;
  final String timeRange;
  final String description;

  const GoldenHour({
    required this.mode,
    required this.timeRange,
    required this.description,
  });
}

class TelemetryReading {
  final String label;
  final String value;
  final IconData icon;

  const TelemetryReading({
    required this.label,
    required this.value,
    required this.icon,
  });
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
