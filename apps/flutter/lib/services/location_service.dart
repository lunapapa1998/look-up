import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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

/// [LocationService] backed by `geolocator`/`geocoding`. Never throws — any
/// failure (service disabled, permission denied, timeout, geocoding error)
/// resolves to the fixed fallback coordinates from `config.dart`.
class GeolocatorLocationService implements LocationService {
  static const _fallback = ObservationLocation(
    lat: defaultObservationLat,
    lng: defaultObservationLng,
    placeName: null,
    isFallback: true,
  );

  @override
  Future<ObservationLocation> currentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallback;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallback;
      }
    } catch (_) {
      return _fallback;
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      return _fallback;
    }

    final List<Placemark> placemarks;
    try {
      placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      return _fallback;
    }
    if (placemarks.isEmpty) {
      return _fallback;
    }

    final placemark = placemarks.first;
    final placeName = assemblePlaceName([
      placemark.administrativeArea,
      placemark.locality,
      placemark.subLocality,
    ]);

    return ObservationLocation(
      lat: position.latitude,
      lng: position.longitude,
      placeName: placeName,
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
}
