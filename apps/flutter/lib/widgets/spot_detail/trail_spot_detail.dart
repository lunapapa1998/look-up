import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/discovery.dart';
import '../../models/trails.dart';
import '../../state/discovery_providers.dart';
import '../../theme/lookup_colors.dart';
import '../../utils/trail_format.dart';
import '../heritage_eats_list.dart';
import '../night_sky_tag.dart';
import '../score_gauge.dart';

/// Trail course detail body for the observation sheet's detail view: back
/// header, a meta row (distance/duration/level/cycle), the endpoint night-sky
/// tag, nearby heritage eats, a day/night suitability section, and (Phase 3)
/// the rich durunubi course detail -- the trail branch of
/// [ObservationSpotDetail]'s switch (mirrors course_detail_screen.dart's
/// layout with new, locally-scoped classes).
class TrailSpotDetail extends ConsumerWidget {
  const TrailSpotDetail({
    super.key,
    required this.course,
    required this.scrollController,
    required this.onBack,
  });

  final TrailCourse course;
  final ScrollController scrollController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailDetailAsync = ref.watch(trailDetailProvider(course.crsIdx));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
                course.name,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TrailMetaRow(course: course),
        const SizedBox(height: 24),
        Text('종점 밤하늘 관측 조건', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        NightSkyTag(nightSky: course.nightSky, large: true),
        const SizedBox(height: 24),
        HeritageEatsList(eats: course.heritageEats),
        const SizedBox(height: 24),
        _TrailSuitabilitySection(course: course),
        // Phase 3 appends rich durunubi detail below this line
        trailDetailAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상세 정보를 불러오지 못했어요',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(trailDetailProvider(course.crsIdx)),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (detail) => _TrailRichDetailSection(detail: detail),
        ),
      ],
    );
  }
}

/// Strips the durunubi source's embedded HTML `<br>`/`<br/>` line breaks in
/// favor of real newlines for plain-text rendering.
String _normalizeHtmlBreaks(String text) {
  return text.replaceAll('<br/>', '\n').replaceAll('<br>', '\n');
}

double _minElevation(List<ElevationPoint> points) {
  return points.map((p) => p.elevationM).reduce((a, b) => a < b ? a : b);
}

double _maxElevation(List<ElevationPoint> points) {
  return points.map((p) => p.elevationM).reduce((a, b) => a > b ? a : b);
}

/// Rich durunubi course detail: description/traveler-info/tour-info/
/// elevation summary, each rendered only when non-null/non-empty (honest
/// placeholder rule). When every field is empty, shows a single neutral
/// "no data" note instead of a wall of empty headings.
class _TrailRichDetailSection extends StatelessWidget {
  const _TrailRichDetailSection({required this.detail});

  final TrailDetailResponse detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final description = detail.description;
    final travelerInfo = detail.travelerInfo;
    final tourInfo = detail.tourInfo;
    final elevationProfile = detail.elevationProfile;
    final hasElevation = elevationProfile.length >= 2;

    final hasDescription = description != null && description.isNotEmpty;
    final hasTravelerInfo = travelerInfo != null && travelerInfo.isNotEmpty;
    final hasTourInfo = tourInfo != null && tourInfo.isNotEmpty;

    if (!hasDescription && !hasTravelerInfo && !hasTourInfo && !hasElevation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '두루누비 상세 정보가 없어요',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null && description.isNotEmpty) ...[
          Text('코스 안내', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 24),
        ],
        if (travelerInfo != null && travelerInfo.isNotEmpty) ...[
          Text('오시는 길', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(_normalizeHtmlBreaks(travelerInfo)),
          const SizedBox(height: 24),
        ],
        if (tourInfo != null && tourInfo.isNotEmpty) ...[
          Text('주변 볼거리', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(_normalizeHtmlBreaks(tourInfo)),
          const SizedBox(height: 24),
        ],
        if (hasElevation) ...[
          Text('고도 프로필', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TrailMetaItem(
                label: '최저 표고',
                value: '${_minElevation(elevationProfile).toStringAsFixed(0)}m',
              ),
              _TrailMetaItem(
                label: '최고 표고',
                value: '${_maxElevation(elevationProfile).toStringAsFixed(0)}m',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrailMetaRow extends StatelessWidget {
  const _TrailMetaRow({required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TrailMetaItem(
              label: '거리',
              value: '${course.distanceKm.toStringAsFixed(1)}km',
            ),
            _TrailMetaItem(
              label: '소요 시간',
              value: formatDurationMin(course.durationMin),
            ),
            _TrailMetaItem(label: '난이도', value: formatLevel(course.level)),
            _TrailMetaItem(label: '순환', value: course.cycle),
          ],
        ),
      ),
    );
  }
}

class _TrailMetaItem extends StatelessWidget {
  const _TrailMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: textTheme.titleSmall),
      ],
    );
  }
}

/// Day/night suitability gauges, mirroring course_detail_screen.dart's
/// `_SuitabilitySection` layout: an honest placeholder text (not a gauge)
/// when either side is null, rather than faking a score.
class _TrailSuitabilitySection extends ConsumerWidget {
  const _TrailSuitabilitySection({required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final daySuitability = course.daySuitability;
    final nightSuitability = course.nightSuitability;

    if (daySuitability == null || nightSuitability == null) {
      return Text(
        '이 코스는 밤하늘 관측 조건을 충족하여 포함되었어요',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final currentMode = ref.watch(obsModeProvider).mode;
    final dayAccent = currentMode == ObsMode.day;
    final nightAccent = currentMode == ObsMode.night;
    // Day/night-meaning accents (yellow / lavender); text via accentText.
    final modeColors = LookUpColors.of(context);
    final dayColor = modeColors.modeDayAccent;
    final nightColor = modeColors.modeNightAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Container(
              decoration: dayAccent
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dayColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: ScoreGauge(
                score: daySuitability.score,
                size: 96,
                progressColor: dayColor,
                scoreTextColor: accentText(context, dayColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '낮 적합도',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: dayAccent ? FontWeight.bold : null,
              ),
            ),
            if (daySuitability.status == 'live')
              Text(
                '실시간',
                style: textTheme.labelSmall?.copyWith(
                  color: accentText(context, dayColor),
                  fontSize: 10,
                ),
              ),
          ],
        ),
        Column(
          children: [
            Container(
              decoration: nightAccent
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: nightColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: ScoreGauge(
                score: nightSuitability.score,
                size: 96,
                progressColor: nightColor,
                scoreTextColor: accentText(context, nightColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '밤 적합도',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: nightAccent ? FontWeight.bold : null,
              ),
            ),
            if (nightSuitability.status == 'live')
              Text(
                '실시간',
                style: textTheme.labelSmall?.copyWith(
                  color: accentText(context, nightColor),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
