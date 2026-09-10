import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:lookup/api/gpx_api.dart';
import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/observation_map_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/utils/gpx_parser.dart';
import 'package:lookup/utils/observation_spot_filter.dart';
import 'package:lookup/widgets/observation_map_overlays.dart';
import 'package:lookup/widgets/observation_marker.dart';

/// Pumps [ObservationMapScreen] wired with [FakeTrailsApi]/[gpxApi], mirroring
/// the pump-helper pattern in observation_map_wiring_test.dart -- kept local
/// to this file since that helper is private to its own file.
Future<void> _pumpTrailMapScreen(
  WidgetTester tester, {
  GpxApi? gpxApi,
}) async {
  final container = ProviderContainer(
    overrides: [
      observationMapApiProvider.overrideWithValue(FakeObservationMapApi()),
      suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(
          const ObservationLocation(
            lat: 37.71,
            lng: 126.42,
            placeName: null,
            isFallback: false,
          ),
        ),
      ),
      trailsApiProvider.overrideWithValue(FakeTrailsApi()),
      gpxApiProvider.overrideWithValue(gpxApi ?? FakeGpxApi()),
    ],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ObservationMapScreen()),
    ),
  );
}

/// Spec 016 (관찰 지도 Figma parity) widget/unit tests. Each phase of the
/// spec appends its own `group` here rather than a new file, so this file
/// grows across phases -- Phase 1 covers on-map pin labels only.

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
    skyClass: 'Class 3 양호한 다크스카이',
    status: 'measured',
  ),
  birds: null,
  heritage: null,
);

/// Pumps a single [ObservationMarker] in a plain [MaterialApp]/[Scaffold],
/// independent of flutter_map/FlutterMap -- this widget has no
/// BuildContext-free rendering dependency on the map itself.
Future<void> _pumpMarker(
  WidgetTester tester, {
  required ObservationSpot spot,
  required bool selected,
  required bool showLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ObservationMarker(
            spot: spot,
            selected: selected,
            showLabel: showLabel,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Phase 1: on-map pin labels', () {
    testWidgets(
      'unselected + below zoom 14: no label text, only the pin renders',
      (tester) async {
        final zoom = 12.0;
        final labeled = computeLabeledSpotIds(
          spots: const [_birdSpot],
          zoom: zoom,
          selectedSpotId: null,
          screenOffsetOf: (spot) => Offset.zero,
        );
        expect(labeled, isEmpty);

        await _pumpMarker(
          tester,
          spot: _birdSpot,
          selected: false,
          showLabel: labeled.contains(_birdSpot.id),
        );

        expect(find.textContaining(_birdSpot.name), findsNothing);
        expect(find.textContaining('저어새'), findsNothing);
        expect(find.byType(ObservationMarker), findsOneWidget);
      },
    );

    testWidgets(
      'selected spot always renders its pill label with name+measurement text, regardless of zoom',
      (tester) async {
        final labeledBelowThreshold = computeLabeledSpotIds(
          spots: const [_birdSpot],
          zoom: 12,
          selectedSpotId: _birdSpot.id,
          screenOffsetOf: (spot) => Offset.zero,
        );
        expect(labeledBelowThreshold, {_birdSpot.id});

        await _pumpMarker(
          tester,
          spot: _birdSpot,
          selected: true,
          showLabel: true,
        );

        expect(find.textContaining(_birdSpot.name), findsOneWidget);
        expect(find.textContaining('저어새'), findsOneWidget);
        expect(find.textContaining('12'), findsOneWidget);
      },
    );

    testWidgets(
      'zoom >= 14: an unselected, non-colliding spot also renders a label',
      (tester) async {
        final labeled = computeLabeledSpotIds(
          spots: const [_starSpot],
          zoom: 14,
          selectedSpotId: null,
          screenOffsetOf: (spot) => const Offset(500, 500),
        );
        expect(labeled, {_starSpot.id});

        await _pumpMarker(
          tester,
          spot: _starSpot,
          selected: false,
          showLabel: true,
        );

        expect(find.textContaining(_starSpot.name), findsOneWidget);
        expect(find.textContaining('SQM 21.70'), findsOneWidget);
      },
    );

    test(
      'collision suppression: two spots within ~56px of each other only both get labels if under the radius, otherwise the later one (by id order) is suppressed',
      () {
        const near = ObservationSpot(
          id: 'bird-002',
          kind: 'bird',
          name: '옆 갯벌',
          coord: Coordinate(lat: 37.602, lng: 126.413),
          nightSky: null,
          birds: BirdObservation(
            speciesCount: 3,
            topSpecies: [],
            mostRecentObsDt: '2026-09-09 07:00',
            status: 'community',
          ),
          heritage: null,
        );

        final labeled = computeLabeledSpotIds(
          spots: const [_birdSpot, near],
          zoom: 14,
          selectedSpotId: null,
          screenOffsetOf: (spot) => spot.id == _birdSpot.id
              ? const Offset(100, 100)
              : const Offset(120, 110), // ~22px away, well under 56px
        );

        expect(labeled, {_birdSpot.id});
        expect(labeled.contains(near.id), isFalse);

        final labeledFar = computeLabeledSpotIds(
          spots: const [_birdSpot, near],
          zoom: 14,
          selectedSpotId: null,
          screenOffsetOf: (spot) => spot.id == _birdSpot.id
              ? const Offset(100, 100)
              : const Offset(300, 300), // far apart, both should label
        );

        expect(labeledFar, {_birdSpot.id, near.id});
      },
    );

    test(
      'spotLabelText: kind-specific measurement-only content, never a suitability score',
      () {
        expect(spotLabelText(_birdSpot), '여차리 갯벌 · 저어새 12');
        expect(spotLabelText(_starSpot), '강화 천문인마을 · SQM 21.70');

        const heritageSpot = ObservationSpot(
          id: 'heritage-001',
          kind: 'heritage',
          name: '강화도령보리밥',
          coord: Coordinate(lat: 37.603, lng: 126.415),
          nightSky: null,
          birds: null,
          heritage: HeritageInfo(
            addr: '인천광역시 강화군 화도면 해안남로 200',
            distanceM: 1820,
            contentId: '855201',
          ),
        );
        expect(spotLabelText(heritageSpot), '강화도령보리밥');

        for (final spot in [_birdSpot, _starSpot, heritageSpot]) {
          expect(spotLabelText(spot), isNot(contains('점')));
          expect(spotLabelText(spot), isNot(contains('적합도')));
        }
      },
    );
  });

  group('Phase 2a: GPX parser plus api', () {
    test('parseGpxTrack: valid multi-point trkpt GPX returns ordered points',
        () {
      const gpx = '''
<?xml version="1.0"?>
<gpx>
  <trk>
    <trkseg>
      <trkpt lat="37.60" lon="126.40"><ele>10</ele></trkpt>
      <trkpt lat="37.61" lon="126.41"><ele>12</ele></trkpt>
      <trkpt lat="37.62" lon="126.42"><ele>15</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      final points = parseGpxTrack(gpx);
      expect(points, [
        const LatLng(37.60, 126.40),
        const LatLng(37.61, 126.41),
        const LatLng(37.62, 126.42),
      ]);
    });

    test('parseGpxTrack: empty string returns an empty list', () {
      expect(parseGpxTrack(''), isEmpty);
    });

    test(
        'parseGpxTrack: malformed non-XML garbage returns an empty list without throwing',
        () {
      expect(() => parseGpxTrack('not xml at all {{{ <<< garbage >>>'),
          returnsNormally);
      expect(parseGpxTrack('not xml at all {{{ <<< garbage >>>'), isEmpty);
    });

    test('parseGpxTrack: rtept-based route with no trkpt tags also parses',
        () {
      const gpx = '''
<?xml version="1.0"?>
<gpx>
  <rte>
    <rtept lat="37.70" lon="126.50"></rtept>
    <rtept lat="37.71" lon="126.51"></rtept>
  </rte>
</gpx>
''';
      final points = parseGpxTrack(gpx);
      expect(points, [
        const LatLng(37.70, 126.50),
        const LatLng(37.71, 126.51),
      ]);
    });

    test('FakeGpxApi: fetchGpxTrack returns the deterministic points',
        () async {
      final api = FakeGpxApi();
      final points = await api.fetchGpxTrack('https://example.com/x.gpx');
      expect(points, [
        const LatLng(37.60, 126.40),
        const LatLng(37.61, 126.41),
        const LatLng(37.62, 126.42),
      ]);
    });

    test(
        'FakeGpxApi(shouldThrow: true): fetchGpxTrack resolves to an empty list rather than throwing',
        () async {
      final api = FakeGpxApi(shouldThrow: true);
      final points = await api.fetchGpxTrack('https://example.com/x.gpx');
      expect(points, isEmpty);
    });
  });

  group('Phase 2b: trail layer chip and polylines', () {
    testWidgets('trail layer defaults off', (tester) async {
      await _pumpTrailMapScreen(tester);
      await tester.pump();

      final chip = tester.widget<FilterChip>(
        find.byKey(const Key('obsmap_chip_trail')),
      );
      expect(chip.selected, isFalse);
    });

    testWidgets(
      'toggling the trail chip renders trailhead markers without throwing',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_chip_trail')));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) => widget is Icon && widget.icon == Icons.hiking,
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'trailhead markers survive a GPX fetch failure, never falling back to a straight line',
      (tester) async {
        await _pumpTrailMapScreen(
          tester,
          gpxApi: FakeGpxApi(shouldThrow: true),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_chip_trail')));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) => widget is Icon && widget.icon == Icons.hiking,
          ),
          findsWidgets,
        );
      },
    );
  });

  group('Phase 3a: spot search, sort and SQM filter', () {
    const spotA = ObservationSpot(
      id: 'bird-a',
      kind: 'bird',
      name: 'Yeocha Tidal Flat',
      coord: Coordinate(lat: 37.10, lng: 127.00),
      nightSky: null,
      birds: BirdObservation(
        speciesCount: 5,
        topSpecies: [],
        mostRecentObsDt: '2026-09-08 10:00',
        status: 'community',
      ),
      heritage: null,
    );

    const spotBLater = ObservationSpot(
      id: 'bird-b-later',
      kind: 'bird',
      name: 'Later Bird Spot',
      coord: Coordinate(lat: 37.50, lng: 127.00),
      nightSky: null,
      birds: BirdObservation(
        speciesCount: 5,
        topSpecies: [],
        mostRecentObsDt: '2026-09-09 10:00',
        status: 'community',
      ),
      heritage: null,
    );

    const spotGarbageDate = ObservationSpot(
      id: 'bird-c-garbage',
      kind: 'bird',
      name: 'Garbage Date Spot',
      coord: Coordinate(lat: 37.20, lng: 127.00),
      nightSky: null,
      birds: BirdObservation(
        speciesCount: 1,
        topSpecies: [],
        mostRecentObsDt: 'not-a-date',
        status: 'community',
      ),
      heritage: null,
    );

    const starHigh = ObservationSpot(
      id: 'star-high',
      kind: 'star',
      name: 'Ganghwa Astro Village',
      coord: Coordinate(lat: 38.00, lng: 127.00),
      nightSky: NightSky(
        sqmValue: 21.7,
        bortleClass: 3,
        skyClass: 'Class 3 양호한 다크스카이',
        status: 'measured',
      ),
      birds: null,
      heritage: null,
    );

    const starLow = ObservationSpot(
      id: 'star-low',
      kind: 'star',
      name: 'Dim Sky Spot',
      coord: Coordinate(lat: 37.30, lng: 127.00),
      nightSky: NightSky(
        sqmValue: 19.0,
        bortleClass: 6,
        skyClass: 'Class 6',
        status: 'measured',
      ),
      birds: null,
      heritage: null,
    );

    const heritageSpot = ObservationSpot(
      id: 'heritage-1',
      kind: 'heritage',
      name: 'Ganghwa Bori Restaurant',
      coord: Coordinate(lat: 37.40, lng: 127.00),
      nightSky: null,
      birds: null,
      heritage: HeritageInfo(
        addr: '인천광역시 강화군 화도면 해안남로 200',
        distanceM: 1820,
        contentId: '855201',
      ),
    );

    test('filterObservationSpotsByQuery: case-insensitive substring match',
        () {
      final spots = [spotA, starHigh];
      expect(
        filterObservationSpotsByQuery(spots, 'astro').map((s) => s.id),
        [starHigh.id],
      );
      expect(
        filterObservationSpotsByQuery(spots, 'ASTRO').map((s) => s.id),
        [starHigh.id],
      );
    });

    test('filterObservationSpotsByQuery: empty/whitespace query is a no-op',
        () {
      final spots = [spotA, starHigh];
      expect(filterObservationSpotsByQuery(spots, ''), same(spots));
      expect(filterObservationSpotsByQuery(spots, '   '), same(spots));
    });

    test('filterObservationSpotsBySqm: active=false is a no-op', () {
      final spots = [spotA, starHigh, starLow, heritageSpot];
      expect(
        filterObservationSpotsBySqm(spots, active: false),
        same(spots),
      );
    });

    test(
        'filterObservationSpotsBySqm: active=true keeps only star spots '
        'at/above threshold, drops bird/heritage entirely', () {
      final spots = [spotA, starHigh, starLow, heritageSpot];
      final result = filterObservationSpotsBySqm(spots, active: true);
      expect(result.map((s) => s.id), [starHigh.id]);
    });

    test('sortObservationSpots(distance): ascending distance from origin',
        () {
      const origin = Coordinate(lat: 37.00, lng: 127.00);
      final spots = [starHigh, spotA, starLow]; // deliberately unordered
      final result = sortObservationSpots(
        spots,
        SpotSort.distance,
        origin: origin,
      );
      expect(result.map((s) => s.id), [spotA.id, starLow.id, starHigh.id]);
    });

    test(
        'sortObservationSpots(recent): later mostRecentObsDt first, '
        'non-bird spots pushed to the end in stable order', () {
      final spots = [starHigh, spotA, heritageSpot, spotBLater];
      final result = sortObservationSpots(spots, SpotSort.recent);
      expect(result[0].id, spotBLater.id);
      expect(result[1].id, spotA.id);
      expect(result.sublist(2).map((s) => s.id), [starHigh.id, heritageSpot.id]);
    });

    test(
        'sortObservationSpots(sqm): higher-SQM star spot first, '
        'non-star spots pushed to the end in stable order', () {
      final spots = [starLow, spotA, starHigh, heritageSpot];
      final result = sortObservationSpots(spots, SpotSort.sqm);
      expect(result[0].id, starHigh.id);
      expect(result[1].id, starLow.id);
      expect(result.sublist(2).map((s) => s.id), [spotA.id, heritageSpot.id]);
    });

    test(
        'sortObservationSpots: never throws on a garbage (non-date) '
        'mostRecentObsDt string', () {
      expect(
        () => sortObservationSpots(
          [spotGarbageDate, spotBLater],
          SpotSort.recent,
        ),
        returnsNormally,
      );
      final result = sortObservationSpots(
        [spotGarbageDate, spotBLater],
        SpotSort.recent,
      );
      expect(result[0].id, spotBLater.id);
      expect(result[1].id, spotGarbageDate.id);
    });
  });

  group('Phase 3b: search bar and filter chips', () {
    testWidgets(
      'search query matching no spot shows the neutral empty-filter message, never the error-banner icon',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('obsmap_search_field')),
          'zzz-no-match-zzz',
        );
        await tester.pumpAndSettle();

        expect(find.text('조건에 맞는 관찰 스팟이 없어요'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      },
    );

    testWidgets(
      'search query matching exactly one spot name filters the list down to only that spot',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('obsmap_search_field')),
          '영월',
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('obsmap_spot_item_star-001')), findsOneWidget);
        expect(find.byKey(const Key('obsmap_spot_item_bird-001')), findsNothing);
        expect(find.byKey(const Key('obsmap_spot_item_heritage-001')), findsNothing);
      },
    );

    testWidgets(
      'tapping the SQM sort ChoiceChip does not throw and flips its selected state to true',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_sort_sqm')));
        await tester.pumpAndSettle();

        final chip = tester.widget<ChoiceChip>(
          find.byKey(const Key('obsmap_sort_sqm')),
        );
        expect(chip.selected, isTrue);
      },
    );

    testWidgets(
      'CRITICAL: with the plain spot list showing (no search/filter), no suitability-score text ever leaks into the search/filter area',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        expect(find.textContaining('점'), findsNothing);
        expect(find.textContaining('적합도'), findsNothing);
      },
    );
  });

  group('Phase 4a: compass button and tide/moon overlay', () {
    testWidgets(
      'CompassButton with rotationDegrees 0 renders nothing (already north-up)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompassButton(rotationDegrees: 0, onTap: () {}),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('obsmap_compass_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'CompassButton with rotationDegrees 45 renders the button and calls onTap exactly once on tap',
      (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompassButton(
                  rotationDegrees: 45,
                  onTap: () => tapCount++,
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('obsmap_compass_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('obsmap_compass_button')));
        await tester.pump();

        expect(tapCount, 1);
      },
    );

    testWidgets(
      'TideMoonOverlay with both tideText and moonText null renders nothing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: TideMoonOverlay(tideText: null, moonText: null),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('obsmap_tide_moon_overlay')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TideMoonOverlay with only tideText set renders the tide line but no moon-line widget',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: TideMoonOverlay(tideText: '만조 14:20', moonText: null),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('obsmap_tide_moon_overlay')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('obsmap_tide_text')), findsOneWidget);
        expect(find.byKey(const Key('obsmap_moon_text')), findsNothing);
      },
    );

    testWidgets(
      'TideMoonOverlay with both set renders both lines with no suitability-score text leaking in',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: TideMoonOverlay(
                  tideText: '만조 14:20',
                  moonText: '상현달 62%',
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('obsmap_tide_text')), findsOneWidget);
        expect(find.byKey(const Key('obsmap_moon_text')), findsOneWidget);
        expect(find.textContaining('점'), findsNothing);
        expect(find.textContaining('적합도'), findsNothing);
      },
    );
  });

  group('Phase 4b: compass and tide/moon overlay wiring', () {
    testWidgets(
      'compass button is absent on initial pump: the map starts north-up',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        expect(find.byKey(const Key('obsmap_compass_button')), findsNothing);
      },
    );

    testWidgets(
      'rotating the map reveals the compass button, and tapping it resets '
      'rotation back to north (the button disappears again)',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        flutterMap.mapController!.rotate(45);
        await tester.pump();

        expect(
          find.byKey(const Key('obsmap_compass_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('obsmap_compass_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('obsmap_compass_button')), findsNothing);
      },
    );

    testWidgets(
      'with FakeSuitabilityApi default data, the tide/moon overlay renders '
      'non-empty tide and moon text once the discovery provider resolves',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('obsmap_tide_moon_overlay')),
          findsOneWidget,
        );

        final tideText = tester
            .widget<Text>(find.byKey(const Key('obsmap_tide_text')))
            .data;
        final moonText = tester
            .widget<Text>(find.byKey(const Key('obsmap_moon_text')))
            .data;
        expect(tideText, isNotNull);
        expect(tideText, isNotEmpty);
        expect(moonText, isNotNull);
        expect(moonText, isNotEmpty);
      },
    );
  });

  group('Phase 2c: all-layers chip', () {
    testWidgets('the "전체" chip renders', (tester) async {
      await _pumpTrailMapScreen(tester);
      await tester.pump();

      expect(find.byKey(const Key('obsmap_chip_all')), findsOneWidget);
    });

    testWidgets(
      'initial state (trail excluded) leaves the "전체" chip unselected',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        final chip = tester.widget<FilterChip>(
          find.byKey(const Key('obsmap_chip_all')),
        );
        expect(chip.selected, isFalse);
      },
    );

    testWidgets(
      'tapping the "전체" chip also selects the trail chip (all 4 layers on)',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_chip_all')));
        await tester.pumpAndSettle();

        final trailChip = tester.widget<FilterChip>(
          find.byKey(const Key('obsmap_chip_trail')),
        );
        expect(trailChip.selected, isTrue);
      },
    );

    testWidgets(
      'tapping the "전체" chip again while all layers are on clears every '
      'layer and shows the "표시할 레이어를 선택하세요" empty-layer banner',
      (tester) async {
        await _pumpTrailMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_chip_all')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('obsmap_chip_all')));
        await tester.pumpAndSettle();

        expect(find.text('표시할 레이어를 선택하세요'), findsOneWidget);
      },
    );
  });
}
