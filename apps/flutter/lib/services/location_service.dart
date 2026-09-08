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

    String? placeName;
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = [
          placemark.administrativeArea,
          placemark.locality,
          placemark.subLocality,
        ].where((part) => part != null && part.isNotEmpty).cast<String>();
        if (parts.isNotEmpty) {
          placeName = parts.join('·');
        }
      }
    } catch (_) {
      return _fallback;
    }

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
