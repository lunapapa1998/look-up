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

/// Measurement-only on-map label text for [spot] (spec 016 P1: name plus a
/// kind-specific measurement summary -- bird species, SQM, or just the name
/// for heritage -- never a suitability score). Mirrors
/// `_measurementSummary` in observation_spot_sheet.dart but folds in the
/// spot name for the single-line on-map pill.
String spotLabelText(ObservationSpot spot) {
  switch (spot.kind) {
    case 'bird':
      final birds = spot.birds!;
      if (birds.topSpecies.isNotEmpty) {
        final top = birds.topSpecies.first;
        final count = top.count;
        return count != null
            ? '${spot.name} · ${top.nameKo} $count'
            : '${spot.name} · ${top.nameKo}';
      }
      return '${spot.name} · ${birds.speciesCount}종';
    case 'star':
      return '${spot.name} · SQM ${spot.nightSky!.sqmValue.toStringAsFixed(2)}';
    case 'heritage':
    default:
      return spot.name;
  }
}

/// Pure collision-suppression for on-map spot labels (spec 016 P1-1).
///
/// - [selectedSpotId], if present among [spots], always gets a label.
/// - Below [zoomThreshold] no other spot ever gets a label (zoom is the
///   sole gate for the "maybe" case).
/// - At/above [zoomThreshold], the remaining spots are walked in stable id
///   order and greedily suppressed (dot-only) if their projected screen
///   offset falls within [collisionRadius] px of an already-placed label.
///
/// [screenOffsetOf] projects a spot to a screen offset (in the real screen,
/// `MapCamera.latLngToScreenOffset`); pass `null` to skip the zoom-gated
/// pass entirely. Deliberately simple/greedy -- full label clustering is
/// out of scope for this phase (see spec Notes).
Set<String> computeLabeledSpotIds({
  required List<ObservationSpot> spots,
  required double zoom,
  String? selectedSpotId,
  Offset Function(ObservationSpot spot)? screenOffsetOf,
  // Labels are shown from the map's default zoom (12) so the map reads like
  // the Figma (labeled pins), not a field of bare dots — collision
  // suppression below still keeps dense clusters (e.g. Ganghwa's 14 bird
  // spots) readable by dropping overlapping labels to dot-only.
  double zoomThreshold = 11,
  double collisionRadius = 56,
}) {
  final labeled = <String>{};
  final placedOffsets = <Offset>[];

  if (selectedSpotId != null) {
    final matches = spots.where((s) => s.id == selectedSpotId);
    if (matches.isNotEmpty) {
      labeled.add(selectedSpotId);
      if (screenOffsetOf != null) {
        placedOffsets.add(screenOffsetOf(matches.first));
      }
    }
  }

  if (zoom < zoomThreshold || screenOffsetOf == null) return labeled;

  final ordered = [...spots]..sort((a, b) => a.id.compareTo(b.id));
  for (final spot in ordered) {
    if (spot.id == selectedSpotId) continue;
    final offset = screenOffsetOf(spot);
    final collides = placedOffsets.any(
      (placed) => (placed - offset).distance < collisionRadius,
    );
    if (collides) continue;
    labeled.add(spot.id);
    placedOffsets.add(offset);
  }
  return labeled;
}

/// Maps the active spots to flutter_map [Marker]s.
///
/// Pure and side-effect free (no [State] access) so it can be unit tested
/// without a widget tree. [zoom] and [screenOffsetOf] gate the on-map label
/// display rules (spec 016 P1-1); both are optional so existing call sites
/// (fixed at the map's initial zoom of 12, below the zoom-gated label
/// threshold) keep compiling and rendering unchanged. In the real screen,
/// [screenOffsetOf] is `(spot) => camera.latLngToScreenOffset(...)`; tests
/// can inject a synthetic projection instead of building a real MapCamera.
List<Marker> buildObservationMarkers({
  required List<ObservationSpot> spots,
  required Set<String> activeKinds,
  String? selectedSpotId,
  required void Function(ObservationSpot) onSpotTap,
  double zoom = 12,
  Offset Function(ObservationSpot spot)? screenOffsetOf,
}) {
  final filtered = filterObservationSpots(spots, activeKinds);
  final labeledIds = computeLabeledSpotIds(
    spots: filtered,
    zoom: zoom,
    selectedSpotId: selectedSpotId,
    screenOffsetOf: screenOffsetOf,
  );

  return filtered.map((spot) {
    final showLabel = labeledIds.contains(spot.id);
    return Marker(
      point: LatLng(spot.coord.lat, spot.coord.lng),
      width: ObservationMarker.markerWidth(showLabel),
      height: ObservationMarker.markerHeight(showLabel),
      alignment: ObservationMarker.markerAlignment(showLabel),
      child: ObservationMarker(
        spot: spot,
        selected: spot.id == selectedSpotId,
        showLabel: showLabel,
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
    this.showLabel = false,
  });

  final ObservationSpot spot;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  /// Desaturated warm gray-brown, hardcoded because it must sit visibly away
  /// from the amber (star) tertiary token on the color wheel; every other
  /// kind uses colorScheme tokens.
  static const _heritageColor = Color(0xFF8A7A68);

  static const double _pinSize = 28;

  /// Hit-testable pin box side length -- unchanged from before on-map
  /// labels existed.
  static const double pinBoxSize = 44;
  static const double _labelGap = 6;
  static const double _labelPillHeight = 22;
  static const double _labelMaxWidth = 150;

  static const _kindLabels = {
    'bird': '조류 관찰 스팟',
    'star': '별 관찰 스팟',
    'heritage': '노포 관찰 스팟',
  };

  /// flutter_map `Marker.width` to reserve: just the pin hit area when no
  /// label shows, or the wider label-pill column when one does.
  static double markerWidth(bool showLabel) =>
      showLabel ? _labelMaxWidth : pinBoxSize;

  /// flutter_map `Marker.height` to reserve: the pin alone, or the pin plus
  /// the fixed-height pill stacked below it with a gap.
  static double markerHeight(bool showLabel) =>
      showLabel ? pinBoxSize + _labelGap + _labelPillHeight : pinBoxSize;

  /// flutter_map `Marker.alignment` -- which point of the box lands on the
  /// spot's LatLng. Unlabeled markers use the original center-of-box anchor
  /// (box == pin, so this exactly reproduces pre-label behavior). Labeled
  /// markers grow taller for the pill below, so they re-anchor to
  /// top-center: the pin (the first, centered child of the column) then
  /// still sits right at the coordinate instead of drifting down as the box
  /// grows.
  static Alignment markerAlignment(bool showLabel) =>
      showLabel ? Alignment.topCenter : Alignment.center;

  @override
  Widget build(BuildContext context) {
    final pin = Semantics(
      button: true,
      label: '${_kindLabels[spot.kind] ?? '관찰 스팟'}, ${spot.name}',
      child: SizedBox(
        width: pinBoxSize,
        height: pinBoxSize,
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

    if (!showLabel) return pin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pin,
        const SizedBox(height: _labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _labelMaxWidth),
          child: _ObservationLabelPill(
            text: spotLabelText(spot),
            selected: selected,
          ),
        ),
      ],
    );
  }
}

/// Semi-transparent pill label shown below a marker's pin (spec 016 P1):
/// measurement-only text, never a suitability score. Own widget class per
/// this file's no-private-build-method convention (see [_RoundPin] et al).
class _ObservationLabelPill extends StatelessWidget {
  const _ObservationLabelPill({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: ObservationMarker._labelPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Fully opaque surface (not a translucent tint) so the text stays
        // readable over the dark map tile underneath regardless of the
        // tile's own brightness at that point -- the token pair alone
        // already clears 4.5:1 (verified WCAG contrast, spec 016 Phase 5
        // P2-4), so no alpha blending with the tile is needed or safe.
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected ? _pinShadow(true) : const [],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelSmall?.copyWith(
          fontSize: 12,
          height: 1.0,
          color: colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
