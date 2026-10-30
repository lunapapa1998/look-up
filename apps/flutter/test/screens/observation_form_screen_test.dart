import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/screens/diary_list_screen.dart';
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

  testWidgets(
    'new save shows 기록했어요 SnackBar whose 생태일기 보기 action opens the diary',
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

      await tester.enterText(find.byType(TextFormField).first, 'Sparrow');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.byType(ObservationFormScreen), findsNothing);
      expect(find.text('기록했어요'), findsOneWidget);
      expect(find.text('생태일기 보기'), findsOneWidget);

      await tester.tap(find.text('생태일기 보기'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryListScreen), findsOneWidget);
      expect(find.text('Sparrow'), findsWidgets);
    },
  );
}
