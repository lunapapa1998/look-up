import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lookup/api/gpx_api.dart';
import 'package:lookup/models/region.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/trail_route_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';

const _defaultRegions = RegionsResponse(
  nearestId: 'ganghwa',
  regions: [
    RegionSummary(
      id: 'ganghwa',
      label: '강화·서해안',
      distanceKm: 0.0,
      center: RegionCenter(lat: 37.7469, lng: 126.4878),
      hasStarSpot: true,
    ),
  ],
);

TrailCourse course(
  String id,
  String region, {
  bool scores = false,
  bool gpx = true,
}) => TrailCourse(
  crsIdx: id,
  name: '$region 관찰길',
  sigun: region,
  distanceKm: 11.2,
  durationMin: 220,
  level: 2,
  cycle: '비순환형',
  gpxUrl: gpx ? 'https://example.com/$id.gpx' : '',
  start: const Coordinate(lat: 37.71, lng: 126.42),
  end: const Coordinate(lat: 37.60, lng: 126.41),
  nightSky: const NightSky(
    sqmValue: 21.8,
    bortleClass: 3,
    skyClass: 'Class 3 양호한 다크스카이',
    status: 'approx',
  ),
  heritageEats: const [
    HeritageEat(
      name: '지역 노포',
      addr: '인천 강화군 해안남로',
      distanceM: 1200,
      lat: 37.601,
      lng: 126.412,
      contentId: 'shared',
    ),
  ],
  daySuitability: scores
      ? const CourseSuitability(score: 67, label: '쾌적', status: 'live')
      : null,
  nightSuitability: scores
      ? const CourseSuitability(score: 64, label: '관측 양호', status: 'approx')
      : null,
);

Future<void> pumpCatalog(
  WidgetTester tester,
  List<TrailCourse> courses, {
  bool night = true,
  double scale = 1,
  RegionsResponse? regions,
}) async {
  final colors = night
      ? AppTheme.nightColorScheme()
      : AppTheme.dayColorScheme();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trailsProvider.overrideWith(() => _Trails(courses)),
        gpxApiProvider.overrideWithValue(FakeGpxApi()),
        regionsProvider.overrideWith((ref) async => regions ?? _defaultRegions),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colors,
          scaffoldBackgroundColor: colors.surface,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const RepaintBoundary(
          key: Key('catalog_render'),
          child: TrailsCatalogScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Trails extends TrailsNotifier {
  _Trails(this.courses);
  final List<TrailCourse> courses;
  @override
  Future<TrailsResponse> build() async =>
      TrailsResponse(region: '강화·서해안', degraded: false, courses: courses);
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final scroll = find.byKey(const Key('trails_catalog_scroll'));
  for (var i = 0; i < 25 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('renders one chip per region in distance order', (
    tester,
  ) async {
    const regions = RegionsResponse(
      nearestId: 'ganghwa',
      regions: [
        RegionSummary(
          id: 'ganghwa',
          label: '강화·서해안',
          distanceKm: 0.0,
          center: RegionCenter(lat: 37.7469, lng: 126.4878),
          hasStarSpot: true,
        ),
        RegionSummary(
          id: 'pyeongchang',
          label: '평창',
          distanceKm: 50.0,
          center: RegionCenter(lat: 37.3706, lng: 128.3904),
          hasStarSpot: true,
        ),
        RegionSummary(
          id: 'suncheon',
          label: '순천',
          distanceKm: 300.0,
          center: RegionCenter(lat: 34.9506, lng: 127.4874),
          hasStarSpot: true,
        ),
      ],
    );
    await pumpCatalog(tester, [course('a', '강화')], regions: regions);
    expect(find.byKey(const Key('trail_region_ganghwa')), findsOneWidget);
    expect(find.byKey(const Key('trail_region_pyeongchang')), findsOneWidget);
    expect(find.byKey(const Key('trail_region_suncheon')), findsOneWidget);
    final chips = find.byType(ChoiceChip).evaluate().toList();
    expect(chips[0].widget.key, const Key('trail_region_ganghwa'));
    expect(chips[1].widget.key, const Key('trail_region_pyeongchang'));
    expect(chips[2].widget.key, const Key('trail_region_suncheon'));
  });

  testWidgets('nearest region chip shows a near_me icon and others do not', (
    tester,
  ) async {
    const regions = RegionsResponse(
      nearestId: 'ganghwa',
      regions: [
        RegionSummary(
          id: 'ganghwa',
          label: '강화·서해안',
          distanceKm: 0.0,
          center: RegionCenter(lat: 37.7469, lng: 126.4878),
          hasStarSpot: true,
        ),
        RegionSummary(
          id: 'suncheon',
          label: '순천',
          distanceKm: 300.0,
          center: RegionCenter(lat: 34.9506, lng: 127.4874),
          hasStarSpot: true,
        ),
      ],
    );
    await pumpCatalog(tester, [course('a', '강화')], regions: regions);
    expect(
      find.descendant(
        of: find.byKey(const Key('trail_region_ganghwa')),
        matching: find.byIcon(Icons.near_me),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('trail_region_suncheon')),
        matching: find.byIcon(Icons.near_me),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'tapping a region chip updates selectedRegionProvider and visually selects it',
    (tester) async {
      const regions = RegionsResponse(
        nearestId: 'ganghwa',
        regions: [
          RegionSummary(
            id: 'ganghwa',
            label: '강화·서해안',
            distanceKm: 0.0,
            center: RegionCenter(lat: 37.7469, lng: 126.4878),
            hasStarSpot: true,
          ),
          RegionSummary(
            id: 'suncheon',
            label: '순천',
            distanceKm: 300.0,
            center: RegionCenter(lat: 34.9506, lng: 127.4874),
            hasStarSpot: true,
          ),
        ],
      );
      await pumpCatalog(tester, [course('a', '강화')], regions: regions);
      await tester.tap(find.byKey(const Key('trail_region_suncheon')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('trail_region_suncheon')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('trail_region_ganghwa')))
            .selected,
        isFalse,
      );
    },
  );

  testWidgets(
    'nearby restaurants are unique and open their address and location',
    (tester) async {
      await pumpCatalog(tester, [course('a', '강화'), course('b', '순천')]);
      final eat = find.byKey(const Key('trail_heritage_shared'));
      await scrollTo(tester, eat);
      expect(eat, findsOneWidget);
      await tester.tap(eat);
      await tester.pumpAndSettle();
      expect(find.byType(TrailRouteScreen), findsOneWidget);
      expect(find.text('인천 강화군 해안남로'), findsOneWidget);
    },
  );

  testWidgets('failed GPX can retry and then render recovered data', (
    tester,
  ) async {
    final api = _RetryGpx();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gpxApiProvider.overrideWithValue(api)],
        child: MaterialApp(home: TrailRouteScreen(course: course('a', '강화'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    await tester.tap(find.byKey(const Key('trail_gpx_retry')));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(api.calls, 2);
  });

  for (final night in [true, false]) {
    testWidgets(
      '320px large text ${night ? 'night' : 'day'} catalog has no overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpCatalog(
          tester,
          [course('a', '인천광역시 강화군', scores: true), course('b', '순천시')],
          night: night,
          scale: 1.6,
        );
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const Key('trail_heritage_shared')));
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const Key('trail_course_b')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _RetryGpx implements GpxApi {
  int calls = 0;
  @override
  Future<List<LatLng>> fetchGpxTrack(String url) async => ++calls == 1
      ? []
      : [const LatLng(37.60, 126.40), const LatLng(37.61, 126.41)];
}
