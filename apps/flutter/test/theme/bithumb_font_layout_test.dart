import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/auth/auth_repository.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/region.dart';
import 'package:lookup/models/stay_package.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/screens/login_screen.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/auth_providers.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/utils/keep_all.dart';

import '../screens/home_discovery_screen_test.dart' show FakeStarlightApi;

/// Layout with the REAL bundled Bithumb Gothic face (flutter_test otherwise
/// renders every family with its own test font): 320x568, text scale 1.0 and
/// 1.3, day and night — no chip truncation, titles <= 2 lines, no overflow.
const _regions = RegionsResponse(
  nearestId: 'ganghwa',
  regions: [
    RegionSummary(
      id: 'ganghwa',
      label: '인천 강화군',
      distanceKm: 0,
      center: RegionCenter(lat: 37.7469, lng: 126.4878),
      hasStarSpot: true,
    ),
    RegionSummary(
      id: 'seosan',
      label: '충남 서산시',
      distanceKm: 90,
      center: RegionCenter(lat: 36.7845, lng: 126.4503),
      hasStarSpot: true,
    ),
    RegionSummary(
      id: 'pyeongchang',
      label: '강원 평창군',
      distanceKm: 150,
      center: RegionCenter(lat: 37.3706, lng: 128.3904),
      hasStarSpot: true,
    ),
  ],
);

class _Trails extends TrailsNotifier {
  @override
  Future<TrailsResponse> build() async =>
      const TrailsResponse(region: '강화·서해안', degraded: false, courses: []);
}

void _setUp(WidgetTester tester, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectChipLabelFits(WidgetTester tester, Key key, String label) {
  final text = find.descendant(of: find.byKey(key), matching: find.text(label));
  expect(text, findsOneWidget, reason: label);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse, reason: label);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01),
    reason: label,
  );
  final style = paragraph.text.style!;
  expect(style.fontFamily, AppTheme.bithumbGothic, reason: label);
  expect(style.fontSize, 14, reason: label);
}

void _expectAtMostTwoLines(WidgetTester tester, Finder title) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: title, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  final lines = paragraph
      .getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      )
      .map((b) => b.top.round())
      .toSet();
  expect(lines.length, lessThanOrEqualTo(2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bithumb = FontLoader(AppTheme.bithumbGothic)
      ..addFont(rootBundle.load('assets/fonts/BithumbGothic-Basic.ttf'));
    await bithumb.load();
    // Fallback family, so any glyph Bithumb lacks also uses a real face.
    final pretendard = FontLoader(AppTheme.pretendard)
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await pretendard.load();
  });

  testWidgets('home night: moon title clear of times, night-sky label '
      'keep-all (320x568)', (tester) async {
    _setUp(tester, 1.0);
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
        starlightApiProvider.overrideWithValue(FakeStarlightApi()),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            const ObservationLocation(
              lat: 37.5921,
              lng: 126.3984,
              placeName: null,
              isFallback: true,
            ),
          ),
        ),
        nowProvider.overrideWithValue(DateTime(2026, 9, 9, 10, 0)),
      ],
    );
    addTearDown(container.dispose);
    container.read(obsModeProvider.notifier).setManual(ObsMode.night);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.themeFor(ObsMode.night),
          home: HomeDiscoveryScreen(onViewMapPressed: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final label = find.byKey(homeNightSkyLabelKey);
    await tester.dragUntilVisible(
      label,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, contains(kWordJoiner));
    expect(tester.widget<Text>(label).semanticsLabel, startsWith('오늘 밤 · '));

    final moonTitle = find.byKey(homeMoonTitleKey);
    await tester.dragUntilVisible(
      moonTitle,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(moonTitle).data, contains(kWordJoiner));
    final titleRect = tester.getRect(moonTitle);
    for (final key in [homeMoonsetKey, homeMoonriseKey]) {
      final timeRect = tester.getRect(find.byKey(key));
      expect(titleRect.overlaps(timeRect), isFalse, reason: '$key');
      expect(titleRect.right, lessThanOrEqualTo(timeRect.left), reason: '$key');
    }
  });

  for (final scale in const [1.0, 1.3]) {
    for (final mode in ObsMode.values) {
      final tag = '320x568 x$scale ${mode.name}';

      testWidgets('login: no overflow ($tag)', (tester) async {
        _setUp(tester, scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(
                const UnavailableAuthRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.themeFor(mode),
              home: LoginScreen(onGuestPressed: () {}),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (scale == 1.0) {
          // All three buttons fit above the 32px bottom padding on a 568-tall
          // screen without scrolling.
          for (final key in [
            LoginScreen.guestButtonKey,
            LoginScreen.kakaoButtonKey,
            LoginScreen.googleButtonKey,
          ]) {
            expect(
              tester.getBottomLeft(find.byKey(key)).dy,
              lessThanOrEqualTo(568 - 32 + 0.01),
              reason: '$key',
            );
          }
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels,
            0,
          );
        }
        for (final label in ['로그인 없이 둘러보기', '카카오로 시작하기', 'Google로 계속하기']) {
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: label);
        }
      });

      testWidgets('home: no overflow, title <= 2 lines ($tag)', (tester) async {
        _setUp(tester, scale);
        final container = ProviderContainer(
          overrides: [
            suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
            starlightApiProvider.overrideWithValue(FakeStarlightApi()),
            locationServiceProvider.overrideWithValue(
              FakeLocationService(
                const ObservationLocation(
                  lat: 37.5921,
                  lng: 126.3984,
                  placeName: null,
                  isFallback: true,
                ),
              ),
            ),
            nowProvider.overrideWithValue(DateTime(2026, 9, 9, 10, 0)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.themeFor(mode),
              home: HomeDiscoveryScreen(onViewMapPressed: () {}),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final title = find.byKey(homeGreetingTitleKey);
        await tester.dragUntilVisible(
          title,
          find.byType(CustomScrollView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectAtMostTwoLines(tester, title);

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('trails: region chips untruncated, no overflow ($tag)', (
        tester,
      ) async {
        _setUp(tester, scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trailsProvider.overrideWith(_Trails.new),
              regionsProvider.overrideWith((ref) async => _regions),
            ],
            child: MaterialApp(
              theme: AppTheme.themeFor(mode),
              home: const TrailsCatalogScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final r in _regions.regions) {
          _expectChipLabelFits(tester, Key('trail_region_${r.id}'), r.label);
        }
      });

      testWidgets('packages: chips untruncated, title <= 2 lines, no overflow '
          '($tag)', (tester) async {
        _setUp(tester, scale);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.themeFor(mode),
              home: const PackagesCatalogScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        _expectChipLabelFits(
          tester,
          const Key('packages_filter_all'),
          '전체 패키지 (${exampleStayPackages.length})',
        );
        for (final c in PackageCategory.values) {
          _expectChipLabelFits(tester, Key('packages_filter_${c.name}'), c.label);
        }
        _expectAtMostTwoLines(
          tester,
          find.byKey(const Key('packages_intro_title')),
        );

        await tester.drag(
          find.byKey(const Key('packages_scroll')),
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
