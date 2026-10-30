import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/app_header_logo.dart';
import 'package:lookup/widgets/common/lookup_header.dart';
import 'package:lookup/widgets/common/mode_toggle.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _widths = <double>[320, 375, 480, 600, 1024];
const _scales = <double>[1.0, 1.3, 2.0];
const _viewHeight = 800.0;

final _header = find.byType(LookUpHeader, skipOffstage: false);
final _toggle = find.byType(ModeToggle);
final _title = find.byKey(LookUpHeader.titleKey);
final _logo = find.byType(AppHeaderLogo);
final _leading = find.byKey(LookUpHeader.leadingKey);
final _action = find.byIcon(Icons.search);

Widget _pureToggle() => ModeToggle(
  mode: ObsMode.day,
  source: ObsModeSource.auto,
  onModeSelected: (_) {},
  onAutoSelected: () {},
);

Widget _searchAction() => IconButton(
  tooltip: '검색',
  icon: const Icon(Icons.search),
  onPressed: () {},
);

Widget _app(ObsMode theme, Widget body, {double textScale = 1.0}) {
  return MaterialApp(
    theme: AppTheme.themeFor(theme),
    themeAnimationStyle: AnimationStyle.noAnimation,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: body),
      ),
    ),
  );
}

Widget _boxHeader(
  ObsMode theme, {
  bool withToggle = true,
  bool withAction = true,
  double textScale = 1.0,
  String title = '위를 봐요',
}) {
  return _app(
    theme,
    Align(
      alignment: Alignment.topCenter,
      child: LookUpHeader(
        title: title,
        modeToggle: withToggle ? _pureToggle() : null,
        actions: withAction ? [_searchAction()] : const [],
      ),
    ),
    textScale: textScale,
  );
}

Widget _sliverHeader(ObsMode theme, {double textScale = 1.0}) {
  return _app(
    theme,
    CustomScrollView(
      slivers: [
        LookUpSliverHeader(
          modeToggle: _pureToggle(),
          actions: [_searchAction()],
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => SizedBox(height: 56, child: Text('item $i')),
            childCount: 60,
          ),
        ),
      ],
    ),
    textScale: textScale,
  );
}

void _setView(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, _viewHeight);
  tester.view.devicePixelRatio = 1;
}

void _resetViewOnTearDown(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// True when the toggle sits on its own row below the title.
bool _isTwoRows(WidgetTester tester) =>
    tester.getRect(_toggle).top >= tester.getRect(_title).bottom - 0.01;

List<SemanticsNode> _allNodes(SemanticsNode root) {
  final out = <SemanticsNode>[root];
  root.visitChildren((child) {
    out.addAll(_allNodes(child));
    return true;
  });
  return out;
}

FocusNode _focusOfText(WidgetTester tester, String label) =>
    Focus.of(tester.element(find.text(label)));

/// Drags [target] vertically by [dy] (after a 20px slop move) and settles.
Future<void> _drag(WidgetTester tester, Finder target, double dy) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(Offset(0, dy.sign * 20));
  await gesture.moveBy(Offset(0, dy));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in ObsMode.values) {
    group('LookUpHeader (${theme.name} theme)', () {
      testWidgets('width x text scale x toggle x action: no overflow, '
          'fits the view, toggle fully visible', (tester) async {
        _resetViewOnTearDown(tester);
        for (final width in _widths) {
          _setView(tester, width);
          for (final scale in _scales) {
            for (final withToggle in [true, false]) {
              for (final withAction in [true, false]) {
                final why =
                    'w=$width scale=$scale toggle=$withToggle action=$withAction';
                await tester.pumpWidget(
                  _boxHeader(
                    theme,
                    withToggle: withToggle,
                    withAction: withAction,
                    textScale: scale,
                  ),
                );
                expect(tester.takeException(), isNull, reason: why);
                final header = tester.getRect(_header);
                expect(header.width, lessThanOrEqualTo(width), reason: why);
                expect(header.left, greaterThanOrEqualTo(0), reason: why);
                expect(header.right, lessThanOrEqualTo(width), reason: why);
                expect(
                  header.bottom,
                  lessThanOrEqualTo(_viewHeight),
                  reason: why,
                );
                expect(
                  header.height,
                  greaterThanOrEqualTo(LookUpHeader.toolbarHeight),
                  reason: why,
                );

                // Leading and actions never leave the header.
                final leading = tester.getRect(_leading);
                expect(leading.left, greaterThanOrEqualTo(0), reason: why);
                expect(
                  leading.bottom,
                  lessThanOrEqualTo(header.bottom + 0.01),
                  reason: why,
                );
                if (withAction) {
                  final action = tester.getRect(find.byType(IconButton));
                  expect(
                    action.right,
                    lessThanOrEqualTo(header.right + 0.01),
                    reason: why,
                  );
                  expect(
                    leading.right,
                    lessThanOrEqualTo(action.left + 0.01),
                    reason: why,
                  );
                }

                if (withToggle) {
                  final toggle = tester.getRect(_toggle);
                  expect(toggle.left, greaterThanOrEqualTo(-0.01), reason: why);
                  expect(
                    toggle.right,
                    lessThanOrEqualTo(width + 0.01),
                    reason: why,
                  );
                  expect(
                    toggle.top,
                    greaterThanOrEqualTo(header.top - 0.01),
                    reason: why,
                  );
                  expect(
                    toggle.bottom,
                    lessThanOrEqualTo(header.bottom + 0.01),
                    reason: why,
                  );
                  // No overlap with the leading block.
                  expect(
                    toggle.overlaps(leading.deflate(0.01)),
                    isFalse,
                    reason: why,
                  );
                  if (withAction) {
                    final action = tester.getRect(find.byType(IconButton));
                    expect(
                      toggle.overlaps(action.deflate(0.01)),
                      isFalse,
                      reason: why,
                    );
                  }
                } else {
                  expect(_toggle, findsNothing, reason: why);
                }
              }
            }
          }
        }
      });

      testWidgets('row mode: two rows at 320/375, one row at 600/1024', (
        tester,
      ) async {
        _resetViewOnTearDown(tester);
        for (final width in const [320.0, 375.0]) {
          for (final scale in _scales) {
            _setView(tester, width);
            await tester.pumpWidget(_boxHeader(theme, textScale: scale));
            expect(tester.takeException(), isNull);
            expect(
              _isTwoRows(tester),
              isTrue,
              reason: 'w=$width scale=$scale',
            );
            // Row 2 = toggle + AppSpacing.sm bottom padding; left-aligned.
            final header = tester.getRect(_header);
            final toggle = tester.getRect(_toggle);
            expect(
              header.bottom - toggle.bottom,
              moreOrLessEquals(8, epsilon: 0.01),
            );
            expect(
              toggle.left,
              moreOrLessEquals(LookUpHeader.horizontalPadding, epsilon: 0.01),
            );
          }
        }

        for (final width in const [600.0, 1024.0]) {
          _setView(tester, width);
          await tester.pumpWidget(_boxHeader(theme));
          expect(tester.takeException(), isNull);
          expect(_isTwoRows(tester), isFalse, reason: 'w=$width');
          // Vertically aligned with the title row (logo centre).
          expect(
            tester.getCenter(_toggle).dy,
            moreOrLessEquals(tester.getCenter(_logo).dy, epsilon: 0.5),
          );
          expect(
            tester.getCenter(_action).dy,
            moreOrLessEquals(tester.getCenter(_logo).dy, epsilon: 0.5),
          );
          // Right-aligned group: [toggle][actions] at the trailing edge.
          final action = tester.getRect(find.byType(IconButton));
          expect(
            action.right,
            moreOrLessEquals(
              width - LookUpHeader.horizontalPadding,
              epsilon: 0.01,
            ),
          );
          expect(tester.getRect(_toggle).right, lessThan(action.left));
          expect(
            tester.getSize(_header).height,
            LookUpHeader.toolbarHeight,
          );
        }
      });

      testWidgets('480 and 600@2.0: whichever the measurement yields, '
          'consistent and without overflow', (tester) async {
        _resetViewOnTearDown(tester);
        for (final (width, scale) in const [
          (480.0, 1.0),
          (480.0, 1.3),
          (480.0, 2.0),
          (600.0, 2.0),
        ]) {
          _setView(tester, width);
          await tester.pumpWidget(_boxHeader(theme, textScale: scale));
          expect(tester.takeException(), isNull);
          final why = 'w=$width scale=$scale';
          final header = tester.getRect(_header);
          final toggle = tester.getRect(_toggle);
          if (_isTwoRows(tester)) {
            expect(
              toggle.left,
              moreOrLessEquals(LookUpHeader.horizontalPadding, epsilon: 0.01),
              reason: why,
            );
            expect(
              header.bottom - toggle.bottom,
              moreOrLessEquals(8, epsilon: 0.01),
              reason: why,
            );
          } else {
            expect(
              tester.getCenter(_toggle).dy,
              moreOrLessEquals(tester.getCenter(_logo).dy, epsilon: 0.5),
              reason: why,
            );
            expect(
              toggle.left,
              greaterThan(tester.getRect(_logo).right),
              reason: why,
            );
          }
          expect(toggle.bottom, lessThanOrEqualTo(header.bottom), reason: why);
          expect(toggle.right, lessThanOrEqualTo(width), reason: why);
        }
      });

      testWidgets('without toggle: a single row at every width and scale', (
        tester,
      ) async {
        _resetViewOnTearDown(tester);
        for (final width in _widths) {
          _setView(tester, width);
          for (final scale in _scales) {
            await tester.pumpWidget(
              _boxHeader(theme, withToggle: false, textScale: scale),
            );
            expect(tester.takeException(), isNull);
            final why = 'w=$width scale=$scale';
            final leadingHeight = tester.getSize(_leading).height;
            expect(
              tester.getSize(_header).height,
              moreOrLessEquals(
                math.max(LookUpHeader.toolbarHeight, leadingHeight),
                epsilon: 0.01,
              ),
              reason: why,
            );
            expect(
              tester.getCenter(_action).dy,
              moreOrLessEquals(tester.getCenter(_logo).dy, epsilon: 0.5),
              reason: why,
            );
          }
        }
      });

      testWidgets('long title ellipsizes without exceptions', (tester) async {
        _resetViewOnTearDown(tester);
        final long = '아주 긴 제목 ' * 10 + '끝까지 보이지 않음';
        expect(long.length, greaterThanOrEqualTo(40));
        for (final width in const [320.0, 1024.0]) {
          _setView(tester, width);
          for (final withToggle in [true, false]) {
            await tester.pumpWidget(
              _boxHeader(theme, title: long, withToggle: withToggle),
            );
            expect(tester.takeException(), isNull);
            final text = tester.widget<Text>(_title);
            expect(text.overflow, TextOverflow.ellipsis);
            expect(text.maxLines, 1);
            final paragraph = tester.renderObject<RenderParagraph>(_title);
            expect(paragraph.didExceedMaxLines, isTrue);
            expect(
              tester.getRect(_title).right,
              lessThanOrEqualTo(tester.getRect(_action).left),
            );
          }
        }
      });

      testWidgets('semantics: header title, logo/subtitle excluded, '
          'toggle and action labels present', (tester) async {
        final handle = tester.ensureSemantics();
        _resetViewOnTearDown(tester);
        for (final width in const [320.0, 1024.0]) {
          _setView(tester, width);
          await tester.pumpWidget(_boxHeader(theme));

          final titleNode = find.bySemanticsLabel('위를 봐요');
          expect(titleNode, findsOneWidget);
          expect(
            tester.getSemantics(titleNode),
            isSemantics(label: '위를 봐요', isHeader: true),
          );
          expect(find.bySemanticsLabel('위를 봐요 로고'), findsNothing);
          expect(find.bySemanticsLabel(RegExp('LOOK UP')), findsNothing);
          expect(find.bySemanticsLabel('낮 모드'), findsOneWidget);
          expect(find.bySemanticsLabel('밤 모드'), findsOneWidget);
          expect(find.bySemanticsLabel('자동 모드 켜짐'), findsOneWidget);

          final nodes = _allNodes(tester.getSemantics(_header));
          expect(
            nodes.any((n) => n.label.contains('LOOK UP')),
            isFalse,
          );
          expect(
            nodes.any((n) => n.label.contains('로고')),
            isFalse,
          );
          expect(
            nodes.any(
              (n) => n.label.contains('검색') || n.tooltip.contains('검색'),
            ),
            isTrue,
          );
        }
        handle.dispose();
      });

      testWidgets('keyboard: Tab order follows the visual order', (
        tester,
      ) async {
        _resetViewOnTearDown(tester);

        // One row: toggle (낮, 밤, 자동) then the action.
        _setView(tester, 1024);
        await tester.pumpWidget(_boxHeader(theme));
        expect(_isTwoRows(tester), isFalse);
        var day = _focusOfText(tester, '낮');
        var night = _focusOfText(tester, '밤');
        var auto = _focusOfText(tester, '자동');
        var action = Focus.of(tester.element(_action));
        day.requestFocus();
        await tester.pump();
        expect(day.hasPrimaryFocus, isTrue);
        for (final next in [night, auto, action]) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(next.hasPrimaryFocus, isTrue);
        }

        // Two rows: the action (row 1) then the toggle (row 2).
        _setView(tester, 320);
        await tester.pumpWidget(_boxHeader(theme));
        await tester.pump();
        expect(_isTwoRows(tester), isTrue);
        day = _focusOfText(tester, '낮');
        night = _focusOfText(tester, '밤');
        auto = _focusOfText(tester, '자동');
        action = Focus.of(tester.element(_action));
        action.requestFocus();
        await tester.pump();
        expect(action.hasPrimaryFocus, isTrue);
        for (final next in [day, night, auto]) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(next.hasPrimaryFocus, isTrue);
        }
      });

      testWidgets('touch targets stay at least 44px', (tester) async {
        _resetViewOnTearDown(tester);
        for (final width in const [320.0, 1024.0]) {
          _setView(tester, width);
          await tester.pumpWidget(_boxHeader(theme));
          for (final key in [
            ModeToggle.dayKey,
            ModeToggle.nightKey,
            ModeToggle.autoKey,
          ]) {
            final size = tester.getSize(find.byKey(key));
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
          final action = tester.getSize(find.byType(IconButton));
          expect(action.width, greaterThanOrEqualTo(44));
          expect(action.height, greaterThanOrEqualTo(44));
        }
      });

      testWidgets('contrast: title and subtitle vs background >= 4.5', (
        tester,
      ) async {
        await tester.pumpWidget(_boxHeader(theme));
        final background = tester
            .widget<Material>(find.byKey(LookUpHeader.backgroundKey))
            .color!;
        final context = tester.element(_header);
        final themeData = Theme.of(context);
        expect(
          background,
          themeData.appBarTheme.backgroundColor ??
              themeData.colorScheme.surface,
        );
        final titleColor = tester
            .renderObject<RenderParagraph>(_title)
            .text
            .style!
            .color!;
        final subtitleColor = tester
            .renderObject<RenderParagraph>(
              find.byKey(LookUpHeader.subtitleKey),
            )
            .text
            .style!
            .color!;
        expect(subtitleColor, themeData.colorScheme.secondary);
        expect(
          contrastRatio(titleColor, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(subtitleColor, background),
          greaterThanOrEqualTo(4.5),
        );
        // Flat: no elevation / shadow.
        final material = tester.widget<Material>(
          find.byKey(LookUpHeader.backgroundKey),
        );
        expect(material.elevation, 0);
      });

      testWidgets('sliver: visible at full height, hidden after scrolling '
          'down 400', (
        tester,
      ) async {
        _resetViewOnTearDown(tester);
        for (final width in const [320.0, 1024.0]) {
          _setView(tester, width);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(_sliverHeader(theme));
          expect(tester.takeException(), isNull);
          final why = 'w=$width';

          // Initially visible at the top; whole two-row height laid out.
          final initial = tester.getRect(_header);
          expect(initial.top, moreOrLessEquals(0, epsilon: 0.01), reason: why);
          final fullHeight = initial.height;
          expect(
            tester.getRect(_toggle).bottom,
            lessThanOrEqualTo(initial.bottom + 0.01),
            reason: why,
          );
          expect(
            tester.getRect(find.text('item 0')).top,
            greaterThanOrEqualTo(initial.bottom - 0.01),
            reason: why,
          );
          if (width == 320) {
            expect(_isTwoRows(tester), isTrue, reason: why);
            expect(fullHeight, greaterThan(LookUpHeader.toolbarHeight));
          }

          // Scroll down 400: hidden.
          await _drag(tester, find.byType(CustomScrollView), -400);
          expect(
            tester.getRect(_header).bottom,
            lessThanOrEqualTo(0.5),
            reason: why,
          );
          expect(_header.hitTestable(), findsNothing, reason: why);
          expect(tester.takeException(), isNull, reason: why);
        }
      });

      testWidgets('sliver: scroll-up 50 floats it back, release snaps it '
          'fully visible', (
        tester,
      ) async {
        _resetViewOnTearDown(tester);
        for (final width in const [320.0, 1024.0]) {
          _setView(tester, width);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(_sliverHeader(theme));
          final fullHeight = tester.getSize(_header).height;
          final why = 'w=$width';

          await _drag(tester, find.byType(CustomScrollView), -400);
          expect(tester.getRect(_header).bottom, lessThanOrEqualTo(0.5));

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(CustomScrollView)),
          );
          await gesture.moveBy(const Offset(0, 20));
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump();
          final partial = tester.getRect(_header);
          expect(partial.bottom, greaterThan(0), reason: why);
          expect(partial.top, lessThan(0), reason: why);

          await gesture.up();
          await tester.pumpAndSettle();
          final settled = tester.getRect(_header);
          expect(settled.top, moreOrLessEquals(0, epsilon: 0.5), reason: why);
          expect(
            settled.height,
            moreOrLessEquals(fullHeight, epsilon: 0.01),
            reason: why,
          );
          expect(
            tester.getRect(_toggle).bottom,
            lessThanOrEqualTo(settled.bottom + 0.01),
            reason: why,
          );
          expect(tester.takeException(), isNull, reason: why);
        }
      });

      testWidgets('box and sliver share the same background color', (
        tester,
      ) async {
        await tester.pumpWidget(_boxHeader(theme));
        final boxColor = tester
            .widget<Material>(find.byKey(LookUpHeader.backgroundKey))
            .color;
        await tester.pumpWidget(_sliverHeader(theme));
        final sliverColor = tester
            .widget<Material>(find.byKey(LookUpHeader.backgroundKey))
            .color;
        expect(boxColor, isNotNull);
        expect(sliverColor, boxColor);
        expect(
          boxColor,
          AppTheme.themeFor(theme).appBarTheme.backgroundColor ??
              AppTheme.themeFor(theme).colorScheme.surface,
        );
      });
    });
  }
}
