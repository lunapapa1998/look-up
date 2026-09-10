import 'package:flutter/material.dart';

import '../models/trails.dart';

/// WCAG 2.x contrast ratio between two colors, computed from their relative
/// luminance: (lighter + 0.05) / (darker + 0.05).
double _contrastRatio(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  final lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Renders a [NightSky] measurement as a compact tag/chip — never a
/// gauge or progress indicator. Night sky brightness is measured data,
/// not a 0-100 suitability score, so this is visually distinct from
/// [ScoreGauge].
class NightSkyTag extends StatelessWidget {
  const NightSkyTag({super.key, required this.nightSky, this.large = false});

  final NightSky nightSky;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // labelSmall defaults to 11sp (below the 12sp floor); labelMedium is
    // already 12sp, so only the small/non-large branch needs an override.
    final monoStyle = large
        ? textTheme.labelMedium
        : textTheme.labelSmall?.copyWith(fontSize: 12);
    final isApprox = nightSky.status == 'approx';
    final hasSufficientContrast =
        _contrastRatio(colorScheme.tertiary, colorScheme.surfaceContainerHigh) >=
        4.5;
    final sqmValueColor = hasSufficientContrast
        ? colorScheme.tertiary
        : colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.nightlight_round,
            size: large ? 20 : 14,
            color: colorScheme.tertiary,
          ),
          SizedBox(width: large ? 6 : 4),
          Text(
            'SQM ${nightSky.sqmValue.toStringAsFixed(2)}',
            style: monoStyle?.copyWith(color: sqmValueColor),
          ),
          SizedBox(width: large ? 8 : 6),
          Text(
            'Bortle ${nightSky.bortleClass}',
            style: monoStyle?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(width: large ? 8 : 6),
          Text(
            nightSky.skyClass,
            style: monoStyle?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (isApprox) ...[
            SizedBox(width: large ? 6 : 4),
            Text(
              '(약)',
              style: monoStyle?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
