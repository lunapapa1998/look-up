import 'dart:math' as math;
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

/// Dark navy for the bird glyph's head/wing/tail/beak on the yellow pin (the
/// body itself is the white [kMapPinGlyph]), per the 2026-10-31 pin sheet.
const Color kMapPinBirdAccent = Color(0xFF1F2A44);

/// Pin fill + glyph colors for a spot [kind] (UI finishing pass,
/// 2026-10-31; pin-shape pass 2026-10-31): bird = day accent yellow #F4C247,
/// star = night accent lavender #9CA3F5, everything else = neutral
/// [kMapPinFill]. Every glyph is the white [kMapPinGlyph] (the bird adds
/// [kMapPinBirdAccent] navy details) and every pin keeps the white
/// [kMapPinRing] for contrast on map tiles.
({Color fill, Color glyph}) mapPinColorsFor(String kind, LookUpColors colors) {
  switch (kind) {
    case 'bird':
      return (fill: colors.modeDayAccent, glyph: kMapPinGlyph);
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

/// Renders a single observation spot pin: one shared teardrop [MapPin]
/// silhouette for every kind, told apart by glyph (bird / star / fork+spoon
/// for heritage eateries / binoculars for anything else). Fill/glyph colors
/// come from [mapPinColorsFor] (bird yellow, star lavender, others neutral
/// ink), always with a white [kMapPinRing] ring; selection is shown by size
/// (1.25x, scaled about the tip) and a thicker ring, never by color.
///
/// The pin's tip sits at the bottom-center of the 44x44 [pinBoxSize] hit
/// box, and [markerAlignment] puts exactly that point on the spot's LatLng.
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

  /// Where the pin's tip lands inside the marker box: bottom-center of the
  /// [pinBoxSize] hit box, which is horizontally centered in the marker
  /// (alone, or as the first child of the label column).
  static Offset tipOffset(bool showLabel) =>
      Offset(markerWidth(showLabel) / 2, pinBoxSize);

  /// flutter_map `Marker.alignment` that puts [tipOffset] exactly on the
  /// spot's LatLng. flutter_map 8 positions the box so the point lands at
  /// `(0.5 * w * (1 - x), 0.5 * h * (1 - y))` inside it, which
  /// [Marker.computePixelAlignment] inverts: unlabeled -> (0, -1) (box
  /// bottom-center), labeled -> (0, 1 - 2 * 44 / 72) (the pin's tip, above
  /// the gap and the pill).
  static Alignment markerAlignment(bool showLabel) {
    final tip = tipOffset(showLabel);
    return Marker.computePixelAlignment(
      width: markerWidth(showLabel),
      height: markerHeight(showLabel),
      left: tip.dx,
      top: tip.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinBox = SizedBox(
      width: pinBoxSize,
      height: pinBoxSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Tip at the box's bottom-center; the selected 1.25x scale pivots on
        // the tip so it never leaves the coordinate.
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: selected ? 1.25 : 1.0,
            alignment: Alignment.bottomCenter,
            child: MapPin(
              kind: MapPinKind.fromSpotKind(spot.kind),
              selected: selected,
            ),
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
/// this file's no-private-build-method convention (see [MapPin] et al).
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

/// The four map-pin glyph kinds (pin-shape pass, 2026-10-31). Spot data
/// only has 'bird' / 'star' / 'heritage' today; any other kind falls back
/// to [other] (binoculars).
enum MapPinKind {
  bird('bird'),
  star('star'),
  restaurant('heritage'),
  other('other');

  const MapPinKind(this.spotKind);

  /// The [ObservationSpot.kind] string this pin kind stands for (fed to
  /// [mapPinColorsFor]).
  final String spotKind;

  static MapPinKind fromSpotKind(String kind) {
    switch (kind) {
      case 'bird':
        return MapPinKind.bird;
      case 'star':
        return MapPinKind.star;
      case 'heritage':
        return MapPinKind.restaurant;
      default:
        return MapPinKind.other;
    }
  }
}

/// One shared teardrop map pin (round head narrowing to a single bottom
/// point) with a kind glyph centered in the head. Box is exactly
/// [width] x [height] with no padding, and the tip is its bottom-center
/// ([tip]), so a parent can anchor the tip precisely.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.kind, this.selected = false});

  const MapPin.bird({super.key, this.selected = false})
    : kind = MapPinKind.bird;
  const MapPin.star({super.key, this.selected = false})
    : kind = MapPinKind.star;
  const MapPin.restaurant({super.key, this.selected = false})
    : kind = MapPinKind.restaurant;
  const MapPin.other({super.key, this.selected = false})
    : kind = MapPinKind.other;

  final MapPinKind kind;
  final bool selected;

  /// Pin width == head diameter (same 28px as the previous pins).
  static const double width = 28;
  static const double height = 36;

  /// Tip position inside the pin box.
  static const Offset tip = Offset(width / 2, height);

  /// Glyph box side, centered on the head circle's center.
  static const double glyphSize = 15;

  /// The bird glyph is a little larger (17px; its round silhouette stays
  /// >= 2px inside the fill edge of the 12px-radius inner head).
  static const double birdGlyphSize = 17;

  @override
  Widget build(BuildContext context) {
    final colors = mapPinColorsFor(kind.spotKind, LookUpColors.of(context));
    const headCenter = width / 2;
    final glyphSize = kind == MapPinKind.bird
        ? MapPin.birdGlyphSize
        : MapPin.glyphSize;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: MapPinShapePainter(
          fill: colors.fill,
          ringWidth: selected ? kMapPinRingSelected : kMapPinRingWidth,
          elevated: selected,
        ),
        child: Stack(
          children: [
            Positioned(
              left: headCenter - glyphSize / 2,
              top: headCenter - glyphSize / 2,
              width: glyphSize,
              height: glyphSize,
              child: MapPinGlyph(kind: kind, color: colors.glyph),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white glyph drawn inside a [MapPin]'s head for [kind]: custom vector
/// paths for bird/star/binoculars, Material [Icons.flatware] (fork + spoon)
/// for restaurants. Fills its parent box.
class MapPinGlyph extends StatelessWidget {
  const MapPinGlyph({super.key, required this.kind, required this.color});

  final MapPinKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case MapPinKind.bird:
        return CustomPaint(
          size: Size.infinite,
          painter: MapPinBirdGlyphPainter(
            body: color,
            accent: kMapPinBirdAccent,
          ),
        );
      case MapPinKind.star:
        return CustomPaint(
          size: Size.infinite,
          painter: MapPinStarGlyphPainter(color: color),
        );
      case MapPinKind.restaurant:
        return Icon(Icons.flatware, size: MapPin.glyphSize, color: color);
      case MapPinKind.other:
        return CustomPaint(
          size: Size.infinite,
          painter: MapPinBinocularsGlyphPainter(color: color),
        );
    }
  }
}

/// Teardrop outline in a [width] x [height] box: head circle of radius
/// `width / 2` at `(width / 2, width / 2)`, two straight edges tangent to
/// it meeting at the tip `(width / 2, height)`. [inset] shrinks the shape
/// uniformly inward (same tangent angle), used for the fill inside the ring.
Path mapPinOutlinePath(double width, double height, {double inset = 0}) {
  final r = width / 2;
  final center = Offset(r, r);
  final d = height - r; // head center -> tip
  final sinTip = r / d; // sine of the half-angle at the tip
  final ri = r - inset;
  final di = d - inset / sinTip;
  final phi = math.acos(ri / di); // tangent point angle from straight down
  final tipPoint = Offset(center.dx, center.dy + di);
  return Path()
    ..moveTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(
      center.dx + ri * math.sin(phi),
      center.dy + ri * math.cos(phi),
    )
    ..arcTo(
      Rect.fromCircle(center: center, radius: ri),
      math.pi / 2 - phi,
      -(2 * math.pi - 2 * phi),
      false,
    )
    ..close();
}

/// Paints the [MapPin] silhouette: white [ring] teardrop, the [fill]
/// teardrop inset by [ringWidth] on top, plus a subtle shadow when
/// [elevated] (selected), like the previous pins.
class MapPinShapePainter extends CustomPainter {
  const MapPinShapePainter({
    required this.fill,
    required this.ringWidth,
    this.ring = kMapPinRing,
    this.elevated = false,
  });

  final Color fill;
  final Color ring;
  final double ringWidth;
  final bool elevated;

  /// The pin tip in this painter's local coordinates.
  static Offset tipFor(Size size) => Offset(size.width / 2, size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = mapPinOutlinePath(size.width, size.height);
    if (elevated) {
      canvas.drawShadow(outer, const Color(0x59000000), 3, false);
    }
    canvas.drawPath(outer, Paint()..color = ring);
    canvas.drawPath(
      mapPinOutlinePath(size.width, size.height, inset: ringWidth),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant MapPinShapePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.ring != ring ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.elevated != elevated;
}

/// Upright, plump side-view songbird facing right (no rotation): round
/// white [body] and head, [accent] navy head cap, wing, tail, beak and eye
/// dot. Drawn in a unit box scaled to the canvas.
class MapPinBirdGlyphPainter extends CustomPainter {
  const MapPinBirdGlyphPainter({required this.body, required this.accent});

  final Color body;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final bodyPaint = Paint()..color = body;
    final accentPaint = Paint()..color = accent;
    Path poly(List<Offset> points) => Path()..addPolygon(points, true);

    // Everything stays within ~0.5 (unit) of the box center, so on the 17px
    // glyph it keeps >= 2px from the fill edge of the pin head.

    // Tail (navy): short wedge at the lower left, behind the body.
    canvas.drawPath(
      poly([p(0.28, 0.70), p(0.10, 0.82), p(0.20, 0.90), p(0.36, 0.84)]),
      accentPaint,
    );

    // Body (white): round, upright, centered slightly low (~60% of box).
    final bodyCenter = p(0.47, 0.60);
    canvas.drawCircle(bodyCenter, 0.28 * w, bodyPaint);

    // Head (white) sitting on the body's upper right.
    final headCenter = p(0.62, 0.36);
    final headRadius = 0.19 * w;
    canvas.drawCircle(headCenter, headRadius, bodyPaint);

    // Head cap (navy): top and back of the head, clipped to the head circle
    // so the lower-right face stays white.
    canvas
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: headCenter, radius: headRadius)),
      )
      ..drawPath(
        poly([
          p(0.30, 0.05),
          p(0.95, 0.05),
          p(0.80, 0.30),
          p(0.58, 0.40),
          p(0.40, 0.56),
          p(0.30, 0.56),
        ]),
        accentPaint,
      )
      ..restore();

    // Wing (navy): rounded teardrop on the body's back half, rounded end
    // forward/up, point trailing back toward the tail.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.22, 0.80).dx, p(0.22, 0.80).dy)
        ..quadraticBezierTo(
          p(0.26, 0.52).dx,
          p(0.26, 0.52).dy,
          p(0.48, 0.52).dx,
          p(0.48, 0.52).dy,
        )
        ..quadraticBezierTo(
          p(0.64, 0.56).dx,
          p(0.64, 0.56).dy,
          p(0.58, 0.68).dx,
          p(0.58, 0.68).dy,
        )
        ..quadraticBezierTo(
          p(0.46, 0.82).dx,
          p(0.46, 0.82).dy,
          p(0.22, 0.80).dx,
          p(0.22, 0.80).dy,
        )
        ..close(),
      accentPaint,
    );

    // Beak (navy): small triangle at the right of the head.
    canvas.drawPath(
      poly([p(0.79, 0.36), p(0.97, 0.42), p(0.79, 0.48)]),
      accentPaint,
    );

    // Eye (navy dot) on the white face, just below the cap edge.
    canvas.drawCircle(p(0.70, 0.41), 0.045 * w, accentPaint);
  }

  @override
  bool shouldRepaint(covariant MapPinBirdGlyphPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.accent != accent;
}

/// Solid five-point star centered in the canvas.
class MapPinStarGlyphPainter extends CustomPainter {
  const MapPinStarGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = math.min(size.width, size.height) / 2;
    final inner = outer * 0.45;
    // A point-up star's bounding box sits slightly high; nudge it down so it
    // reads optically centered.
    final center = Offset(size.width / 2, size.height / 2 + outer * 0.06);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant MapPinStarGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Front-view binoculars: two barrels with round lenses (holes cut through
/// so the pin fill shows), joined by a bridge. Material has no binoculars
/// icon, so this is a custom path.
class MapPinBinocularsGlyphPainter extends CustomPainter {
  const MapPinBinocularsGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromLTRB(l * w, t * h, rr * w, b * h);
    final corner = Radius.circular(0.06 * w);

    final solid = Path()
      // Eyepiece tubes.
      ..addRRect(RRect.fromRectAndRadius(r(0.14, 0.14, 0.40, 0.56), corner))
      ..addRRect(RRect.fromRectAndRadius(r(0.60, 0.14, 0.86, 0.56), corner))
      // Bridge.
      ..addRect(r(0.38, 0.36, 0.62, 0.58))
      // Objective barrels.
      ..addOval(r(0.02, 0.42, 0.48, 0.88))
      ..addOval(r(0.52, 0.42, 0.98, 0.88));
    final lenses = Path()
      ..addOval(r(0.13, 0.53, 0.37, 0.77))
      ..addOval(r(0.63, 0.53, 0.87, 0.77));
    // All solid contours share one winding direction, so the default
    // nonzero fill treats overlaps as a union; then punch the lenses out.
    canvas.drawPath(
      Path.combine(PathOperation.difference, solid, lenses),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant MapPinBinocularsGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
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
