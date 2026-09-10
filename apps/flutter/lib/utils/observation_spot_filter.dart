import 'package:latlong2/latlong.dart';

import '../models/observation_map.dart';
import '../models/trails.dart';

/// Sort options for the observation map spot list.
enum SpotSort { distance, recent, sqm }

/// Case-insensitive substring match against [ObservationSpot.name]. An empty
/// or whitespace-only [query] is a no-op.
List<ObservationSpot> filterObservationSpotsByQuery(
  List<ObservationSpot> spots,
  String query,
) {
  if (query.trim().isEmpty) return spots;
  final lowerQuery = query.toLowerCase();
  return spots
      .where((spot) => spot.name.toLowerCase().contains(lowerQuery))
      .toList();
}

/// Light-pollution filter: when [active] is true, keeps only star spots at
/// or above [threshold] SQM, dropping every bird/heritage spot since they
/// have no matching data.
List<ObservationSpot> filterObservationSpotsBySqm(
  List<ObservationSpot> spots, {
  required bool active,
  double threshold = 21.5,
}) {
  if (!active) return spots;
  return spots
      .where(
        (spot) =>
            spot.kind == 'star' &&
            spot.nightSky != null &&
            spot.nightSky!.sqmValue >= threshold,
      )
      .toList();
}

/// Returns a new sorted list per [sort]; never mutates [spots] and never
/// throws, falling back to stable sorts-last placement for spots with
/// missing or malformed data.
///
/// `List.sort` is not guaranteed stable in Dart, so ties are broken by
/// original index to keep input order as the tiebreak.
List<ObservationSpot> sortObservationSpots(
  List<ObservationSpot> spots,
  SpotSort sort, {
  Coordinate? origin,
}) {
  final indexed = List<MapEntry<int, ObservationSpot>>.generate(
    spots.length,
    (i) => MapEntry(i, spots[i]),
  );

  switch (sort) {
    case SpotSort.distance:
      {
        if (origin == null) return List<ObservationSpot>.from(spots);
        final distance = const Distance();
        final originLatLng = LatLng(origin.lat, origin.lng);
        double distanceOf(ObservationSpot spot) {
          try {
            return distance.as(
              LengthUnit.Meter,
              originLatLng,
              LatLng(spot.coord.lat, spot.coord.lng),
            );
          } catch (_) {
            return double.infinity;
          }
        }

        indexed.sort((a, b) {
          final cmp = distanceOf(a.value).compareTo(distanceOf(b.value));
          return cmp != 0 ? cmp : a.key.compareTo(b.key);
        });
        return indexed.map((e) => e.value).toList();
      }
    case SpotSort.recent:
      {
        DateTime? recentOf(ObservationSpot spot) {
          if (spot.birds == null) return null;
          return DateTime.tryParse(spot.birds!.mostRecentObsDt);
        }

        indexed.sort((a, b) {
          final aDt = recentOf(a.value);
          final bDt = recentOf(b.value);
          final cmp = aDt == null && bDt == null
              ? 0
              : aDt == null
                  ? 1
                  : bDt == null
                      ? -1
                      : bDt.compareTo(aDt);
          return cmp != 0 ? cmp : a.key.compareTo(b.key);
        });
        return indexed.map((e) => e.value).toList();
      }
    case SpotSort.sqm:
      {
        indexed.sort((a, b) {
          final aSqm = a.value.nightSky?.sqmValue;
          final bSqm = b.value.nightSky?.sqmValue;
          final cmp = aSqm == null && bSqm == null
              ? 0
              : aSqm == null
                  ? 1
                  : bSqm == null
                      ? -1
                      : bSqm.compareTo(aSqm);
          return cmp != 0 ? cmp : a.key.compareTo(b.key);
        });
        return indexed.map((e) => e.value).toList();
      }
  }
}
