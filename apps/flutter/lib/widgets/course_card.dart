import 'package:flutter/material.dart';

import '../models/trails.dart';
import '../theme/layout_tokens.dart';
import '../utils/trail_format.dart';
import 'night_sky_tag.dart';
import 'trails/trail_map.dart';

/// Both variants share the same course data and detail destination.
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
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: featured
            ? BorderSide(color: colors.secondary.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: Semantics(
        label: featured ? '대표 코스, ${course.name}' : course.name,
        button: true,
        child: InkWell(
          key: Key('trail_course_${course.crsIdx}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (featured)
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(child: TrailMap(course: course)),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  colors.surfaceContainer,
                                ],
                                stops: const [0.35, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CourseBadge(
                              label: '두루누비 코스',
                              color: colors.secondary,
                            ),
                            _CourseBadge(
                              label: 'Day-to-Night',
                              color: colors.tertiary,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ECO OBSERVATION ROUTE',
                              style: text.labelSmall?.copyWith(
                                color: colors.secondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(course.name, style: text.titleLarge),
                            Text(
                              '${course.sigun} · ${course.cycle}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!featured) ...[
                      Text(course.name, style: text.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _CourseMeta(course: course),
                    const SizedBox(height: AppSpacing.md),
                    NightSkyTag(nightSky: course.nightSky),
                    if (featured) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ObservationPanel(
                        label: '낮 적합도',
                        subtitle: '숲과 바다를 걷는 생태 관찰',
                        suitability: course.daySuitability,
                        color: colors.tertiary,
                        icon: Icons.wb_sunny_outlined,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ObservationPanel(
                        label: '밤 적합도',
                        subtitle: '코스 종점의 밤하늘 관측 조건',
                        suitability: course.nightSuitability,
                        color: colors.secondary,
                        icon: Icons.nightlight_round,
                      ),
                      if (course.heritageEats.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${course.heritageEats.first.name} 등 인근 노포 '
                          '${course.heritageEats.length}곳',
                          style: text.bodySmall,
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '코스 자세히 보기',
                          style: text.labelMedium?.copyWith(
                            color: colors.secondary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colors.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseBadge extends StatelessWidget {
  const _CourseBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    ),
  );
}

class _CourseMeta extends StatelessWidget {
  const _CourseMeta({required this.course});
  final TrailCourse course;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? 2
          : 4;
      final values = [
        ('총 거리', '${course.distanceKm.toStringAsFixed(1)}km'),
        ('소요 시간', formatDurationMin(course.durationMin)),
        ('코스 난이도', formatLevel(course.level)),
        ('코스 유형', course.cycle),
      ];
      return Wrap(
        runSpacing: 12,
        children: [
          for (final value in values)
            SizedBox(
              width: constraints.maxWidth / columns,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value.$2,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _ObservationPanel extends StatelessWidget {
  const _ObservationPanel({
    required this.label,
    required this.subtitle,
    required this.suitability,
    required this.color,
    required this.icon,
  });
  final String label;
  final String subtitle;
  final CourseSuitability? suitability;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              Text(label, style: text.labelMedium?.copyWith(color: color)),
              if (suitability != null)
                Text(
                  '${suitability!.score} / 100',
                  style: text.labelMedium?.copyWith(color: color),
                ),
              if (suitability != null)
                Text(
                  suitability!.status == 'live' ? '실시간' : '참고값',
                  style: text.bodySmall,
                ),
            ],
          ),
          if (suitability != null) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: suitability!.score.clamp(0, 100) / 100,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(suitability?.label ?? '관측 적합도 정보가 없어요', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
