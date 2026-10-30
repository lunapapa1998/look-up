import 'package:flutter/material.dart';

import '../../theme/layout_tokens.dart';
import '../../theme/lookup_colors.dart';

/// The four request states shown by [StatusView] (spec 054-2b).
enum StatusKind { loading, empty, error, degraded }

/// Flat inline status block for loading / empty / error / degraded states
/// (spec 054-2b).
///
/// - [StatusView.loading]: neutral surface; a small spinner, or a static
///   hourglass icon when the platform asks to reduce motion.
/// - [StatusView.empty]: neutral surface, neutral icon, optional
///   [TextButton] action. Never uses error colors.
/// - [StatusView.error]: the request failed; `errorContainer` surface with an
///   optional reason line and a "다시 시도" retry button.
/// - [StatusView.degraded]: the screen rendered but PART of the data failed
///   to load ("일부 정보를 불러오지 못했어요"). Warning-tone surface; text
///   stays the body color. "마지막 갱신 HH:mm" is shown only when a real
///   [lastUpdated] is given; a time is never invented.
///
/// Degraded is not stale: data that loaded but is old is marked with
/// `ProvenanceChip.stale` ('지연'), never with this view, and this view never
/// says '지연'. Sample/demo data is announced by `SampleDataNotice`, not here.
///
/// Not yet applied to any screen (specs 055/058). The component adds no
/// outer margin or page gutter; the caller positions it.
class StatusView extends StatelessWidget {
  const StatusView.loading({super.key, this.message = '불러오는 중이에요'})
    : kind = StatusKind.loading,
      icon = null,
      actionLabel = null,
      onAction = null,
      detail = null,
      lastUpdated = null,
      onRetry = null;

  const StatusView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  }) : kind = StatusKind.empty,
       detail = null,
       lastUpdated = null,
       onRetry = null;

  const StatusView.error({
    super.key,
    this.message = '정보를 불러오지 못했어요',
    this.detail,
    this.onRetry,
  }) : kind = StatusKind.error,
       icon = null,
       actionLabel = null,
       onAction = null,
       lastUpdated = null;

  const StatusView.degraded({
    super.key,
    this.message = '일부 정보를 불러오지 못했어요',
    this.lastUpdated,
    this.onRetry,
  }) : kind = StatusKind.degraded,
       icon = null,
       actionLabel = null,
       onAction = null,
       detail = null;

  final StatusKind kind;

  /// Main line (max 3 lines, wraps).
  final String message;

  /// Leading icon for [StatusKind.empty] only.
  final IconData? icon;

  /// Optional empty-state action; shown only when [onAction] is set too.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional reason line for [StatusKind.error].
  final String? detail;

  /// Real last-update time for [StatusKind.degraded]; no time line if null.
  final DateTime? lastUpdated;

  /// Retry callback for error/degraded; the button is hidden when null.
  final VoidCallback? onRetry;

  /// Key of the colored surface container, for tests.
  static const Key surfaceKey = Key('status_view_surface');

  /// Key of the leading icon / progress indicator box, for tests.
  static const Key leadingKey = Key('status_view_leading');

  /// Key of the retry button (error/degraded).
  static const Key retryKey = Key('status_view_retry');

  /// Key of the optional empty-state action button.
  static const Key actionKey = Key('status_view_action');

  /// Below this width the action button moves under the text.
  static const double narrowWidth = 300;

  static const double _iconSize = 18;

  /// Keeps a >= 44px (48) hit area even where the platform default would
  /// shrink-wrap the button (desktop/web: compact density, shrinkWrap).
  static const ButtonStyle _actionStyle = ButtonStyle(
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  String? get _secondLine {
    switch (kind) {
      case StatusKind.error:
        return detail;
      case StatusKind.degraded:
        final at = lastUpdated;
        return at == null ? null : '마지막 갱신 ${_hhmm(at)}';
      case StatusKind.loading:
      case StatusKind.empty:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LookUpColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Color background;
    final Color foreground;
    final Color iconColor;
    switch (kind) {
      case StatusKind.loading:
      case StatusKind.empty:
        background = scheme.surfaceContainer;
        foreground = scheme.onSurface;
        iconColor = scheme.onSurfaceVariant;
      case StatusKind.error:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        iconColor = scheme.onErrorContainer;
      case StatusKind.degraded:
        background = colors.warningContainer;
        foreground = scheme.onSurface;
        iconColor = colors.warning;
    }

    final textStyle = theme.textTheme.bodySmall?.copyWith(color: foreground);
    final second = _secondLine;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
        if (second != null)
          Text(
            second,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
      ],
    );

    final action = _action();
    final leading = _leading(iconColor, reduceMotion);

    return Semantics(
      key: Key('status_view_${kind.name}'),
      container: true,
      liveRegion: kind != StatusKind.empty,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = action != null && constraints.maxWidth < narrowWidth;
          final row = Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: text),
              if (action != null && !narrow) ...[
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            ],
          );
          return Container(
            key: surfaceKey,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: narrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      row,
                      const SizedBox(height: AppSpacing.xs),
                      action,
                    ],
                  )
                : row,
          );
        },
      ),
    );
  }

  Widget _leading(Color color, bool reduceMotion) {
    switch (kind) {
      case StatusKind.loading:
        if (reduceMotion) {
          return Icon(
            Icons.hourglass_empty,
            key: leadingKey,
            size: _iconSize,
            color: color,
          );
        }
        return SizedBox(
          key: leadingKey,
          width: _iconSize,
          height: _iconSize,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ),
        );
      case StatusKind.empty:
        return Icon(
          icon ?? Icons.inbox_outlined,
          key: leadingKey,
          size: _iconSize,
          color: color,
        );
      case StatusKind.error:
        return Icon(
          Icons.error_outline,
          key: leadingKey,
          size: _iconSize,
          color: color,
        );
      case StatusKind.degraded:
        return Icon(
          Icons.warning_amber_rounded,
          key: leadingKey,
          size: _iconSize,
          color: color,
        );
    }
  }

  Widget? _action() {
    switch (kind) {
      case StatusKind.error:
      case StatusKind.degraded:
        final retry = onRetry;
        if (retry == null) return null;
        return FilledButton.tonal(
          key: retryKey,
          style: _actionStyle,
          onPressed: retry,
          child: const Text('다시 시도'),
        );
      case StatusKind.empty:
        final label = actionLabel;
        final callback = onAction;
        if (label == null || callback == null) return null;
        return TextButton(
          key: actionKey,
          style: _actionStyle,
          onPressed: callback,
          child: Text(label),
        );
      case StatusKind.loading:
        return null;
    }
  }
}

/// 24h zero-padded local "HH:mm" (no intl dependency). Private copy of the
/// formatter in `provenance_chip.dart`.
String _hhmm(DateTime at) {
  final local = at.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
