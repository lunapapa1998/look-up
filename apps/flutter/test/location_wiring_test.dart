import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/config.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';

/// Pumps [HomeDiscoveryScreen] wired to [location] via
/// [locationServiceProvider] override, mirroring the pattern in
/// suitability_wiring_test.dart.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required ObservationLocation location,
  void Function(double lat, double lng)? onFetchSuitability,
}) async {
  final container = ProviderContainer(
    overrides: [
      suitabilityApiProvider.overrideWithValue(
        FakeSuitabilityApi(onFetchSuitability: onFetchSuitability),
      ),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(location),
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
  testWidgets('permission granted with place name renders the resolved label', (
    tester,
  ) async {
    double? capturedLat;
    double? capturedLng;
    await _pumpHome(
      tester,
      location: const ObservationLocation(
        lat: 35.1,
        lng: 129.0,
        placeName: '해운대구',
        isFallback: false,
      ),
      onFetchSuitability: (lat, lng) {
        capturedLat = lat;
        capturedLng = lng;
      },
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('해운대구'), findsOneWidget);
    expect(find.text(fallbackPlaceName), findsNothing);
    expect(capturedLat, 35.1);
    expect(capturedLng, 129.0);
  });

  testWidgets('permission denied falls back to the default place label', (
    tester,
  ) async {
    double? capturedLat;
    double? capturedLng;
    await _pumpHome(
      tester,
      location: const ObservationLocation(
        lat: 37.5921,
        lng: 126.3984,
        placeName: null,
        isFallback: true,
      ),
      onFetchSuitability: (lat, lng) {
        capturedLat = lat;
        capturedLng = lng;
      },
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(fallbackPlaceName), findsOneWidget);
    expect(capturedLat, 37.5921);
    expect(capturedLng, 126.3984);
  });

  testWidgets('location loading shows a placeholder before the fetch resolves', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      location: const ObservationLocation(
        lat: 35.1,
        lng: 129.0,
        placeName: '해운대구',
        isFallback: false,
      ),
    );

    expect(find.text('위치 확인 중'), findsOneWidget);
  });

  group('assemblePlaceName', () {
    test('exact duplicate values collapse to one plus max 2 elements kept', () {
      final result = assemblePlaceName(['서울특별시', '서울특별시', '태평로1가']);
      expect(result, '서울특별시·태평로1가');
    });

    test('case and whitespace insensitive duplicates collapse too', () {
      final result = assemblePlaceName([' Seoul ', 'seoul', '태평로1가']);
      expect(result, ' Seoul ·태평로1가');
    });

    test('all null or empty returns null', () {
      expect(assemblePlaceName([null, '', null]), isNull);
    });

    test('three distinct values keeps only first 2 joined by the middle dot', () {
      final result = assemblePlaceName(['서울특별시', '중구', '태평로1가']);
      expect(result, '서울특별시·중구');
    });
  });
}
