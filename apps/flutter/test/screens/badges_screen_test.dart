import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/screens/badges_screen.dart';
import 'package:lookup/state/providers.dart';

void main() {
  testWidgets('renders all badge names', (tester) async {
    final api = FakeEcologApi();

    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: BadgesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 관찰'), findsOneWidget);
    expect(find.text('탐험가'), findsOneWidget);
    expect(find.text('관찰 마스터'), findsOneWidget);
    expect(find.text('새 관찰자'), findsOneWidget);
    expect(find.text('별 관찰자'), findsOneWidget);
  });
}
