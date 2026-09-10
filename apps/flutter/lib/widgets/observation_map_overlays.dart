import 'package:flutter/material.dart';

/// iOS-Maps-style compass reset button for the observation map (spec 016
/// Phase 4a). Pure widget -- no Riverpod/BuildContext-provider access, all
/// data comes from constructor params; the screen wiring this in owns the
/// live rotation stream and tap handler.
class CompassButton extends StatelessWidget {
  const CompassButton({
    super.key,
    required this.rotationDegrees,
    required this.onTap,
  });

  final double rotationDegrees;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Effectively north-up already: a reset-to-north button is meaningless
    // and dead at that point, so hide it entirely rather than just dim it.
    if (rotationDegrees.abs() < 0.5) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '지도를 북쪽으로 재설정',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('obsmap_compass_button'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Transform.rotate(
                angle: -rotationDegrees * 3.141592653589793 / 180,
                child: Icon(Icons.explore, color: colorScheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact tide/moon measurement overlay for the observation map (spec 016
/// Phase 4a). Measurement values only -- tide state and moon phase/
/// illumination -- never a suitability score, per this spec's
/// species-vs-suitability separation rule that governs the whole map
/// screen. Pure widget, same no-provider-access contract as [CompassButton].
class TideMoonOverlay extends StatelessWidget {
  const TideMoonOverlay({
    super.key,
    required this.tideText,
    required this.moonText,
  });

  final String? tideText;
  final String? moonText;

  @override
  Widget build(BuildContext context) {
    // Measurement data unavailable -- never render an empty pill (P2-2).
    if (tideText == null && moonText == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface,
        );

    return Container(
      key: const Key('obsmap_tide_moon_overlay'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Each line is independently constrained/ellipsized so a long
          // moon line can never push the tide line off-screen or overflow
          // -- this stacked layout is how "tide takes priority under width
          // constraints" is satisfied without a shared Row budget.
          if (tideText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                tideText!,
                key: const Key('obsmap_tide_text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          if (moonText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                moonText!,
                key: const Key('obsmap_moon_text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
        ],
      ),
    );
  }
}
