import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/state/sample_data_provider.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/widgets/common/provenance_chip.dart';
import 'package:lookup/widgets/sample_data_notice.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Spec 054-2c: SampleMark delegates to ProvenanceChip.sample; the
/// SampleDataNotice stays neutral with a >= 44 tonal retry button.
void main() {
  const noticeKey = Key('sample_data_notice');
  const retryKey = Key('sample_data_notice_retry');
  const noticeText = '서버에 연결할 수 없어 예시 데이터를 보여드려요';

  Widget harness(ObsMode mode, Widget child) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(body: child),
    );
  }

  void setNarrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps [child] (usually containing a [SampleDataNotice]) in a fresh
  /// provider container and returns it.
  Future<ProviderContainer> pumpWithContainer(
    WidgetTester tester,
    ObsMode mode,
    Widget child,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: harness(mode, child),
      ),
    );
    return container;
  }

  Text markText(WidgetTester tester, Finder mark) => tester.widget<Text>(
    find.descendant(of: mark, matching: find.byType(Text)),
  );

  for (final mode in ObsMode.values) {
    group('SampleMark on ProvenanceChip (${mode.name})', () {
      testWidgets('renders a sample ProvenanceChip in both sizes', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            mode,
            const Column(
              children: [
                SampleMark(key: Key('normal')),
                SampleMark(key: Key('compact'), compact: true),
              ],
            ),
          ),
        );

        for (final entry in const {'normal': 11.0, 'compact': 9.0}.entries) {
          final mark = find.byKey(Key(entry.key));
          final chip = find.descendant(
            of: mark,
            matching: find.byType(ProvenanceChip),
          );
          expect(chip, findsOneWidget);
          final widget = tester.widget<ProvenanceChip>(chip);
          expect(widget.kind, ProvenanceKind.sample);
          expect(widget.compact, entry.key == 'compact');
          expect(
            find.descendant(
              of: mark,
              matching: find.byKey(ProvenanceChip.dashedOutlineKey),
            ),
            findsOneWidget,
          );
          final text = markText(tester, mark);
          expect(text.data, '예시');
          expect(text.style!.fontSize, entry.value);
          expect(
            text.style!.color,
            Theme.of(tester.element(mark)).colorScheme.onSurface,
          );
        }

        expect(find.text('예시'), findsNWidgets(2));
        expect(find.bySemanticsLabel('예시 데이터'), findsNWidgets(2));
        // The visible text is not a separate semantics node.
        expect(find.bySemanticsLabel('예시'), findsNothing);
        handle.dispose();
      });

      testWidgets('same box as ProvenanceChip.sample; old SampleMark height', (
        tester,
      ) async {
        for (final compact in [false, true]) {
          await tester.pumpWidget(
            harness(
              mode,
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SampleMark(key: const Key('mark'), compact: compact),
                    ProvenanceChip.sample(
                      key: const Key('chip'),
                      compact: compact,
                    ),
                  ],
                ),
              ),
            ),
          );

          final markSize = tester.getSize(find.byKey(const Key('mark')));
          final chipSize = tester.getSize(find.byKey(const Key('chip')));
          expect(markSize, chipSize, reason: 'compact: $compact');

          // Pre-054-2c SampleMark sizes measured at a112bbb (test font).
          final expectedHeight = compact ? 13.0 : 17.0;
          expect(markSize.height, expectedHeight, reason: 'compact: $compact');
        }
      });

      testWidgets('label merges into the enclosing card node (old behavior)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            mode,
            Center(
              child: Semantics(
                key: const Key('card'),
                container: true,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('카드 제목'),
                    SizedBox(width: 8),
                    SampleMark(),
                  ],
                ),
              ),
            ),
          ),
        );
        final card = tester.getSemantics(find.byKey(const Key('card')));
        expect(card.label, contains('카드 제목'));
        expect(card.label, contains('예시 데이터'));
        // Not a separate node: the mark is absorbed into the card.
        expect(card.childrenCount, 0);
        handle.dispose();
      });

      testWidgets('inside ExcludeSemantics (map pin) exposes no node', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            mode,
            const Center(
              child: ExcludeSemantics(child: SampleMark(compact: true)),
            ),
          ),
        );
        expect(find.text('예시'), findsOneWidget);
        expect(find.bySemanticsLabel('예시 데이터'), findsNothing);
        handle.dispose();
      });
    });

    group('SampleDataNotice (${mode.name})', () {
      testWidgets('visibility follows sampleSourcesProvider ∩ sources', (
        tester,
      ) async {
        final container = await pumpWithContainer(
          tester,
          mode,
          Column(
            children: [
              SampleDataNotice(
                sources: const {SampleSource.trails},
                onRetry: () {},
                margin: const EdgeInsets.all(16),
              ),
            ],
          ),
        );
        final notifier = container.read(sampleSourcesProvider.notifier);
        double height() => tester.getSize(find.byType(SampleDataNotice)).height;

        // Real data: nothing, margin included.
        expect(find.byKey(noticeKey), findsNothing);
        expect(height(), 0);

        // Unrelated source sampled: still hidden.
        notifier.markSample(SampleSource.suitability);
        await tester.pump();
        expect(find.byKey(noticeKey), findsNothing);
        expect(height(), 0);

        // Watched source sampled: visible.
        notifier.markSample(SampleSource.trails);
        await tester.pump();
        expect(find.byKey(noticeKey), findsOneWidget);
        expect(find.text(noticeText), findsOneWidget);
        expect(height(), greaterThan(0));

        // Back to real: hidden again.
        notifier.markReal(SampleSource.trails);
        await tester.pump();
        expect(find.byKey(noticeKey), findsNothing);
        expect(height(), 0);
      });

      testWidgets('retry: tonal FilledButton, enabled, >= 44, calls once', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var calls = 0;
        final container = await pumpWithContainer(
          tester,
          mode,
          SampleDataNotice(
            sources: const {SampleSource.trails},
            onRetry: () => calls++,
          ),
        );
        container
            .read(sampleSourcesProvider.notifier)
            .markSample(SampleSource.trails);
        await tester.pump();

        final retry = find.byKey(retryKey);
        expect(retry, findsOneWidget);
        final button = tester.widget<FilledButton>(retry);
        expect(button.onPressed, isNotNull);
        expect(button.style?.visualDensity, VisualDensity.standard);
        expect(button.style?.tapTargetSize, MaterialTapTargetSize.padded);
        expect(find.byType(TextButton), findsNothing);
        expect(
          find.descendant(of: retry, matching: find.text('다시 시도')),
          findsOneWidget,
        );

        // Tonal variant: filled with secondaryContainer.
        final scheme = Theme.of(tester.element(retry)).colorScheme;
        final material = tester.widget<Material>(
          find.descendant(of: retry, matching: find.byType(Material)).first,
        );
        expect(material.color, scheme.secondaryContainer);

        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        expect(
          tester.getSemantics(retry),
          isSemantics(
            label: '다시 시도',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(retry);
        await tester.pump();
        expect(calls, 1);
        handle.dispose();
      });

      testWidgets('neutral colors and contrast', (tester) async {
        final container = await pumpWithContainer(
          tester,
          mode,
          SampleDataNotice(
            sources: const {SampleSource.trails},
            onRetry: () {},
          ),
        );
        container
            .read(sampleSourcesProvider.notifier)
            .markSample(SampleSource.trails);
        await tester.pump();

        final notice = find.byKey(noticeKey);
        final theme = Theme.of(tester.element(notice));
        final scheme = theme.colorScheme;
        final colors = theme.extension<LookUpColors>()!;

        final background =
            (tester.widget<Container>(notice).decoration! as BoxDecoration)
                .color!;
        expect(background, scheme.surfaceContainerHigh);

        // Collect every color used inside the notice.
        final used = <Color>{background};
        for (final c in tester.widgetList<Container>(
          find.descendant(of: notice, matching: find.byType(Container)),
        )) {
          final deco = c.decoration;
          if (c.color != null) used.add(c.color!);
          if (deco is BoxDecoration && deco.color != null) {
            used.add(deco.color!);
          }
        }
        for (final m in tester.widgetList<Material>(
          find.descendant(of: notice, matching: find.byType(Material)),
        )) {
          if (m.color != null) used.add(m.color!);
        }
        for (final i in tester.widgetList<Icon>(
          find.descendant(of: notice, matching: find.byType(Icon)),
        )) {
          if (i.color != null) used.add(i.color!);
        }
        for (final t in tester.widgetList<Text>(
          find.descendant(of: notice, matching: find.byType(Text)),
        )) {
          if (t.style?.color != null) used.add(t.style!.color!);
        }
        for (final forbidden in [
          scheme.error,
          scheme.errorContainer,
          scheme.onErrorContainer,
          colors.warning,
          colors.warningContainer,
        ]) {
          expect(used, isNot(contains(forbidden)));
        }

        final textColor = tester.widget<Text>(find.text(noticeText)).style!
            .color!;
        expect(textColor, scheme.onSurface);
        expect(
          contrastRatio(textColor, background),
          greaterThanOrEqualTo(4.5),
        );

        final icon = tester.widget<Icon>(
          find.descendant(of: notice, matching: find.byIcon(Icons.info_outline)),
        );
        expect(
          contrastRatio(icon.color!, background),
          greaterThanOrEqualTo(3.0),
        );
      });

      testWidgets('320px: notice with retry and a SampleMark row', (
        tester,
      ) async {
        setNarrowView(tester);
        final container = await pumpWithContainer(
          tester,
          mode,
          Column(
            children: [
              SampleDataNotice(
                sources: const {SampleSource.trails},
                onRetry: () {},
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '아주 긴 예시 둘레길 코스 이름이 들어가는 줄입니다',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    SampleMark(),
                    SizedBox(width: 4),
                    SampleMark(compact: true),
                  ],
                ),
              ),
            ],
          ),
        );
        container
            .read(sampleSourcesProvider.notifier)
            .markSample(SampleSource.trails);
        await tester.pump();

        expect(find.byKey(noticeKey), findsOneWidget);
        expect(find.byKey(retryKey), findsOneWidget);
        expect(find.byType(SampleMark), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
