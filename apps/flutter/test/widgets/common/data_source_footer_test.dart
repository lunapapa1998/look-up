import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/common/data_source_footer.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Spec 054-2b: DataSourceFooter dedupe, toggle, keyboard, links, 320px.
void main() {
  final kmaUrl = Uri.parse('https://www.weather.go.kr/');
  final otherUrl = Uri.parse('https://example.com/other');
  final ebirdUrl = Uri.parse('https://ebird.org/');

  Widget harness(
    ObsMode mode,
    Widget child, {
    double width = 360,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    );
  }

  void setNarrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final toggle = find.byKey(DataSourceFooter.toggleKey);

  test('DataSource equality covers name, url and attribution', () {
    expect(
      DataSource(name: 'a', url: kmaUrl, attribution: 'x'),
      DataSource(name: 'a', url: kmaUrl, attribution: 'x'),
    );
    expect(
      DataSource(name: 'a', url: kmaUrl, attribution: 'x').hashCode,
      DataSource(name: 'a', url: kmaUrl, attribution: 'x').hashCode,
    );
    expect(
      const DataSource(name: 'a'),
      isNot(DataSource(name: 'a', url: kmaUrl)),
    );
    expect(
      const DataSource(name: 'a'),
      isNot(const DataSource(name: 'a', attribution: 'x')),
    );
    expect(const DataSource(name: 'a'), isNot(const DataSource(name: 'b')));
  });

  test('dedupeDataSources: trim/collapse/lowercase, first wins, no blanks', () {
    final result = dedupeDataSources([
      DataSource(name: 'eBird', url: ebirdUrl),
      const DataSource(name: '   '),
      const DataSource(name: ''),
      const DataSource(name: ' EBIRD '),
      const DataSource(name: '한국  천문 연구원'),
      const DataSource(name: '한국 천문 연구원'),
    ]);
    expect(result, [
      DataSource(name: 'eBird', url: ebirdUrl),
      const DataSource(name: '한국  천문 연구원'),
    ]);
  });

  for (final mode in ObsMode.values) {
    group('DataSourceFooter (${mode.name})', () {
      testWidgets('empty or blank-only list renders nothing', (tester) async {
        for (final sources in const <List<DataSource>>[
          [],
          [DataSource(name: ''), DataSource(name: '   ')],
        ]) {
          await tester.pumpWidget(
            harness(mode, DataSourceFooter(sources: sources)),
          );
          expect(find.byKey(DataSourceFooter.rootKey), findsNothing);
          expect(toggle, findsNothing);
          expect(find.text('데이터 출처'), findsNothing);
          expect(tester.getSize(find.byType(DataSourceFooter)).height, 0);
        }
      });

      testWidgets('dedupe: count 2, first occurrence keeps its url', (
        tester,
      ) async {
        final opened = <DataSource>[];
        final first = DataSource(name: '기상청', url: kmaUrl);
        await tester.pumpWidget(
          harness(
            mode,
            DataSourceFooter(
              sources: [
                first,
                DataSource(name: ' 기상청 ', url: otherUrl),
                const DataSource(name: 'eBird'),
              ],
              onOpenSource: opened.add,
            ),
          ),
        );
        expect(find.text('· 2'), findsOneWidget);
        expect(find.text('기상청 · eBird'), findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('기상청'), findsOneWidget);
        await tester.tap(find.text('기상청'));
        await tester.pump();
        expect(opened, [first]);
        expect(opened.single.url, kmaUrl);
      });

      testWidgets('collapsed by default; toggle expands and collapses', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            mode,
            const DataSourceFooter(
              sources: [
                DataSource(name: '한국관광공사'),
                DataSource(name: '기상청'),
                DataSource(name: 'eBird'),
              ],
            ),
          ),
        );
        expect(find.byKey(DataSourceFooter.rootKey), findsOneWidget);
        expect(find.text('데이터 출처'), findsOneWidget);
        expect(find.text('· 3'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        final preview = find.text('한국관광공사 · 기상청 · eBird');
        expect(preview, findsOneWidget);
        final previewText = tester.widget<Text>(preview);
        expect(previewText.maxLines, 1);
        expect(previewText.overflow, TextOverflow.ellipsis);
        expect(find.text('기상청'), findsNothing);
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(preview, findsNothing);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        for (final name in ['한국관광공사', '기상청', 'eBird']) {
          expect(find.text(name), findsOneWidget);
        }

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(preview, findsOneWidget);
        expect(find.text('기상청'), findsNothing);

        // New key -> fresh State, so initiallyExpanded is read again
        // (it is only read on State creation).
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            mode,
            const DataSourceFooter(
              key: ValueKey('initially_expanded'),
              sources: [DataSource(name: '기상청')],
              initiallyExpanded: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(
          tester.getSemantics(toggle),
          isSemantics(hasExpandedState: true, isExpanded: true),
        );
        handle.dispose();
      });

      testWidgets('expanded state survives a parent rebuild', (tester) async {
        const sources = [DataSource(name: '기상청'), DataSource(name: 'eBird')];
        await tester.pumpWidget(
          harness(mode, const DataSourceFooter(sources: sources)),
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          harness(mode, const DataSourceFooter(sources: sources), width: 340),
        );
        await tester.pumpAndSettle();
        expect(find.text('기상청'), findsOneWidget);
      });

      testWidgets('keyboard Enter/Space toggle; header semantics', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            mode,
            const DataSourceFooter(
              sources: [DataSource(name: '기상청'), DataSource(name: 'eBird')],
            ),
          ),
        );
        expect(
          tester.getSemantics(toggle),
          isSemantics(
            label: '데이터 출처 2개',
            hint: '펼치기',
            isButton: true,
            hasExpandedState: true,
            isExpanded: false,
            isFocusable: true,
            hasTapAction: true,
          ),
        );

        final node = Focus.of(
          tester.element(
            find.descendant(of: toggle, matching: find.text('데이터 출처')),
          ),
        );
        node.requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('기상청'), findsOneWidget);
        expect(
          tester.getSemantics(toggle),
          isSemantics(
            label: '데이터 출처 2개',
            hint: '접기',
            isButton: true,
            hasExpandedState: true,
            isExpanded: true,
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('기상청'), findsNothing);
        expect(find.text('기상청 · eBird'), findsOneWidget);
        expect(node.hasPrimaryFocus, isTrue);
        handle.dispose();
      });

      testWidgets('link only with url + callback; others are plain text', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final opened = <DataSource>[];
        final kma = DataSource(name: '기상청', url: kmaUrl);
        await tester.pumpWidget(
          harness(
            mode,
            DataSourceFooter(
              initiallyExpanded: true,
              onOpenSource: opened.add,
              sources: [kma, const DataSource(name: '한국천문연구원')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Link: underline, open_in_new icon, link semantics, >= 44 tall.
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
        expect(tester.widget<Icon>(find.byIcon(Icons.open_in_new)).size, 14);
        final linkText = tester.widget<Text>(find.text('기상청'));
        expect(linkText.style!.decoration, TextDecoration.underline);
        expect(
          tester.getSemantics(find.text('기상청')),
          isSemantics(isLink: true, hasTapAction: true, isFocusable: true),
        );
        final linkInk = find.ancestor(
          of: find.text('기상청'),
          matching: find.byType(InkWell),
        );
        expect(linkInk, findsOneWidget);
        expect(tester.getSize(linkInk).height, greaterThanOrEqualTo(44));
        await tester.tap(find.text('기상청'));
        await tester.pump();
        expect(opened, [kma]);

        // No url: plain text, not focusable, no icon, not a link.
        final plain = tester.widget<Text>(find.text('한국천문연구원'));
        expect(plain.style!.decoration, isNot(TextDecoration.underline));
        expect(
          find.ancestor(
            of: find.text('한국천문연구원'),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.text('한국천문연구원')),
          isSemantics(isLink: false),
        );
        await tester.tap(find.text('한국천문연구원'));
        await tester.pump();
        expect(opened, [kma]);

        // Url but no callback: also plain.
        await tester.pumpWidget(
          harness(
            mode,
            DataSourceFooter(initiallyExpanded: true, sources: [kma]),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.open_in_new), findsNothing);
        expect(
          find.ancestor(of: find.text('기상청'), matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.text('기상청')),
          isSemantics(isLink: false),
        );
        handle.dispose();
      });

      testWidgets('attribution is its own line; no default license text', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            mode,
            const DataSourceFooter(
              initiallyExpanded: true,
              sources: [
                DataSource(name: 'eBird', attribution: 'eBird 데이터 이용 고지'),
                DataSource(name: '기상청'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('eBird'), findsOneWidget);
        expect(find.text('eBird 데이터 이용 고지'), findsOneWidget);
        expect(
          tester.getRect(find.text('eBird 데이터 이용 고지')).top,
          greaterThanOrEqualTo(tester.getRect(find.text('eBird')).bottom),
        );
        // Only one attribution line exists (기상청 has none).
        expect(find.textContaining('고지'), findsOneWidget);

        await tester.pumpWidget(
          harness(
            mode,
            const DataSourceFooter(
              initiallyExpanded: true,
              sources: [DataSource(name: '기상청'), DataSource(name: 'eBird')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final word in ['공공누리', 'CC', '라이선스', '고지']) {
          expect(find.textContaining(word), findsNothing, reason: word);
        }
        // Collapsed too.
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        for (final word in ['공공누리', 'CC', '라이선스']) {
          expect(find.textContaining(word), findsNothing, reason: word);
        }
      });

      testWidgets('contrast of every footer text vs surface >= 4.5', (
        tester,
      ) async {
        final surface = AppTheme.themeFor(mode).colorScheme.surface;
        Future<void> checkAll() async {
          final texts = tester.widgetList<Text>(
            find.descendant(
              of: find.byType(DataSourceFooter),
              matching: find.byType(Text),
            ),
          );
          expect(texts, isNotEmpty);
          for (final text in texts) {
            expect(
              contrastRatio(text.style!.color!, surface),
              greaterThanOrEqualTo(4.5),
              reason: text.data,
            );
          }
        }

        final widget = DataSourceFooter(
          onOpenSource: (_) {},
          sources: [
            DataSource(name: '기상청', url: kmaUrl),
            const DataSource(name: 'eBird', attribution: 'eBird 데이터 이용 고지'),
          ],
        );
        await tester.pumpWidget(harness(mode, widget));
        await checkAll();
        // Preview text style is bodySmall of the ambient theme.
        final bodySmall = Theme.of(
          tester.element(find.byType(DataSourceFooter)),
        ).textTheme.bodySmall!;
        expect(
          tester.widget<Text>(find.text('기상청 · eBird')).style!.fontSize,
          bodySmall.fontSize,
        );

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await checkAll();
        expect(
          tester.widget<Text>(find.text('eBird 데이터 이용 고지')).style!.fontSize,
          bodySmall.fontSize,
        );
      });

      testWidgets('320px with a 60-char name: collapsed and expanded', (
        tester,
      ) async {
        setNarrowView(tester);
        final longName = '긴출처이름' * 12;
        expect(longName.length, 60);
        const spaced =
            '국립해양조사원 해양 관측 부이 실시간 자료와 조석 예보 정보를 함께 제공하는 아주 긴 기관 이름';
        final widget = DataSourceFooter(
          onOpenSource: (_) {},
          sources: [
            DataSource(name: longName, url: kmaUrl),
            DataSource(name: longName.substring(1)),
            const DataSource(name: spaced, attribution: spaced),
          ],
        );
        await tester.pumpWidget(harness(mode, widget, width: 320));
        expect(tester.takeException(), isNull);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(longName), findsOneWidget);
        expect(
          tester.getSize(find.byKey(DataSourceFooter.rootKey)).width,
          320,
        );
      });

      testWidgets('reduce motion: toggle completes in one pump', (
        tester,
      ) async {
        const widget = DataSourceFooter(
          sources: [DataSource(name: '기상청'), DataSource(name: 'eBird')],
        );
        await tester.pumpWidget(harness(mode, widget, reduceMotion: true));
        expect(find.byType(AnimatedSize), findsNothing);

        await tester.tap(toggle);
        await tester.pump();
        expect(find.text('기상청'), findsOneWidget);
        expect(find.byType(AnimatedSize), findsNothing);
        final height = tester.getSize(find.byKey(DataSourceFooter.rootKey));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(DataSourceFooter.rootKey)), height);

        await tester.tap(toggle);
        await tester.pump();
        expect(find.text('기상청'), findsNothing);
        expect(find.text('기상청 · eBird'), findsOneWidget);

        // Animations allowed: expansion goes through AnimatedSize.
        await tester.pumpWidget(harness(mode, widget));
        expect(find.byType(AnimatedSize), findsOneWidget);
      });
    });
  }
}
