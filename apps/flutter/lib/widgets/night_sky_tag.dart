import 'package:flutter/material.dart';

import '../models/trails.dart';
import 'night_sky_scale.dart';

/// WCAG 2.x contrast ratio between two colors, computed from their relative
/// luminance: (lighter + 0.05) / (darker + 0.05).
double _contrastRatio(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  final lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

String _buildSemanticsLabel(NightSkyDisplay display) {
  final parts = <String>['5점 중 ${display.filledStars}점', display.label];
  if (display.expectation.isNotEmpty) parts.add(display.expectation);
  if (display.isApprox) parts.add('추정치');
  return parts.join(', ');
}

void showNightSkyInfoSheet(BuildContext context, NightSky nightSky) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SQM과 Bortle 등급이란?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('SQM은 밤하늘의 밝기를 측정한 값으로, 숫자가 높을수록 하늘이 더 어둡고 별이 잘 보여요.'),
          const SizedBox(height: 4),
          const Text('Bortle 등급은 빛공해 정도를 1~9단계로 나눈 지표로, 낮을수록 별을 관측하기 좋아요.'),
          const SizedBox(height: 4),
          const Text('두 값은 위성 데이터를 기반으로 추정한 값일 수 있어 실제와 다소 차이가 있을 수 있어요.'),
          const Divider(height: 24),
          Text(
            '현재 측정값: SQM ${nightSky.sqmValue.toStringAsFixed(2)} · Bortle ${nightSky.bortleClass}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class NightSkyInfoButton extends StatelessWidget {
  const NightSkyInfoButton({super.key, required this.nightSky});

  final NightSky nightSky;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SQM, Bortle 측정값 설명 보기',
      child: SizedBox(
        width: 44,
        height: 44,
        child: InkWell(
          onTap: () => showNightSkyInfoSheet(context, nightSky),
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders a [NightSky] measurement as a compact tag/chip — never a
/// gauge or progress indicator. Night sky brightness is measured data,
/// not a 0-100 suitability score, so this is visually distinct from
/// [ScoreGauge]. Surfaces plain-language brightness (via [mapNightSky])
/// rather than raw SQM/Bortle numbers; the numeric values are demoted to
/// expert-only info shown in [large] mode and behind the info sheet.
class NightSkyTag extends StatelessWidget {
  const NightSkyTag({super.key, required this.nightSky, this.large = false});

  final NightSky nightSky;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = mapNightSky(
      bortleClass: nightSky.bortleClass,
      status: nightSky.status ?? '',
    );

    // Star rating decoration is neutral grey; the filled count carries the
    // tier.
    final tierColor = colorScheme.onSurfaceVariant;
    final hasSufficientContrast =
        _contrastRatio(tierColor, colorScheme.surfaceContainerHigh) >= 4.5;
    final starColor = hasSufficientContrast ? tierColor : colorScheme.onSurface;
    final emptyStarColor = colorScheme.outline.withValues(alpha: 0.3);

    final labelStyle = large ? textTheme.titleSmall : textTheme.labelLarge;
    final expectationStyle = large ? textTheme.bodyMedium : textTheme.bodySmall;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: _buildSemanticsLabel(display),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            final filled = i < display.filledStars;
                            final starOpacity = display.isApprox ? 0.6 : 1.0;
                            return Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.auto_awesome,
                                size: large ? 20 : 14,
                                color: filled
                                    ? starColor.withValues(alpha: starOpacity)
                                    : emptyStarColor,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              display.label,
                              style: labelStyle?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (display.expectation.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                display.expectation,
                                style: expectationStyle?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!display.hasNoData) NightSkyInfoButton(nightSky: nightSky),
            ],
          ),
          if (large && !display.hasNoData)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SQM ${nightSky.sqmValue.toStringAsFixed(2)} · Bortle ${nightSky.bortleClass}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (display.isApprox) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '추정치',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
