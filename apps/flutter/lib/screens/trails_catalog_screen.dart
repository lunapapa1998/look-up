import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../widgets/course_card.dart';
import 'course_detail_screen.dart';

class TrailsCatalogScreen extends ConsumerWidget {
  const TrailsCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailsAsync = ref.watch(trailsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('트레일·노포')),
      body: trailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => _ErrorState(
          onRetry: () => ref.invalidate(trailsProvider),
        ),
        data: (response) {
          final courses = response.courses;
          if (!response.degraded && courses.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (response.degraded)
                _DegradedBanner(onRetry: () => ref.invalidate(trailsProvider)),
              if (courses.isNotEmpty)
                ..._buildCatalogContent(context, response),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCatalogContent(
    BuildContext context,
    TrailsResponse response,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final courses = response.courses;
    final remaining = courses.sublist(1);

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: colorScheme.secondary),
              const SizedBox(width: 4),
              Text(response.region, style: textTheme.labelMedium),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '밤하늘이 가장 어두운 순서예요',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      CourseCard(
        course: courses.first,
        featured: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(course: courses.first),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '이 권역의 다른 코스 · ${remaining.length}개',
        style: textTheme.titleSmall,
      ),
      const SizedBox(height: 12),
      for (final course in remaining) ...[
        CourseCard(
          course: course,
          featured: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
