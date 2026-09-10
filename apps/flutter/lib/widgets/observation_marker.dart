import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/observation_map.dart';

/// Keeps only the spots whose [ObservationSpot.kind] is in [activeKinds].
///
/// Pure and side-effect free so it can be unit tested without a widget tree.
List<ObservationSpot> filterObservationSpots(
  List<ObservationSpot> spots,
  Set<String> activeKinds,
) {
  return spots.where((spot) => activeKinds.contains(spot.kind)).toList();
}

/// Maps the active spots to flutter_map [Marker]s.
///
/// Pure and side-effect free (no [State] access) so it can be unit tested
/// without a widget tree.
List<Marker> buildObservationMarkers({
  required List<ObservationSpot> spots,
  required Set<String> activeKinds,
  String? selectedSpotId,
  required void Function(ObservationSpot) onSpotTap,
}) {
  return filterObservationSpots(spots, activeKinds).map((spot) {
    return Marker(
      point: LatLng(spot.coord.lat, spot.coord.lng),
      width: 44,
      height: 44,
      child: ObservationMarker(
        spot: spot,
        selected: spot.id == selectedSpotId,
        onTap: () => onSpotTap(spot),
      ),
    );
  }).toList();
}

/// Renders a single observation spot pin, shaped and colored by
/// [ObservationSpot.kind]: teardrop/teal for birds, circle/amber for night
/// sky, rounded-square/neutral for heritage eateries.
class ObservationMarker extends StatelessWidget {
  const ObservationMarker({
    super.key,
    required this.spot,
    required this.selected,
    required this.onTap,
  });

  final ObservationSpot spot;
  final bool selected;
  final VoidCallback onTap;

  /// Desaturated warm gray-brown, hardcoded because it must sit visibly away
  /// from the amber (star) tertiary token on the color wheel; every other
  /// kind uses colorScheme tokens.
  static const _heritageColor = Color(0xFF8A7A68);

  static const double _pinSize = 28;

  static const _kindLabels = {
    'bird': '조류 관찰 스팟',
    'star': '별 관찰 스팟',
    'heritage': '노포 관찰 스팟',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${_kindLabels[spot.kind] ?? '관찰 스팟'}, ${spot.name}',
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Transform.scale(
              scale: selected ? 1.25 : 1.0,
              child: _ObservationPin(spot: spot, selected: selected),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the kind-specific pin shape/color for [ObservationMarker],
/// extracted so the shape switch is a standalone, independently testable
/// widget rather than a private builder method.
class _ObservationPin extends StatelessWidget {
  const _ObservationPin({required this.spot, required this.selected});

  final ObservationSpot spot;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (spot.kind) {
      case 'bird':
        return _TeardropPin(
          color: colorScheme.secondary,
          elevated: selected,
          child: const CustomPaint(
            size: Size(
              ObservationMarker._pinSize * 0.5,
              ObservationMarker._pinSize * 0.5,
            ),
            painter: _BirdSilhouettePainter(color: Colors.white),
          ),
        );
      case 'star':
        return _RoundPin(
          color: colorScheme.tertiary,
          elevated: selected,
          icon: Icons.star,
        );
      case 'heritage':
      default:
        return _RoundedSquarePin(
          color: ObservationMarker._heritageColor,
          elevated: selected,
          icon: Icons.storefront,
        );
    }
  }
}

List<BoxShadow> _pinShadow(bool elevated) {
  if (!elevated) return const [];
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

class _RoundPin extends StatelessWidget {
  const _RoundPin({
    required this.color,
    required this.elevated,
    required this.icon,
  });

  final Color color;
  final bool elevated;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ObservationMarker._pinSize,
      height: ObservationMarker._pinSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: _pinShadow(elevated),
      ),
      child: Icon(icon, size: ObservationMarker._pinSize * 0.6, color: Colors.white),
    );
  }
}

class _RoundedSquarePin extends StatelessWidget {
  const _RoundedSquarePin({
    required this.color,
    required this.elevated,
    required this.icon,
  });

  final Color color;
  final bool elevated;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ObservationMarker._pinSize,
      height: ObservationMarker._pinSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _pinShadow(elevated),
      ),
      child: Icon(icon, size: ObservationMarker._pinSize * 0.6, color: Colors.white),
    );
  }
}

/// Circle top tapering to a point at the bottom (map-pin/teardrop shape),
/// built as the union of a circle and a triangular tail so the geometry
/// stays simple and robust at any size.
class _TeardropClipper extends CustomClipper<Path> {
  const _TeardropClipper();

  @override
  Path getClip(Size size) {
    final circleDiameter = size.width;
    final circle = Path()
      ..addOval(Rect.fromLTWH(0, 0, circleDiameter, circleDiameter));
    final tail = Path()
      ..moveTo(size.width * 0.28, circleDiameter * 0.72)
      ..lineTo(size.width * 0.72, circleDiameter * 0.72)
      ..lineTo(size.width / 2, size.height)
      ..close();
    return Path.combine(PathOperation.union, circle, tail);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TeardropPin extends StatelessWidget {
  const _TeardropPin({
    required this.color,
    required this.elevated,
    required this.child,
  });

  final Color color;
  final bool elevated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = ObservationMarker._pinSize;
    final height = width * 1.3;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          PhysicalShape(
            clipper: const _TeardropClipper(),
            color: color,
            elevation: elevated ? 6 : 0,
            child: SizedBox(width: width, height: height),
          ),
          Padding(
            padding: EdgeInsets.only(top: width * 0.22),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// No Material [Icons] constant depicts a bird (and [Icons.flutter_dash] is
/// off-limits as the Flutter mascot), so the bird glyph is hand-drawn as a
/// minimal two-swoop "gull in flight" silhouette.
class _BirdSilhouettePainter extends CustomPainter {
  const _BirdSilhouettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.65)
      ..quadraticBezierTo(w * 0.25, 0, w * 0.5, h * 0.55)
      ..quadraticBezierTo(w * 0.75, 0, w, h * 0.65);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BirdSilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}
