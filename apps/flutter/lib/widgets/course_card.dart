import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discovery.dart';
import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../utils/trail_format.dart';
import 'night_sky_tag.dart';
import 'score_gauge.dart';

/// Course card shared by the featured spot and the regular list on the
/// trails catalog screen. Both variants render the identical
/// [_CourseCardCore] (name/meta/nightSky) — [featured] only appends extra
/// slots below it (border, dual suitability gauges, heritage preview).
/// There is no separate reduced-layout path for the list variant.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.featured,
    required this.onTap,
  });

  final TrailCourse course;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticLabel = featured
        ? '대표 코스, ${course.name}, 밤하늘 가장 어두움'
        : course.name;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: featured
              ? BorderSide(color: colorScheme.secondary, width: 1)
              : BorderSide.none,
        ),
        child: Semantics(
          label: semanticLabel,
          button: true,
          container: true,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CourseCardCore(course: course),
                  if (featured) ..._buildFeaturedExtras(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeaturedExtras(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final daySuitability = course.daySuitability!;
    final nightSuitability = course.nightSuitability!;

    return [
      const SizedBox(height: 12),
      Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      Consumer(
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
                      size: 72,
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
                      size: 72,
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
      ),
      if (course.heritageEats.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.storefront,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${course.heritageEats.first.name} 등 인근 노포 '
                '${course.heritageEats.length}곳',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    ];
  }
}

/// Shared name/meta-row/nightSky tree. Both featured and non-featured
/// [CourseCard]s call this same core — never a second, reduced tree.
class _CourseCardCore extends StatelessWidget {
  const _CourseCardCore({required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(course.name, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${course.distanceKm.toStringAsFixed(1)}km · '
          '${formatDurationMin(course.durationMin)} · '
          '${formatLevel(course.level)} · ${course.cycle}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        NightSkyTag(nightSky: course.nightSky),
      ],
    );
  }
}
