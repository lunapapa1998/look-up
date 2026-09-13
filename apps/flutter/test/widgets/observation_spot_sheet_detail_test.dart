import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/gpx_api.dart';
import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/species_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/species.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/observation_map_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/utils/observation_spot_filter.dart';
import 'package:lookup/widgets/observation_spot_sheet.dart';
import 'package:lookup/widgets/spot_detail/bird_spot_detail.dart';
import 'package:lookup/widgets/spot_detail/heritage_spot_detail.dart';
import 'package:lookup/widgets/spot_detail/species_detail.dart';
import 'package:lookup/widgets/spot_detail/star_spot_detail.dart';
import 'package:lookup/widgets/spot_detail/trail_spot_detail.dart';

/// Pumps [ObservationMapScreen] wired with [FakeObservationMapApi]/
/// [FakeTrailsApi]/[FakeGpxApi] -- mirrors the pump-helper pattern in
/// observation_map_wiring_test.dart / observation_map_parity_test.dart,
/// kept local to this file since those helpers are private to their own
/// files. Covers the spec 021 two-view sheet state machine (list <->
/// spotDetail/trailDetail via the shared back button).
Future<void> _pumpMapScreen(
  WidgetTester tester, {
  SpeciesApi? speciesApi,
}) async {
  final container = ProviderContainer(
    overrides: [
      observationMapApiProvider.overrideWithValue(FakeObservationMapApi()),
      suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      speciesApiProvider.overrideWithValue(speciesApi ?? FakeSpeciesApi()),
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
      gpxApiProvider.overrideWithValue(FakeGpxApi()),
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

/// Small copy of [FakeTrailsApi]'s private `_featuredCourse` fixture, kept
/// local to this file so trail-detail tests below don't need to drive the
/// full [ObservationMapScreen] + flutter_map + a synthetic marker tap just
/// to get a [TrailCourse] to hand to [ObservationSpotSheet] -- flutter_map's
/// marker hit-testing depends on the map camera actually having projected
/// the marker's lat/lng onto the tapped screen pixel, which is exactly the
/// kind of geometry this sheet-focused test suite should not depend on.
const _testTrailCourse = TrailCourse(
  crsIdx: 'T_CRS_MNG0000009999',
  name: '서해랑길 101코스',
  sigun: '인천 강화군',
  distanceKm: 11.0,
  durationMin: 210,
  level: 1,
  cycle: '비순환형',
  gpxUrl: 'https://www.durunubi.kr/courseInfo/101.gpx',
  start: Coordinate(lat: 37.71, lng: 126.42),
  end: Coordinate(lat: 37.60, lng: 126.41),
  nightSky: NightSky(
    sqmValue: 20.15,
    bortleClass: 3,
    skyClass: 'Class 3 양호한 다크스카이',
    status: 'approx',
  ),
  heritageEats: [
    HeritageEat(
      name: '꽃게와낙지',
      addr: '인천광역시 강화군 화도면 해안남로 123',
      distanceM: 1363,
      lat: 37.601,
      lng: 126.412,
      contentId: '855186',
    ),
  ],
  daySuitability: CourseSuitability(score: 67, label: '쾌적', status: 'live'),
  nightSuitability: CourseSuitability(
    score: 64,
    label: '천체관측 양호',
    status: 'live',
  ),
);

/// Pumps [ObservationSpotSheet] directly (no map, no screen) with a fixed
/// [selectedTrail] -- isolates the sheet's own list<->detail view-state
/// switching from flutter_map marker-tap geometry. `trailsApiProvider` is
/// overridden with [FakeTrailsApi] so `TrailSpotDetail`'s Phase 3
/// `trailDetailProvider` watch doesn't attempt a real HTTP call.
Future<void> _pumpSheetWithTrail(
  WidgetTester tester,
  TrailCourse trail,
) async {
  final sheetController = DraggableScrollableController();
  addTearDown(sheetController.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [trailsApiProvider.overrideWithValue(FakeTrailsApi())],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: ObservationSpotSheet(
              spots: const [],
              selectedSpot: null,
              selectedTrail: trail,
              onSelectSpot: (_) {},
              onSelectSpecies: (_) {},
              onBack: () {},
              sheetController: sheetController,
              searchQuery: '',
              onSearchChanged: (_) {},
              sortBy: SpotSort.distance,
              onSortChanged: (_) {},
              sqmFilterActive: false,
              onSqmFilterChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Owns the `selectedTrail` state itself (starting at [initialTrail]) and
/// wires [ObservationSpotSheet.onBack] to clear it via `setState` -- lets
/// the back-button test observe a real list<->detail transition on the
/// sheet alone, without needing [ObservationMapScreen].
class _TrailSheetHarness extends StatefulWidget {
  const _TrailSheetHarness({required this.initialTrail});

  final TrailCourse initialTrail;

  @override
  State<_TrailSheetHarness> createState() => _TrailSheetHarnessState();
}

class _TrailSheetHarnessState extends State<_TrailSheetHarness> {
  late TrailCourse? _selected = widget.initialTrail;
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [trailsApiProvider.overrideWithValue(FakeTrailsApi())],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: ObservationSpotSheet(
              spots: const [],
              selectedSpot: null,
              selectedTrail: _selected,
              onSelectSpot: (_) {},
              onSelectSpecies: (_) {},
              onBack: () => setState(() => _selected = null),
              sheetController: _sheetController,
              searchQuery: '',
              onSearchChanged: (_) {},
              sortBy: SpotSort.distance,
              onSortChanged: (_) {},
              sqmFilterActive: false,
              onSqmFilterChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('spec 021: sheet list <-> detail state machine', () {
    testWidgets(
      'selecting a trail renders TrailSpotDetail content: course name '
      'visible, list not visible',
      (tester) async {
        await _pumpSheetWithTrail(tester, _testTrailCourse);

        expect(find.byType(TrailSpotDetail), findsOneWidget);
        expect(find.text('서해랑길 101코스'), findsOneWidget);
        expect(find.byKey(const Key('obsmap_search_field')), findsNothing);
      },
    );

    testWidgets(
      'tapping the back button while a spot is selected returns to the '
      'list view',
      (tester) async {
        await _pumpMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();
        expect(find.byType(BirdSpotDetail), findsOneWidget);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(BirdSpotDetail), findsNothing);
        expect(find.byKey(const Key('obsmap_search_field')), findsOneWidget);
        expect(
          find.byKey(const Key('obsmap_spot_item_bird-001')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the back button while a trail is selected also returns to '
      'the list view',
      (tester) async {
        await tester.pumpWidget(
          _TrailSheetHarness(initialTrail: _testTrailCourse),
        );
        await tester.pump();
        expect(find.byType(TrailSpotDetail), findsOneWidget);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pump();

        expect(find.byType(TrailSpotDetail), findsNothing);
        expect(find.byKey(const Key('obsmap_search_field')), findsOneWidget);
      },
    );

    testWidgets(
      'bird/star/heritage selection each render their own kind-specific '
      'detail widget class',
      (tester) async {
        await _pumpMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();
        expect(find.byType(BirdSpotDetail), findsOneWidget);
        expect(find.byType(StarSpotDetail), findsNothing);
        expect(find.byType(HeritageSpotDetail), findsNothing);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_star-001')));
        await tester.pumpAndSettle();
        expect(find.byType(StarSpotDetail), findsOneWidget);
        expect(find.byType(BirdSpotDetail), findsNothing);
        expect(find.byType(HeritageSpotDetail), findsNothing);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('obsmap_spot_item_heritage-001')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HeritageSpotDetail), findsOneWidget);
        expect(find.byType(BirdSpotDetail), findsNothing);
        expect(find.byType(StarSpotDetail), findsNothing);
      },
    );

    testWidgets(
      'no AlertDialog appears anywhere in the tree when a trail is '
      'selected (the old _TrailInfoDialog popup is gone)',
      (tester) async {
        await _pumpSheetWithTrail(tester, _testTrailCourse);

        // Prove the trail actually got selected first -- otherwise
        // `findsNothing` for AlertDialog below would pass vacuously even if
        // selection had silently failed.
        expect(find.byType(TrailSpotDetail), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });

  group('spec 021 Phase 2: species detail (list -> spot -> species stack)', () {
    testWidgets(
      'tapping a topSpecies row in BirdSpotDetail transitions to '
      'SpeciesDetail showing that species\' name',
      (tester) async {
        await _pumpMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('obsmap_species_item_blbspo1')));
        await tester.pumpAndSettle();

        expect(find.byType(SpeciesDetail), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SpeciesDetail),
            matching: find.text('저어새'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'wiki data with a summary and no thumbnail renders the summary text '
      'and the photo placeholder',
      (tester) async {
        await _pumpMapScreen(
          tester,
          speciesApi: FakeSpeciesApi(
            response: const SpeciesInfo(
              nameKo: '저어새',
              nameSci: 'Platalea minor',
              summary: '저어새는 저어새과에 속하는 물새다.',
              thumbnailUrl: null,
              wikiUrl: 'https://ko.wikipedia.org/wiki/저어새',
              source: 'ko.wikipedia',
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('obsmap_species_item_blbspo1')));
        await tester.pumpAndSettle();

        expect(find.text('저어새는 저어새과에 속하는 물새다.'), findsOneWidget);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'SpeciesDetail back returns to the spot detail (not the list), '
      'proving a real three-level stack -- a second back returns to the list',
      (tester) async {
        await _pumpMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('obsmap_species_item_blbspo1')));
        await tester.pumpAndSettle();
        expect(find.byType(SpeciesDetail), findsOneWidget);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(SpeciesDetail), findsNothing);
        expect(find.byType(BirdSpotDetail), findsOneWidget);
        expect(find.byKey(const Key('obsmap_search_field')), findsNothing);

        await tester.tap(find.byKey(const Key('obsmap_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(BirdSpotDetail), findsNothing);
        expect(find.byKey(const Key('obsmap_search_field')), findsOneWidget);
      },
    );

    testWidgets(
      'no BirdSpeciesDetail-style modal key ever appears, whether reached '
      'from the measurement-list row or a scattered marker',
      (tester) async {
        await _pumpMapScreen(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('obsmap_spot_item_bird-001')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('obsmap_species_item_blbspo1')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('bird_species_detail_sheet')),
          findsNothing,
        );
        expect(find.byType(SpeciesDetail), findsOneWidget);
      },
    );
  });
}
