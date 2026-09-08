import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/state/discovery_providers.dart';

/// Pumps [HomeDiscoveryScreen] wired to [api] via [suitabilityApiProvider]
/// override, mirroring the pattern in home_discovery_screen_test.dart.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required SuitabilityApi api,
}) async {
  final container = ProviderContainer(
    overrides: [suitabilityApiProvider.overrideWithValue(api)],
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

    await tester.tap(find.text('밤의 별을 보러 (천체관측)'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

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
