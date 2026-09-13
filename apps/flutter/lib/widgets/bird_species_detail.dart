import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../utils/bird_scatter.dart';
import '../utils/relative_time.dart';
import 'observation_marker.dart';

/// Species-detail bottom sheet content shown when a scattered individual
/// bird marker is tapped (spec 019 P1-4), replacing the earlier minimal
/// name-only SnackBar tooltip. Intended as the `builder` content of a
/// `showModalBottomSheet` call -- no [Scaffold] of its own.
class BirdSpeciesDetail extends ConsumerWidget {
  const BirdSpeciesDetail({
    super.key,
    required this.bird,
    required this.spotName,
    required this.spotCoord,
  });

  final ScatteredBird bird;
  final String spotName;
  final Coordinate spotCoord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.watch(nowProvider);
    final relativeTime = formatRelativeTime(bird.obsDt, now);

    return SafeArea(
      key: const Key('bird_species_detail_sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: bird.nameKo,
              child: Text(bird.nameKo, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(
              bird.nameSci,
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(64, 64),
                      painter: BirdSilhouettePainter(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '사진은 준비 중이에요',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (bird.count != null) Text('관측 ${bird.count}마리'),
            Text('관측 $relativeTime'),
            Text(
              '$spotName (${spotCoord.lat.toStringAsFixed(4)}, '
              '${spotCoord.lng.toStringAsFixed(4)})',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '커뮤니티 관측 · $relativeTime',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
