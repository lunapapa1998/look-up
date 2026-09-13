import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/observation_map.dart';
import '../../utils/spot_name.dart';
import '../night_sky_tag.dart';
import '../observation_spot_detail.dart';

/// Star spot detail body for the observation sheet's detail view: back
/// header, the [NightSkyTag] measurement, then the shared
/// [SuitabilityBlock] -- the star branch of [ObservationSpotDetail]'s kind
/// switch.
class StarSpotDetail extends ConsumerWidget {
  const StarSpotDetail({
    super.key,
    required this.spot,
    required this.scrollController,
    required this.onBack,
  });

  final ObservationSpot spot;
  final ScrollController scrollController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        NightSkyTag(nightSky: spot.nightSky!, large: true),
        const Divider(height: 32),
        SuitabilityBlock(spot: spot),
      ],
    );
  }
}
