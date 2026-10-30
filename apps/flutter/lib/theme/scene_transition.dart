import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/discovery.dart' show ObsMode;
import '../state/discovery_providers.dart' show ObsModeSource;

/// A 2-stage front-loaded brightness ramp used for the night-to-day
/// transition, designed to avoid a white-flash glare when going from dark
/// to light: stage A (0-65% of the transition) ramps quickly to a
/// mid-brightness proxy value, stage B (65-100%) eases gently from mid to
/// full brightness so the biggest brightness jump lands in the final 35%.
class NightToDayGlareCurve extends Curve {
  const NightToDayGlareCurve();

  @override
  double transform(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if (clamped <= 0.65) {
      return 0.6 * Curves.easeOutCubic.transform(clamped / 0.65);
    }
    return 0.6 + 0.4 * Curves.easeInOut.transform((clamped - 0.65) / 0.35);
  }
}

/// Total duration of a scene transition into [to], based on who triggered
/// it. With reduce-motion the scene swaps instantly (no curtain), so the
/// duration is [Duration.zero] (spec 060).
Duration sceneTransitionDuration({
  required ObsMode to,
  required ObsModeSource source,
  required bool reduceMotion,
}) {
  if (reduceMotion) return Duration.zero;
  if (source == ObsModeSource.auto) {
    return const Duration(milliseconds: 800);
  }
  return to == ObsMode.day
      ? const Duration(milliseconds: 640)
      : const Duration(milliseconds: 560);
}

/// Easing curve for a scene transition into [to].
Curve sceneTransitionCurve({required ObsMode to, required bool reduceMotion}) {
  if (reduceMotion) {
    return Curves.linear;
  }
  return to == ObsMode.night
      ? Curves.easeInOutCubic
      : const NightToDayGlareCurve();
}

/// Manual transitions get a haptic tap on entry; auto (ambient) ones don't.
bool shouldHapticOnTransition(ObsModeSource source) {
  return source == ObsModeSource.manual;
}

/// Fade-through curtain color (spec 060): the same near-black for both
/// directions, so a transition never flashes white.
const Color kSceneCurtainColor = Color(0xFF141414);

/// Share of the total transition duration spent raising the curtain; the
/// rest lowers it. The theme swaps when the curtain is fully opaque.
const double kCurtainRiseFraction = 0.5;

/// Pointer and keyboard input are blocked while the curtain opacity is at
/// or above this value (the screen is mostly hidden).
const double kCurtainBlockThreshold = 0.5;

/// Curve used while the curtain rises (opacity 0 -> 1) towards [to].
Curve curtainRiseCurve(ObsMode to) {
  return to == ObsMode.night ? Curves.easeInOutCubic : Curves.easeInCubic;
}

/// Curve used while the curtain falls (opacity 1 -> 0) into [to].
///
/// Used with `animateTo(0)`, so opacity = 1 - curve(t): into day the
/// brightness follows the [NightToDayGlareCurve] ramp.
Curve curtainFallCurve(ObsMode to) {
  return to == ObsMode.night
      ? Curves.easeInOutCubic
      : const NightToDayGlareCurve();
}

/// Full-screen #141414 curtain painted above the app's Navigator.
///
/// Uses the color's alpha instead of an `Opacity` widget (no saveLayer on
/// web). Invisible to the accessibility tree, never focusable, and only
/// absorbs pointers while [opacity] >= [kCurtainBlockThreshold].
class SceneCurtain extends StatelessWidget {
  const SceneCurtain({super.key, required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        ignoring: opacity < kCurtainBlockThreshold,
        child: SizedBox.expand(
          // ColoredBox hit-tests opaque, so when not ignoring it absorbs
          // every pointer aimed at the content underneath.
          child: ColoredBox(
            key: const Key('scene_curtain'),
            color: kSceneCurtainColor.withValues(
              alpha: opacity >= 1.0 ? 1.0 : opacity,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyboard guard placed directly above the Navigator (inside
/// `MaterialApp.builder`), i.e. under the app-root default shortcuts, so its
/// bindings win. While [blocked], activation (Enter/Space/NumpadEnter),
/// focus-traversal (Tab/Shift+Tab/arrows) and dismiss (Escape) keys are
/// consumed by a [DoNothingIntent]; nothing is queued or replayed.
///
/// It never moves or removes focus, and its widget structure is identical
/// whether blocked or not, so the Navigator subtree is never reparented.
class SceneInputGuard extends StatelessWidget {
  const SceneInputGuard({
    super.key,
    required this.blocked,
    required this.child,
  });

  final bool blocked;
  final Widget child;

  static const Map<ShortcutActivator, Intent> _blockedShortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.space): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.tab): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.tab, shift: true):
            DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): DoNothingIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DoNothingIntent(),
      };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: blocked
          ? _blockedShortcuts
          : const <ShortcutActivator, Intent>{},
      child: child,
    );
  }
}
