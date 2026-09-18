import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/course_detail_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/widgets/course_card.dart';

/// Pumps [TrailsCatalogScreen] wired to [api] via [trailsApiProvider]
/// override, mirroring the pattern in suitability_wiring_test.dart.
Future<ProviderContainer> _pumpTrails(
  WidgetTester tester, {
  required TrailsApi api,
}) async {
  final container = ProviderContainer(
    overrides: [
      trailsApiProvider.overrideWithValue(api),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(
          const ObservationLocation(
            lat: 37.71,
            lng: 126.42,
            placeName: null,
            isFallback: true,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: const TrailsCatalogScreen()),
    ),
  );
  return container;
}

/// [TrailsApi] fixture returning an empty course list — distinct from
/// [FakeTrailsApi] so the empty-state test doesn't ride on any of its
/// fixed fixture data.
class _EmptyTrailsApi implements TrailsApi {
  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  }) async {
    return const TrailsResponse(region: 'test', degraded: false, courses: []);
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({required String crsIdx}) async {
    return TrailDetailResponse(
      crsIdx: crsIdx,
      found: false,
      description: null,
      themeId: null,
      startName: null,
      endName: null,
      travelerInfo: null,
      tourInfo: null,
      elevationProfile: const [],
      degraded: false,
    );
  }
}

void main() {
  testWidgets(
    'data state: featured course card renders both suitability labels and a heritage preview line',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi());
      await tester.pump();

      expect(find.text('낮 적합도'), findsOneWidget);
      expect(find.text('밤 적합도'), findsOneWidget);
      expect(find.text('꽃게와낙지 등 인근 노포 2곳'), findsOneWidget);

      final featuredCard = tester.widget<Card>(
        find.descendant(
          of: find.byType(CourseCard).first,
          matching: find.byType(Card),
        ),
      );
      final featuredShape = featuredCard.shape as RoundedRectangleBorder;
      expect(featuredShape.side.width, greaterThan(0));
    },
  );

  testWidgets(
    'data state: non-featured course card renders its NightSkyTag, and only the featured card shows the day suitability label',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi());
      await tester.pump();

      expect(find.text('낮 적합도'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('trail_course_T_CRS_MNG0000008888')),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('trails_catalog_scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('SQM 18.20'), findsOneWidget);
      expect(find.text('Class 4 도시외곽 다크스카이'), findsOneWidget);
    },
  );

  testWidgets(
    'degraded state: shows the partial-data banner and a retry button',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi(degraded: true));
      await tester.pump();

      expect(find.text('일부 데이터를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    },
  );

  testWidgets(
    'empty state: shows the empty-state text and icon, and never the degraded-banner styling',
    (tester) async {
      await _pumpTrails(tester, api: _EmptyTrailsApi());
      await tester.pump();

      expect(find.text('이 권역에는 아직 등록된 코스가 없어요'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off), findsOneWidget);

      expect(find.text('일부 데이터를 불러오지 못했어요'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    },
  );

  testWidgets(
    'loading state: shows CircularProgressIndicator before the fetch resolves',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'error state: shows the fixed Korean error copy and a retry button',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi(shouldThrow: true));
      await tester.pump();

      expect(find.text('트레일 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    },
  );

  testWidgets(
    'navigation: featured card opens its detail with heritage eat + gauges; non-featured card opens its detail with the neutral caption',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi());
      await tester.pump();

      await tester.tap(find.byType(CourseCard).first);
      await tester.pumpAndSettle();

      final featuredDetail = find.byType(CourseDetailScreen);
      expect(featuredDetail, findsOneWidget);
      expect(
        find.descendant(of: featuredDetail, matching: find.text('꽃게와낙지')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: featuredDetail, matching: find.text('낮 적합도')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: featuredDetail, matching: find.text('밤 적합도')),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      final secondCourse = find.byKey(
        const Key('trail_course_T_CRS_MNG0000008888'),
      );
      for (
        var i = 0;
        i < 20 && secondCourse.hitTestable().evaluate().isEmpty;
        i++
      ) {
        await tester.drag(
          find.byKey(const Key('trails_catalog_scroll')),
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(secondCourse);
      await tester.pumpAndSettle();

      final secondDetail = find.byType(CourseDetailScreen);
      expect(secondDetail, findsOneWidget);
      expect(
        find.descendant(
          of: secondDetail,
          matching: find.text('이 코스는 밤하늘 관측 조건을 충족하여 포함되었어요'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: secondDetail, matching: find.text('낮 적합도')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'single source of truth: the featured course SQM text matches on both the catalog and detail screens',
    (tester) async {
      await _pumpTrails(tester, api: FakeTrailsApi());
      await tester.pump();

      expect(find.text('SQM 20.15'), findsOneWidget);

      await tester.tap(find.byType(CourseCard).first);
      await tester.pumpAndSettle();

      final detail = find.byType(CourseDetailScreen);
      expect(
        find.descendant(of: detail, matching: find.text('SQM 20.15')),
        findsOneWidget,
      );
    },
  );
}
