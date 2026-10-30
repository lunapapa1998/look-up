import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discovery.dart';
import '../models/observation_map.dart';
import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../theme/lookup_colors.dart';
import 'observation_spot_sheet.dart';
import 'score_gauge.dart';
import 'spot_detail/bird_spot_detail.dart';
import 'spot_detail/heritage_spot_detail.dart';
import 'spot_detail/star_spot_detail.dart';
import 'spot_detail/trail_spot_detail.dart';

/// Thin switcher swapped into [ObservationSpotSheet]'s detail view: renders
/// [TrailSpotDetail] when [trail] is set, otherwise dispatches on
/// [spot.kind] to the matching kind-specific detail widget. Exactly one of
/// [spot]/[trail] must be non-null.
class ObservationSpotDetail extends StatelessWidget {
  const ObservationSpotDetail({
    super.key,
    this.spot,
    this.trail,
    required this.scrollController,
    required this.onBack,
    required this.onSelectSpecies,
  }) : assert(
         (spot == null) != (trail == null),
         'exactly one of spot/trail must be non-null',
       );

  final ObservationSpot? spot;
  final TrailCourse? trail;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final ValueChanged<SelectedSpecies> onSelectSpecies;

  @override
  Widget build(BuildContext context) {
    final trail = this.trail;
    if (trail != null) {
      return TrailSpotDetail(
        course: trail,
        scrollController: scrollController,
        onBack: onBack,
      );
    }

    final spot = this.spot!;
    switch (spot.kind) {
      case 'bird':
        return BirdSpotDetail(
          spot: spot,
          scrollController: scrollController,
          onBack: onBack,
          onSpeciesTap: onSelectSpecies,
        );
      case 'star':
        return StarSpotDetail(
          spot: spot,
          scrollController: scrollController,
          onBack: onBack,
        );
      case 'heritage':
      default:
        return HeritageSpotDetail(
          spot: spot,
          scrollController: scrollController,
          onBack: onBack,
        );
    }
  }
}

/// 0-100 suitability score gauge shown below the measurement block, for
/// every kind except heritage (an observation-fitness gauge doesn't apply
/// to a restaurant). Used by [BirdSpotDetail] and other non-heritage spot
/// kinds.
class SuitabilityBlock extends ConsumerWidget {
  const SuitabilityBlock({super.key, required this.spot});

  final ObservationSpot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeColors = LookUpColors.of(context);
    final mode = ref.watch(obsModeProvider).mode;
    final query = (lat: spot.coord.lat, lng: spot.coord.lng, mode: mode);
    final overviewAsync = ref.watch(spotSuitabilityProvider(query));
    // Day/night-meaning accent (yellow / lavender); score text via
    // accentText so it stays readable on the light theme.
    final progressColor = mode == ObsMode.day
        ? modeColors.modeDayAccent
        : modeColors.modeNightAccent;

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
          scoreTextColor: accentText(context, progressColor),
        ),
      ),
    );
  }
}
