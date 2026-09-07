import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/screens/observation_form_screen.dart';
import 'package:lookup/state/providers.dart';

void main() {
  testWidgets('fills species name, saves, creates observation, and pops',
      (tester) async {
    final api = FakeEcologApi();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
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

    expect(find.byType(ObservationFormScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Sparrow');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    final observations = await api.listObservations();
    expect(observations, hasLength(1));
    expect(observations.first.speciesName, 'Sparrow');
    expect(observations.first.speciesType, SpeciesType.bird);

    expect(find.byType(ObservationFormScreen), findsNothing);
  });
}
