import 'package:flutter/animation.dart';

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

/// Duration of a scene transition into [to], based on who triggered it and
/// whether reduce-motion is active.
Duration sceneTransitionDuration({
  required ObsMode to,
  required ObsModeSource source,
  required bool reduceMotion,
}) {
  if (reduceMotion) {
    return to == ObsMode.day
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 150);
  }
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
