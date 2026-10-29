import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/sample_data_provider.dart';
import '../theme/layout_tokens.dart';

/// "Showing sample data" banner (spec 052 Phase 3). Renders only while at
/// least one of [sources] is in [sampleSourcesProvider]; otherwise it is a
/// zero-size box, so [margin] (spacing to its neighbors) also disappears.
///
/// Neutral surfaceContainerHigh tone, never error colors: the screen still
/// works, it is just not showing live data. All styling for the banner and
/// [SampleMark] lives in this file so a later design pass can restyle both
/// in one place.
class SampleDataNotice extends ConsumerWidget {
  const SampleDataNotice({
    super.key,
    required this.sources,
    required this.onRetry,
    this.margin = EdgeInsets.zero,
  });

  /// Sources this screen draws from; the banner ignores all others.
  final Set<SampleSource> sources;

  /// Must invalidate data providers only, never `*ApiProvider`s.
  final VoidCallback onRetry;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(sampleSourcesProvider).intersection(sources);
    if (visible.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('sample_data_notice'),
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '서버에 연결할 수 없어 예시 데이터를 보여드려요',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            key: const Key('sample_data_notice_retry'),
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// Small "예시" tag for a card, list row or map pin drawn from sample data.
/// Distinguished by a dashed outline and text, not by color alone.
/// [compact] shrinks it for map pins and dense list rows.
class SampleMark extends StatelessWidget {
  const SampleMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '예시 데이터',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colorScheme.outline,
          fill: colorScheme.surfaceContainerHigh,
          radius: AppRadius.sm,
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                )
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
          child: Text(
            '예시',
            maxLines: 1,
            style: textTheme.labelSmall?.copyWith(
              fontSize: compact ? 9 : 11,
              height: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled rounded rect with a dashed 1px outline for [SampleMark].
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.fill,
    required this.radius,
  });

  final Color color;
  final Color fill;
  final double radius;

  static const double _dash = 3;
  static const double _gap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()..addRRect(rrect);
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.radius != radius;
}
