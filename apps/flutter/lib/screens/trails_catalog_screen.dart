import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trails.dart';
import '../theme/layout_tokens.dart';
import '../state/discovery_providers.dart';
import '../widgets/app_header_logo.dart';
import '../widgets/course_card.dart';
import '../utils/trail_format.dart';
import 'course_detail_screen.dart';
import 'trail_route_screen.dart';

class TrailsCatalogScreen extends ConsumerStatefulWidget {
  const TrailsCatalogScreen({super.key});
  @override
  ConsumerState<TrailsCatalogScreen> createState() =>
      _TrailsCatalogScreenState();
}

class _TrailsCatalogScreenState extends ConsumerState<TrailsCatalogScreen> {
  String? _region;

  @override
  Widget build(BuildContext context) {
    final trails = ref.watch(trailsProvider);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: Row(
          children: [
            const AppHeaderLogo(),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('위를 봐요', style: text.titleMedium),
                Text(
                  'LOOK UP',
                  style: text.labelSmall?.copyWith(
                    color: colors.secondary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Flexible(
              child: Text(
                trails.valueOrNull?.region ?? '트레일·노포',
                style: text.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: trails.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) =>
              _ErrorState(onRetry: () => ref.invalidate(trailsProvider)),
          data: (response) {
            final regions = response.courses
                .map((c) => c.sigun)
                .toSet()
                .toList();
            final selected = regions.contains(_region) ? _region : null;
            final courses = response.courses
                .where((c) => selected == null || c.sigun == selected)
                .toList();
            final eats = <String, (HeritageEat, TrailCourse)>{};
            for (final course in courses) {
              for (final eat in course.heritageEats) {
                final id = eat.contentId.isEmpty
                    ? '${eat.name}-${eat.lat}-${eat.lng}'
                    : eat.contentId;
                final existing = eats[id];
                if (existing == null || eat.distanceM < existing.$1.distanceM) {
                  eats[id] = (eat, course);
                }
              }
            }
            final nearby = eats.values.toList()
              ..sort((a, b) => a.$1.distanceM.compareTo(b.$1.distanceM));
            return CustomScrollView(
              key: const Key('trails_catalog_scroll'),
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(child: _CatalogIntro()),
                ),
                if (response.degraded)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _DegradedBanner(
                        onRetry: () => ref.invalidate(trailsProvider),
                      ),
                    ),
                  ),
                if (regions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      child: Row(
                        children: [
                          for (final region in [null, ...regions])
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ChoiceChip(
                                key: Key('trail_region_${region ?? 'all'}'),
                                label: Text(region ?? '전체 권역'),
                                selected: selected == region,
                                selectedColor: colors.secondary,
                                labelStyle: text.labelMedium?.copyWith(
                                  color: selected == region
                                      ? colors.onSecondary
                                      : colors.onSurfaceVariant,
                                ),
                                onSelected: (_) =>
                                    setState(() => _region = region),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (courses.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  ),
                if (courses.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.lg,
                      AppSpacing.page,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '밤하늘이 가장 어두운 순서예요',
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CourseCard(
                            course: courses.first,
                            featured: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: courses.first),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RouteStops(course: courses.first),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('trail_gpx_open'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TrailRouteScreen(course: courses.first),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('GPX 코스 지도 보기'),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const _SectionTitle(
                            eyebrow: 'LOCAL HERITAGE',
                            title: '관찰 후 들르는 지역 노포',
                            description: '코스 종점 주변, 함께 둘러보기 좋은 곳',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (nearby.isEmpty)
                            const Text('이 코스 주변에는 아직 등록된 노포가 없어요'),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    sliver: SliverList.builder(
                      itemCount: nearby.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _HeritageCard(
                          eat: nearby[i].$1,
                          course: nearby[i].$2,
                        ),
                      ),
                    ),
                  ),
                  if (courses.length > 1) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.xl,
                        AppSpacing.page,
                        AppSpacing.md,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '이 권역의 다른 코스 · ${courses.length - 1}개',
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      sliver: SliverList.builder(
                        itemCount: courses.length - 1,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: CourseCard(
                            course: courses[i + 1],
                            featured: false,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: courses[i + 1]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CatalogIntro extends StatelessWidget {
  const _CatalogIntro();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DURUNUBI × ECO-OBSERVATORY',
          style: text.labelSmall?.copyWith(
            color: colors.secondary,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('두루누비 코리아둘레길', style: text.headlineSmall),
        Text(
          '생태 관찰 트레일',
          style: text.headlineSmall?.copyWith(color: colors.secondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '낮에는 숲과 바다의 새소리를 걷고, 밤에는 별빛 아래 쉬어가는 저탄소 도보길',
          style: text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: text.labelSmall?.copyWith(
            color: colors.tertiary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(title, style: text.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RouteStops extends StatelessWidget {
  const _RouteStops({required this.course});
  final TrailCourse course;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final stops = [('출발 지점', course.start), ('도착 · 밤하늘 관측 지점', course.end)];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('코스 주요 지점', style: text.titleSmall),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < stops.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colors.surfaceContainerHigh,
                    child: Text(
                      '${i + 1}',
                      style: text.labelSmall?.copyWith(color: colors.secondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stops[i].$1, style: text.bodyMedium),
                        Text(
                          '${stops[i].$2.lat.toStringAsFixed(4)}, ${stops[i].$2.lng.toStringAsFixed(4)}',
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeritageCard extends StatelessWidget {
  const _HeritageCard({required this.eat, required this.course});
  final HeritageEat eat;
  final TrailCourse course;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('trail_heritage_${eat.contentId}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrailRouteScreen(course: course, eat: eat),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.storefront, color: colors.tertiary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '종점에서 ${formatDistanceM(eat.distanceM)}',
                      style: text.labelSmall?.copyWith(color: colors.tertiary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(eat.name, style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      eat.addr,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors the degraded banner in home_discovery_screen.dart (errorContainer
/// background, warning_amber_rounded icon, onErrorContainer text) plus a
/// retry button this screen requires that the home banner does not have.
class _DegradedBanner extends StatelessWidget {
  const _DegradedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '일부 데이터를 불러오지 못했어요',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              '다시 시도',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral "nothing here" state -- deliberately avoids every error color
/// token (errorContainer/error/onErrorContainer) and the warning icon so it
/// stays visually distinguishable from [_DegradedBanner] by color alone.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: colorScheme.surfaceContainer,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '이 권역에는 아직 등록된 코스가 없어요',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('트레일 정보를 불러오지 못했어요', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
