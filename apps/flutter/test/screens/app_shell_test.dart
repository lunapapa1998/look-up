import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/screens/app_shell.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/state/providers.dart';

void main() {
  testWidgets(
    'shows 5 nav destinations with discovery tab selected initially',
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

      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('발견·큐레이션'), findsWidgets);
      await tester.tap(find.byIcon(Icons.route));
      await tester.pump();
      expect(find.byType(PackagesCatalogScreen), findsOneWidget);
      expect(find.text('낮에는 탐조, 밤에는 별자리'), findsOneWidget);
    },
  );

  testWidgets('tapping the diary tab shows the diary list screen', (
    tester,
  ) async {
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

    await tester.tap(find.byIcon(Icons.auto_stories));
    await tester.pumpAndSettle();

    expect(find.text('관찰 일지'), findsOneWidget);
  });
}
