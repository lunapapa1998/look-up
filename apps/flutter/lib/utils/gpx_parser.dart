import 'package:latlong2/latlong.dart';

final RegExp _trackPointPattern =
    RegExp(r'<(?:trkpt|rtept)\s+lat="([-0-9.]+)"\s+lon="([-0-9.]+)"');

/// Extracts track/route points from GPX XML text, in document order.
///
/// This is a lightweight regex-based parser (no `xml` package dependency) --
/// it only looks for `trkpt`/`rtept` `lat`/`lon` attribute pairs and ignores
/// everything else in the document. Never throws: malformed XML, no
/// matches, or an empty string all resolve to an empty list.
List<LatLng> parseGpxTrack(String gpxXml) {
  try {
    final points = <LatLng>[];
    for (final match in _trackPointPattern.allMatches(gpxXml)) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }
    return points;
  } catch (_) {
    return [];
  }
}
