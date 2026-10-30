import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trails.dart';
import '../theme/layout_tokens.dart';
import '../state/discovery_providers.dart';
import '../state/sample_data_provider.dart';
import '../widgets/common/lookup_header.dart';
import '../widgets/common/lookup_scroll_behavior.dart';
import '../widgets/common/mode_toggle.dart';
import '../widgets/common/status_view.dart';
import '../widgets/course_card.dart';
import '../widgets/sample_data_notice.dart';
import '../utils/keep_all.dart';
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
  @override
  Widget build(BuildContext context) {
    final trails = ref.watch(trailsProvider);
    final regionsAsync = ref.watch(regionsProvider);
    final isTrailsSample = ref
        .watch(sampleSourcesProvider)
        .contains(SampleSource.trails);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: trails.when(
          loading: () => const CustomScrollView(
            slivers: [
              LookUpSliverHeader(modeToggle: ObsModeToggle()),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (err, st) => CustomScrollView(
            slivers: [
              const LookUpSliverHeader(modeToggle: ObsModeToggle()),
              // hasScrollBody: true -- StatusView's LayoutBuilder cannot
              // report intrinsic heights, which hasScrollBody: false needs.
              SliverFillRemaining(
                hasScrollBody: true,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: StatusView.error(
                      message: '트레일 정보를 불러오지 못했어요',
                      onRetry: () => ref.invalidate(trailsProvider),
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (response) {
            final courses = response.courses;
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
                const LookUpSliverHeader(modeToggle: ObsModeToggle()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SampleDataNotice(
                      sources: const {SampleSource.trails, SampleSource.regions},
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      onRetry: () {
                        ref.invalidate(trailsProvider);
                        ref.invalidate(regionsProvider);
                      },
                    ),
                  ),
                ),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: StatusView.degraded(
                        onRetry: () => ref.invalidate(trailsProvider),
                      ),
                    ),
                  ),
                regionsAsync.when(
                  data: (regionsResponse) {
                    if (regionsResponse.regions.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      );
                    }
                    final effectiveRegion =
                        ref.watch(selectedRegionProvider) ??
                        regionsResponse.nearestId;
                    return SliverToBoxAdapter(
                      child: ScrollConfiguration(
                        behavior: const LookUpScrollBehavior(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: Row(
                            children: [
                              for (final region in regionsResponse.regions)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.sm,
                                  ),
                                  child: ChoiceChip(
                                    key: Key('trail_region_${region.id}'),
                                    avatar:
                                        region.id == regionsResponse.nearestId
                                        ? Icon(
                                            Icons.near_me,
                                            size: 16,
                                            color: effectiveRegion == region.id
                                                ? colors.onPrimary
                                                : colors.onSurfaceVariant,
                                          )
                                        : null,
                                    label: Text(region.label),
                                    selected: effectiveRegion == region.id,
                                    // Neutral (black/white) selected fill.
                                    selectedColor: colors.primary,
                                    // Bundled Bithumb Gothic labelLarge, not the
                                    // runtime-loaded mono labelMedium that
                                    // clipped labels on web (see
                                    // packages_catalog_screen.dart).
                                    labelStyle: text.labelLarge?.copyWith(
                                      color: effectiveRegion == region.id
                                          ? colors.onPrimary
                                          : colors.onSurfaceVariant,
                                    ),
                                    padding: catalogChipPadding,
                                    labelPadding: catalogChipLabelPadding,
                                    visualDensity: VisualDensity.standard,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.padded,
                                    onSelected: (_) => ref
                                        .read(selectedRegionProvider.notifier)
                                        .state = region.id,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  ),
                  error: (_, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
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
                            isSample: isTrailsSample,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: courses.first),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RouteStops(course: courses.first),
                          const SizedBox(height: AppSpacing.xl),
                          const _SectionTitle(
                            eyebrow: 'LOCAL HERITAGE',
                            title: '관찰 후 들르는 지역 식당',
                            description: '코스 종점 주변, 함께 둘러보기 좋은 곳',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (nearby.isEmpty)
                            const Text('이 코스 주변에는 아직 등록된 식당이 없어요'),
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
                          isSample: isTrailsSample,
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
                            isSample: isTrailsSample,
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

const trailsIntroDescription =
    '낮에는 숲과 바다의 새소리를 걷고, 밤에는 별빛 아래 쉬어가는 저탄소 도보길';

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
            color: colors.onSurfaceVariant,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('두루누비 코리아둘레길', style: text.headlineSmall),
        Text(
          '생태 관찰 트레일',
          style: text.headlineSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          keepAll(trailsIntroDescription),
          semanticsLabel: trailsIntroDescription,
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
            color: colors.onSurfaceVariant,
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
                      style: text.labelSmall?.copyWith(color: colors.onSurface),
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
  const _HeritageCard({
    required this.eat,
    required this.course,
    this.isSample = false,
  });
  final HeritageEat eat;
  final TrailCourse course;
  final bool isSample;
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
                child: Icon(
                  Icons.storefront,
                  color: colors.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '종점에서 ${formatDistanceM(eat.distanceM)}',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (isSample)
                      Row(
                        children: [
                          Flexible(
                            child: Text(eat.name, style: text.titleMedium),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const SampleMark(),
                        ],
                      )
                    else
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

/// Neutral "nothing here" state -- deliberately avoids every error color
/// token (errorContainer/error/onErrorContainer) and the warning icon so it
/// stays visually distinguishable from the degraded [StatusView] by color
/// alone.
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
