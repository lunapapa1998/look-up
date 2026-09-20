import 'package:geolocator/geolocator.dart';

import '../config.dart';

/// Raised by [LocationService.deviceLocation] when the real device position
/// cannot be resolved (location services off, or permission denied). Carries a
/// user-facing [message] so the UI can surface it directly.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'LocationUnavailableException: $message';
}

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
  /// The location the app opens on. Curated to Ganghwa in production so the
  /// initial data set is relevant.
  Future<ObservationLocation> currentLocation();

  /// The device's real GPS position, resolved on explicit user intent (e.g.
  /// tapping "내 위치"). Throws [LocationUnavailableException] when unavailable.
  Future<ObservationLocation> deviceLocation();
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

  @override
  Future<ObservationLocation> deviceLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationUnavailableException(
        '위치 서비스가 꺼져 있어요. 설정에서 켜주세요',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        '위치 권한이 필요해요. 설정에서 허용해주세요',
      );
    }
    final position = await Geolocator.getCurrentPosition();
    return ObservationLocation(
      lat: position.latitude,
      lng: position.longitude,
      placeName: '내 위치',
      isFallback: false,
    );
  }
}

/// In-memory implementation of [LocationService] for tests. No network or
/// platform-channel calls — always returns the location it was constructed
/// with.
class FakeLocationService implements LocationService {
  FakeLocationService(this.location);

  final ObservationLocation location;

  @override
  Future<ObservationLocation> currentLocation() => Future.value(location);

  @override
  Future<ObservationLocation> deviceLocation() => Future.value(location);
}
