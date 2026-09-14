class Conservation {
  final String? naturalMonument;
  final String? koreaEndangered;
  final String? iucn;

  const Conservation({
    this.naturalMonument,
    this.koreaEndangered,
    this.iucn,
  });

  factory Conservation.fromJson(Map<String, dynamic> json) {
    return Conservation(
      naturalMonument: json['naturalMonument'] as String?,
      koreaEndangered: json['koreaEndangered'] as String?,
      iucn: json['iucn'] as String?,
    );
  }
}

class SpeciesInfo {
  final String? nameKo;
  final String? nameSci;
  final String? summary;
  final String? thumbnailUrl;
  final String? wikiUrl;
  final String source;
  final String? summaryLong;
  final Conservation? conservation;

  const SpeciesInfo({
    required this.nameKo,
    required this.nameSci,
    required this.summary,
    required this.thumbnailUrl,
    required this.wikiUrl,
    required this.source,
    this.summaryLong,
    this.conservation,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> json) {
    return SpeciesInfo(
      nameKo: json['nameKo'] as String?,
      nameSci: json['nameSci'] as String?,
      summary: json['summary'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      wikiUrl: json['wikiUrl'] as String?,
      source: json['source'] as String,
      summaryLong: json['summaryLong'] as String?,
      conservation: _parseConservation(json['conservation']),
    );
  }

  static Conservation? _parseConservation(dynamic raw) {
    if (raw == null) return null;
    final conservation = Conservation.fromJson(raw as Map<String, dynamic>);
    if (conservation.naturalMonument == null &&
        conservation.koreaEndangered == null &&
        conservation.iucn == null) {
      return null;
    }
    return conservation;
  }
}
