import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/observation_map_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/widgets/night_sky_tag.dart';
import 'package:lookup/widgets/observation_marker.dart';
import 'package:lookup/widgets/score_gauge.dart';

/// Pumps [ObservationMapScreen] wired to [observationMapApi]/[suitabilityApi]
/// via provider overrides, mirroring the pattern in trails_wiring_test.dart.
/// [location] defaults to a non-fallback point so the location-fallback
/// banner (case 9) doesn't leak into the other 8 cases.
Future<ProviderContainer> _pumpObservationMap(
  WidgetTester tester, {
  required ObservationMapApi observationMapApi,
  SuitabilityApi? suitabilityApi,
  ObservationLocation location = const ObservationLocation(
    lat: 37.71,
    lng: 126.42,
    placeName: null,
    isFallback: false,
  ),
}) async {
  final container = ProviderContainer(
    overrides: [
      observationMapApiProvider.overrideWithValue(observationMapApi),
      suitabilityApiProvider.overrideWithValue(
        suitabilityApi ?? FakeSuitabilityApi(),
      ),
      locationServiceProvider.overrideWithValue(FakeLocationService(location)),
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
      child: MaterialApp(home: ObservationMapScreen(key: ValueKey(observationMapApi))),
    ),
  );
  return container;
}

/// [ObservationMapApi] fixture returning zero spots with degraded=false --
/// distinct from [FakeObservationMapApi] so the empty-state test doesn't ride
/// on any of its fixed fixture data.
class _EmptyObservationMapApi implements ObservationMapApi {
  @override
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  }) async {
    return const ObservationMapResponse(
      region: 'test',
      degraded: false,
      spots: [],
    );
  }
}

/// [ObservationMapApi] fixture returning a single bird spot whose
/// `mostRecentObsDt` is not a parseable date, for the date-parse-failure
/// fallback check in case 5.
class _BadDateBirdApi implements ObservationMapApi {
  static const _spot = ObservationSpot(
    id: 'bird-001',
    kind: 'bird',
    name: '강화도 동막갯벌',
    coord: Coordinate(lat: 37.601, lng: 126.412),
    nightSky: null,
    birds: BirdObservation(
      speciesCount: 1,
      topSpecies: [],
      mostRecentObsDt: 'not-a-date',
      status: 'community',
    ),
    heritage: null,
  );

  @override
  Future<ObservationMapResponse> fetchObservationMap({
    required double lat,
    required double lng,
  }) async {
    return const ObservationMapResponse(
      region: 'test',
      degraded: false,
      spots: [_spot],
    );
  }
}

void main() {
  testWidgets(
    'data state: the screen renders its Scaffold, and buildObservationMarkers maps exactly one marker per spot',
    (tester) async {
      final api = FakeObservationMapApi();
      await _pumpObservationMap(tester, observationMapApi: api);
      await tester.pump();

      expect(find.byKey(const Key('obsmap_screen')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('obsmap_screen'))),
        isA<Scaffold>(),
      );

      final response = await api.fetchObservationMap(lat: 37.71, lng: 126.42);
      final markers = buildObservationMarkers(
        spots: response.spots,
        activeKinds: const {'bird', 'star', 'heritage'},
        selectedSpotId: null,
        onSpotTap: (_) {},
      );
      expect(markers, hasLength(3));
      expect(
        markers.map((m) => (m.child as ObservationMarker).spot.kind).toSet(),
        {'bird', 'star', 'heritage'},
      );
    },
  );

  testWidgets(
    'layer chip toggle: turning a chip off flips its selected state, and turning all three off shows the layer-selection prompt',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('obsmap_chip_bird')));
      await tester.pump();

      final birdChip = tester.widget<FilterChip>(
        find.byKey(const Key('obsmap_chip_bird')),
      );
      expect(birdChip.selected, isFalse);

      final api = FakeObservationMapApi();
      final response = await api.fetchObservationMap(lat: 37.71, lng: 126.42);
      final filtered = filterObservationSpots(response.spots, const {
        'star',
        'heritage',
      });
      expect(filtered, hasLength(2));
      expect(filtered.map((s) => s.kind), isNot(contains('bird')));

      await tester.tap(find.byKey(const Key('obsmap_chip_star')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('obsmap_chip_heritage')));
      await tester.pump();

      expect(find.text('표시할 레이어를 선택하세요'), findsOneWidget);
    },
  );

  testWidgets(
    'pin/list tap -> selected spot detail: tapping the bird sheet row renders the bird detail body',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
      await tester.pumpAndSettle();

      expect(find.textContaining('조류 12종 관측'), findsOneWidget);
      // findsWidgets, not findsOneWidget: spec 016 Phase 1 gives the now-
      // selected bird-001 marker its own on-map pill label, which legitimately
      // repeats the top species name ("저어새") alongside the detail body's
      // species list -- see observation_map_parity_test.dart for the
      // dedicated label-content assertion.
      expect(find.textContaining('저어새'), findsWidgets);
      expect(find.textContaining('검은머리물떼새'), findsOneWidget);
    },
  );

  testWidgets(
    'measurement/suitability separation: the star spot detail shows a ScoreGauge outside the NightSkyTag measurement subtree, with a Divider between them',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('obsmap_spot_item_star-001')));
      await tester.pumpAndSettle();

      expect(find.byType(ScoreGauge), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NightSkyTag),
          matching: find.byType(ScoreGauge),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'bird honesty copy: shows the community-observation badge and a relative "N일 전" recency label, never "실시간"/"live"; a bad obsDt falls back to the raw string without crashing',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
      await tester.pumpAndSettle();

      expect(find.text('커뮤니티 관측'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+일 전')), findsOneWidget);
      expect(find.textContaining('실시간'), findsNothing);
      expect(
        find.textContaining(RegExp('live', caseSensitive: false)),
        findsNothing,
      );

      await _pumpObservationMap(
        tester,
        observationMapApi: _BadDateBirdApi(),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
      await tester.pumpAndSettle();

      expect(find.text('not-a-date'), findsOneWidget);
    },
  );

  testWidgets(
    'degraded/empty/loading/error states: each renders its own distinct banner/icon',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(degraded: true),
      );
      await tester.pump();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);

      await _pumpObservationMap(
        tester,
        observationMapApi: _EmptyObservationMapApi(),
      );
      await tester.pump();
      expect(find.text('주변에 표시할 관찰 스팟이 없어요'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(shouldThrow: true),
      );
      await tester.pump();
      expect(find.text('다시 시도'), findsOneWidget);

      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'single source of truth: the star spot SQM value matches on both the sheet list row and the NightSkyTag detail',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      // findsWidgets, not findsOneWidget: spec 016 Phase 1 gives the now-
      // zoomed-in star-001 marker its own on-map pill label, which
      // legitimately repeats "SQM 20.15" alongside the sheet list row.
      expect(find.textContaining('SQM 20.15'), findsWidgets);

      await tester.tap(find.byKey(const Key('obsmap_spot_item_star-001')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(NightSkyTag),
          matching: find.textContaining('SQM 20.15'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'accessibility: marker and chip hit areas are at least 44px, and both carry a descriptive Semantics label',
    (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
      );
      await tester.pump();

      final starMarker = find.byWidgetPredicate(
        (widget) => widget is ObservationMarker && widget.spot.kind == 'star',
      );
      final markerHitArea = tester.getSize(
        find.descendant(of: starMarker, matching: find.byType(SizedBox)).first,
      );
      expect(markerHitArea.width, greaterThanOrEqualTo(44));
      expect(markerHitArea.height, greaterThanOrEqualTo(44));

      final chipHitArea = tester.getSize(
        find
            .ancestor(
              of: find.byKey(const Key('obsmap_chip_bird')),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(chipHitArea.height, greaterThanOrEqualTo(44));

      expect(find.bySemanticsLabel(RegExp('별 관찰 스팟')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('조류 레이어')), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets(
    'location fallback (P1-3): an isFallback location shows the "location not found" banner and an enable-location button without crashing',
    (tester) async {
      await _pumpObservationMap(
        tester,
        observationMapApi: FakeObservationMapApi(),
        location: const ObservationLocation(
          lat: 37.71,
          lng: 126.42,
          placeName: null,
          isFallback: true,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('obsmap_screen')), findsOneWidget);
      expect(find.text('현재 위치를 못 찾아 강화 기준으로 표시 중'), findsOneWidget);
      expect(find.text('위치 켜기'), findsOneWidget);
    },
  );
}
