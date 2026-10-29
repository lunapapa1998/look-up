import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/demo/fallback_apis.dart';
import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/regions_api.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/screens/observation_form_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/state/providers.dart';
import 'package:lookup/state/sample_data_provider.dart';
import 'package:lookup/widgets/sample_data_notice.dart';

/// [EcologApi] whose every call fails, standing in for an unreachable
/// backend so [FallbackEcologApi] serves from its on-device store.
class _UnreachableEcologApi implements EcologApi {
  Never _fail() => throw EcologApiException(503, 'unreachable');

  @override
  Future<List<Observation>> listObservations({SpeciesType? speciesType}) async =>
      _fail();

  @override
  Future<Observation> getObservation(int id) async => _fail();

  @override
  Future<Observation> createObservation(ObservationCreate body) async =>
      _fail();

  @override
  Future<Observation> updateObservation(int id, ObservationUpdate body) async =>
      _fail();

  @override
  Future<void> deleteObservation(int id) async => _fail();

  @override
  Future<List<BadgeProgress>> listBadges() async => _fail();
}

void main() {
  testWidgets(
    'trails catalog: failing APIs fall back to sample courses with the banner and 예시 marks',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          trailsApiProvider.overrideWith(
            (ref) => FallbackTrailsApi(
              primary: FakeTrailsApi(shouldThrow: true),
              reporter: sampleReporterFor(ref),
            ),
          ),
          regionsApiProvider.overrideWith(
            (ref) => FallbackRegionsApi(
              primary: FakeRegionsApi(shouldThrow: true),
              reporter: sampleReporterFor(ref),
            ),
          ),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              const ObservationLocation(
                lat: 37.71,
                lng: 126.42,
                placeName: null,
                isFallback: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TrailsCatalogScreen()),
        ),
      );
      // Location -> failing fetch -> sample + report -> rebuild.
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      expect(
        container.read(sampleSourcesProvider),
        containsAll([SampleSource.trails, SampleSource.regions]),
      );
      expect(find.byKey(const Key('sample_data_notice')), findsOneWidget);
      expect(find.text('예시 둘레길 1코스'), findsWidgets);
      expect(find.byType(SampleMark), findsWidgets);
      expect(find.text('두루누비 코스'), findsNothing);
    },
  );

  testWidgets(
    'observation form: a save served by the on-device fallback shows the temporary-save SnackBar',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ecologApiProvider.overrideWith(
              (ref) => FallbackEcologApi(
                primary: _UnreachableEcologApi(),
                reporter: sampleReporterFor(ref),
              ),
            ),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ObservationFormScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '예시 참새');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.byType(ObservationFormScreen), findsNothing);
      expect(find.textContaining('이 기기에만 임시 저장됐어요'), findsOneWidget);
    },
  );
}
