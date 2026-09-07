import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/state/discovery_providers.dart';

void main() {
  testWidgets('renders suitability score, golden hours and telemetry', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );

    expect(find.text('88'), findsOneWidget);
    expect(find.text('매우 쾌적 (Prime)'), findsOneWidget);
    expect(find.text('14:00 - 17:30'), findsOneWidget);
    expect(find.text('21:40 - 01:20'), findsOneWidget);
  });

  testWidgets('renders both hotspot cards', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );

    expect(find.text('강화도 동막갯벌 & 여차리 도래지'), findsOneWidget);
    expect(find.text('영월 별마로 & 봉래산 다크스카이'), findsOneWidget);
  });

  testWidgets('tapping night segment switches obsModeProvider to night', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: HomeDiscoveryScreen(onViewMapPressed: () {})),
      ),
    );

    expect(container.read(obsModeProvider), ObsMode.day);

    await tester.tap(find.text('밤의 별을 보러 (천체관측)'));
    await tester.pump();

    expect(container.read(obsModeProvider), ObsMode.night);
  });
}
