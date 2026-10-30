import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tide.dart';
import '../../state/discovery_providers.dart';
import '../../theme/lookup_colors.dart';

/// Today's tide timeline (Figma 105-461), shown as the last section of
/// [SpeciesDetail]. The caller resolves [tideTodayProvider] and only
/// constructs this widget when [tides].found is true -- a "no tide data"
/// fallback would be misleading for a spot that simply isn't near a tide
/// station, so that case is handled by the caller not building this widget.
///
/// Renders a vertical timeline card: each low/high extreme (with water level),
/// a neutral "지금" marker at the current time, and a highlighted "만조기"
/// window (2h before each high tide -- the tidal feeding/observation peak).
/// 일몰(sunset) from 105-461 is intentionally omitted: it lives in astronomy
/// data, not the tide response (follow-up).
class TodayTidesSection extends ConsumerWidget {
  const TodayTidesSection({super.key, required this.tides});

  final TodayTides tides;


  static int _parseMin(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String _fmtMin(int min) {
    final clamped = min < 0 ? 0 : min;
    final h = (clamped ~/ 60) % 24;
    final m = clamped % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.watch(nowProvider);
    final nowMin = now.hour * 60 + now.minute;

    // ── 타임라인 엔트리 병합: 극값 + 만조기(만조 전 2시간) + 지금 ──
    // order: 같은 분일 때 지금(0) < 만조기(1) < 극값(2)로 결정적 정렬.
    final entries = <_TideEntry>[];
    for (final extreme in tides.extremes) {
      final t = _parseMin(extreme.time);
      if (extreme.kind == 'high') {
        final ws = t - 120;
        entries.add(
          _TideEntry.peak(
            sort: ws,
            windowLabel: '${_fmtMin(ws)} ~ ${extreme.time} · 만조기',
          ),
        );
      }
      entries.add(_TideEntry.extreme(sort: t, extreme: extreme));
    }
    entries.add(_TideEntry.now(sort: nowMin, label: '${_fmtMin(nowMin)} · 지금'));
    entries.sort((a, b) {
      final c = a.sort.compareTo(b.sort);
      return c != 0 ? c : a.order.compareTo(b.order);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '오늘의 물때',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tides.stationName != null) ...[
                const Spacer(),
                Text(
                  '${tides.stationName} 기준',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in entries)
            _TimelineRow(entry: entry, colorScheme: colorScheme),
        ],
      ),
    );
  }
}

enum _TideEntryKind { now, peak, extreme }

class _TideEntry {
  const _TideEntry._({
    required this.sort,
    required this.kind,
    this.extreme,
    this.label,
    this.windowLabel,
  });

  factory _TideEntry.extreme({required int sort, required TideExtreme extreme}) =>
      _TideEntry._(sort: sort, kind: _TideEntryKind.extreme, extreme: extreme);

  factory _TideEntry.now({required int sort, required String label}) =>
      _TideEntry._(sort: sort, kind: _TideEntryKind.now, label: label);

  factory _TideEntry.peak({required int sort, required String windowLabel}) =>
      _TideEntry._(sort: sort, kind: _TideEntryKind.peak, windowLabel: windowLabel);

  final int sort;
  final _TideEntryKind kind;
  final TideExtreme? extreme;
  final String? label;
  final String? windowLabel;

  // 같은 분 tie-break 우선순위.
  int get order => switch (kind) {
        _TideEntryKind.now => 0,
        _TideEntryKind.peak => 1,
        _TideEntryKind.extreme => 2,
      };
}

/// One timeline row: a left rail (continuous 2px track + a colored dot) and
/// the row content. [IntrinsicHeight] lets the rail's track fill the row so
/// consecutive rows form one unbroken line.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.colorScheme});

  final _TideEntry entry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 만조기 is the bird feeding/observation peak -> day-meaning accent
    // (yellow); its text goes through accentText for light-theme contrast.
    final dayAccent = LookUpColors.of(context).modeDayAccent;
    final dayAccentText = accentText(context, dayAccent);

    late final Color dotColor;
    late final bool glow;
    late final Widget content;

    switch (entry.kind) {
      case _TideEntryKind.now:
        // Neutral "지금" marker (was off-brand purple #8152C9, ~3.1:1 on
        // the night card): onSurface dot + bold onSurface text.
        dotColor = colorScheme.onSurface;
        glow = false;
        content = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            entry.label!,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        );
      case _TideEntryKind.peak:
        dotColor = dayAccent;
        glow = true;
        content = Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: dayAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.windowLabel!,
                style: textTheme.labelSmall?.copyWith(
                  color: dayAccentText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '만조 전 2시간',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case _TideEntryKind.extreme:
        final extreme = entry.extreme!;
        final isHigh = extreme.kind == 'high';
        final kindLabel = isHigh ? '만조' : '간조';
        dotColor = colorScheme.surfaceContainerHighest;
        glow = false;
        content = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${extreme.time} · $kindLabel',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (extreme.levelCm != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '조위 ${extreme.levelCm}cm',
                    style: textTheme.labelSmall?.copyWith(
                      color: isHigh
                          ? dayAccentText
                          : colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            colorScheme: colorScheme,
            dotColor: dotColor,
            glow: glow,
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Left rail: a full-height 2px track with a 10px dot near the top, so
/// stacked rows read as one continuous vertical timeline.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.colorScheme,
    required this.dotColor,
    required this.glow,
  });

  final ColorScheme colorScheme;
  final Color dotColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 2,
                color: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Positioned(
            top: 2,
            left: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: glow
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
