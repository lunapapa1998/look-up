import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';

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

  testWidgets('renders both hotspot cards', (tester) async {
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
      find.text('강화도 동막갯벌 & 여차리 도래지'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    expect(find.text('강화도 동막갯벌 & 여차리 도래지'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('영월 별마로 & 봉래산 다크스카이'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    expect(find.text('영월 별마로 & 봉래산 다크스카이'), findsOneWidget);
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
}
