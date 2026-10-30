import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/observation_map.dart';
import '../theme/lookup_colors.dart';
import '../utils/spot_name.dart';
import 'sample_data_notice.dart';

/// Neutral fill for restaurant/heritage/other pins, trailhead dots and route
/// lines (branding fix, 2026-10-31): #141414 ink with a white ring/casing
/// reads on both the dark Esri tiles and the light OSM tiles, in both themes.
/// Bird and star pins use the day/night-meaning accents instead (see
/// [mapPinColorsFor]); no teal/amber/brown anywhere.
const Color kMapPinFill = Color(0xFF141414);

/// White ring around [kMapPinFill] pins / casing around route lines.
const Color kMapPinRing = Color(0xFFFFFFFF);

/// Glyph drawn on a [kMapPinFill] pin.
const Color kMapPinGlyph = Color(0xFFFFFFFF);

/// Ring width of an unselected pin; selected pins use [kMapPinRingSelected]
/// (plus the 1.25x scale) instead of a color change.
const double kMapPinRingWidth = 2;
const double kMapPinRingSelected = 3;

/// Pin fill + glyph colors for a spot [kind] (UI finishing pass,
/// 2026-10-31): bird = day accent yellow #F4C247 with #141414 glyph, star =
/// night accent lavender #9CA3F5 with white glyph, everything else = neutral
/// [kMapPinFill] with a white [kMapPinGlyph]. Every pin keeps the white
/// [kMapPinRing] for contrast on map tiles.
({Color fill, Color glyph}) mapPinColorsFor(String kind, LookUpColors colors) {
  switch (kind) {
    case 'bird':
      return (fill: colors.modeDayAccent, glyph: colors.onModeDayAccent);
    case 'star':
      return (fill: colors.modeNightAccent, glyph: colors.onModeNightAccent);
    default:
      return (fill: kMapPinFill, glyph: kMapPinGlyph);
  }
}

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
  final name = shortSpotName(spot.name);
  switch (spot.kind) {
    case 'bird':
      final birds = spot.birds!;
      if (birds.topSpecies.isNotEmpty) {
        final top = birds.topSpecies.first;
        final count = top.count;
        return count != null
            ? '$name · ${top.nameKo} $count'
            : '$name · ${top.nameKo}';
      }
      return '$name · ${birds.speciesCount}종';
    case 'star':
      return '$name · SQM ${spot.nightSky!.sqmValue.toStringAsFixed(2)}';
    case 'heritage':
    default:
      return name;
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
  bool scatterActive = false,
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

  // Scatter reveal (spec 017 P3) hides every other on-map label so the
  // scattered individuals read cleanly, regardless of zoom.
  if (scatterActive) return labeled;

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
  bool scatterActive = false,
  bool isSample = false,
}) {
  final filtered = filterObservationSpots(spots, activeKinds);
  final labeledIds = computeLabeledSpotIds(
    spots: filtered,
    zoom: zoom,
    selectedSpotId: selectedSpotId,
    screenOffsetOf: screenOffsetOf,
    scatterActive: scatterActive,
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
        isSample: isSample,
      ),
    );
  }).toList();
}

/// Renders a single observation spot pin, shaped by [ObservationSpot.kind]
/// (teardrop + bird glyph for birds, circle + star for night sky,
/// rounded-square + storefront for heritage eateries). Fill/glyph colors come
/// from [mapPinColorsFor] (bird yellow, star lavender, others neutral ink),
/// always with a white [kMapPinRing] ring; selection is shown by size
/// (1.25x) and a thicker ring, never by color.
class ObservationMarker extends StatelessWidget {
  const ObservationMarker({
    super.key,
    required this.spot,
    required this.selected,
    required this.onTap,
    this.showLabel = false,
    this.isSample = false,
  });

  final ObservationSpot spot;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  /// Spot comes from demo sample data (spec 052): adds a [SampleMark] to
  /// the pin and ", 예시" to its semantics label.
  final bool isSample;

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
    final pinBox = SizedBox(
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
    );
    final pin = Semantics(
      button: true,
      label:
          '${_kindLabels[spot.kind] ?? '관찰 스팟'}, ${shortSpotName(spot.name)}'
          '${isSample ? ', 예시' : ''}',
      child: isSample
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                pinBox,
                // Pointer- and semantics-transparent: taps still reach the
                // pin, and the label above already says ", 예시".
                const Positioned(
                  top: 0,
                  right: -4,
                  child: IgnorePointer(
                    child: ExcludeSemantics(child: SampleMark(compact: true)),
                  ),
                ),
              ],
            )
          : pinBox,
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
    final ringWidth = selected ? kMapPinRingSelected : kMapPinRingWidth;
    final pinColors = mapPinColorsFor(spot.kind, LookUpColors.of(context));

    switch (spot.kind) {
      case 'bird':
        return _TeardropPin(
          ringWidth: ringWidth,
          elevated: selected,
          fill: pinColors.fill,
          child: CustomPaint(
            size: const Size(
              ObservationMarker._pinSize * 0.5,
              ObservationMarker._pinSize * 0.5,
            ),
            painter: BirdSilhouettePainter(color: pinColors.glyph),
          ),
        );
      case 'star':
        return _RoundPin(
          ringWidth: ringWidth,
          elevated: selected,
          icon: Icons.star,
          fill: pinColors.fill,
          glyph: pinColors.glyph,
        );
      case 'heritage':
      default:
        return _RoundedSquarePin(
          ringWidth: ringWidth,
          elevated: selected,
          icon: Icons.storefront,
          fill: pinColors.fill,
          glyph: pinColors.glyph,
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
    required this.ringWidth,
    required this.elevated,
    required this.icon,
    required this.fill,
    required this.glyph,
  });

  final double ringWidth;
  final bool elevated;
  final IconData icon;
  final Color fill;
  final Color glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ObservationMarker._pinSize,
      height: ObservationMarker._pinSize,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: kMapPinRing, width: ringWidth),
        boxShadow: _pinShadow(elevated),
      ),
      child: Icon(
        icon,
        size: ObservationMarker._pinSize * 0.55,
        color: glyph,
      ),
    );
  }
}

class _RoundedSquarePin extends StatelessWidget {
  const _RoundedSquarePin({
    required this.ringWidth,
    required this.elevated,
    required this.icon,
    required this.fill,
    required this.glyph,
  });

  final double ringWidth;
  final bool elevated;
  final IconData icon;
  final Color fill;
  final Color glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ObservationMarker._pinSize,
      height: ObservationMarker._pinSize,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kMapPinRing, width: ringWidth),
        boxShadow: _pinShadow(elevated),
      ),
      child: Icon(
        icon,
        size: ObservationMarker._pinSize * 0.55,
        color: glyph,
      ),
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
    required this.ringWidth,
    required this.elevated,
    required this.fill,
    required this.child,
  });

  final double ringWidth;
  final bool elevated;
  final Color fill;
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
          // White teardrop underneath = the ring; the inset teardrop on top
          // is the fill.
          PhysicalShape(
            clipper: const _TeardropClipper(),
            color: kMapPinRing,
            elevation: elevated ? 6 : 0,
            child: SizedBox(width: width, height: height),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(ringWidth),
              child: ClipPath(
                clipper: const _TeardropClipper(),
                child: ColoredBox(color: fill),
              ),
            ),
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
class BirdSilhouettePainter extends CustomPainter {
  const BirdSilhouettePainter({required this.color});

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
  bool shouldRepaint(covariant BirdSilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Renders one scattered individual bird (spec 017 P1-4): a bare bright
/// silhouette glyph with no teardrop container and no per-species shape or
/// color, so a spread of these reads as "presence" rather than "these are
/// N distinct pins" -- deliberately distinct from [ObservationMarker]'s
/// teardrop pin. Tap reveals a species-name tooltip (spec 017 P4).
class ScatteredBirdMarker extends StatelessWidget {
  const ScatteredBirdMarker({
    super.key,
    required this.nameKo,
    required this.onTap,
  });

  final String nameKo;
  final VoidCallback onTap;

  /// flutter_map `Marker.height` to reserve -- matches
  /// [ObservationMarker.pinBoxSize]'s hit-box convention even though this
  /// marker has no hit target yet.
  static const double markerBoxSize = 44;
  static const double _glyphSize = 15;
  static const double _labelGap = 4;
  static const double _labelMaxWidth = 96;

  /// flutter_map `Marker.width` to reserve: the glyph plus the gap plus the
  /// species-name label pill next to it (spec 019 P2).
  static const double markerBoxWidth =
      _glyphSize + _labelGap + _labelMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: nameKo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: markerBoxWidth,
          height: markerBoxSize,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _glyphSize,
                height: _glyphSize,
                child: Stack(
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                      child: CustomPaint(
                        size: const Size(_glyphSize, _glyphSize),
                        painter: const BirdSilhouettePainter(
                          color: Color(0x66000000),
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(_glyphSize, _glyphSize),
                      painter: const BirdSilhouettePainter(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _labelGap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _labelMaxWidth),
                child: _ObservationLabelPill(text: nameKo, selected: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
