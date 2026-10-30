import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/sample_data_provider.dart';
import '../theme/layout_tokens.dart';
import 'common/provenance_chip.dart';

/// "Showing sample data" banner (spec 052 Phase 3). Renders only while at
/// least one of [sources] is in [sampleSourcesProvider]; otherwise it is a
/// zero-size box, so [margin] (spacing to its neighbors) also disappears.
///
/// Neutral surfaceContainerHigh tone, never error or warning colors: sample
/// data is not an error and not stale data (spec 054 amendment 2026-10-30);
/// the screen still works, it is just not showing live data. Failures use
/// `StatusView`, old data uses `ProvenanceChip.stale`.
///
/// Spec 054-2c: the retry action is a `FilledButton.tonal` with the same
/// style override as `StatusView`'s retry, so its hit area stays >= 44 (48)
/// on web/desktop too.
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

  /// Keeps a >= 44px (48) hit area even where the platform default would
  /// shrink-wrap the button (desktop/web: compact density, shrinkWrap).
  /// Same override as `StatusView`'s retry button.
  static const ButtonStyle _retryStyle = ButtonStyle(
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

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
        right: AppSpacing.xs,
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
          FilledButton.tonal(
            key: const Key('sample_data_notice_retry'),
            style: _retryStyle,
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// Small "예시" tag for a card, list row or map pin drawn from sample data.
///
/// Spec 054-2c: delegates to [ProvenanceChip.sample] (text '예시', dashed
/// outline, semantics '예시 데이터'), so there is a single sample-tag
/// implementation. Distinguished by the dashed outline and text, not by
/// color alone. [compact] shrinks it for map pins and dense list rows.
/// Map pins wrap it in `ExcludeSemantics` themselves.
class SampleMark extends StatelessWidget {
  const SampleMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Keep the pre-054-2c screen-reader behavior: a NON-container
    // Semantics label, so '예시 데이터' merges into the enclosing card/row
    // node instead of becoming its own node. excludeSemantics drops the
    // chip's own `Semantics(container: true)` node underneath.
    return Semantics(
      label: '예시 데이터',
      excludeSemantics: true,
      child: ProvenanceChip.sample(compact: compact),
    );
  }
}
