import 'package:flutter/material.dart';

import '../../models/stay_package.dart';
import '../../theme/layout_tokens.dart';
import '../../theme/lookup_colors.dart';

/// Maximum edge length of the square package hero illustration.
const double packageHeroMaxExtent = 360;

class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.onPreview,
  });
  final StayPackage package;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image has a separate caption so enlarged titles cannot obscure it.
          // Near-square pixel art: shown as a square (minimal crop), capped at
          // [packageHeroMaxExtent] on wide screens and centred in the card.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: packageHeroMaxExtent,
                maxHeight: packageHeroMaxExtent,
              ),
              child: AspectRatio(
                key: Key('package_hero_${package.id}'),
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      package.imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                    // Only the last ~20% fades into the card surface.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, colors.surfaceContainer],
                          stops: const [0.8, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (var i = 0; i < package.badges.length; i++)
                            PackageTag(
                              label: package.badges[i],
                              color: colors.onSurface,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.eyebrow,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(package.title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < package.benefits.length; i++)
                      PackageTag(
                        label: package.benefits[i],
                        color: i == 1
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var i = 0; i < package.stops.length; i++)
                  PackageTimelineStop(
                    stop: package.stops[i],
                    last: i == package.stops.length - 1,
                  ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: colors.outline.withValues(alpha: 0.2)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  package.transport,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final price = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('가격 · 1인', style: text.bodySmall),
                        Text(
                          '${formatPackagePrice(package.pricePerPerson)}원',
                          style: text.titleLarge,
                        ),
                      ],
                    );
                    final button = FilledButton.icon(
                      key: Key('package_preview_${package.id}'),
                      onPressed: onPreview,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('예약 미리보기'),
                    );
                    if (constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          price,
                          const SizedBox(height: AppSpacing.md),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: price),
                        button,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '시안 상품 · 일정·가격·혜택 확정 전',
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PackageTag extends StatelessWidget {
  const PackageTag({super.key, required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    ),
  );
}

class PackageTimelineStop extends StatelessWidget {
  const PackageTimelineStop({super.key, required this.stop, this.last = false});
  final PackageStop stop;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Day stops yellow, night stops lavender, sunset (meal) stops neutral.
    // Time text uses accentText so it stays readable on the light theme.
    final modeColors = LookUpColors.of(context);
    final color = switch (stop.moment) {
      PackageMoment.day => modeColors.modeDayAccent,
      PackageMoment.night => modeColors.modeNightAccent,
      PackageMoment.sunset => colors.onSurfaceVariant,
    };
    final timeColor = stop.moment == PackageMoment.sunset
        ? colors.onSurfaceVariant
        : accentText(context, color);
    final icon = switch (stop.moment) {
      PackageMoment.day => Icons.wb_sunny_outlined,
      PackageMoment.sunset => Icons.restaurant_outlined,
      PackageMoment.night => Icons.nightlight_round,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceContainerHigh,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (!last)
                  Expanded(
                    child: VerticalDivider(
                      width: 1,
                      color: colors.outline.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.time,
                    style: text.labelSmall?.copyWith(color: timeColor),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(stop.title, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    stop.description,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
