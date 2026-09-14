class TideExtreme {
  final String time;
  final String kind;
  final int? levelCm;

  const TideExtreme({
    required this.time,
    required this.kind,
    required this.levelCm,
  });

  factory TideExtreme.fromJson(Map<String, dynamic> json) {
    return TideExtreme(
      time: json['time'] as String,
      kind: json['kind'] as String,
      levelCm: json['levelCm'] as int?,
    );
  }
}

class TodayTides {
  final bool found;
  final bool degraded;
  final String? stationName;
  final List<TideExtreme> extremes;

  const TodayTides({
    required this.found,
    required this.degraded,
    required this.stationName,
    required this.extremes,
  });

  factory TodayTides.fromJson(Map<String, dynamic> json) {
    return TodayTides(
      found: json['found'] as bool,
      degraded: json['degraded'] as bool,
      stationName: json['stationName'] as String?,
      extremes: (json['extremes'] as List)
          .map((e) => TideExtreme.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
