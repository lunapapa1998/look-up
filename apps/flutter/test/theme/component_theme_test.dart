import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/scene_transition.dart';

/// Spec 054-1 widget checks for the theme-level chip / navigation bar
/// styles at the narrowest supported width (320 logical px).
void main() {
  const choiceLabels = <String>['전체', '조류', '별', '노포', '탐방로', '거리순'];
  const filterLabel = 'SQM 21.5 이상 · 빛공해 적음';

  Widget harness(ObsMode mode) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in choiceLabels)
                ChoiceChip(
                  key: Key('choice_$label'),
                  label: Text(label),
                  selected: label == '전체',
                  onSelected: (_) {},
                ),
              // Mirrors the real multi-select call sites, which opt into the
              // checkmark (the theme default is showCheckmark: false).
              FilterChip(
                key: const Key('filter_sqm'),
                showCheckmark: true,
                label: const Text(filterLabel),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                key: const Key('filter_off'),
                showCheckmark: true,
                label: const Text('조류'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.map), label: '관찰 지도'),
            NavigationDestination(icon: Icon(Icons.radar), label: '발견'),
            NavigationDestination(icon: Icon(Icons.route), label: '낮-밤 패키지'),
          ],
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

  Color? chipFill(WidgetTester tester, Key key) {
    final ink = tester.widget<Ink>(
      find.descendant(of: find.byKey(key), matching: find.byType(Ink)).first,
    );
    return (ink.decoration! as ShapeDecoration).color;
  }

  Color? labelColor(WidgetTester tester, Key chipKey, String text) {
    final style = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byKey(chipKey),
                  matching: find.text(text),
                ),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    return style.color;
  }

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  Widget selectedChipsHarness(ThemeData theme) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Wrap(
          children: [
            ChoiceChip(
              key: const Key('rest_choice'),
              label: const Text('전체'),
              selected: true,
              onSelected: (_) {},
            ),
            ChoiceChip(
              key: const Key('rest_choice_off'),
              label: const Text('전체'),
              selected: false,
              onSelected: (_) {},
            ),
            FilterChip(
              key: const Key('rest_filter_on'),
              showCheckmark: true,
              label: const Text('위성'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              key: const Key('rest_filter_off'),
              showCheckmark: true,
              label: const Text('위성'),
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  for (final mode in [ObsMode.day, ObsMode.night]) {
    group('$mode', () {
      testWidgets(
        'at-rest app theme (sceneTheme t=1) keeps selected chip labels on '
        'surface',
        (WidgetTester tester) async {
          // Mirrors main.dart's at-rest path: two separately built themes for
          // the same mode, combined via sceneTheme at t == 1.
          final theme = sceneTheme(
            AppTheme.themeFor(mode),
            AppTheme.themeFor(mode),
            1.0,
          );
          final scheme = theme.colorScheme;
          await tester.pumpWidget(selectedChipsHarness(theme));
          await tester.pumpAndSettle();

          for (final entry in {
            const Key('rest_choice'): '전체',
            const Key('rest_filter_on'): '위성',
          }.entries) {
            final color = labelColor(tester, entry.key, entry.value);
            expect(color, scheme.surface, reason: '${entry.key}');
            expect(color, isNot(scheme.onSurface), reason: '${entry.key}');
            expect(chipFill(tester, entry.key), scheme.onSurface);
            expect(
              contrast(color!, scheme.onSurface),
              greaterThanOrEqualTo(4.5),
            );
          }
        },
      );

      testWidgets(
        'selected FilterChip (showCheckmark: true) shows a surface checkmark; '
        'selected ChoiceChip shows none',
        (WidgetTester tester) async {
          final theme = AppTheme.themeFor(mode);
          final scheme = theme.colorScheme;
          await tester.pumpWidget(selectedChipsHarness(theme));
          await tester.pumpAndSettle();

          // Theme default stays "no checkmark" (the ChoiceChip behavior).
          final context = tester.element(
            find.byKey(const Key('rest_choice')),
          );
          final chipTheme = ChipTheme.of(context);
          expect(chipTheme.showCheckmark, isFalse);

          // The checkmark lives in the avatar drawer, which only opens when
          // selected: the selected FilterChip is wider than the identical
          // unselected one by roughly the checkmark width.
          final filterOn = tester
              .getSize(find.byKey(const Key('rest_filter_on')))
              .width;
          final filterOff = tester
              .getSize(find.byKey(const Key('rest_filter_off')))
              .width;
          expect(filterOn - filterOff, greaterThan(8));

          // ChoiceChip: no avatar drawer opens on selection, so selected and
          // unselected chips with the same label have the same width.
          final choiceOn = tester
              .getSize(find.byKey(const Key('rest_choice')))
              .width;
          final choiceOff = tester
              .getSize(find.byKey(const Key('rest_choice_off')))
              .width;
          expect(choiceOn, closeTo(choiceOff, 1.0));
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(const Key('rest_choice')))
                .showCheckmark,
            isNull,
          );

          // Checkmark color: FilterChip does not override it, so it resolves
          // to the theme's `surface`, readable on the `onSurface` fill.
          expect(
            tester
                .widget<FilterChip>(find.byKey(const Key('rest_filter_on')))
                .checkmarkColor,
            isNull,
          );
          expect(chipTheme.checkmarkColor, scheme.surface);
          final fill = chipFill(tester, const Key('rest_filter_on'));
          expect(fill, scheme.onSurface);
          expect(
            contrast(chipTheme.checkmarkColor!, fill!),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      testWidgets('renders chips + nav bar at 320px without exceptions', (
        WidgetTester tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(harness(mode));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ChoiceChip), findsNWidgets(choiceLabels.length));
        expect(find.byType(FilterChip), findsNWidgets(2));
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        // The selected SQM FilterChip carries its checkmark and still fits
        // the 320px row (320 - 2 * 16 padding).
        expect(
          tester.widget<FilterChip>(find.byKey(const Key('filter_sqm')))
              .showCheckmark,
          isTrue,
        );
        expect(
          tester.getSize(find.byKey(const Key('filter_sqm'))).width,
          lessThanOrEqualTo(288),
        );
      });

      testWidgets('selected chips render inverted, unselected transparent', (
        WidgetTester tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(harness(mode));
        await tester.pumpAndSettle();
        final scheme = AppTheme.themeFor(mode).colorScheme;

        // Selected ChoiceChip: inverted fill + surface label, w600.
        expect(chipFill(tester, const Key('choice_전체')), scheme.onSurface);
        expect(
          labelColor(tester, const Key('choice_전체'), '전체'),
          scheme.surface,
        );
        final selectedText = tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('전체'),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            )
            .style;
        expect(selectedText.fontWeight, FontWeight.w600);

        // Unselected ChoiceChip: transparent fill + onSurface label.
        expect(
          chipFill(tester, const Key('choice_조류')),
          Colors.transparent,
        );
        expect(
          labelColor(tester, const Key('choice_조류'), '조류'),
          scheme.onSurface,
        );

        // Selected FilterChip: inverted fill + surface label.
        expect(chipFill(tester, const Key('filter_sqm')), scheme.onSurface);
        expect(
          labelColor(tester, const Key('filter_sqm'), filterLabel),
          scheme.surface,
        );
        expect(
          chipFill(tester, const Key('filter_off')),
          Colors.transparent,
        );
      });

      testWidgets('Tab moves keyboard focus onto a chip', (
        WidgetTester tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(harness(mode));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        final focus = FocusManager.instance.primaryFocus;
        expect(focus, isNotNull);
        final context = focus!.context;
        expect(context, isNotNull);
        final inChip =
            context!.findAncestorWidgetOfExactType<ChoiceChip>() != null ||
            context.findAncestorWidgetOfExactType<FilterChip>() != null;
        expect(inChip, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('chip and nav destination hit areas are >= 44x44', (
        WidgetTester tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(harness(mode));
        await tester.pumpAndSettle();

        final chips = find.byWidgetPredicate(
          (w) => w is ChoiceChip || w is FilterChip,
        );
        expect(chips, findsNWidgets(choiceLabels.length + 2));
        for (final element in chips.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(44), reason: '$size');
          expect(size.height, greaterThanOrEqualTo(44), reason: '$size');
        }

        final destinations = find.byType(NavigationDestination);
        for (final element in destinations.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(44), reason: '$size');
          expect(size.height, greaterThanOrEqualTo(44), reason: '$size');
        }
      });
    });
  }
}
