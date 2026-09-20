import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/observation_map.dart';
import '../../models/starlight_forecast.dart';
import '../../state/discovery_providers.dart';
import '../../utils/spot_name.dart';
import '../night_sky_tag.dart';
import '../tonight_sky_section.dart';

/// Star spot detail body for the observation sheet's detail view: back
/// header, the [NightSkyTag] measurement, then the golden-time and
/// tonight-sky forecast content.
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
    final forecastAsync = ref.watch(
      spotStarlightForecastProvider((lat: spot.coord.lat, lng: spot.coord.lng)),
    );

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
        const SizedBox(height: 16),
        forecastAsync.when(
          data: (forecast) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GoldenTimeBlock(forecast: forecast),
              const SizedBox(height: 16),
              TonightSkySection(
                targets: forecast.allVisibleTargets,
                isApprox: forecast.degraded,
              ),
            ],
          ),
          loading: () => const _GoldenTimeSkeleton(),
          error: (err, st) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _GoldenTimeBlock extends StatelessWidget {
  const _GoldenTimeBlock({required this.forecast});

  final StarlightForecast forecast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('천체 골든타임', style: textTheme.titleMedium),
            if (forecast.degraded) ...[
              const SizedBox(width: 6),
              Text('추정치', style: textTheme.labelSmall),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(forecast.summary, style: textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          '일몰 ${forecast.sunset} · 관측 시작 ${forecast.astronomicalTwilightEnd}',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _GoldenTimeSkeleton extends StatelessWidget {
  const _GoldenTimeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(height: 20, width: 120),
        SizedBox(height: 8),
        _SkeletonBox(height: 16),
        SizedBox(height: 4),
        _SkeletonBox(height: 14, width: 200),
        SizedBox(height: 16),
        _SkeletonBox(height: 80),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(color: Colors.grey.shade300),
    );
  }
}
