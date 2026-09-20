import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/starlight_forecast.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
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

    await tester.tap(find.byKey(const Key('discovery_degraded_retry')));
    await tester.pumpAndSettle();
    expect(fetchCount, 2);

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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
    await tester.pumpAndSettle();

    expect(find.textContaining('오늘 밤 ·'), findsOneWidget);
    expect(find.textContaining('SQM 21.90 · Bortle 1'), findsOneWidget);

    final scoreDy = tester.getTopLeft(find.text('92')).dy;
    final nightSkyDy = tester.getTopLeft(find.textContaining('오늘 밤 ·')).dy;
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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.textContaining('오늘의 달'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    final scoreDy = tester.getTopLeft(find.text('92')).dy;
    final nightSkyDy = tester.getTopLeft(find.textContaining('오늘 밤 ·')).dy;
    final goldenHourDy =
        tester.getTopLeft(find.text('21:40 - 01:20').first).dy;
    final moonDy = tester.getTopLeft(find.textContaining('오늘의 달')).dy;

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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
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

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });
}
