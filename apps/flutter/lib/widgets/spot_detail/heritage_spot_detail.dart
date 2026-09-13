import 'package:flutter/material.dart';

import '../../models/observation_map.dart';
import '../../utils/spot_name.dart';
import '../../utils/trail_format.dart';

/// Heritage spot detail body for the observation sheet's detail view: back
/// header plus the address/distance measurement -- the heritage branch of
/// [ObservationSpotDetail]'s kind switch. No suitability section: an
/// observation-fitness gauge doesn't apply to a restaurant.
class HeritageSpotDetail extends StatelessWidget {
  const HeritageSpotDetail({
    super.key,
    required this.spot,
    required this.scrollController,
    required this.onBack,
  });

  final ObservationSpot spot;
  final ScrollController scrollController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
        _HeritageMeasurement(heritage: spot.heritage!),
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
