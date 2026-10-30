import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/observation.dart';
import '../state/providers.dart';
import '../theme/lookup_colors.dart';
import '../widgets/app_header_logo.dart';
import 'badges_screen.dart';
import 'observation_form_screen.dart';

/// Home screen: list of observations, backed by [observationsProvider].
class DiaryListScreen extends ConsumerWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsAsync = ref.watch(observationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [AppHeaderLogo(), SizedBox(width: 8), Text('관찰 일지')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: '배지',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
          ),
        ],
      ),
      body: observationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('관찰 기록을 불러오지 못했어요.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(observationsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (observations) => observations.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: observations.length,
                itemBuilder: (context, index) =>
                    _ObservationCard(observation: observations[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ObservationFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('아직 관찰 기록이 없어요.'),
          const SizedBox(height: 4),
          const Text('+ 버튼을 눌러 첫 새 또는 별 관찰을 기록해보세요.'),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final Observation observation;

  const _ObservationCard({required this.observation});

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isBird = observation.speciesType == SpeciesType.bird;
    final photoUrl = observation.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: hasPhoto
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _SpeciesIconPlaceholder(isBird: isBird),
                  ),
                )
              : _SpeciesIconPlaceholder(isBird: isBird),
        ),
        title: Text(observation.speciesName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (observation.note != null && observation.note!.isNotEmpty)
              Text(observation.note!),
            Text(
              _formatDateTime(observation.observedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        isThreeLine: observation.note != null && observation.note!.isNotEmpty,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ObservationFormScreen(existing: observation),
          ),
        ),
      ),
    );
  }
}

class _SpeciesIconPlaceholder extends StatelessWidget {
  final bool isBird;

  const _SpeciesIconPlaceholder({required this.isBird});

  @override
  Widget build(BuildContext context) {
    // Bird = day observation (yellow), star = night observation (lavender).
    final modeColors = LookUpColors.of(context);
    return Center(
      child: Icon(
        isBird ? Icons.flutter_dash : Icons.star,
        color: isBird ? modeColors.modeDayAccent : modeColors.modeNightAccent,
      ),
    );
  }
}
