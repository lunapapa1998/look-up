import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';

/// Pumps [HomeDiscoveryScreen] wired to [api] via [suitabilityApiProvider]
/// override, mirroring the pattern in home_discovery_screen_test.dart.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required SuitabilityApi api,
}) async {
  final container = ProviderContainer(
    overrides: [
      suitabilityApiProvider.overrideWithValue(api),
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
  return container;
}

void main() {
  testWidgets('data state: renders score, label, golden time and a telemetry icon', (
    tester,
  ) async {
    await _pumpHome(tester, api: FakeSuitabilityApi());
    await tester.pump();

    expect(find.text('88'), findsOneWidget);
    expect(find.text('매우 쾌적 (Prime)'), findsOneWidget);
    expect(find.text('14:00 - 17:30'), findsOneWidget);
    expect(find.text('21:40 - 01:20'), findsOneWidget);
    // telemetry kind 'sky' -> Icons.wb_sunny
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
  });

  testWidgets('mode toggle: tapping night segment re-fetches and renders night values', (
    tester,
  ) async {
    await _pumpHome(tester, api: FakeSuitabilityApi());
    await tester.pump();

    expect(find.text('88'), findsOneWidget);
    expect(find.text('매우 쾌적 (Prime)'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('focusModeNightSegment')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );

    await tester.tap(find.byKey(const Key('focusModeNightSegment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('88'), findsNothing);
    expect(find.text('매우 쾌적 (Prime)'), findsNothing);
    expect(find.text('92'), findsOneWidget);
    expect(find.text('천체관측 최적 (Prime)'), findsOneWidget);
  });

  testWidgets('loading state: shows CircularProgressIndicator before the fetch resolves', (
    tester,
  ) async {
    await _pumpHome(tester, api: FakeSuitabilityApi());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state: shows fixed Korean error copy, retry button, and hides raw exception text', (
    tester,
  ) async {
    await _pumpHome(tester, api: FakeSuitabilityApi(shouldThrow: true));
    await tester.pump();

    expect(find.text('적합도 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('fake failure'), findsNothing);
    expect(find.textContaining('SuitabilityApiException'), findsNothing);
  });

  testWidgets('degraded state: shows the partial-data banner', (tester) async {
    await _pumpHome(tester, api: FakeSuitabilityApi(degraded: true));
    await tester.pump();

    expect(find.text('일부 데이터를 불러오지 못했어요'), findsOneWidget);
  });

  testWidgets(
    'mode caching: day/night toggle fetches each mode once and revisits hit the cache without a spinner',
    (tester) async {
      var fetchCount = 0;
      await _pumpHome(
        tester,
        api: FakeSuitabilityApi(
          onFetchSuitability: (lat, lng) => fetchCount++,
        ),
      );
      await tester.pump();

      expect(fetchCount, 1);
      expect(find.text('88'), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const Key('focusModeNightSegment')),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      await tester.tap(find.byKey(const Key('focusModeNightSegment')));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
      expect(find.text('92'), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const Key('focusModeDaySegment')),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      await tester.tap(find.byKey(const Key('focusModeDaySegment')));
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('88'),
        find.byType(CustomScrollView),
        const Offset(0, 200),
      );

      expect(fetchCount, 2);
      expect(find.text('88'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.dragUntilVisible(
        find.byKey(const Key('focusModeNightSegment')),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      await tester.tap(find.byKey(const Key('focusModeNightSegment')));
      await tester.pump();

      expect(fetchCount, 2);
      expect(find.text('92'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  group('kind -> icon mapping coverage', () {
    testWidgets(
      'FakeSuitabilityApi telemetry covers sky/humidity/wind/precip/tide, each rendering its mapped icon',
      (tester) async {
        await _pumpHome(tester, api: FakeSuitabilityApi());
        await tester.pump();

        expect(find.byIcon(Icons.wb_sunny), findsOneWidget); // sky
        expect(find.byIcon(Icons.water_drop), findsOneWidget); // humidity
        expect(find.byIcon(Icons.air), findsOneWidget); // wind
        expect(find.byIcon(Icons.grain), findsOneWidget); // precip
        expect(find.byIcon(Icons.waves), findsOneWidget); // tide
      },
    );
  });
}
