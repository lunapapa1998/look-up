import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/widgets/common/provenance_chip.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Spec 054-2a: ProvenanceChip texts, markers, semantics, contrast, sizes.
void main() {
  final at = DateTime(2026, 10, 30, 9, 5);

  Widget harness(ObsMode mode, Widget child) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(body: Center(child: child)),
    );
  }

  void setNarrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Text chipText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byType(ProvenanceChip),
      matching: find.byType(Text),
    ),
  );

  group('resolveProvenance', () {
    test('sample data is never labeled 실시간 (sample beats everything)', () {
      expect(
        resolveProvenance(sample: true, live: true),
        ProvenanceKind.sample,
      );
      expect(
        resolveProvenance(sample: true, stale: true, approx: true, live: true),
        ProvenanceKind.sample,
      );
      expect(
        resolveProvenance(sample: true, approx: true),
        ProvenanceKind.sample,
      );
    });

    test('stale > approx > live, none -> null', () {
      expect(
        resolveProvenance(stale: true, approx: true, live: true),
        ProvenanceKind.stale,
      );
      expect(
        resolveProvenance(stale: true, live: true),
        ProvenanceKind.stale,
      );
      expect(
        resolveProvenance(approx: true, live: true),
        ProvenanceKind.approx,
      );
      expect(resolveProvenance(live: true), ProvenanceKind.live);
      expect(resolveProvenance(), isNull);
    });
  });

  for (final mode in ObsMode.values) {
    group('ProvenanceChip (${mode.name})', () {
      testWidgets('exact text per kind without a time', (tester) async {
        final cases = <Widget, String>{
          const ProvenanceChip.live(): '실시간',
          const ProvenanceChip.approx(): '추정',
          const ProvenanceChip.sample(): '예시',
          const ProvenanceChip.stale(): '지연',
        };
        for (final entry in cases.entries) {
          await tester.pumpWidget(harness(mode, entry.key));
          expect(find.text(entry.value), findsOneWidget);
          expect(find.textContaining(':'), findsNothing);
        }
      });

      testWidgets('time shown only for live/stale when at is given', (
        tester,
      ) async {
        await tester.pumpWidget(harness(mode, ProvenanceChip.live(at: at)));
        expect(find.text('실시간 · 09:05'), findsOneWidget);

        await tester.pumpWidget(harness(mode, ProvenanceChip.stale(at: at)));
        expect(find.text('지연 · 09:05 기준'), findsOneWidget);

        // Generic constructor: at is ignored for approx/sample.
        await tester.pumpWidget(
          harness(
            mode,
            ProvenanceChip(kind: ProvenanceKind.approx, at: at),
          ),
        );
        expect(find.text('추정'), findsOneWidget);
        expect(find.textContaining('09:05'), findsNothing);

        await tester.pumpWidget(
          harness(
            mode,
            ProvenanceChip(kind: ProvenanceKind.sample, at: at),
          ),
        );
        expect(find.text('예시'), findsOneWidget);
        expect(find.textContaining('09:05'), findsNothing);

        await tester.pumpWidget(
          harness(mode, ProvenanceChip(kind: ProvenanceKind.live, at: at)),
        );
        expect(find.text('실시간 · 09:05'), findsOneWidget);
      });

      testWidgets('markers: dot, ring, warning icon, dashed sample', (
        tester,
      ) async {
        await tester.pumpWidget(harness(mode, const ProvenanceChip.live()));
        var marker = tester.widget<Container>(
          find.byKey(ProvenanceChip.markerKey),
        );
        var deco = marker.decoration! as BoxDecoration;
        expect(deco.shape, BoxShape.circle);
        expect(deco.color, isNotNull);
        expect(deco.border, isNull);
        expect(find.byKey(ProvenanceChip.solidOutlineKey), findsOneWidget);
        expect(find.byKey(ProvenanceChip.dashedOutlineKey), findsNothing);

        await tester.pumpWidget(harness(mode, const ProvenanceChip.approx()));
        marker = tester.widget<Container>(
          find.byKey(ProvenanceChip.markerKey),
        );
        deco = marker.decoration! as BoxDecoration;
        expect(deco.shape, BoxShape.circle);
        expect(deco.color, isNull);
        expect((deco.border! as Border).top.width, 1.5);
        expect(find.byKey(ProvenanceChip.solidOutlineKey), findsOneWidget);

        await tester.pumpWidget(harness(mode, const ProvenanceChip.stale()));
        final icon = tester.widget<Icon>(find.byKey(ProvenanceChip.markerKey));
        expect(icon.icon, Icons.warning_amber_rounded);
        expect(icon.size, 12);
        expect(find.byKey(ProvenanceChip.solidOutlineKey), findsOneWidget);

        await tester.pumpWidget(harness(mode, const ProvenanceChip.sample()));
        expect(find.byKey(ProvenanceChip.markerKey), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.byKey(ProvenanceChip.solidOutlineKey), findsNothing);
        final dashed = find.descendant(
          of: find.byType(ProvenanceChip),
          matching: find.byType(CustomPaint),
        );
        expect(dashed, findsWidgets);
        expect(find.byKey(ProvenanceChip.dashedOutlineKey), findsOneWidget);
        expect(
          tester
              .widget<CustomPaint>(find.byKey(ProvenanceChip.dashedOutlineKey))
              .painter,
          isNotNull,
        );
      });

      testWidgets('solid outline is a 1px outline-colored stadium on surface', (
        tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        await tester.pumpWidget(harness(mode, const ProvenanceChip.live()));
        final box = tester.widget<DecoratedBox>(
          find.byKey(ProvenanceChip.solidOutlineKey),
        );
        final deco = box.decoration as ShapeDecoration;
        expect(deco.color, theme.colorScheme.surface);
        final shape = deco.shape as StadiumBorder;
        expect(shape.side.width, 1);
        expect(shape.side.style, BorderStyle.solid);
        expect(shape.side.color, theme.colorScheme.outline);
      });

      testWidgets('contrast: text >= 4.5, markers >= 3.0 on the fill', (
        tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        final fill = theme.colorScheme.surface;
        final colors = theme.extension<LookUpColors>()!;

        for (final chip in const <Widget>[
          ProvenanceChip.live(),
          ProvenanceChip.approx(),
          ProvenanceChip.sample(),
          ProvenanceChip.stale(),
        ]) {
          await tester.pumpWidget(harness(mode, chip));
          final textColor = chipText(tester).style!.color!;
          expect(textColor, theme.colorScheme.onSurface);
          expect(contrastRatio(textColor, fill), greaterThanOrEqualTo(4.5));
        }

        await tester.pumpWidget(harness(mode, const ProvenanceChip.live()));
        final liveDot =
            (tester
                        .widget<Container>(find.byKey(ProvenanceChip.markerKey))
                        .decoration!
                    as BoxDecoration)
                .color!;
        expect(liveDot, colors.provenanceLive);
        expect(contrastRatio(liveDot, fill), greaterThanOrEqualTo(3.0));

        await tester.pumpWidget(harness(mode, const ProvenanceChip.approx()));
        final ring =
            ((tester
                            .widget<Container>(
                              find.byKey(ProvenanceChip.markerKey),
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
                .top
                .color;
        expect(ring, colors.provenanceApprox);
        expect(contrastRatio(ring, fill), greaterThanOrEqualTo(3.0));

        await tester.pumpWidget(harness(mode, const ProvenanceChip.stale()));
        final iconColor = tester
            .widget<Icon>(find.byKey(ProvenanceChip.markerKey))
            .color!;
        expect(iconColor, colors.provenanceStale);
        expect(contrastRatio(iconColor, fill), greaterThanOrEqualTo(3.0));

        // Sample's only cue besides text is the dashed outline.
        expect(
          contrastRatio(colors.provenanceSample, fill),
          greaterThanOrEqualTo(3.0),
        );
      });

      testWidgets('semantics label per kind, single node', (tester) async {
        final handle = tester.ensureSemantics();
        final cases = <Widget, String>{
          const ProvenanceChip.live(): '데이터 상태: 실시간',
          ProvenanceChip.live(at: at): '데이터 상태: 실시간, 09:05 기준',
          const ProvenanceChip.approx(): '데이터 상태: 추정',
          const ProvenanceChip.sample(): '예시 데이터',
          const ProvenanceChip.stale(): '데이터 상태: 지연',
          ProvenanceChip.stale(at: at): '데이터 상태: 지연, 09:05 기준',
        };
        for (final entry in cases.entries) {
          await tester.pumpWidget(harness(mode, entry.key));
          final found = find.bySemanticsLabel(entry.value);
          expect(found, findsOneWidget, reason: entry.value);
          // excludeSemantics: the visible text is not a separate node.
          expect(tester.getSemantics(found).childrenCount, 0);
          final visible = chipText(tester).data!;
          expect(find.bySemanticsLabel(visible), findsNothing);
        }
        handle.dispose();
      });

      testWidgets('compact uses fontSize 9, normal 11', (tester) async {
        await tester.pumpWidget(harness(mode, const ProvenanceChip.sample()));
        expect(chipText(tester).style!.fontSize, 11);
        await tester.pumpWidget(
          harness(mode, const ProvenanceChip.sample(compact: true)),
        );
        expect(chipText(tester).style!.fontSize, 9);
        await tester.pumpWidget(
          harness(mode, const ProvenanceChip.stale(compact: true)),
        );
        expect(chipText(tester).style!.fontSize, 9);
        expect(
          tester.widget<Icon>(find.byKey(ProvenanceChip.markerKey)).size,
          10,
        );
      });

      testWidgets('320px: four chips in a row, timed chips wrap', (
        tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(
          harness(
            mode,
            const SizedBox(
              width: 320,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProvenanceChip.live(),
                  SizedBox(width: 4),
                  ProvenanceChip.approx(),
                  SizedBox(width: 4),
                  ProvenanceChip.sample(),
                  SizedBox(width: 4),
                  ProvenanceChip.stale(),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ProvenanceChip), findsNWidgets(4));

        await tester.pumpWidget(
          harness(
            mode,
            SizedBox(
              width: 320,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ProvenanceChip.live(at: at),
                  const ProvenanceChip.approx(),
                  const ProvenanceChip.sample(),
                  ProvenanceChip.stale(at: at),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('compact sample fits a map-pin sized box', (tester) async {
        setNarrowView(tester);
        await tester.pumpWidget(
          harness(
            mode,
            const SizedBox(
              width: 40,
              height: 16,
              child: Center(child: ProvenanceChip.sample(compact: true)),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('예시'), findsOneWidget);
      });
    });
  }
}
