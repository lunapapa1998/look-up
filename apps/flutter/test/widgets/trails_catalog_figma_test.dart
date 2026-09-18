import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lookup/api/gpx_api.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/trail_route_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/course_card.dart';

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
}) async {
  final colors = night
      ? AppTheme.nightColorScheme()
      : AppTheme.dayColorScheme();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trailsProvider.overrideWith(() => _Trails(courses)),
        gpxApiProvider.overrideWithValue(FakeGpxApi()),
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
  testWidgets('region selection filters courses and reset restores list', (
    tester,
  ) async {
    await pumpCatalog(tester, [
      course('a', '강화', scores: true),
      course('b', '순천'),
    ]);
    await tester.tap(find.byKey(const Key('trail_region_순천')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard).first).course.crsIdx,
      'b',
    );
    expect(find.text('관측 적합도 정보가 없어요'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('trail_region_all')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard).first).course.crsIdx,
      'a',
    );
  });

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

  testWidgets('GPX action displays real fetched points as a polyline', (
    tester,
  ) async {
    await pumpCatalog(tester, [course('a', '강화')]);
    final action = find.byKey(const Key('trail_gpx_open'));
    await scrollTo(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('두루누비 GPX 경로 · 3개 지점'), findsOneWidget);
    final lines = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(lines.single.points, [
      const LatLng(37.60, 126.40),
      const LatLng(37.61, 126.41),
      const LatLng(37.62, 126.42),
    ]);
  });

  testWidgets(
    'missing GPX preserves endpoints and never draws an invented route',
    (tester) async {
      await pumpCatalog(tester, [course('a', '강화', gpx: false)]);
      final action = find.byKey(const Key('trail_gpx_open'));
      await scrollTo(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('등록된 GPX 경로가 없어요. 출발·도착 위치를 표시합니다.'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
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
