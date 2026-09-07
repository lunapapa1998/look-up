enum SpeciesType {
  bird,
  star;

  static SpeciesType fromJson(String value) {
    switch (value) {
      case 'bird':
        return SpeciesType.bird;
      case 'star':
        return SpeciesType.star;
      default:
        throw ArgumentError('Unknown SpeciesType: $value');
    }
  }

  String toJson() => name;
}

class Observation {
  final int id;
  final SpeciesType speciesType;
  final String speciesName;
  final String? note;
  final String? photoUrl;
  final DateTime observedAt;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  Observation({
    required this.id,
    required this.speciesType,
    required this.speciesName,
    this.note,
    this.photoUrl,
    required this.observedAt,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      id: json['id'] as int,
      speciesType: SpeciesType.fromJson(json['speciesType'] as String),
      speciesName: json['speciesName'] as String,
      note: json['note'] as String?,
      photoUrl: json['photoUrl'] as String?,
      observedAt: DateTime.parse(json['observedAt'] as String),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'speciesType': speciesType.toJson(),
      'speciesName': speciesName,
      'note': note,
      'photoUrl': photoUrl,
      'observedAt': observedAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ObservationCreate {
  final SpeciesType speciesType;
  final String speciesName;
  final String? note;
  final String? photoUrl;
  final DateTime? observedAt;
  final double? lat;
  final double? lng;

  ObservationCreate({
    required this.speciesType,
    required this.speciesName,
    this.note,
    this.photoUrl,
    this.observedAt,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'speciesType': speciesType.toJson(),
      'speciesName': speciesName,
    };
    if (note != null) json['note'] = note;
    if (photoUrl != null) json['photoUrl'] = photoUrl;
    if (observedAt != null) json['observedAt'] = observedAt!.toIso8601String();
    if (lat != null) json['lat'] = lat;
    if (lng != null) json['lng'] = lng;
    return json;
  }
}

class ObservationUpdate {
  final SpeciesType? speciesType;
  final String? speciesName;
  final DateTime? observedAt;

  final String? _note;
  final bool _noteSet;
  final String? _photoUrl;
  final bool _photoUrlSet;
  final double? _lat;
  final bool _latSet;
  final double? _lng;
  final bool _lngSet;

  ObservationUpdate({
    this.speciesType,
    this.speciesName,
    this.observedAt,
    String? note,
    bool noteSet = false,
    String? photoUrl,
    bool photoUrlSet = false,
    double? lat,
    bool latSet = false,
    double? lng,
    bool lngSet = false,
  })  : _note = note,
        _noteSet = noteSet || note != null,
        _photoUrl = photoUrl,
        _photoUrlSet = photoUrlSet || photoUrl != null,
        _lat = lat,
        _latSet = latSet || lat != null,
        _lng = lng,
        _lngSet = lngSet || lng != null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (speciesType != null) json['speciesType'] = speciesType!.toJson();
    if (speciesName != null) json['speciesName'] = speciesName;
    if (observedAt != null) json['observedAt'] = observedAt!.toIso8601String();
    if (_noteSet) json['note'] = _note;
    if (_photoUrlSet) json['photoUrl'] = _photoUrl;
    if (_latSet) json['lat'] = _lat;
    if (_lngSet) json['lng'] = _lng;
    return json;
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final int targetCount;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.targetCount,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      targetCount: json['targetCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetCount': targetCount,
    };
  }
}

class BadgeProgress {
  final Badge badge;
  final bool achieved;
  final int currentCount;

  BadgeProgress({
    required this.badge,
    required this.achieved,
    required this.currentCount,
  });

  factory BadgeProgress.fromJson(Map<String, dynamic> json) {
    return BadgeProgress(
      badge: Badge.fromJson(json['badge'] as Map<String, dynamic>),
      achieved: json['achieved'] as bool,
      currentCount: json['currentCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'badge': badge.toJson(),
      'achieved': achieved,
      'currentCount': currentCount,
    };
  }
}
