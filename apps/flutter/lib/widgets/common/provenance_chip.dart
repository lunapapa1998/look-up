import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/layout_tokens.dart';
import '../../theme/lookup_colors.dart';

/// Where a displayed value comes from (spec 054). Exactly four states; the
/// '참고값' wording for non-live suitability is NOT one of them.
enum ProvenanceKind { live, approx, sample, stale }

/// Picks the single provenance to show when several flags apply.
///
/// Priority: sample > stale > approx > live (spec 054 amendment 2026-10-30),
/// so sample data is never labeled '실시간'. Returns null when nothing
/// applies.
ProvenanceKind? resolveProvenance({
  bool sample = false,
  bool stale = false,
  bool approx = false,
  bool live = false,
}) {
  if (sample) return ProvenanceKind.sample;
  if (stale) return ProvenanceKind.stale;
  if (approx) return ProvenanceKind.approx;
  if (live) return ProvenanceKind.live;
  return null;
}

/// Small pill telling where a value comes from (spec 054-2a).
///
/// When to use each kind:
/// - [ProvenanceChip.live] ("실시간"): the API status is 'live' and the value
///   is not served from sample data.
/// - [ProvenanceChip.approx] ("추정"): computed or estimated values.
/// - [ProvenanceChip.sample] ("예시"): `sampleSourcesProvider` contains the
///   value's source.
/// - [ProvenanceChip.stale] ("지연"): only when a real last-updated time
///   exists or the source is known to be stale.
///
/// When several apply, use [resolveProvenance] (sample > stale > approx >
/// live). The time ("HH:mm") is shown only when [at] is given; a time is
/// never invented.
///
/// This chip does NOT replace the '참고값' wording used for non-live
/// suitability (spec 054 amendment 2026-10-30).
///
/// State is never conveyed by color alone: live = filled dot, approx =
/// hollow ring, stale = warning icon, sample = dashed outline, each with its
/// text. Text is always `onSurface`; provenance colors are used only on the
/// marker. Not interactive.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip.live({super.key, this.at, this.compact = false})
    : kind = ProvenanceKind.live;
  const ProvenanceChip.approx({super.key, this.compact = false})
    : kind = ProvenanceKind.approx,
      at = null;
  const ProvenanceChip.sample({super.key, this.compact = false})
    : kind = ProvenanceKind.sample,
      at = null;
  const ProvenanceChip.stale({super.key, this.at, this.compact = false})
    : kind = ProvenanceKind.stale;

  /// Generic form; [at] is ignored for approx/sample.
  const ProvenanceChip({
    super.key,
    required this.kind,
    this.at,
    this.compact = false,
  });

  final ProvenanceKind kind;

  /// Last real update time; shown as local "HH:mm" for live/stale only.
  final DateTime? at;

  /// Smaller variant for map pins and dense list rows (SampleMark sizes).
  final bool compact;

  /// Key of the leading marker (dot, ring or icon), for tests.
  static const Key markerKey = Key('provenance_chip_marker');

  /// Key of the dashed outline painter (sample only), for tests.
  static const Key dashedOutlineKey = Key('provenance_chip_dashed_outline');

  /// Key of the solid stadium decoration (live/approx/stale), for tests.
  static const Key solidOutlineKey = Key('provenance_chip_solid_outline');

  DateTime? get _time =>
      (kind == ProvenanceKind.live || kind == ProvenanceKind.stale)
      ? at
      : null;

  String get _text {
    final time = _time;
    switch (kind) {
      case ProvenanceKind.live:
        return time == null ? '실시간' : '실시간 · ${_hhmm(time)}';
      case ProvenanceKind.approx:
        return '추정';
      case ProvenanceKind.sample:
        return '예시';
      case ProvenanceKind.stale:
        return time == null ? '지연' : '지연 · ${_hhmm(time)} 기준';
    }
  }

  String get _semanticsLabel {
    final time = _time;
    final suffix = time == null ? '' : ', ${_hhmm(time)} 기준';
    switch (kind) {
      case ProvenanceKind.live:
        return '데이터 상태: 실시간$suffix';
      case ProvenanceKind.approx:
        return '데이터 상태: 추정';
      case ProvenanceKind.sample:
        return '예시 데이터';
      case ProvenanceKind.stale:
        return '데이터 상태: 지연$suffix';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = LookUpColors.of(context);

    final label = Text(
      _text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: compact ? 9 : 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: colorScheme.onSurface,
      ),
    );

    final marker = _marker(colors);
    final content = Padding(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (marker != null) ...[
            marker,
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: label),
        ],
      ),
    );

    final Widget body = kind == ProvenanceKind.sample
        ? CustomPaint(
            key: dashedOutlineKey,
            painter: _DashedBorderPainter(
              color: colors.provenanceSample,
              fill: colorScheme.surface,
              radius: AppRadius.pill,
            ),
            child: content,
          )
        : DecoratedBox(
            key: solidOutlineKey,
            decoration: ShapeDecoration(
              color: colorScheme.surface,
              shape: StadiumBorder(
                side: BorderSide(color: colorScheme.outline, width: 1),
              ),
            ),
            child: content,
          );

    return Semantics(
      container: true,
      label: _semanticsLabel,
      excludeSemantics: true,
      child: body,
    );
  }

  Widget? _marker(LookUpColors colors) {
    final dot = compact ? 5.0 : 6.0;
    switch (kind) {
      case ProvenanceKind.live:
        return Container(
          key: markerKey,
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.provenanceLive,
          ),
        );
      case ProvenanceKind.approx:
        return Container(
          key: markerKey,
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.provenanceApprox, width: 1.5),
          ),
        );
      case ProvenanceKind.stale:
        return Icon(
          Icons.warning_amber_rounded,
          key: markerKey,
          size: compact ? 10 : 12,
          color: colors.provenanceStale,
        );
      case ProvenanceKind.sample:
        return null;
    }
  }
}

/// 24h zero-padded local "HH:mm" (no intl dependency).
String _hhmm(DateTime at) {
  final local = at.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Filled rounded rect with a dashed 1px outline. Private copy of the
/// painter in `sample_data_notice.dart`; deduplicated in spec 054-2c.
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
    final rect = (Offset.zero & size).deflate(0.5);
    // Clamp so [AppRadius.pill] yields a stadium.
    final r = math.min(radius, rect.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
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
