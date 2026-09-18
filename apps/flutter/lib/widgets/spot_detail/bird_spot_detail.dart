import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/observation_map.dart';
import '../../models/trails.dart';
import '../../state/discovery_providers.dart';
import '../../utils/relative_time.dart';
import '../../utils/spot_name.dart';
import '../observation_spot_sheet.dart';

/// Bird spot detail body for the observation sheet's detail view: back
/// header + species chips (the score gauge was removed per owner request) --
/// the bird branch of the observation spot detail's kind switch.
class BirdSpotDetail extends ConsumerWidget {
  const BirdSpotDetail({
    super.key,
    required this.spot,
    required this.scrollController,
    required this.onBack,
    required this.onSpeciesTap,
  });

  final ObservationSpot spot;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final ValueChanged<SelectedSpecies> onSpeciesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('obsmap_detail_back_button'),
              icon: const Icon(Icons.arrow_back),
              tooltip: '뒤로 가기',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                shortSpotName(spot.name),
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _BirdMeasurement(
          spotName: spot.name,
          spotCoord: spot.coord,
          birds: spot.birds!,
          now: now,
          onSpeciesTap: onSpeciesTap,
        ),
      ],
    );
  }
}

class _BirdMeasurement extends StatelessWidget {
  const _BirdMeasurement({
    required this.spotName,
    required this.spotCoord,
    required this.birds,
    required this.now,
    required this.onSpeciesTap,
  });

  final String spotName;
  final Coordinate spotCoord;
  final BirdObservation birds;
  final DateTime now;
  final ValueChanged<SelectedSpecies> onSpeciesTap;

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final species in birds.topSpecies.take(5))
              Semantics(
                label: species.nameKo,
                child: InkWell(
                  key: Key('obsmap_species_item_${species.speciesCode}'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSpeciesTap((
                    nameKo: species.nameKo,
                    nameSci: species.nameSci,
                    count: species.count,
                    obsDt: species.obsDt,
                    spotName: spotName,
                    spotCoord: spotCoord,
                    status: birds.status,
                  )),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      species.count != null
                          ? '${species.nameKo} · ${species.count}마리'
                          : species.nameKo,
                      style: textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
