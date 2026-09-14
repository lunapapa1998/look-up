import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tide.dart';
import '../../state/discovery_providers.dart';

/// Today's tide extremes, shown as the last section of [SpeciesDetail] (spec
/// 023 Phase 3). The caller resolves [tideTodayProvider] and only constructs
/// this widget when [tides].found is true -- a "no tide data" fallback would
/// be misleading for a spot that simply isn't near a tide station, so that
/// case is handled by the caller not building this widget at all.
class TodayTidesSection extends ConsumerWidget {
  const TodayTidesSection({super.key, required this.tides});

  final TodayTides tides;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.watch(nowProvider);

    final nowLabel =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final rows = <Widget>[];
    var nowInserted = false;
    for (final extreme in tides.extremes) {
      if (!nowInserted && extreme.time.compareTo(nowLabel) > 0) {
        rows.add(_NowMarkerRow(label: nowLabel, colorScheme: colorScheme));
        nowInserted = true;
      }
      rows.add(_TideExtremeRow(extreme: extreme));
    }
    if (!nowInserted) {
      rows.add(_NowMarkerRow(label: nowLabel, colorScheme: colorScheme));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text('이 갯벌의 오늘 물때', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _TideExtremeRow extends StatelessWidget {
  const _TideExtremeRow({required this.extreme});

  final TideExtreme extreme;

  @override
  Widget build(BuildContext context) {
    final kindLabel = extreme.kind == 'high' ? '만조' : '간조';
    final levelCm = extreme.levelCm;
    final text = levelCm != null
        ? '${extreme.time}  $kindLabel · 조위${levelCm}cm'
        : '${extreme.time}  $kindLabel';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }
}

class _NowMarkerRow extends StatelessWidget {
  const _NowMarkerRow({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '지금 $label',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
