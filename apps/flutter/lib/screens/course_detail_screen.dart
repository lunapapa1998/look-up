import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discovery.dart';
import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../utils/trail_format.dart';
import '../widgets/heritage_eats_list.dart';
import '../widgets/night_sky_tag.dart';
import '../widgets/score_gauge.dart';

/// Detail screen for a single [TrailCourse], pushed from a catalog card tap.
/// Takes the already-fetched [course] directly — no re-fetch from any
/// provider or API here.
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final featured = course.daySuitability != null;

    return Scaffold(
      appBar: AppBar(title: Text(course.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.name, style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              course.sigun,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (featured) ...[
              const SizedBox(height: 8),
              const _FeaturedBadge(),
            ],
            const SizedBox(height: 16),
            _MetaRow(course: course),
            const SizedBox(height: 24),
            Text('종점 밤하늘 관측 조건', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            NightSkyTag(nightSky: course.nightSky, large: true),
            const SizedBox(height: 24),
            _SuitabilitySection(course: course),
            const SizedBox(height: 24),
            Text('관측 후 들르기 좋은 곳', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            HeritageEatsList(eats: course.heritageEats),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '밤하늘이 가장 어두운 순서예요',
        style: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.course});

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
            _MetaItem(
              label: '거리',
              value: '${course.distanceKm.toStringAsFixed(1)}km',
            ),
            _MetaItem(
              label: '소요 시간',
              value: formatDurationMin(course.durationMin),
            ),
            _MetaItem(label: '난이도', value: formatLevel(course.level)),
            _MetaItem(label: '순환', value: course.cycle),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

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

class _SuitabilitySection extends StatelessWidget {
  const _SuitabilitySection({required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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

    return Consumer(
      builder: (context, ref, child) {
        final currentMode = ref.watch(obsModeProvider).mode;
        final dayAccent = currentMode == ObsMode.day;
        final nightAccent = currentMode == ObsMode.night;

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
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: ScoreGauge(
                    score: daySuitability.score,
                    size: 96,
                    progressColor: colorScheme.tertiary,
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
                      color: colorScheme.tertiary,
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
                              color: colorScheme.secondary.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: ScoreGauge(
                    score: nightSuitability.score,
                    size: 96,
                    progressColor: colorScheme.secondary,
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
                      color: colorScheme.secondary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
