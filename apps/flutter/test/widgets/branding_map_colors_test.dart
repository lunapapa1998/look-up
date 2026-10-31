import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:lookup/models/discovery.dart' show ObsMode;
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/widgets/app_header_logo.dart';
import 'package:lookup/widgets/course_card.dart';
import 'package:lookup/widgets/observation_marker.dart';
import 'package:lookup/widgets/trails/trail_map.dart';

/// Branding fix (2026-10-31): map pins, route lines and course cards must
/// never render the old teal (colorScheme.secondary / birdAccent), the old
/// light-brown/amber (colorScheme.tertiary / starAccent) or the legacy
/// mapTrail/mapHeritage hues. Kinds are told apart by shape/glyph only.

const _birdSpot = ObservationSpot(
  id: 'bird-001',
  kind: 'bird',
  name: '여차리 갯벌',
  coord: Coordinate(lat: 37.601, lng: 126.412),
  nightSky: null,
  birds: BirdObservation(
    speciesCount: 12,
    topSpecies: [
      BirdSpecies(
        nameKo: '저어새',
        nameSci: 'Platalea minor',
        speciesCode: 'blbspo1',
        count: 12,
        obsDt: '2026-09-09 07:12',
      ),
    ],
    mostRecentObsDt: '2026-09-09 07:12',
    status: 'community',
  ),
  heritage: null,
);

const _starSpot = ObservationSpot(
  id: 'star-001',
  kind: 'star',
  name: '강화 천문인마을',
  coord: Coordinate(lat: 37.71, lng: 126.42),
  nightSky: NightSky(
    sqmValue: 21.7,
    bortleClass: 3,
    skyClass: 'Class 3',
    status: 'measured',
  ),
  birds: null,
  heritage: null,
);

const _heritageSpot = ObservationSpot(
  id: 'heritage-001',
  kind: 'heritage',
  name: '노포 하나',
  coord: Coordinate(lat: 37.601, lng: 126.446),
  nightSky: null,
  birds: null,
  heritage: HeritageInfo(
    addr: '인천 강화군 테스트로 1',
    distanceM: 3000,
    contentId: 'H1',
  ),
);

const _course = TrailCourse(
  crsIdx: 'T_TEST_1',
  name: '테스트 코스',
  sigun: '강화군',
  distanceKm: 12.3,
  durationMin: 240,
  level: 2,
  cycle: '순환형',
  gpxUrl: '',
  start: Coordinate(lat: 37.70, lng: 126.40),
  end: Coordinate(lat: 37.72, lng: 126.45),
  nightSky: NightSky(
    sqmValue: 21.2,
    bortleClass: 3,
    skyClass: 'Class 3',
    status: 'live',
  ),
  heritageEats: [],
  daySuitability: CourseSuitability(score: 82, label: '낮 쾌적', status: 'live'),
  nightSuitability: CourseSuitability(
    score: 64,
    label: '밤 보통',
    status: 'approx',
  ),
);

/// Every color drawn by the widgets under (and including) [root]: box
/// fills/borders/gradients/shadows, icons, text spans, physical shapes,
/// bird-glyph painters, progress bars and polylines.
List<Color> _renderedColors(Finder root) {
  final colors = <Color>[];

  void addSpan(InlineSpan span) {
    final c = span.style?.color;
    if (c != null) colors.add(c);
    if (span is TextSpan) {
      for (final child in span.children ?? const <InlineSpan>[]) {
        addSpan(child);
      }
    }
  }

  void addDecoration(Decoration? d) {
    if (d is BoxDecoration) {
      if (d.color != null) colors.add(d.color!);
      final border = d.border;
      if (border is Border) {
        colors.addAll([
          border.top.color,
          border.right.color,
          border.bottom.color,
          border.left.color,
        ]);
      }
      if (d.gradient != null) colors.addAll(d.gradient!.colors);
      for (final shadow in d.boxShadow ?? const <BoxShadow>[]) {
        colors.add(shadow.color);
      }
    } else if (d is ShapeDecoration) {
      if (d.color != null) colors.add(d.color!);
    }
  }

  final elements = [
    ...root.evaluate(),
    ...find
        .descendant(of: root, matching: find.byWidgetPredicate((_) => true))
        .evaluate(),
  ];
  for (final element in elements) {
    final w = element.widget;
    if (w is Container) {
      if (w.color != null) colors.add(w.color!);
      addDecoration(w.decoration);
      addDecoration(w.foregroundDecoration);
    } else if (w is DecoratedBox) {
      addDecoration(w.decoration);
    } else if (w is ColoredBox) {
      colors.add(w.color);
    } else if (w is Icon) {
      if (w.color != null) colors.add(w.color!);
    } else if (w is RichText) {
      addSpan(w.text);
    } else if (w is PhysicalShape) {
      colors.add(w.color);
    } else if (w is PhysicalModel) {
      colors.add(w.color);
    } else if (w is Material) {
      if (w.color != null) colors.add(w.color!);
    } else if (w is CustomPaint) {
      for (final p in [w.painter, w.foregroundPainter]) {
        if (p is BirdSilhouettePainter) colors.add(p.color);
        if (p is MapPinShapePainter) colors.addAll([p.fill, p.ring]);
        if (p is MapPinBirdGlyphPainter) colors.addAll([p.body, p.accent]);
        if (p is MapPinStarGlyphPainter) colors.add(p.color);
        if (p is MapPinBinocularsGlyphPainter) colors.add(p.color);
      }
    } else if (w is LinearProgressIndicator) {
      if (w.color != null) colors.add(w.color!);
      if (w.backgroundColor != null) colors.add(w.backgroundColor!);
    } else if (w is PolylineLayer) {
      for (final line in w.polylines) {
        colors
          ..add(line.color)
          ..add(line.borderColor);
      }
    }
  }
  return colors;
}

/// The retired teal / light-brown / legacy map hues for the ambient theme.
List<Color> _forbidden(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final lookUp = LookUpColors.of(context);
  return [
    scheme.secondary,
    scheme.tertiary,
    lookUp.birdAccent,
    lookUp.starAccent,
    lookUp.mapTrail,
    lookUp.mapHeritage,
  ];
}

/// RGB-only key so alpha-tinted variants (`withValues(alpha: ...)`) of a
/// forbidden hue are caught too.
int _rgb(Color c) => c.toARGB32() & 0x00FFFFFF;

void _expectNoForbidden(WidgetTester tester, Finder root) {
  final context = tester.element(root.first);
  final forbidden = _forbidden(context).map(_rgb).toSet();
  final offenders = _renderedColors(root)
      .where((c) => c.a > 0 && forbidden.contains(_rgb(c)))
      .toList();
  expect(offenders, isEmpty, reason: 'retired teal/brown/map hue rendered');
}

Future<void> _pumpInTheme(
  WidgetTester tester,
  ObsMode mode,
  Widget child,
) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  for (final mode in ObsMode.values) {
    group('${mode.name} theme', () {
      testWidgets(
        'observation marker set (bird/star/heritage, one selected, labeled) '
        'renders no secondary/tertiary/birdAccent/starAccent/mapTrail/'
        'mapHeritage colors',
        (tester) async {
          final offsets = {
            'bird-001': const Offset(0, 0),
            'star-001': const Offset(300, 0),
            'heritage-001': const Offset(600, 0),
          };
          final markers = buildObservationMarkers(
            spots: const [_birdSpot, _starSpot, _heritageSpot],
            activeKinds: const {'bird', 'star', 'heritage'},
            selectedSpotId: 'star-001',
            onSpotTap: (_) {},
            zoom: 13,
            screenOffsetOf: (spot) => offsets[spot.id]!,
          );
          expect(markers, hasLength(3));

          await _pumpInTheme(
            tester,
            mode,
            Row(
              key: const Key('marker_set'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in markers)
                  SizedBox(width: m.width, height: m.height, child: m.child),
              ],
            ),
          );

          final root = find.byKey(const Key('marker_set'));
          _expectNoForbidden(tester, root);

          // Positive: one shared teardrop shape for every kind; bird = day
          // yellow, star = night lavender, heritage = neutral ink; every
          // glyph white (bird adds navy head/wing); all keep the white ring
          // and the selected (star) pin gets the thicker ring, not a new
          // color.
          const dayAccent = Color(0xFFF4C247);
          const nightAccent = Color(0xFF9CA3F5);
          const white = Color(0xFFFFFFFF);
          const navy = Color(0xFF1F2A44);
          final lookUp = LookUpColors.of(tester.element(root));
          expect(lookUp.modeDayAccent, dayAccent);
          expect(lookUp.modeNightAccent, nightAccent);
          expect(kMapPinFill, const Color(0xFF141414));
          expect(kMapPinGlyph, white);
          expect(kMapPinBirdAccent, navy);

          List<T> painters<T>() => tester
              .widgetList<CustomPaint>(
                find.descendant(of: root, matching: find.byType(CustomPaint)),
              )
              .map((p) => p.painter)
              .whereType<T>()
              .toList();

          final shapes = painters<MapPinShapePainter>();
          expect(shapes, hasLength(3));
          final birdShape = shapes.singleWhere((s) => s.fill == dayAccent);
          final starShape = shapes.singleWhere((s) => s.fill == nightAccent);
          final heritageShape = shapes.singleWhere(
            (s) => s.fill == kMapPinFill,
          );
          for (final s in shapes) {
            expect(s.ring, kMapPinRing);
          }
          expect(starShape.ringWidth, kMapPinRingSelected);
          expect(starShape.elevated, isTrue);
          expect(birdShape.ringWidth, kMapPinRingWidth);
          expect(heritageShape.ringWidth, kMapPinRingWidth);
          expect(birdShape.elevated, isFalse);

          final birdGlyph = painters<MapPinBirdGlyphPainter>().single;
          expect(birdGlyph.body, white);
          expect(birdGlyph.accent, navy);
          expect(painters<MapPinStarGlyphPainter>().single.color, white);
          expect(
            tester.widget<Icon>(find.byIcon(Icons.flatware)).color,
            white,
          );
          // The old per-kind shapes/glyphs are gone.
          expect(find.byIcon(Icons.storefront), findsNothing);
          expect(find.byIcon(Icons.star), findsNothing);
          expect(painters<BirdSilhouettePainter>(), isEmpty);

          // Helper mapping (restaurant/other kinds stay neutral).
          expect(mapPinColorsFor('bird', lookUp), (
            fill: dayAccent,
            glyph: white,
          ));
          expect(mapPinColorsFor('star', lookUp), (
            fill: nightAccent,
            glyph: white,
          ));
          for (final kind in ['heritage', 'restaurant', 'other']) {
            expect(mapPinColorsFor(kind, lookUp), (
              fill: kMapPinFill,
              glyph: kMapPinGlyph,
            ));
          }
        },
      );

      testWidgets(
        'featured CourseCard renders no secondary/tertiary/birdAccent/'
        'starAccent/mapTrail/mapHeritage colors',
        (tester) async {
          await _pumpInTheme(
            tester,
            mode,
            SizedBox(
              width: 420,
              child: CourseCard(course: _course, featured: true, onTap: () {}),
            ),
          );
          final root = find.byType(CourseCard);
          expect(root, findsOneWidget);
          _expectNoForbidden(tester, root);
        },
      );

      testWidgets(
        'TrailMap route line and start/end pins are neutral ink with a '
        'white casing/ring',
        (tester) async {
          await _pumpInTheme(
            tester,
            mode,
            const SizedBox(
              width: 400,
              height: 300,
              child: TrailMap(
                course: _course,
                points: [LatLng(37.70, 126.40), LatLng(37.72, 126.45)],
              ),
            ),
          );
          final root = find.byType(TrailMap);
          _expectNoForbidden(tester, root);

          final layer = tester.widget<PolylineLayer>(
            find.byWidgetPredicate((w) => w is PolylineLayer),
          );
          expect(layer.polylines.single.color, kMapPinFill);
          expect(layer.polylines.single.borderColor, kMapPinRing);
          expect(layer.polylines.single.borderStrokeWidth, greaterThan(0));

          // Start/end differ by glyph, not by color.
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
          for (final icon in [Icons.play_arrow_rounded, Icons.flag_rounded]) {
            expect(tester.widget<Icon>(find.byIcon(icon)).color, kMapPinGlyph);
          }
        },
      );
    });
  }

  testWidgets('AppHeaderLogo shows the approved app icon, rounded 32x32', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: AppHeaderLogo()))),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/app_icon_ui.png',
    );
    expect(image.width, 32);
    expect(image.height, 32);
    expect(image.fit, BoxFit.cover);
    expect(image.filterQuality, FilterQuality.medium);
    final clip = tester.widget<ClipRRect>(
      find.ancestor(of: find.byType(Image), matching: find.byType(ClipRRect)),
    );
    expect(clip.borderRadius, BorderRadius.circular(8));
    expect(find.bySemanticsLabel('위를 봐요 로고'), findsOneWidget);
  });
}
