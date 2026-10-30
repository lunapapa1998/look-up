import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/common/eyebrow_label.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Spec 054-2a: EyebrowLabel Hangul vs Latin mono paths.
void main() {
  Widget harness(ObsMode mode, Widget child) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(body: Center(child: child)),
    );
  }

  Text labelText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byType(EyebrowLabel),
      matching: find.byType(Text),
    ),
  );

  for (final mode in ObsMode.values) {
    group('EyebrowLabel (${mode.name})', () {
      testWidgets('Hangul keeps case, theme spacing, w600, onSurfaceVariant', (
        tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        await tester.pumpWidget(harness(mode, const EyebrowLabel('오늘의 관측')));

        expect(find.text('오늘의 관측'), findsOneWidget);
        final text = labelText(tester);
        expect(text.semanticsLabel, isNull);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        final style = text.style!;
        // Compare with the theme the widget sees: MaterialApp merges the M3
        // typography geometry (letterSpacing/fontSize) into labelMedium.
        final labelMedium = Theme.of(
          tester.element(find.byType(EyebrowLabel)),
        ).textTheme.labelMedium!;
        expect(style.letterSpacing, labelMedium.letterSpacing);
        expect(style.fontSize, labelMedium.fontSize);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, theme.colorScheme.onSurfaceVariant);
        expect(
          contrastRatio(style.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('Latin uses mono uppercase with original semantics', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final theme = AppTheme.themeFor(mode);
        await tester.pumpWidget(harness(mode, const EyebrowLabel('golden hour')));

        expect(find.text('GOLDEN HOUR'), findsOneWidget);
        expect(find.text('golden hour'), findsNothing);
        final text = labelText(tester);
        expect(text.semanticsLabel, 'golden hour');
        final style = text.style!;
        expect(style.letterSpacing, closeTo(0.06 * style.fontSize!, 1e-9));
        expect(
          style.letterSpacing,
          AppTheme.monoLabel(theme).letterSpacing,
        );
        expect(style.color, theme.colorScheme.onSurfaceVariant);
        expect(find.bySemanticsLabel('golden hour'), findsOneWidget);
        expect(find.bySemanticsLabel('GOLDEN HOUR'), findsNothing);
        handle.dispose();
      });

      testWidgets('mixed Latin + Hangul uses the Hangul path', (tester) async {
        await tester.pumpWidget(
          harness(mode, const EyebrowLabel('SQM 21.5 이상')),
        );
        expect(find.text('SQM 21.5 이상'), findsOneWidget);
        final style = labelText(tester).style!;
        expect(style.fontWeight, FontWeight.w600);
        final labelMedium = Theme.of(
          tester.element(find.byType(EyebrowLabel)),
        ).textTheme.labelMedium!;
        expect(style.letterSpacing, labelMedium.letterSpacing);

        // Lowercase Latin next to Hangul is not uppercased either.
        await tester.pumpWidget(harness(mode, const EyebrowLabel('sqm 이상')));
        expect(find.text('sqm 이상'), findsOneWidget);
      });

      testWidgets('custom color is honored', (tester) async {
        const custom = Color(0xFF0A7864);
        await tester.pumpWidget(
          harness(mode, const EyebrowLabel('오늘', color: custom)),
        );
        expect(labelText(tester).style!.color, custom);

        await tester.pumpWidget(
          harness(mode, const EyebrowLabel('tonight', color: custom)),
        );
        expect(labelText(tester).style!.color, custom);
      });

      testWidgets('long text ellipsizes at 320px without exceptions', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          harness(
            mode,
            const SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EyebrowLabel(
                    '오늘 밤 별 관측에 가장 좋은 장소와 시간을 한눈에 확인하세요 정말 긴 라벨',
                  ),
                  EyebrowLabel(
                    'an extremely long latin eyebrow label that cannot fit',
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
        }
      });
    });
  }
}
