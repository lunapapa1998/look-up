class RegionCenter {
  final double lat;
  final double lng;

  const RegionCenter({
    required this.lat,
    required this.lng,
  });

  factory RegionCenter.fromJson(Map<String, dynamic> json) {
    return RegionCenter(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class RegionSummary {
  final String id;
  final String label;
  final double distanceKm;
  final RegionCenter center;
  final bool hasStarSpot;

  const RegionSummary({
    required this.id,
    required this.label,
    required this.distanceKm,
    required this.center,
    required this.hasStarSpot,
  });

  factory RegionSummary.fromJson(Map<String, dynamic> json) {
    return RegionSummary(
      id: json['id'] as String,
      label: json['label'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      center: RegionCenter.fromJson(json['center'] as Map<String, dynamic>),
      hasStarSpot: json['hasStarSpot'] as bool,
    );
  }
}

class RegionsResponse {
  final String nearestId;
  final List<RegionSummary> regions;

  const RegionsResponse({
    required this.nearestId,
    required this.regions,
  });

  factory RegionsResponse.fromJson(Map<String, dynamic> json) {
    return RegionsResponse(
      nearestId: json['nearestId'] as String,
      regions: (json['regions'] as List)
          .map((e) => RegionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
