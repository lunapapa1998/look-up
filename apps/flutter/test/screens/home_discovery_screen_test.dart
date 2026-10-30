import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/starlight_forecast.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/layout_tokens.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/utils/keep_all.dart';
import 'package:lookup/widgets/common/mode_toggle.dart';
import 'package:lookup/widgets/night_sky_tag.dart';

class FakeStarlightApi implements StarlightApi {
  FakeStarlightApi({this.onFetchForecast});

  final void Function()? onFetchForecast;

  static const _target = StarlightTarget(
    id: 'test-target-1',
    name: '테스트자리 성단',
    constellation: '테스트자리',
    targetType: 'cluster',
    altitudeDeg: 45.0,
    azimuthDeg: 180.0,
    direction: '남쪽',
    observationMode: 'naked_eye',
    description: '테스트용 관측 대상',
  );

  @override
  Future<StarlightForecast> fetchForecast({
    required double lat,
    required double lng,
    String? date,
    String? time,
    String? target,
    double? sqm,
    int? moonIllumination,
    String? twilightEnd,
  }) async {
    onFetchForecast?.call();
    return const StarlightForecast(
      title: '야간 전환 별빛 예보',
      summary: '테스트 요약',
      lat: 37.5921,
      lng: 126.3984,
      date: '2026-09-09',
      sunset: '18:30',
      astronomicalTwilightEnd: '20:00',
      target: _target,
      allVisibleTargets: [_target],
      conditions: StarlightConditions(
        lunarAgeDays: 5.0,
        moonIlluminationPct: 30,
        moonPhaseName: '상현달',
        sqmValue: 21.5,
        skyClass: 'Class 3',
        milkyWayVisible: true,
      ),
      degraded: false,
    );
  }
}

void main() {
  // The finishing pass (page gutters, card padding, 12px journey-step
  // padding, larger home title) moved the conditions card below the default
  // 800x600 view + sliver cache, so the lazy SliverList no longer built it.
  // A taller default view keeps it built; assertions are unchanged. Tests
  // that size the view themselves (pumpHomeAt, setSurfaceSize) still win.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(800, 1600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher
        .implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('renders suitability score, golden hours and telemetry', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(find.text('88'), findsOneWidget);
    expect(find.text('매우 쾌적 (Prime)'), findsOneWidget);
    expect(find.text('14:00 - 17:30'), findsOneWidget);
    expect(find.text('21:40 - 01:20'), findsOneWidget);
    expect(find.text('LIVE FIELD TELEMETRY'), findsNothing);
    expect(find.text(' | 강화 · 영월 실시간 기상망'), findsNothing);
    expect(find.byKey(const Key('focusModeResetAffordance')), findsNothing);
  });

  for (final theme in ObsMode.values) {
    testWidgets(
      'golden-hour rows use day yellow / night lavender accents '
      '(${theme.name} theme)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
              theme: AppTheme.themeFor(theme),
              home: HomeDiscoveryScreen(onViewMapPressed: () {}),
            ),
          ),
        );
        await tester.pump();

        const dayAccent = Color(0xFFF4C247);
        const nightAccent = Color(0xFF9CA3F5);
        final colors = Theme.of(
          tester.element(find.byType(HomeDiscoveryScreen)),
        ).extension<LookUpColors>()!;
        expect(colors.modeDayAccent, dayAccent);
        expect(colors.modeNightAccent, nightAccent);

        Icon ghIcon(IconData data) => tester.widget<Icon>(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == data && w.size == 28,
          ),
        );
        expect(ghIcon(Icons.forest).color, dayAccent);
        expect(ghIcon(Icons.dark_mode).color, nightAccent);

        final scheme = Theme.of(
          tester.element(find.byType(HomeDiscoveryScreen)),
        ).colorScheme;
        for (final icon in [ghIcon(Icons.forest), ghIcon(Icons.dark_mode)]) {
          expect(icon.color, isNot(scheme.tertiary));
          expect(icon.color, isNot(scheme.secondary));
        }

        // Readability: golden-hour labels are accent text only on the dark
        // (night) theme; on the light (day) theme they are onSurface.
        Color? labelColor(String label) => tester
            .widget<Text>(
              find.byWidgetPredicate(
                (w) => w is Text && w.data == label && w.style?.fontSize == 12,
              ),
            )
            .style
            ?.color;
        final isNight = theme == ObsMode.night;
        expect(
          labelColor('낮 · 탐조 골든타임'),
          isNight ? dayAccent : scheme.onSurface,
        );
        expect(
          labelColor('밤 · 천체 골든타임'),
          isNight ? nightAccent : scheme.onSurface,
        );
      },
    );
  }

  testWidgets('degraded data can retry with button and pull to refresh', (
    tester,
  ) async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(
          FakeSuitabilityApi(
            degraded: true,
            onFetchSuitability: (_, _) => fetchCount++,
          ),
        ),
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discovery_degraded_retry')), findsOneWidget);
    expect(fetchCount, 1);

    // Spec 058: the journey card pushes the banner below the fold.
    await tester.ensureVisible(
      find.byKey(const Key('discovery_degraded_retry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discovery_degraded_retry')));
    await tester.pumpAndSettle();
    expect(fetchCount, 2);

    // Back to the top so the pull-to-refresh drag overscrolls.
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(fetchCount, 3);
  });

  testWidgets('tapping night segment switches obsModeProvider to night', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(container.read(obsModeProvider).mode, ObsMode.day);

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pump();
    await tester.pump();

    expect(container.read(obsModeProvider).mode, ObsMode.night);
  });

  testWidgets(
    'shows plain-language night sky label alongside inline SQM/Bortle, never the raw skyClass string',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
            home: HomeDiscoveryScreen(onViewMapPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('별이 쏟아져요'), findsWidgets);
      expect(find.textContaining('SQM 21.60 · Bortle 2'), findsWidgets);
      expect(find.text('Class 2 최적 다크스카이'), findsNothing);
      expect(find.byType(NightSkyTag), findsNothing);
    },
  );

  testWidgets('night mode shows night sky section between score and golden hours', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    expect(find.byKey(homeNightSkyLabelKey), findsOneWidget);
    expect(find.textContaining('SQM 21.90 · Bortle 1'), findsOneWidget);

    final scoreDy = tester.getTopLeft(find.text('92')).dy;
    final nightSkyDy = tester.getTopLeft(find.byKey(homeNightSkyLabelKey)).dy;
    final goldenHourDy = tester.getTopLeft(find.text('21:40 - 01:20').first).dy;

    expect(nightSkyDy, greaterThan(scoreDy));
    expect(nightSkyDy, lessThan(goldenHourDy));
  });

  testWidgets('night mode orders score then night sky then golden hours then moon', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(homeMoonTitleKey),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    final scoreDy = tester.getTopLeft(find.text('92')).dy;
    final nightSkyDy = tester.getTopLeft(find.byKey(homeNightSkyLabelKey)).dy;
    final goldenHourDy =
        tester.getTopLeft(find.text('21:40 - 01:20').first).dy;
    final moonDy = tester.getTopLeft(find.byKey(homeMoonTitleKey)).dy;

    expect(nightSkyDy, greaterThan(scoreDy));
    expect(goldenHourDy, greaterThan(nightSkyDy));
    expect(moonDy, greaterThan(goldenHourDy));
  });

  testWidgets('day mode shows tonight night sky line with mini scale', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(find.textContaining('오늘 밤 ·'), findsWidgets);
    expect(find.byType(NightSkyInfoButton), findsWidgets);
  });

  testWidgets('approx night sky shows dimmed stars and label', (tester) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(
          FakeSuitabilityApi(nightSkyStatusOverride: 'approx'),
        ),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('추정치'), findsWidgets);
  });

  testWidgets('day-mode night sky line renders approx badge adjacent to Bortle text', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(
          FakeSuitabilityApi(nightSkyStatusOverride: 'approx'),
        ),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    final textWidget = tester.widget<Text>(
      find.byKey(const Key('nightSkyDayLineText')),
    );
    final rootSpan = textWidget.textSpan! as TextSpan;
    final children = rootSpan.children!;

    final bortleIndex = children.indexWhere(
      (span) => span is TextSpan && (span.text?.contains('Bortle') ?? false),
    );
    expect(bortleIndex, isNot(-1));
    expect(children.length, bortleIndex + 3);

    final spacerSpan = children[bortleIndex + 1] as WidgetSpan;
    expect(spacerSpan.child, isA<SizedBox>());

    final badgeSpan = children[bortleIndex + 2] as WidgetSpan;
    final badgeText = badgeSpan.child as Text;
    expect(badgeText.data, '추정치');
  });

  testWidgets('no data night sky hides stars and info button', (tester) async {
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(
          FakeSuitabilityApi(nightSkyStatusOverride: 'none'),
        ),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('밤하늘 밝기 정보 없음'), findsWidgets);
    expect(find.byType(NightSkyInfoButton), findsNothing);
  });

  testWidgets('does not overflow at narrow surface widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 800));

    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  Future<ProviderContainer> pumpHomeAt(
    WidgetTester tester,
    Size size, {
    ObsMode theme = ObsMode.day,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
          theme: AppTheme.themeFor(theme),
          home: HomeDiscoveryScreen(onViewMapPressed: () {}),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('greeting shows the new title/description with keep-all', (
    tester,
  ) async {
    await pumpHomeAt(tester, const Size(390, 844));

    expect(find.text(keepAll(homeGreetingTitle)), findsOneWidget);
    expect(find.text(keepAll(homeGreetingDescription)), findsOneWidget);
    expect(homeGreetingTitle, '오늘은 하늘을 보기 좋은 날이에요.');
    expect(
      homeGreetingDescription,
      '갯벌을 찾은 새부터 밤하늘의 별까지, 오늘의 관찰을 시작해 보세요.',
    );

    // Old copy and the interpolated name are gone.
    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? ''))
        .map((s) => s.replaceAll(kWordJoiner, ''))
        .join('\n');
    expect(allText, isNot(contains('하늘을 올려다보기')));
    expect(allText, isNot(contains('관찰자님')));
    expect(allText, isNot(contains('지상 갯벌의 날갯짓')));

    final title = tester.widget<Text>(find.byKey(homeGreetingTitleKey));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.data, contains(kWordJoiner));
    expect(title.data!.replaceAll(kWordJoiner, ''), homeGreetingTitle);
    expect(title.semanticsLabel, homeGreetingTitle);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.style!.height, 1.3);
    expect(title.style!.fontSize, 24);

    final description = tester.widget<Text>(
      find.byKey(homeGreetingDescriptionKey),
    );
    expect(description.maxLines, 3);
    expect(description.data, contains(kWordJoiner));
    expect(description.semanticsLabel, homeGreetingDescription);
    expect(description.style!.fontSize, 15);
    expect(description.style!.height, 1.5);

    // Title -> description gap is 8.
    final titleBottom = tester.getBottomLeft(find.byKey(homeGreetingTitleKey));
    final descTop = tester.getTopLeft(find.byKey(homeGreetingDescriptionKey));
    expect(descTop.dy - titleBottom.dy, closeTo(8, 0.01));
  });

  test('home title size is responsive (22 / 24 / 28)', () {
    expect(homeTitleFontSize(320), 22);
    expect(homeTitleFontSize(360), 22);
    expect(homeTitleFontSize(390), 24);
    expect(homeTitleFontSize(599), 24);
    expect(homeTitleFontSize(600), 28);
    expect(homeTitleFontSize(1280), 28);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(1280, 800)]) {
    for (final theme in ObsMode.values) {
      testWidgets(
        'no overflow and title fits 2 lines at '
        '${size.width.toInt()}x${size.height.toInt()} (${theme.name})',
        (tester) async {
          final container = await pumpHomeAt(tester, size, theme: theme);
          expect(tester.takeException(), isNull);

          final titleFinder = find.byKey(homeGreetingTitleKey);
          await tester.dragUntilVisible(
            titleFinder,
            find.byType(CustomScrollView),
            const Offset(0, -200),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Text>(titleFinder).style!.fontSize,
            homeTitleFontSize(size.width),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: titleFinder, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);

          // Title starts on the page gutter.
          final gutter = AppLayout.pageInsets(size.width).left;
          expect(tester.getTopLeft(titleFinder).dx, closeTo(gutter, 0.01));

          // Scroll the rest of the page into view (lazy sliver children).
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          container.read(obsModeProvider.notifier).setManual(
            theme == ObsMode.day ? ObsMode.night : ObsMode.day,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('night mode renders the tonight sky section with fetched targets', (
    tester,
  ) async {
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('테스트자리 성단'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    expect(find.text('테스트자리 성단'), findsOneWidget);
  });

  testWidgets('day mode does not render the tonight sky section and does not call the starlight API', (
    tester,
  ) async {
    var callCount = 0;
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
        starlightApiProvider.overrideWithValue(
          FakeStarlightApi(onFetchForecast: () => callCount++),
        ),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(find.text('테스트자리 성단'), findsNothing);
    expect(callCount, 0);
  });

  testWidgets('switching from day to night mode fetches the starlight forecast exactly once', (
    tester,
  ) async {
    var callCount = 0;
    final container = ProviderContainer(
      overrides: [
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
        starlightApiProvider.overrideWithValue(
          FakeStarlightApi(onFetchForecast: () => callCount++),
        ),
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
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );
    await tester.pump();

    expect(callCount, 0);

    // Spec 058: the header ModeToggle replaced the in-body focus segments.
    await tester.tap(find.byKey(ModeToggle.nightKey));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });
}
