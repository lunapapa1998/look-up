import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/screens/app_shell.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/state/journey_providers.dart';
import 'package:lookup/state/providers.dart';
import 'package:lookup/utils/keep_all.dart';
import 'package:lookup/widgets/observation_spot_sheet.dart';

void main() {
  testWidgets(
    'shows 4 nav destinations with home tab selected initially',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ecologApiProvider.overrideWithValue(FakeEcologApi()),
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
          child: const MaterialApp(home: AppShell()),
        ),
      );

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('홈'), findsWidgets);
      await tester.tap(find.byIcon(Icons.route));
      await tester.pump();
      expect(find.byType(PackagesCatalogScreen), findsOneWidget);
      expect(find.text(keepAll(packagesIntroTitle)), findsOneWidget);
      expect(find.text('D.U.A.L.I.S.M. · 1박 2일 생태여행'), findsNothing);
    },
  );

  testWidgets('selected tab reads and writes appTabIndexProvider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ecologApiProvider.overrideWithValue(FakeEcologApi()),
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );

    NavigationBar navBar() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    IndexedStack shellStack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack).first);

    expect(container.read(appTabIndexProvider), AppTab.home);
    expect(navBar().selectedIndex, 0);

    // Another screen switching tabs through the provider.
    container.read(appTabIndexProvider.notifier).state = AppTab.packages;
    await tester.pump();
    expect(navBar().selectedIndex, 3);
    expect(shellStack().index, 3);

    // Tapping a destination writes the provider.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.map),
      ),
    );
    await tester.pump();
    expect(container.read(appTabIndexProvider), AppTab.observationMap);
    expect(shellStack().index, 1);
  });

  testWidgets('map tab spot sheet peek does not overflow at 800x600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ecologApiProvider.overrideWithValue(FakeEcologApi()),
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );

    container.read(appTabIndexProvider.notifier).state =
        AppTab.observationMap;
    await tester.pump();
    await tester.pump();

    expect(find.byType(ObservationSpotSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
