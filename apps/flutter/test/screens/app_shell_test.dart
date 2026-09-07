import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/screens/app_shell.dart';
import 'package:lookup/state/providers.dart';

void main() {
  testWidgets('shows 5 nav destinations with discovery tab selected initially', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(FakeEcologApi())],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('발견·큐레이션'), findsWidgets);
  });

  testWidgets('tapping the diary tab shows the diary list screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ecologApiProvider.overrideWithValue(FakeEcologApi())],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    await tester.tap(find.byIcon(Icons.auto_stories));
    await tester.pumpAndSettle();

    expect(find.text('관찰 일지'), findsOneWidget);
  });
}
