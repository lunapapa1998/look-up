import '../config.dart';

/// Resolved observation location, either from device GPS + reverse geocoding
/// or the fixed fallback coordinates when location is unavailable/denied.
class ObservationLocation {
  const ObservationLocation({
    required this.lat,
    required this.lng,
    required this.placeName,
    required this.isFallback,
  });

  final double lat;
  final double lng;
  final String? placeName;
  final bool isFallback;
}

/// Contract for resolving the device's current observation location.
abstract class LocationService {
  Future<ObservationLocation> currentLocation();
}

/// Assembles a short display place name from raw placemark fields
/// (administrativeArea, locality, subLocality, in that order), dropping
/// null/empty entries, deduping case/whitespace-insensitive duplicates
/// (keeping the first occurrence), and capping the result at 2 elements.
String? assemblePlaceName(List<String?> rawParts) {
  final seen = <String>{};
  final deduped = <String>[];
  for (final part in rawParts) {
    if (part == null || part.isEmpty) continue;
    final key = part.trim().toLowerCase();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    deduped.add(part);
  }
  final capped = deduped.take(2).toList();
  if (capped.isEmpty) return null;
  return capped.join('·');
}

/// Production [LocationService]. Owner override: the app's data (birds/trails/
/// tides/suitability) is curated around the Ganghwa tidal flats, so the
/// observation location is fixed there instead of the device GPS fix -- a real
/// GPS fix elsewhere would surface empty/irrelevant results. GPS is bypassed
/// on purpose; tests inject [FakeLocationService], so this only affects real
/// devices. `isFallback` is false because Ganghwa is the intended location.
class GeolocatorLocationService implements LocationService {
  static const _ganghwa = ObservationLocation(
    lat: defaultObservationLat,
    lng: defaultObservationLng,
    placeName: '강화도',
    isFallback: false,
  );

  @override
  Future<ObservationLocation> currentLocation() async => _ganghwa;
}

/// In-memory implementation of [LocationService] for tests. No network or
/// platform-channel calls — always returns the location it was constructed
/// with.
class FakeLocationService implements LocationService {
  FakeLocationService(this.location);

  final ObservationLocation location;

  @override
  Future<ObservationLocation> currentLocation() => Future.value(location);
}
