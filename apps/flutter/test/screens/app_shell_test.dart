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
      expect(find.text('낮에는 탐조, 밤에는 별자리'), findsOneWidget);
      expect(find.text('D.U.A.L.I.S.M. · 1박 2일 생태여행'), findsNothing);
    },
  );
}
