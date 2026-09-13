import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discovery.dart';
import '../models/observation_map.dart';
import '../state/discovery_providers.dart';
import '../utils/relative_time.dart';
import '../utils/trail_format.dart';
import 'night_sky_tag.dart';
import 'score_gauge.dart';

/// Spot detail body swapped into [ObservationSpotSheet] once a spot is
/// selected: a measurement block (kind-specific, always factual) followed by
/// a suitability block (0-100 score) -- separated by a [Divider], never on
/// the same row, per the trail-screen precedent. Heritage spots have no
/// suitability block: an observation-fitness gauge doesn't apply to a
/// restaurant.
class ObservationSpotDetail extends ConsumerWidget {
  const ObservationSpotDetail({
    super.key,
    required this.spot,
    required this.scrollController,
  });

  final ObservationSpot spot;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(spot.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _MeasurementBlock(spot: spot),
        if (spot.kind != 'heritage') ...[
          const Divider(height: 32),
          _SuitabilityBlock(spot: spot),
        ],
      ],
    );
  }
}

/// Kind-specific, always-factual measurement block (species count, SQM,
/// distance) shown above the suitability block in [ObservationSpotDetail].
class _MeasurementBlock extends ConsumerWidget {
  const _MeasurementBlock({required this.spot});

  final ObservationSpot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (spot.kind) {
      case 'bird':
        final now = ref.watch(nowProvider);
        return _BirdMeasurement(birds: spot.birds!, now: now);
      case 'star':
        return NightSkyTag(nightSky: spot.nightSky!, large: true);
      case 'heritage':
      default:
        return _HeritageMeasurement(heritage: spot.heritage!);
    }
  }
}

/// 0-100 suitability score gauge shown below the measurement block, for
/// every kind except heritage (an observation-fitness gauge doesn't apply
/// to a restaurant).
class _SuitabilityBlock extends ConsumerWidget {
  const _SuitabilityBlock({required this.spot});

  final ObservationSpot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final mode = ref.watch(obsModeProvider).mode;
    final query = (lat: spot.coord.lat, lng: spot.coord.lng, mode: mode);
    final overviewAsync = ref.watch(spotSuitabilityProvider(query));
    final progressColor =
        mode == ObsMode.day ? colorScheme.tertiary : colorScheme.secondary;

    return Center(
      child: overviewAsync.when(
        loading: () => const CircularProgressIndicator(),
        error: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('적합도를 불러오지 못했어요.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(spotSuitabilityProvider(query)),
              child: const Text('다시 시도'),
            ),
          ],
        ),
        data: (overview) => ScoreGauge(
          score: overview.suitabilityIndex.score,
          progressColor: progressColor,
        ),
      ),
    );
  }
}

class _BirdMeasurement extends StatelessWidget {
  const _BirdMeasurement({required this.birds, required this.now});

  final BirdObservation birds;
  final DateTime now;

  String _recencyLabel() => formatRelativeTime(birds.mostRecentObsDt, now);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '조류 ${birds.speciesCount}종 관측',
                style: textTheme.titleMedium,
              ),
            ),
            if (birds.status == 'community')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '커뮤니티 관측',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _recencyLabel(),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final species in birds.topSpecies.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              species.count != null
                  ? '${species.nameKo} · ${species.count}마리'
                  : species.nameKo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _HeritageMeasurement extends StatelessWidget {
  const _HeritageMeasurement({required this.heritage});

  final HeritageInfo heritage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final distanceM = heritage.distanceM;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heritage.addr, style: textTheme.bodyMedium),
        if (distanceM != null) ...[
          const SizedBox(height: 4),
          Text(
            formatDistanceM(distanceM),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
