import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/observation.dart';
import '../state/providers.dart';

/// Grid of badge progress, backed by [badgesProvider].
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('배지')),
      body: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('배지 정보를 불러오지 못했어요.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(badgesProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (badges) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) => _BadgeCard(progress: badges[index]),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeProgress progress;

  const _BadgeCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final badge = progress.badge;
    final achieved = progress.achieved;
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: achieved ? 1.0 : 0.5,
      child: Card(
        color: achieved ? colorScheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                achieved ? Icons.emoji_events : Icons.emoji_events_outlined,
                size: 40,
                color: achieved ? colorScheme.onSurface : colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                badge.name,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                badge.description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (progress.currentCount / badge.targetCount).clamp(0.0, 1.0),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.currentCount} / ${badge.targetCount}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
