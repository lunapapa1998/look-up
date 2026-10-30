import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/main.dart' show MyApp;
import 'package:lookup/models/discovery.dart';
import 'package:lookup/screens/auth_gate.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/theme/scene_transition.dart';
import 'package:lookup/widgets/common/mode_toggle.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

final _day = find.byKey(ModeToggle.dayKey);
final _night = find.byKey(ModeToggle.nightKey);
final _auto = find.byKey(ModeToggle.autoKey);

Material _material(WidgetTester tester, Finder control) =>
    tester.widget<Material>(control);

Text _text(WidgetTester tester, Finder control, String label) =>
    tester.widget<Text>(
      find.descendant(of: control, matching: find.text(label)),
    );

Icon _icon(WidgetTester tester, Finder control) => tester.widget<Icon>(
  find.descendant(of: control, matching: find.byType(Icon)),
);

FocusNode _focusOf(WidgetTester tester, Finder control, String label) =>
    Focus.of(
      tester.element(find.descendant(of: control, matching: find.text(label))),
    );

ColorScheme _schemeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ModeToggle))).colorScheme;

LookUpColors _colorsOf(WidgetTester tester) => Theme.of(
  tester.element(find.byType(ModeToggle)),
).extension<LookUpColors>()!;

/// Final user-confirmed day/night accents (spec 054-3a):
/// day = yellow with #141414 text/icon, night = lavender with white
/// text/icon.
const _dayAccent = Color(0xFFF4C247);
const _nightAccent = Color(0xFF9CA3F5);
const _onDayAccent = Color(0xFF141414);
const _onNightAccent = Color(0xFFFFFFFF);

BorderSide _side(WidgetTester tester, Finder control) =>
    (_material(tester, control).shape! as RoundedRectangleBorder).side;

/// The focused control's two ring lines: (outer keyed ring, inner line).
(BorderSide, BorderSide) _ringSides(
  WidgetTester tester,
  Finder control,
  ColorScheme scheme,
) {
  BorderSide topOf(DecoratedBox box) =>
      ((box.decoration as BoxDecoration).border! as Border).top;

  final outer = topOf(
    tester.widget<DecoratedBox>(
      find.descendant(of: control, matching: find.byKey(ModeToggle.focusRingKey)),
    ),
  );
  final innerFinder = find.descendant(
    of: control,
    matching: find.byWidgetPredicate((w) {
      if (w is! DecoratedBox || w.key == ModeToggle.focusRingKey) {
        return false;
      }
      final d = w.decoration;
      if (d is! BoxDecoration || d.border is! Border) return false;
      return (d.border! as Border).top.color == scheme.surface;
    }),
  );
  expect(innerFinder, findsOneWidget);
  final inner = topOf(tester.widget<DecoratedBox>(innerFinder));
  return (outer, inner);
}

/// Records callback calls of a pure [ModeToggle].
class _Calls {
  final modes = <ObsMode>[];
  int autos = 0;
}

Widget _harness(
  ObsMode theme,
  Widget child, {
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.themeFor(theme),
    themeAnimationStyle: AnimationStyle.noAnimation,
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

Widget _pure(
  ObsMode theme, {
  required ObsMode mode,
  required ObsModeSource source,
  _Calls? calls,
  bool reduceMotion = false,
}) {
  return _harness(
    theme,
    ModeToggle(
      mode: mode,
      source: source,
      onModeSelected: (m) => calls?.modes.add(m),
      onAutoSelected: () => calls?.autos++,
    ),
    reduceMotion: reduceMotion,
  );
}

// ---------------------------------------------------------------------------
// App-root harness (mirrors test/scene_transition_test.dart).
// ---------------------------------------------------------------------------

ProviderContainer _containerAt(DateTime now) {
  return ProviderContainer(
    overrides: [
      nowProvider.overrideWithValue(now),
      suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(
          const ObservationLocation(
            lat: 37.5921,
            lng: 126.3984,
            placeName: null,
            isFallback: true,
          ),
        ),
      ),
    ],
  );
}

const Key _curtainKey = Key('scene_curtain');

double _curtain(WidgetTester tester) {
  final finder = find.byKey(_curtainKey);
  if (finder.evaluate().isEmpty) return 0;
  return tester.widget<ColoredBox>(finder).color.a;
}

ObsMode _paintedMode(WidgetTester tester) {
  final scheme = tester
      .widget<MaterialApp>(find.byType(MaterialApp))
      .theme!
      .colorScheme;
  final day = AppTheme.themeFor(ObsMode.day).colorScheme;
  final night = AppTheme.themeFor(ObsMode.night).colorScheme;
  expect(scheme, anyOf(equals(day), equals(night)));
  return scheme == day ? ObsMode.day : ObsMode.night;
}

class _ToggleProbePage extends StatelessWidget {
  const _ToggleProbePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Align(alignment: Alignment.topLeft, child: ObsModeToggle()),
    );
  }
}

/// Pumps the real [MyApp] at 10:00 (day/auto), pushes a page containing
/// [ObsModeToggle] and counts selection-click haptics.
Future<(ProviderContainer, int Function())> _pumpAppWithToggle(
  WidgetTester tester,
) async {
  var haptics = 0;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate' &&
        call.arguments == 'HapticFeedbackType.selectionClick') {
      haptics++;
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

  final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pump();
  Navigator.of(tester.element(find.byType(AuthGate))).push(
    MaterialPageRoute<void>(builder: (_) => const _ToggleProbePage()),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ObsModeToggle), findsOneWidget);
  return (container, () => haptics);
}

void main() {
  for (final theme in ObsMode.values) {
    group('ModeToggle (${theme.name} theme)', () {
      testWidgets('renders icons + labels; taps call the right callbacks', (
        tester,
      ) async {
        final calls = _Calls();
        await tester.pumpWidget(
          _pure(
            theme,
            mode: ObsMode.day,
            source: ObsModeSource.auto,
            calls: calls,
          ),
        );
        expect(find.byIcon(Icons.light_mode), findsOneWidget);
        expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        for (final label in ['낮', '밤', '자동']) {
          expect(find.text(label), findsOneWidget);
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 1);
          expect(text.softWrap, isFalse);
        }

        await tester.tap(_night);
        await tester.pump();
        expect(calls.modes, [ObsMode.night]);
        expect(calls.autos, 0);

        await tester.tap(_day);
        await tester.pump();
        expect(calls.modes, [ObsMode.night, ObsMode.day]);

        await tester.tap(_auto);
        await tester.pump();
        expect(calls.autos, 1);
        expect(calls.modes, hasLength(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('selected segment fill/fg and weights; group outline', (
        tester,
      ) async {
        for (final mode in ObsMode.values) {
          await tester.pumpWidget(
            _pure(theme, mode: mode, source: ObsModeSource.manual),
          );
          final scheme = _schemeOf(tester);
          final labelLarge = Theme.of(
            tester.element(find.byType(ModeToggle)),
          ).textTheme.labelLarge!;

          final dayText = _text(tester, _day, '낮');
          final nightText = _text(tester, _night, '밤');
          expect(dayText.style!.fontSize, labelLarge.fontSize);
          expect(nightText.style!.fontSize, labelLarge.fontSize);
          expect(dayText.style!.fontFamily, labelLarge.fontFamily);

          final selected = mode == ObsMode.day ? _day : _night;
          final unselected = mode == ObsMode.day ? _night : _day;
          final selectedText = mode == ObsMode.day ? dayText : nightText;
          final unselectedText = mode == ObsMode.day ? nightText : dayText;
          final colors = _colorsOf(tester);
          final fill = mode == ObsMode.day
              ? colors.modeDayAccent
              : colors.modeNightAccent;
          final onFill = mode == ObsMode.day
              ? colors.onModeDayAccent
              : colors.onModeNightAccent;
          // Final user colors, identical in both themes.
          expect(
            fill,
            mode == ObsMode.day ? _dayAccent : _nightAccent,
          );
          expect(
            onFill,
            mode == ObsMode.day ? _onDayAccent : _onNightAccent,
          );

          expect(_material(tester, selected).color, fill);
          expect(selectedText.style!.color, onFill);
          expect(selectedText.style!.fontWeight, FontWeight.w700);
          // Selected icon matches the text: day sun #141414, night moon
          // white #FFFFFF (user decision).
          expect(_icon(tester, selected).color, onFill);
          if (mode == ObsMode.night) {
            expect(selectedText.style!.color, const Color(0xFFFFFFFF));
            expect(_icon(tester, selected).color, const Color(0xFFFFFFFF));
          } else {
            expect(selectedText.style!.color, const Color(0xFF141414));
            expect(_icon(tester, selected).color, const Color(0xFF141414));
          }
          // No border on the selected segment (user decision).
          expect(_side(tester, selected), BorderSide.none);

          expect(_material(tester, unselected).color, Colors.transparent);
          expect(_side(tester, unselected), BorderSide.none);
          expect(unselectedText.style!.color, scheme.onSurface);
          expect(unselectedText.style!.fontWeight, FontWeight.w500);
          expect(_icon(tester, unselected).color, scheme.onSurfaceVariant);

          // Flat: no elevation anywhere.
          for (final control in [_day, _night, _auto]) {
            expect(_material(tester, control).elevation, 0);
          }

          final group = tester.widget<Container>(
            find.byKey(ModeToggle.groupKey),
          );
          final border =
              (group.decoration! as BoxDecoration).border! as Border;
          expect(border.top.color, scheme.outline);
          expect(border.top.width, 1);
          // A 1px outline divider between the two segments.
          final divider = find.descendant(
            of: find.byKey(ModeToggle.groupKey),
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == scheme.outline,
            ),
          );
          expect(divider, findsOneWidget);
          expect(tester.getSize(divider).width, 1);
        }
      });

      testWidgets("'자동' is filled when auto, outlined when manual", (
        tester,
      ) async {
        await tester.pumpWidget(
          _pure(theme, mode: ObsMode.day, source: ObsModeSource.auto),
        );
        var scheme = _schemeOf(tester);
        var material = _material(tester, _auto);
        expect(material.color, scheme.onSurface);
        expect(
          (material.shape! as RoundedRectangleBorder).side,
          BorderSide.none,
        );
        var text = _text(tester, _auto, '자동');
        expect(text.style!.color, scheme.surface);
        expect(text.style!.fontWeight, FontWeight.w700);
        expect(_icon(tester, _auto).color, scheme.surface);

        await tester.pumpWidget(
          _pure(theme, mode: ObsMode.day, source: ObsModeSource.manual),
        );
        scheme = _schemeOf(tester);
        material = _material(tester, _auto);
        expect(material.color, Colors.transparent);
        final side = (material.shape! as RoundedRectangleBorder).side;
        expect(side.color, scheme.outline);
        expect(side.width, 1);
        text = _text(tester, _auto, '자동');
        expect(text.style!.color, scheme.onSurface);
        expect(text.style!.fontWeight, FontWeight.w500);
      });

      testWidgets('semantics: segments, auto button and group label', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _pure(theme, mode: ObsMode.day, source: ObsModeSource.auto),
        );
        expect(find.bySemanticsLabel('관찰 모드'), findsOneWidget);
        expect(
          tester.getSemantics(_day),
          isSemantics(
            label: '낮 모드',
            hint: '자동으로 선택됨',
            isButton: true,
            isInMutuallyExclusiveGroup: true,
            hasSelectedState: true,
            isSelected: true,
            isFocusable: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(_night),
          isSemantics(
            label: '밤 모드',
            hint: '눌러서 직접 선택',
            isButton: true,
            isInMutuallyExclusiveGroup: true,
            hasSelectedState: true,
            isSelected: false,
            isFocusable: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(_auto),
          isSemantics(
            label: '자동 모드 켜짐',
            hint: '시간에 따라 낮·밤이 자동으로 바뀝니다',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            isFocusable: true,
            hasTapAction: true,
          ),
        );

        await tester.pumpWidget(
          _pure(theme, mode: ObsMode.night, source: ObsModeSource.manual),
        );
        expect(
          tester.getSemantics(_night),
          isSemantics(
            label: '밤 모드',
            hint: '직접 선택됨',
            isButton: true,
            isInMutuallyExclusiveGroup: true,
            isSelected: true,
          ),
        );
        expect(
          tester.getSemantics(_day),
          isSemantics(
            label: '낮 모드',
            hint: '눌러서 직접 선택',
            isInMutuallyExclusiveGroup: true,
            isSelected: false,
          ),
        );
        expect(
          tester.getSemantics(_auto),
          isSemantics(
            label: '자동 모드로 돌아가기',
            hint: '시간에 따라 낮·밤이 자동으로 바뀝니다',
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
          ),
        );
        handle.dispose();
      });

      testWidgets('keyboard: Tab order, Enter/Space activate, focus ring', (
        tester,
      ) async {
        final calls = _Calls();
        await tester.pumpWidget(
          _pure(
            theme,
            mode: ObsMode.day,
            source: ObsModeSource.manual,
            calls: calls,
          ),
        );
        final scheme = _schemeOf(tester);
        final ring = find.byKey(ModeToggle.focusRingKey);
        expect(ring, findsNothing);

        final dayFocus = _focusOf(tester, _day, '낮');
        final nightFocus = _focusOf(tester, _night, '밤');
        final autoFocus = _focusOf(tester, _auto, '자동');

        dayFocus.requestFocus();
        await tester.pump();
        expect(dayFocus.hasPrimaryFocus, isTrue);
        expect(
          find.descendant(of: _day, matching: ring),
          findsOneWidget,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(nightFocus.hasPrimaryFocus, isTrue);
        expect(ring, findsOneWidget);
        expect(find.descendant(of: _night, matching: ring), findsOneWidget);
        final decoration =
            tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
        final ringBorder = decoration.border! as Border;
        expect(ringBorder.top.width, 2);
        expect(ringBorder.top.color, scheme.onSurface);
        // Inner 2px `surface` line of the two-tone ring.
        final innerLine = find.descendant(
          of: _night,
          matching: find.byWidgetPredicate((w) {
            if (w is! DecoratedBox) return false;
            final d = w.decoration;
            if (d is! BoxDecoration || d.border is! Border) return false;
            final side = (d.border! as Border).top;
            return side.width == 2 && side.color == scheme.surface;
          }),
        );
        expect(innerLine, findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(autoFocus.hasPrimaryFocus, isTrue);
        expect(find.descendant(of: _auto, matching: ring), findsOneWidget);

        nightFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls.modes, [ObsMode.night]);

        autoFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(calls.autos, 1);
        expect(calls.modes, [ObsMode.night]);

        // Focus leaves the toggle: no ring remains.
        autoFocus.unfocus();
        await tester.pump();
        expect(ring, findsNothing);
      });

      testWidgets('each control is at least 44x44', (tester) async {
        for (final source in ObsModeSource.values) {
          await tester.pumpWidget(
            _pure(theme, mode: ObsMode.night, source: source),
          );
          for (final control in [_day, _night, _auto]) {
            final size = tester.getSize(control);
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
        }
      });

      testWidgets('contrast: text >= 4.5, fills and outlines >= 3.0', (
        tester,
      ) async {
        for (final mode in ObsMode.values) {
          for (final source in ObsModeSource.values) {
            await tester.pumpWidget(_pure(theme, mode: mode, source: source));
            final scheme = _schemeOf(tester);
            final surface = scheme.surface;
            final why = '${theme.name} theme, $mode, $source';

            final selected = mode == ObsMode.day ? _day : _night;
            final unselected = mode == ObsMode.day ? _night : _day;
            final selectedLabel = mode == ObsMode.day ? '낮' : '밤';
            final unselectedLabel = mode == ObsMode.day ? '밤' : '낮';

            final fill = _material(tester, selected).color!;
            final selectedFg = _text(
              tester,
              selected,
              selectedLabel,
            ).style!.color!;
            final selectedTextRatio = contrastRatio(selectedFg, fill);
            final selectedIconRatio = contrastRatio(
              _icon(tester, selected).color!,
              fill,
            );
            if (mode == ObsMode.day) {
              // #141414 on day #F4C247 ~= 11.1:1.
              expect(
                selectedTextRatio,
                greaterThanOrEqualTo(11.0),
                reason: 'selected day text vs fill: $why',
              );
              expect(
                selectedIconRatio,
                greaterThanOrEqualTo(11.0),
                reason: 'selected day icon vs fill: $why',
              );
            } else {
              // KNOWN LIMITATION (final user decision, accepted; do NOT
              // "fix" by changing colors or adding a border): the selected
              // '밤' text and moon icon are white #FFFFFF on lavender
              // #9CA3F5, ~2.34:1 — below the 4.5:1 text target and the
              // 3:1 non-text (icon) target.
              expect(
                selectedTextRatio,
                allOf(closeTo(2.34, 0.05), lessThan(4.5)),
                reason: 'selected night text (white) vs fill: $why',
              );
              expect(
                selectedIconRatio,
                allOf(closeTo(2.34, 0.05), lessThan(3.0)),
                reason: 'selected night icon (white) vs fill: $why',
              );
            }

            // KNOWN LIMITATION (recorded, user-accepted; NOT a target):
            // there is no selected border, so on the white day page the
            // fill alone is ~1.66 (day #F4C247) / ~2.34 (night #9CA3F5),
            // below the 3:1 non-text guideline. Selection still reads via
            // w700 and semantics. On the night page (#141414) it is
            // ~11.1 / ~7.9.
            if (theme == ObsMode.day) {
              expect(
                contrastRatio(fill, surface),
                lessThan(3.0),
                reason: 'documented day-page limitation: $why',
              );
            } else {
              expect(
                contrastRatio(fill, surface),
                greaterThanOrEqualTo(3.0),
                reason: 'selected fill vs surface: $why',
              );
            }
            expect(
              contrastRatio(
                _text(tester, unselected, unselectedLabel).style!.color!,
                surface,
              ),
              greaterThanOrEqualTo(4.5),
              reason: 'unselected text vs surface: $why',
            );
            expect(
              contrastRatio(_icon(tester, unselected).color!, surface),
              greaterThanOrEqualTo(3.0),
              reason: 'unselected icon vs surface: $why',
            );
            expect(
              contrastRatio(scheme.outline, surface),
              greaterThanOrEqualTo(3.0),
              reason: 'group outline vs surface: $why',
            );

            final autoMaterial = _material(tester, _auto);
            final autoText = _text(tester, _auto, '자동').style!.color!;
            if (source == ObsModeSource.auto) {
              final autoFill = autoMaterial.color!;
              expect(
                contrastRatio(autoText, autoFill),
                greaterThanOrEqualTo(4.5),
                reason: 'auto active fg vs fill: $why',
              );
              expect(
                contrastRatio(autoFill, surface),
                greaterThanOrEqualTo(3.0),
                reason: 'auto fill vs surface: $why',
              );
            } else {
              final shape = autoMaterial.shape! as RoundedRectangleBorder;
              final side = shape.side;
              expect(
                contrastRatio(side.color, surface),
                greaterThanOrEqualTo(3.0),
                reason: 'auto outline vs surface: $why',
              );
              expect(
                contrastRatio(autoText, surface),
                greaterThanOrEqualTo(4.5),
                reason: 'auto available text vs surface: $why',
              );
            }
          }
        }
      });

      testWidgets('focus ring on the selected segment: 2px + 2px, contrast', (
        tester,
      ) async {
        for (final mode in ObsMode.values) {
          await tester.pumpWidget(
            _pure(theme, mode: mode, source: ObsModeSource.manual),
          );
          final scheme = _schemeOf(tester);
          final surface = scheme.surface;
          final why = '${theme.name} theme, $mode';
          final selected = mode == ObsMode.day ? _day : _night;
          final label = mode == ObsMode.day ? '낮' : '밤';
          final fill = _material(tester, selected).color!;
          expect(_side(tester, selected), BorderSide.none, reason: why);

          _focusOf(tester, selected, label).requestFocus();
          await tester.pump();
          // InkWell.onFocusChange -> setState lands one frame later when
          // focus moves from the previous iteration's segment.
          await tester.pump();
          final (outer, inner) = _ringSides(tester, selected, scheme);
          expect(outer.color, scheme.onSurface, reason: why);
          expect(outer.width, 2, reason: why);
          expect(inner.color, scheme.surface, reason: why);
          expect(inner.width, 2, reason: why);

          // Outer ring vs page: #141414/#FFFFFF (or reverse) ~= 18.4.
          expect(
            contrastRatio(outer.color, surface),
            greaterThanOrEqualTo(3.0),
            reason: 'outer ring vs surface: $why',
          );
          if (theme == ObsMode.night) {
            // Inner #141414 on #F4C247 ~= 11.1, on #9CA3F5 ~= 7.9.
            expect(
              contrastRatio(inner.color, fill),
              greaterThanOrEqualTo(3.0),
              reason: 'inner ring vs fill: $why',
            );
          } else {
            // Outer #141414 ring on #F4C247 ~= 11.1, on #9CA3F5 ~= 7.9.
            expect(
              contrastRatio(outer.color, fill),
              greaterThanOrEqualTo(3.0),
              reason: 'outer ring vs fill: $why',
            );
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
        }
      });

      testWidgets('no colorScheme.secondary/tertiary inside the toggle', (
        tester,
      ) async {
        for (final mode in ObsMode.values) {
          for (final source in ObsModeSource.values) {
            await tester.pumpWidget(_pure(theme, mode: mode, source: source));
            final scheme = _schemeOf(tester);
            final colors = _colorsOf(tester);
            final selected = mode == ObsMode.day ? _day : _night;
            final label = mode == ObsMode.day ? '낮' : '밤';
            _focusOf(tester, selected, label).requestFocus();
            await tester.pump();

            // Colors the toggle legitimately uses; skip a forbidden color
            // only if it coincides with one of them.
            final allowed = <Color>{
              scheme.surface,
              scheme.onSurface,
              scheme.onSurfaceVariant,
              scheme.outline,
              Colors.transparent,
              colors.modeDayAccent,
              colors.onModeDayAccent,
              colors.modeNightAccent,
              colors.onModeNightAccent,
            };
            final forbidden = <Color>{
              scheme.secondary,
              scheme.onSecondary,
              scheme.tertiary,
              scheme.onTertiary,
            }.difference(allowed);

            final used = <Color>[];
            final root = find.byType(ModeToggle);
            for (final m in tester.widgetList<Material>(
              find.descendant(of: root, matching: find.byType(Material)),
            )) {
              if (m.color != null) used.add(m.color!);
              final shape = m.shape;
              if (shape is RoundedRectangleBorder) used.add(shape.side.color);
            }
            for (final t in tester.widgetList<Text>(
              find.descendant(of: root, matching: find.byType(Text)),
            )) {
              if (t.style?.color != null) used.add(t.style!.color!);
            }
            for (final i in tester.widgetList<Icon>(
              find.descendant(of: root, matching: find.byType(Icon)),
            )) {
              if (i.color != null) used.add(i.color!);
            }
            for (final b in tester.widgetList<ColoredBox>(
              find.descendant(of: root, matching: find.byType(ColoredBox)),
            )) {
              used.add(b.color);
            }
            for (final d in tester.widgetList<DecoratedBox>(
              find.descendant(of: root, matching: find.byType(DecoratedBox)),
            )) {
              final deco = d.decoration;
              if (deco is BoxDecoration) {
                if (deco.color != null) used.add(deco.color!);
                final b = deco.border;
                if (b is Border) used.add(b.top.color);
              }
            }
            expect(used, isNotEmpty);
            for (final c in used) {
              expect(
                forbidden.contains(c),
                isFalse,
                reason: '${theme.name} theme, $mode, $source uses $c',
              );
            }
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pump();
          }
        }
      });

      testWidgets('320px: no exception, whole toggle fits within 288', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final mode in ObsMode.values) {
          for (final source in ObsModeSource.values) {
            await tester.pumpWidget(_pure(theme, mode: mode, source: source));
            expect(tester.takeException(), isNull);
            final width = tester.getSize(find.byType(ModeToggle)).width;
            expect(width, lessThanOrEqualTo(288));
            expect(width, lessThanOrEqualTo(320));
          }
        }
      });

      testWidgets('reduce motion: switches in a single pump, no animations', (
        tester,
      ) async {
        var mode = ObsMode.day;
        var source = ObsModeSource.auto;
        await tester.pumpWidget(
          _harness(
            theme,
            StatefulBuilder(
              builder: (context, setState) => ModeToggle(
                mode: mode,
                source: source,
                onModeSelected: (m) => setState(() {
                  mode = m;
                  source = ObsModeSource.manual;
                }),
                onAutoSelected: () => setState(() {
                  mode = ObsMode.day;
                  source = ObsModeSource.auto;
                }),
              ),
            ),
            reduceMotion: true,
          ),
        );
        final scheme = _schemeOf(tester);
        final colors = _colorsOf(tester);

        await tester.tap(_night);
        await tester.pump();
        expect(_material(tester, _night).color, colors.modeNightAccent);
        expect(_material(tester, _day).color, Colors.transparent);
        expect(_material(tester, _auto).color, Colors.transparent);

        await tester.tap(_auto);
        await tester.pump();
        expect(_material(tester, _day).color, colors.modeDayAccent);
        expect(_material(tester, _auto).color, scheme.onSurface);

        // Pure prop change (no ink feedback involved): nothing animates.
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _pure(
            theme,
            mode: ObsMode.night,
            source: ObsModeSource.manual,
            reduceMotion: true,
          ),
        );
        expect(tester.hasRunningAnimations, isFalse);
        expect(_material(tester, _night).color, colors.modeNightAccent);
        expect(_material(tester, _auto).color, Colors.transparent);
      });
    });
  }

  test('LookUpColors.day and .night carry identical mode accents', () {
    const day = LookUpColors.day;
    const night = LookUpColors.night;
    expect(day.modeDayAccent, _dayAccent);
    expect(day.modeNightAccent, _nightAccent);
    expect(day.onModeDayAccent, _onDayAccent);
    expect(day.onModeNightAccent, _onNightAccent);
    expect(night.modeDayAccent, day.modeDayAccent);
    expect(night.onModeDayAccent, day.onModeDayAccent);
    expect(night.modeNightAccent, day.modeNightAccent);
    expect(night.onModeNightAccent, day.onModeNightAccent);
    // Identical endpoints: the scene lerp never shifts these.
    final mid = day.lerp(night, 0.5);
    expect(mid.modeDayAccent, _dayAccent);
    expect(mid.modeNightAccent, _nightAccent);
  });

  group('ObsModeToggle adapter', () {
    Future<ProviderContainer> pumpAdapter(
      WidgetTester tester,
      DateTime now,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [nowProvider.overrideWithValue(now)],
          child: MaterialApp(
            theme: AppTheme.themeFor(ObsMode.day),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ObsModeToggle(),
              ),
            ),
          ),
        ),
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(ObsModeToggle)),
      );
    }

    for (final hour in const [10, 22]) {
      testWidgets('hour $hour: segment -> manual, 자동 -> modeForHour', (
        tester,
      ) async {
        final now = DateTime(2026, 9, 9, hour, 0);
        final container = await pumpAdapter(tester, now);
        final hourMode = modeForHour(now.hour);
        final other = hourMode == ObsMode.day ? ObsMode.night : ObsMode.day;

        var state = container.read(obsModeProvider);
        expect(state.mode, hourMode);
        expect(state.source, ObsModeSource.auto);
        var toggle = tester.widget<ModeToggle>(find.byType(ModeToggle));
        expect(toggle.mode, hourMode);
        expect(toggle.source, ObsModeSource.auto);

        await tester.tap(other == ObsMode.night ? _night : _day);
        await tester.pump();
        state = container.read(obsModeProvider);
        expect(state.mode, other);
        expect(state.source, ObsModeSource.manual);
        toggle = tester.widget<ModeToggle>(find.byType(ModeToggle));
        expect(toggle.mode, other);
        expect(toggle.source, ObsModeSource.manual);

        await tester.tap(_auto);
        await tester.pump();
        state = container.read(obsModeProvider);
        expect(state.mode, modeForHour(now.hour));
        expect(state.source, ObsModeSource.auto);
        toggle = tester.widget<ModeToggle>(find.byType(ModeToggle));
        expect(toggle.mode, hourMode);
        expect(toggle.source, ObsModeSource.auto);
      });
    }

    testWidgets('tap 밤 sets night/manual', (tester) async {
      final container = await pumpAdapter(
        tester,
        DateTime(2026, 9, 9, 10, 0),
      );
      await tester.tap(_night);
      await tester.pump();
      final state = container.read(obsModeProvider);
      expect(state.mode, ObsMode.night);
      expect(state.source, ObsModeSource.manual);
    });
  });

  group('ObsModeToggle under MyApp (spec 060 root transition)', () {
    testWidgets('tap 밤: fade-through runs, night theme, exactly one haptic', (
      tester,
    ) async {
      final (container, haptics) = await _pumpAppWithToggle(tester);
      expect(_paintedMode(tester), ObsMode.day);

      await tester.tap(_night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_curtain(tester), greaterThan(0));
      expect(_paintedMode(tester), ObsMode.day);

      await tester.pumpAndSettle();
      expect(_curtain(tester), 0);
      expect(find.byKey(_curtainKey), findsNothing);
      expect(_paintedMode(tester), ObsMode.night);
      final state = container.read(obsModeProvider);
      expect(state.mode, ObsMode.night);
      expect(state.source, ObsModeSource.manual);
      expect(haptics(), 1);

      // Same mode again (already manual night): no haptic, no curtain.
      await tester.tap(_night);
      await tester.pump();
      expect(find.byKey(_curtainKey), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_curtainKey), findsNothing);
      await tester.pumpAndSettle();
      expect(haptics(), 1);
      expect(_paintedMode(tester), ObsMode.night);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap on 낮 is blocked while curtain >= 0.5, works after', (
      tester,
    ) async {
      final (container, haptics) = await _pumpAppWithToggle(tester);

      await tester.tap(_night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));

      await tester.tap(_day, warnIfMissed: false);
      await tester.pump();
      expect(container.read(obsModeProvider).mode, ObsMode.night);
      expect(container.read(obsModeProvider).source, ObsModeSource.manual);

      await tester.pumpAndSettle();
      expect(_paintedMode(tester), ObsMode.night);
      expect(haptics(), 1);

      await tester.tap(_day);
      await tester.pump();
      expect(container.read(obsModeProvider).mode, ObsMode.day);
      expect(container.read(obsModeProvider).source, ObsModeSource.manual);
      await tester.pumpAndSettle();
      expect(_paintedMode(tester), ObsMode.day);
      expect(haptics(), 2);
    });

    testWidgets('자동: same mode -> no transition; different -> transition, '
        'no haptic', (tester) async {
      final (container, haptics) = await _pumpAppWithToggle(tester);

      // 10:00 auto day -> manual day: same mode, the root ignores it.
      await tester.tap(_day);
      await tester.pump();
      expect(container.read(obsModeProvider).source, ObsModeSource.manual);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_curtainKey), findsNothing);
      expect(haptics(), 0);

      // 자동 resolves to day (= current): still nothing.
      await tester.tap(_auto);
      await tester.pump();
      var state = container.read(obsModeProvider);
      expect(state.mode, modeForHour(10));
      expect(state.source, ObsModeSource.auto);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_curtainKey), findsNothing);
      await tester.pumpAndSettle();
      expect(haptics(), 0);
      expect(_paintedMode(tester), ObsMode.day);

      // Manual night (one haptic), then 자동 back to day: auto-sourced
      // transition runs, without a haptic.
      await tester.tap(_night);
      await tester.pumpAndSettle();
      expect(_paintedMode(tester), ObsMode.night);
      expect(haptics(), 1);

      await tester.tap(_auto);
      await tester.pump();
      state = container.read(obsModeProvider);
      expect(state.mode, ObsMode.day);
      expect(state.source, ObsModeSource.auto);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_curtain(tester), greaterThan(0));
      expect(_paintedMode(tester), ObsMode.night);
      await tester.pumpAndSettle();
      expect(_paintedMode(tester), ObsMode.day);
      expect(_curtain(tester), 0);
      expect(haptics(), 1);
    });
  });
}
