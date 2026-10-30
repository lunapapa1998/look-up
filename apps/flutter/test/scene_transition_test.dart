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
import 'package:lookup/theme/scene_transition.dart';

/// [MyApp] renders [AppShell] -> [HomeDiscoveryScreen], which reads
/// [suitabilityApiProvider]/[locationServiceProvider]; overridden to fakes so
/// these tests don't make real HTTP/geolocation calls (mirrors the pattern
/// in `mode_header_test.dart`'s full-screen pump).
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

/// Pumps [MyApp] against a real [ProviderContainer] via
/// [UncontrolledProviderScope], optionally with an explicit [MediaQuery]
/// ancestor so `disableAnimations`/`accessibleNavigation` can be forced
/// (mirrors the pattern already used for provider containers in
/// `mode_header_test.dart`/`home_discovery_screen_test.dart`).
Widget _harness(ProviderContainer container, {MediaQueryData? mediaQuery}) {
  final app = UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  );
  if (mediaQuery == null) return app;
  return MediaQuery(data: mediaQuery, child: app);
}

MaterialApp _materialApp(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

/// Selected-state chip label color, resolved like RawChip does.
Color? _selectedChipLabel(ThemeData theme) {
  return WidgetStateProperty.resolveAs<Color?>(
    theme.chipTheme.labelStyle!.color,
    <WidgetState>{WidgetState.selected},
  );
}

const Key _curtainKey = Key('scene_curtain');

/// Current curtain opacity (0 when the curtain widget is absent).
double _curtain(WidgetTester tester) {
  final finder = find.byKey(_curtainKey);
  if (finder.evaluate().isEmpty) return 0;
  return tester.widget<ColoredBox>(finder).color.a;
}

/// Reference color schemes, built inside a testWidgets body (themeFor
/// touches GoogleFonts/AssetManifest, which needs the test binding).
class _Schemes {
  _Schemes()
    : day = AppTheme.themeFor(ObsMode.day).colorScheme,
      night = AppTheme.themeFor(ObsMode.night).colorScheme;

  final ColorScheme day;
  final ColorScheme night;
}

/// Asserts the painted theme is a pure day or night theme — both the
/// `MaterialApp.theme` value and what `Theme.of` resolves below it (no
/// AnimatedTheme lerp) — and returns which one.
ObsMode _painted(WidgetTester tester, _Schemes s) {
  final theme = _materialApp(tester).theme!;
  expect(
    theme.colorScheme,
    anyOf(equals(s.day), equals(s.night)),
    reason: 'MaterialApp.theme must be exactly the day or night theme',
  );
  expect(theme.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
  final inherited = Theme.of(
    tester.element(find.byType(Navigator).first),
  ).colorScheme;
  expect(
    inherited,
    theme.colorScheme,
    reason: 'Theme.of below MaterialApp must not be animated/lerped',
  );
  return theme.colorScheme == s.day ? ObsMode.day : ObsMode.night;
}

/// Exact-theme assertion without caring which mode.
void _expectPureTheme(WidgetTester tester, _Schemes s) {
  _painted(tester, s);
}

class _Frame {
  _Frame(this.mode, this.curtain);

  final ObsMode mode;
  final double curtain;
}

/// Pumps [total] in [step] increments, recording the painted mode and the
/// curtain opacity of every frame (each frame also asserts a pure theme).
Future<List<_Frame>> _sample(
  WidgetTester tester,
  _Schemes s,
  Duration total, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  final frames = <_Frame>[];
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
    frames.add(_Frame(_painted(tester, s), _curtain(tester)));
  }
  return frames;
}

/// Every frame where the painted mode differs from the previous frame must
/// show a fully opaque curtain (the swap happens only under full cover).
void _expectSwapsUnderFullCurtain(ObsMode start, List<_Frame> frames) {
  var previous = start;
  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    if (frame.mode != previous) {
      expect(
        frame.curtain,
        1.0,
        reason: 'frame $i swapped to ${frame.mode} with curtain '
            '${frame.curtain}',
      );
    }
    previous = frame.mode;
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Test-only page pushed on the real root Navigator to observe state
/// preservation, input blocking and semantics across a transition.
class _ProbePage extends StatefulWidget {
  const _ProbePage();

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  final ScrollController scroll = ScrollController();
  final FocusNode buttonFocus = FocusNode(debugLabel: 'probe_button');
  bool chipSelected = true;
  int presses = 0;

  @override
  void dispose() {
    scroll.dispose();
    buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChip(
            key: const Key('probe_filter'),
            showCheckmark: true,
            label: const Text('probe filter'),
            selected: chipSelected,
            onSelected: (value) => setState(() => chipSelected = value),
          ),
          FilledButton(
            key: const Key('probe_button'),
            focusNode: buttonFocus,
            onPressed: () => presses++,
            child: const Text('probe button'),
          ),
          TextButton(
            key: const Key('probe_open_sheet'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(
                height: 200,
                child: Center(child: Text('probe sheet')),
              ),
            ),
            child: const Text('open sheet'),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushes [_ProbePage] on the app's root Navigator.
Future<_ProbePageState> _pushProbe(WidgetTester tester) async {
  final navigator = Navigator.of(tester.element(find.byType(AuthGate)));
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const _ProbePage()),
  );
  await tester.pumpAndSettle();
  return tester.state<_ProbePageState>(find.byType(_ProbePage));
}

/// Pumps the real app at 10:00 (day/auto) and returns its container.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  MediaQueryData? mediaQuery,
}) async {
  final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
  addTearDown(container.dispose);
  await tester.pumpWidget(_harness(container, mediaQuery: mediaQuery));
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'mode change converges on the target theme after pumpAndSettle',
    (tester) async {
      final container = await _pumpApp(tester);

      // At rest on first build the state-dependent chip label survives.
      final initial = _materialApp(tester).theme!;
      expect(initial.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(initial), initial.colorScheme.surface);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      final target = AppTheme.themeFor(ObsMode.night);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
      expect(theme.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(theme), target.colorScheme.surface);
      expect(_curtain(tester), 0);
      expect(find.byKey(_curtainKey), findsNothing);

      // And back to day (night-to-day glare curve path).
      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pumpAndSettle();

      final dayTarget = AppTheme.themeFor(ObsMode.day);
      final dayTheme = _materialApp(tester).theme!;
      expect(dayTheme.colorScheme, dayTarget.colorScheme);
      expect(dayTheme.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(dayTheme), dayTarget.colorScheme.surface);
      expect(_curtain(tester), 0);
      expect(find.byKey(_curtainKey), findsNothing);

      // Themes are cached per mode: the same instance comes back.
      expect(identical(dayTheme, initial), isTrue);
    },
  );

  testWidgets(
    'day->night: old theme until the curtain is fully closed, target after',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), 0);

      // Manual to night = 560ms: rise 280ms, fall 280ms.
      final rising = await _sample(
        tester,
        s,
        const Duration(milliseconds: 260),
        step: const Duration(milliseconds: 20),
      );
      expect(rising.every((f) => f.mode == ObsMode.day), isTrue);
      for (var i = 1; i < rising.length; i++) {
        expect(rising[i].curtain, greaterThanOrEqualTo(rising[i - 1].curtain));
      }

      await tester.pump(const Duration(milliseconds: 10)); // 270ms
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), greaterThan(0.5));

      await tester.pump(const Duration(milliseconds: 20)); // 290ms
      expect(_painted(tester, s), ObsMode.night);
      expect(_curtain(tester), 1.0);

      final falling = await _sample(
        tester,
        s,
        const Duration(milliseconds: 300),
        step: const Duration(milliseconds: 20),
      );
      expect(falling.every((f) => f.mode == ObsMode.night), isTrue);
      expect(falling.last.curtain, 0);
      expect(find.byKey(_curtainKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'night->day: old theme until the curtain is fully closed, target after',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pump();
      expect(_painted(tester, s), ObsMode.night);

      // Manual to day = 640ms: rise 320ms, fall 320ms.
      final rising = await _sample(
        tester,
        s,
        const Duration(milliseconds: 300),
        step: const Duration(milliseconds: 20),
      );
      expect(rising.every((f) => f.mode == ObsMode.night), isTrue);

      await tester.pump(const Duration(milliseconds: 10)); // 310ms
      expect(_painted(tester, s), ObsMode.night);
      expect(_curtain(tester), greaterThan(0.5));

      await tester.pump(const Duration(milliseconds: 20)); // 330ms
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), 1.0);

      final falling = await _sample(
        tester,
        s,
        const Duration(milliseconds: 340),
        step: const Duration(milliseconds: 20),
      );
      expect(falling.every((f) => f.mode == ObsMode.day), isTrue);
      expect(falling.last.curtain, 0);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'auto-sourced and manual-sourced mode changes use different durations',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);

      // Move away from the initial (day/auto) state so resetToAuto below is
      // an observable auto-sourced mode change back to day.
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      // Auto night -> day = 800ms: rise 400ms, fall 400ms.
      container.read(obsModeProvider.notifier).resetToAuto();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 390));
      expect(_painted(tester, s), ObsMode.night);
      expect(_curtain(tester), greaterThan(0.5));

      await tester.pump(const Duration(milliseconds: 20)); // 410ms
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), 1.0);

      await tester.pump(const Duration(milliseconds: 200)); // 610ms
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), greaterThan(0));
      expect(_curtain(tester), lessThan(1));

      await tester.pump(const Duration(milliseconds: 400)); // 1010ms
      expect(_curtain(tester), 0);
      await tester.pumpAndSettle();

      // Manual day -> night = 560ms: swapped by 290ms, done by 580ms.
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 290));
      expect(_painted(tester, s), ObsMode.night);

      await tester.pump(const Duration(milliseconds: 290)); // 580ms
      expect(_painted(tester, s), ObsMode.night);
      expect(_curtain(tester), 0);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'reduced motion (disableAnimations) day-to-night swaps in one frame',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(
        tester,
        mediaQuery: const MediaQueryData(disableAnimations: true),
      );

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();

      expect(_painted(tester, s), ObsMode.night);
      expect(find.byKey(_curtainKey), findsNothing);
      final target = AppTheme.themeFor(ObsMode.night);
      expect(
        _materialApp(tester).theme!.scaffoldBackgroundColor,
        target.scaffoldBackgroundColor,
      );
    },
  );

  testWidgets(
    'reduced motion detected via platform accessibility features without an '
    'explicit MediaQuery ancestor swaps in one frame',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final s = _Schemes();
      final container = await _pumpApp(tester);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();

      expect(_painted(tester, s), ObsMode.night);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'reduced motion (disableAnimations) night-to-day swaps in one frame',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(
        tester,
        mediaQuery: const MediaQueryData(disableAnimations: true),
      );

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      expect(_painted(tester, s), ObsMode.night);

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pump();
      expect(_painted(tester, s), ObsMode.day);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'accessible navigation swaps in one frame without a curtain',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(
        tester,
        mediaQuery: const MediaQueryData(accessibleNavigation: true),
      );

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();

      expect(_painted(tester, s), ObsMode.night);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'retoggle during the rise lowers the curtain without ever swapping',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painted(tester, s), ObsMode.day);
      expect(_curtain(tester), greaterThan(0));
      expect(_curtain(tester), lessThan(kCurtainBlockThreshold));

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      final frames = await _sample(
        tester,
        s,
        const Duration(milliseconds: 1000),
      );
      expect(frames.every((f) => f.mode == ObsMode.day), isTrue);
      expect(frames.last.curtain, 0);

      await tester.pumpAndSettle();
      expect(_painted(tester, s), ObsMode.day);
      expect(find.byKey(_curtainKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retoggle during the fall raises the curtain again and swaps only under '
    'full cover',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // swap frame
      expect(_painted(tester, s), ObsMode.night);
      await tester.pump(const Duration(milliseconds: 100)); // falling
      expect(_painted(tester, s), ObsMode.night);
      final falling = _curtain(tester);
      expect(falling, greaterThan(0));
      expect(falling, lessThan(1));

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      final frames = await _sample(
        tester,
        s,
        const Duration(milliseconds: 1000),
      );
      _expectSwapsUnderFullCurtain(ObsMode.night, frames);
      expect(frames.any((f) => f.mode == ObsMode.day), isTrue);
      expect(frames.last.mode, ObsMode.day);
      expect(frames.last.curtain, 0);

      await tester.pumpAndSettle();
      expect(_painted(tester, s), ObsMode.day);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'five rapid changes converge on the last one with pure themes throughout',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);
      final notifier = container.read(obsModeProvider.notifier);

      final frames = <_Frame>[];
      for (final mode in const [
        ObsMode.night,
        ObsMode.day,
        ObsMode.night,
        ObsMode.day,
        ObsMode.night,
      ]) {
        notifier.setManual(mode);
        frames.addAll(
          await _sample(
            tester,
            s,
            const Duration(milliseconds: 50),
            step: const Duration(milliseconds: 25),
          ),
        );
      }
      frames.addAll(
        await _sample(tester, s, const Duration(milliseconds: 1500)),
      );

      _expectSwapsUnderFullCurtain(ObsMode.day, frames);
      expect(frames.last.mode, ObsMode.night);
      expect(frames.last.curtain, 0);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_painted(tester, s), ObsMode.night);
      expect(find.byKey(_curtainKey), findsNothing);
    },
  );

  testWidgets(
    'one haptic per accepted manual change, none for auto or reselect',
    (tester) async {
      var haptics = 0;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick') {
          haptics++;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final container = await _pumpApp(tester);
      final notifier = container.read(obsModeProvider.notifier);

      notifier.setManual(ObsMode.night);
      await tester.pumpAndSettle();
      notifier.setManual(ObsMode.day);
      await tester.pumpAndSettle();
      notifier.setManual(ObsMode.night);
      await tester.pumpAndSettle();
      expect(haptics, 3);

      // Auto-sourced change back to day: no haptic.
      notifier.resetToAuto();
      await tester.pumpAndSettle();
      expect(haptics, 3);

      // Reselecting the current mode is ignored: no haptic.
      notifier.setManual(ObsMode.day);
      await tester.pumpAndSettle();
      expect(haptics, 3);
    },
  );

  testWidgets(
    'scroll offset, chip selection, open sheet and State survive the '
    'transition',
    (tester) async {
      final s = _Schemes();
      final container = await _pumpApp(tester);
      final probe = await _pushProbe(tester);

      probe.scroll.jumpTo(900);
      await tester.pump();
      await tester.tap(find.byKey(const Key('probe_open_sheet')));
      await tester.pumpAndSettle();
      expect(find.text('probe sheet'), findsOneWidget);

      void expectPreserved() {
        final state = tester.state<_ProbePageState>(
          find.byType(_ProbePage, skipOffstage: false),
        );
        expect(identical(state, probe), isTrue);
        expect(state.scroll.offset, 900);
        expect(state.chipSelected, isTrue);
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const Key('probe_filter'), skipOffstage: false),
              )
              .selected,
          isTrue,
        );
        expect(find.text('probe sheet'), findsOneWidget);
      }

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        _expectPureTheme(tester, s);
        expectPreserved();
      }
      await tester.pumpAndSettle();
      expect(_painted(tester, s), ObsMode.night);
      expectPreserved();
    },
  );

  testWidgets(
    'selected FilterChip keeps label/checkmark contrast in every phase',
    (tester) async {
      final container = await _pumpApp(tester);
      await _pushProbe(tester);

      void expectChipContrast(String phase) {
        final theme = _materialApp(tester).theme!;
        const selected = <WidgetState>{WidgetState.selected};
        final label = _selectedChipLabel(theme)!;
        final fill = theme.chipTheme.color!.resolve(selected)!;
        final checkmark = theme.chipTheme.checkmarkColor!;
        expect(
          _contrast(label, fill),
          greaterThanOrEqualTo(4.5),
          reason: '$phase label',
        );
        expect(
          _contrast(checkmark, fill),
          greaterThanOrEqualTo(3.0),
          reason: '$phase checkmark',
        );
      }

      expectChipContrast('start');
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 270));
      expectChipContrast('270ms');
      await tester.pump(const Duration(milliseconds: 20));
      expectChipContrast('290ms');
      await tester.pumpAndSettle();
      expectChipContrast('settled');
    },
  );

  testWidgets(
    'keyboard activation/traversal is blocked under the curtain and recovers '
    'without replay or focus loss',
    (tester) async {
      final container = await _pumpApp(tester);
      final probe = await _pushProbe(tester);

      probe.buttonFocus.requestFocus();
      await tester.pump();
      expect(probe.buttonFocus.hasPrimaryFocus, isTrue);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));

      for (final key in const [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.arrowDown,
      ]) {
        expect(await tester.sendKeyEvent(key), isTrue, reason: '$key');
      }
      expect(probe.presses, 0);
      expect(probe.buttonFocus.hasPrimaryFocus, isTrue);

      // Swap, then fall below the block threshold: input works again even
      // though the curtain is still partly visible.
      await tester.pump(const Duration(milliseconds: 100)); // swap
      expect(probe.buttonFocus.hasPrimaryFocus, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      final curtain = _curtain(tester);
      expect(curtain, greaterThan(0));
      expect(curtain, lessThan(kCurtainBlockThreshold));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(probe.presses, 1);

      await tester.pumpAndSettle();
      expect(_curtain(tester), 0);
      expect(probe.buttonFocus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      // Exactly two presses: nothing pressed while blocked was replayed.
      expect(probe.presses, 2);
    },
  );

  testWidgets('Escape under the curtain does not close an open sheet', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    await _pushProbe(tester);
    await tester.tap(find.byKey(const Key('probe_open_sheet')));
    await tester.pumpAndSettle();
    expect(find.text('probe sheet'), findsOneWidget);

    container.read(obsModeProvider.notifier).setManual(ObsMode.night);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue);

    await tester.pumpAndSettle();
    expect(_curtain(tester), 0);
    expect(find.text('probe sheet'), findsOneWidget);

    // Positive control: with no curtain, Escape dismisses the sheet.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('probe sheet'), findsNothing);
  });

  testWidgets(
    'pointer reaches content below the threshold and is dropped above it',
    (tester) async {
      final container = await _pumpApp(tester);
      final probe = await _pushProbe(tester);
      final button = find.byKey(const Key('probe_button'));

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));
      await tester.tap(button, warnIfMissed: false);
      expect(probe.presses, 0);
      await tester.pumpAndSettle();
      expect(probe.presses, 0);

      // Early in the next rise the curtain is still mostly transparent.
      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final curtain = _curtain(tester);
      expect(curtain, greaterThan(0));
      expect(curtain, lessThan(kCurtainBlockThreshold));
      await tester.tap(button);
      expect(probe.presses, 1);
      await tester.pumpAndSettle();
      expect(probe.presses, 1);
    },
  );

  testWidgets('mode changes while input is blocked still converge', (
    tester,
  ) async {
    final s = _Schemes();
    final container = await _pumpApp(tester);
    final notifier = container.read(obsModeProvider.notifier);

    notifier.setManual(ObsMode.night);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));
    notifier.setManual(ObsMode.day);
    await tester.pumpAndSettle();
    expect(_painted(tester, s), ObsMode.day);
    expect(_curtain(tester), 0);

    // Same through resetToAuto (10:00 -> day).
    notifier.setManual(ObsMode.night);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));
    notifier.resetToAuto();
    await tester.pumpAndSettle();
    expect(_painted(tester, s), ObsMode.day);
    expect(_curtain(tester), 0);
  });

  testWidgets(
    'curtain is excluded from semantics; content semantics stay in place',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = await _pumpApp(tester);
      await _pushProbe(tester);
      expect(find.bySemanticsLabel('probe button'), findsWidgets);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 270));
      expect(_curtain(tester), greaterThan(0.9));
      expect(find.bySemanticsLabel('probe button'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byKey(_curtainKey),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 20)); // swapped
      expect(find.bySemanticsLabel('probe button'), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('probe button'), findsWidgets);
      handle.dispose();
    },
  );

  testWidgets(
    'semantics tap under the curtain is not blocked (spec 060 4-3 rule 2)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = await _pumpApp(tester);
      final probe = await _pushProbe(tester);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_curtain(tester), greaterThanOrEqualTo(kCurtainBlockThreshold));

      tester.semantics.tap(find.semantics.byLabel('probe button'));
      expect(probe.presses, 1);

      await tester.pumpAndSettle();
      expect(_curtain(tester), 0);
      handle.dispose();
    },
  );

  testWidgets('no exceptions at 320px through both directions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final s = _Schemes();
    final container = await _pumpApp(tester);

    container.read(obsModeProvider.notifier).setManual(ObsMode.night);
    await tester.pump();
    final toNight = await _sample(
      tester,
      s,
      const Duration(milliseconds: 600),
      step: const Duration(milliseconds: 50),
    );
    _expectSwapsUnderFullCurtain(ObsMode.day, toNight);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    container.read(obsModeProvider.notifier).setManual(ObsMode.day);
    await tester.pump();
    final toDay = await _sample(
      tester,
      s,
      const Duration(milliseconds: 700),
      step: const Duration(milliseconds: 50),
    );
    _expectSwapsUnderFullCurtain(ObsMode.night, toDay);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_painted(tester, s), ObsMode.day);
  });

  testWidgets('disposing the app mid-transition throws nothing', (
    tester,
  ) async {
    final container = await _pumpApp(tester);

    container.read(obsModeProvider.notifier).setManual(ObsMode.night);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
