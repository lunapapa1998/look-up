import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/scene_transition.dart';

/// Spec 060 Phase 1 unit checks for the fade-through building blocks in
/// `lib/theme/scene_transition.dart` (curtain, keyboard guard, timings).
void main() {
  const curtainKey = Key('scene_curtain');

  group('SceneCurtain', () {
    Widget stackHarness(double opacity, VoidCallback onPressed) {
      return MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ElevatedButton(
                key: const Key('under'),
                onPressed: onPressed,
                child: const Text('under'),
              ),
            ),
            SceneCurtain(opacity: opacity),
          ],
        ),
      );
    }

    testWidgets('opacity 0 renders no curtain', (tester) async {
      var presses = 0;
      await tester.pumpWidget(stackHarness(0, () => presses++));
      expect(find.byKey(curtainKey), findsNothing);
      await tester.tap(find.byKey(const Key('under')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 1);
    });

    testWidgets('below the threshold it is #141414 at that alpha and lets '
        'pointers through', (tester) async {
      var presses = 0;
      await tester.pumpWidget(stackHarness(0.3, () => presses++));
      final box = tester.widget<ColoredBox>(find.byKey(curtainKey));
      expect(box.color, kSceneCurtainColor.withValues(alpha: 0.3));
      expect(kSceneCurtainColor, const Color(0xFF141414));

      await tester.tap(find.byKey(const Key('under')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 1);
    });

    testWidgets('at or above the threshold it absorbs pointers', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(stackHarness(0.7, () => presses++));
      await tester.tap(find.byKey(const Key('under')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 0);

      await tester.pumpWidget(stackHarness(1.0, () => presses++));
      expect(tester.widget<ColoredBox>(find.byKey(curtainKey)).color.a, 1.0);
      await tester.tap(find.byKey(const Key('under')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 0);
    });

    testWidgets('is wrapped in ExcludeSemantics and not focusable', (
      tester,
    ) async {
      await tester.pumpWidget(stackHarness(0.7, () {}));
      expect(
        find.descendant(
          of: find.byType(SceneCurtain),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SceneCurtain),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    });
  });

  group('SceneInputGuard', () {
    Widget guardHarness(
      ValueNotifier<bool> blocked,
      FocusNode focusNode,
      VoidCallback onPressed,
    ) {
      return MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: blocked,
          builder: (context, isBlocked, child) =>
              SceneInputGuard(blocked: isBlocked, child: child!),
          child: Scaffold(
            body: Center(
              child: _GuardedButton(focusNode: focusNode, onPressed: onPressed),
            ),
          ),
        ),
      );
    }

    testWidgets('blocked: activation, traversal and Escape keys are consumed '
        'and focus stays put', (tester) async {
      final blocked = ValueNotifier<bool>(true);
      final focusNode = FocusNode(debugLabel: 'guarded');
      addTearDown(blocked.dispose);
      addTearDown(focusNode.dispose);
      var presses = 0;

      await tester.pumpWidget(guardHarness(blocked, focusNode, () => presses++));
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      for (final key in const [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.escape,
      ]) {
        expect(await tester.sendKeyEvent(key), isTrue, reason: '$key');
        expect(focusNode.hasPrimaryFocus, isTrue, reason: '$key');
      }

      // Shift+Tab.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(focusNode.hasPrimaryFocus, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 0);
    });

    testWidgets('unblocking keeps the same child State and Enter activates '
        'again without replaying blocked keys', (tester) async {
      final blocked = ValueNotifier<bool>(true);
      final focusNode = FocusNode(debugLabel: 'guarded');
      addTearDown(blocked.dispose);
      addTearDown(focusNode.dispose);
      var presses = 0;

      await tester.pumpWidget(guardHarness(blocked, focusNode, () => presses++));
      focusNode.requestFocus();
      await tester.pump();
      final stateBefore = tester.state(find.byType(_GuardedButton));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 0);

      blocked.value = false;
      await tester.pump();
      expect(
        identical(tester.state(find.byType(_GuardedButton)), stateBefore),
        isTrue,
      );
      expect(focusNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(presses, 1);
    });
  });

  group('timings and curves', () {
    test('reduce motion means an instant swap (zero duration)', () {
      for (final mode in ObsMode.values) {
        for (final source in ObsModeSource.values) {
          expect(
            sceneTransitionDuration(
              to: mode,
              source: source,
              reduceMotion: true,
            ),
            Duration.zero,
          );
        }
      }
    });

    test('auto 800ms, manual day 640ms / night 560ms are unchanged', () {
      expect(
        sceneTransitionDuration(
          to: ObsMode.day,
          source: ObsModeSource.auto,
          reduceMotion: false,
        ),
        const Duration(milliseconds: 800),
      );
      expect(
        sceneTransitionDuration(
          to: ObsMode.day,
          source: ObsModeSource.manual,
          reduceMotion: false,
        ),
        const Duration(milliseconds: 640),
      );
      expect(
        sceneTransitionDuration(
          to: ObsMode.night,
          source: ObsModeSource.manual,
          reduceMotion: false,
        ),
        const Duration(milliseconds: 560),
      );
    });

    test('curtain constants', () {
      expect(kCurtainRiseFraction, 0.5);
      expect(kCurtainBlockThreshold, 0.5);
    });

    test('rise/fall curves follow the spec table', () {
      expect(curtainRiseCurve(ObsMode.night), same(Curves.easeInOutCubic));
      expect(curtainRiseCurve(ObsMode.day), same(Curves.easeInCubic));
      expect(curtainFallCurve(ObsMode.night), same(Curves.easeInOutCubic));
      expect(curtainFallCurve(ObsMode.day), isA<NightToDayGlareCurve>());
    });

    test('manual transitions get a haptic, auto ones do not', () {
      expect(shouldHapticOnTransition(ObsModeSource.manual), isTrue);
      expect(shouldHapticOnTransition(ObsModeSource.auto), isFalse);
    });
  });
}

class _GuardedButton extends StatefulWidget {
  const _GuardedButton({required this.focusNode, required this.onPressed});

  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  State<_GuardedButton> createState() => _GuardedButtonState();
}

class _GuardedButtonState extends State<_GuardedButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      focusNode: widget.focusNode,
      onPressed: widget.onPressed,
      child: const Text('guarded'),
    );
  }
}
