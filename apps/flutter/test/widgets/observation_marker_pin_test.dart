import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart' show ObsMode;
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart' show Coordinate, NightSky;
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/observation_marker.dart';

/// Pin-shape pass (2026-10-31): one shared teardrop for every kind, glyph by
/// kind, and the pin TIP (not the box center) lands on the spot coordinate.

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

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeFor(ObsMode.day),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(100),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _painterFinder<T>() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is T,
);

void main() {
  test('outline path: bottom point is the tip at (width / 2, height)', () {
    // contains() probes (not getBounds, which may use loose conic control
    // points): the shape reaches exactly the box edges and the tip.
    final outer = mapPinOutlinePath(MapPin.width, MapPin.height);
    expect(outer.contains(const Offset(14, 35.4)), isTrue); // just above tip
    expect(outer.contains(const Offset(14, 36.5)), isFalse); // below tip
    expect(outer.contains(const Offset(13, 35.6)), isFalse); // tip is a point
    expect(outer.contains(const Offset(14, 0.5)), isTrue);
    expect(outer.contains(const Offset(14, -0.5)), isFalse);
    expect(outer.contains(const Offset(0.5, 14)), isTrue);
    expect(outer.contains(const Offset(-0.5, 14)), isFalse);
    expect(outer.contains(const Offset(27.5, 14)), isTrue);
    expect(outer.contains(const Offset(28.5, 14)), isFalse);
    for (final inset in [kMapPinRingWidth, kMapPinRingSelected]) {
      // Inset fill stays inside the outer one, leaving the ring all round.
      final inner = mapPinOutlinePath(
        MapPin.width,
        MapPin.height,
        inset: inset,
      );
      expect(inner.contains(Offset(14, inset - 0.5)), isFalse);
      expect(inner.contains(Offset(14, inset + 0.5)), isTrue);
      expect(inner.contains(Offset(inset - 0.5, 14)), isFalse);
      expect(inner.contains(Offset(14, MapPin.height - inset)), isFalse);
    }
    expect(MapPinShapePainter.tipFor(const Size(28, 36)), MapPin.tip);
    expect(MapPin.tip, const Offset(14, 36));
  });

  test('buildObservationMarkers uses the tip-anchored alignment', () {
    final labeled = buildObservationMarkers(
      spots: const [_starSpot],
      activeKinds: const {'star'},
      onSpotTap: (_) {},
      zoom: 13,
      screenOffsetOf: (_) => Offset.zero,
    ).single;
    expect(labeled.alignment, ObservationMarker.markerAlignment(true));
    final unlabeled = buildObservationMarkers(
      spots: const [_starSpot],
      activeKinds: const {'star'},
      onSpotTap: (_) {},
      zoom: 10,
    ).single;
    expect(unlabeled.alignment, ObservationMarker.markerAlignment(false));
    expect(ObservationMarker.markerAlignment(false), Alignment.topCenter);
  });

  for (final showLabel in [false, true]) {
    for (final selected in [false, true]) {
      testWidgets(
        'pin tip lands on the Marker anchor (showLabel=$showLabel, '
        'selected=$selected)',
        (tester) async {
          final w = ObservationMarker.markerWidth(showLabel);
          final h = ObservationMarker.markerHeight(showLabel);
          final a = ObservationMarker.markerAlignment(showLabel);
          await _pump(
            tester,
            SizedBox(
              key: const Key('marker_box'),
              width: w,
              height: h,
              child: ObservationMarker(
                spot: _starSpot,
                selected: selected,
                showLabel: showLabel,
                onTap: () {},
              ),
            ),
          );

          // flutter_map 8 MarkerLayer: Positioned(left: p.x - right,
          // top: p.y - bottom) with right = 0.5*w*(1 - a.x),
          // bottom = 0.5*h*(1 - a.y) => the LatLng sits at (right, bottom)
          // inside the marker box.
          final boxTopLeft = tester.getTopLeft(find.byKey(const Key('marker_box')));
          final expectedAnchor =
              boxTopLeft + Offset(0.5 * w * (1 - a.x), 0.5 * h * (1 - a.y));

          final shape = _painterFinder<MapPinShapePainter>();
          expect(shape, findsOneWidget);
          final render = tester.renderObject<RenderBox>(shape);
          expect(render.size, const Size(MapPin.width, MapPin.height));
          final paintedTip = render.localToGlobal(
            MapPinShapePainter.tipFor(render.size),
          );
          expect(
            (paintedTip - expectedAnchor).distance,
            lessThanOrEqualTo(1.0),
            reason: 'tip $paintedTip vs anchor $expectedAnchor',
          );
        },
      );
    }
  }

  testWidgets('each pin kind renders its own glyph on the shared shape', (
    tester,
  ) async {
    await _pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapPin.bird(key: Key('bird')),
          MapPin.star(key: Key('star')),
          MapPin.restaurant(key: Key('restaurant')),
          MapPin.other(key: Key('other'), selected: true),
        ],
      ),
    );

    expect(_painterFinder<MapPinShapePainter>(), findsNWidgets(4));

    Finder inPin(String key, Finder f) =>
        find.descendant(of: find.byKey(Key(key)), matching: f);

    expect(inPin('bird', _painterFinder<MapPinBirdGlyphPainter>()), findsOneWidget);
    expect(inPin('star', _painterFinder<MapPinStarGlyphPainter>()), findsOneWidget);
    expect(inPin('restaurant', find.byIcon(Icons.flatware)), findsOneWidget);
    expect(
      inPin('other', _painterFinder<MapPinBinocularsGlyphPainter>()),
      findsOneWidget,
    );

    final shapes = {
      for (final k in ['bird', 'star', 'restaurant', 'other'])
        k: tester.widget<CustomPaint>(
          inPin(k, _painterFinder<MapPinShapePainter>()),
        ).painter! as MapPinShapePainter,
    };
    expect(shapes['bird']!.fill, const Color(0xFFF4C247));
    expect(shapes['star']!.fill, const Color(0xFF9CA3F5));
    expect(shapes['restaurant']!.fill, const Color(0xFF141414));
    expect(shapes['other']!.fill, const Color(0xFF141414));
    expect(shapes['other']!.ringWidth, kMapPinRingSelected);
    expect(shapes['bird']!.ringWidth, kMapPinRingWidth);

    expect(
      tester.widget<Icon>(find.byIcon(Icons.flatware)).color,
      kMapPinGlyph,
    );
    expect(
      (tester.widget<CustomPaint>(
                _painterFinder<MapPinBinocularsGlyphPainter>(),
              ).painter!
              as MapPinBinocularsGlyphPainter)
          .color,
      kMapPinGlyph,
    );
  });

  test('spot kinds map to pin kinds (heritage = restaurant, unknown = other)',
      () {
    expect(MapPinKind.fromSpotKind('bird'), MapPinKind.bird);
    expect(MapPinKind.fromSpotKind('star'), MapPinKind.star);
    expect(MapPinKind.fromSpotKind('heritage'), MapPinKind.restaurant);
    expect(MapPinKind.fromSpotKind('viewpoint'), MapPinKind.other);
  });
}
