class SpeciesInfo {
  final String? nameKo;
  final String? nameSci;
  final String? summary;
  final String? thumbnailUrl;
  final String? wikiUrl;
  final String source;

  const SpeciesInfo({
    required this.nameKo,
    required this.nameSci,
    required this.summary,
    required this.thumbnailUrl,
    required this.wikiUrl,
    required this.source,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> json) {
    return SpeciesInfo(
      nameKo: json['nameKo'] as String?,
      nameSci: json['nameSci'] as String?,
      summary: json['summary'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      wikiUrl: json['wikiUrl'] as String?,
      source: json['source'] as String,
    );
  }
}
