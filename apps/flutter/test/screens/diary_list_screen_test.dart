import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/screens/diary_list_screen.dart';
import 'package:lookup/state/providers.dart';

void main() {
  testWidgets('renders seeded observation species names', (tester) async {
    final api = FakeEcologApi(
      seed: [
        Observation(
          id: 1,
          speciesType: SpeciesType.bird,
          speciesName: 'Magpie',
          note: 'Saw it on the fence',
          observedAt: DateTime(2026, 9, 1, 8, 30),
          createdAt: DateTime(2026, 9, 1, 8, 30),
        ),
        Observation(
          id: 2,
          speciesType: SpeciesType.star,
          speciesName: 'Vega',
          observedAt: DateTime(2026, 9, 2, 21, 0),
          createdAt: DateTime(2026, 9, 2, 21, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiaryListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Magpie'), findsOneWidget);
    expect(find.text('Vega'), findsOneWidget);
  });

  testWidgets('renders empty-state message when no observations', (tester) async {
    final api = FakeEcologApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiaryListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No observations yet.'), findsOneWidget);
  });

  testWidgets('renders photo thumbnail when observation has a photoUrl', (tester) async {
    final api = FakeEcologApi(
      seed: [
        Observation(
          id: 1,
          speciesType: SpeciesType.bird,
          speciesName: 'Magpie',
          photoUrl: 'https://example.com/magpie.jpg',
          observedAt: DateTime(2026, 9, 1, 8, 30),
          createdAt: DateTime(2026, 9, 1, 8, 30),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiaryListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('renders species icon placeholder when observation has no photoUrl', (tester) async {
    final api = FakeEcologApi(
      seed: [
        Observation(
          id: 2,
          speciesType: SpeciesType.star,
          speciesName: 'Vega',
          observedAt: DateTime(2026, 9, 2, 21, 0),
          createdAt: DateTime(2026, 9, 2, 21, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DiaryListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
