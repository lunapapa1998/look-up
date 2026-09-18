import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/species.dart';
import '../../state/discovery_providers.dart';
import '../../utils/relative_time.dart';
import '../../utils/spot_name.dart';
import '../observation_spot_sheet.dart';
import 'conservation_badges.dart';
import 'today_tides_section.dart';

/// Bird species wiki-detail view (spec 021 Phase 2): the third level of the
/// sheet's list -> spot detail -> species detail stack, reached by tapping a
/// [SelectedSpecies] row from `BirdSpotDetail` or a scattered individual
/// marker on the map. [selection]'s own observation fields render
/// immediately, independent of network state; the wiki summary/photo below
/// comes from [speciesInfoProvider].
class SpeciesDetail extends ConsumerWidget {
  const SpeciesDetail({
    super.key,
    required this.selection,
    required this.scrollController,
    required this.onBack,
  });

  final SelectedSpecies selection;
  final ScrollController scrollController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final query = (sci: selection.nameSci, ko: selection.nameKo);
    final infoAsync = ref.watch(speciesInfoProvider(query));
    final conservation = infoAsync.valueOrNull?.conservation;
    final isProtectedSpecies = conservation != null &&
        (conservation.koreaEndangered != null ||
            conservation.naturalMonument != null);
    final tidesAsync = ref.watch(
      tideTodayProvider((lat: selection.spotCoord.lat, lng: selection.spotCoord.lng)),
    );
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conservation != null) ...[
                ConservationBadges(conservation: conservation),
                const SizedBox(height: 8),
              ],
              Text(
                selection.nameKo,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                selection.nameSci,
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _SpeciesMediaCard(
          infoAsync: infoAsync,
          onBack: onBack,
          onRetry: () => ref.invalidate(speciesInfoProvider(query)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ObservationCard(
                selection: selection,
                now: now,
                isProtectedSpecies: isProtectedSpecies,
              ),
              const SizedBox(height: 16),
              tidesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (tides) => tides.found
                    ? TodayTidesSection(tides: tides)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              infoAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (info) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '정보',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        info.summaryLong ?? info.summary ?? '설명 준비 중이에요',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Observation-facts card (Figma 62-154 dark-cell restyle) replacing the old
/// borderless flat grid: a "최근 관측 정보" header above a 2-column grid of
/// [colorScheme.surfaceContainerHigh] cell boxes (spot+coords, observed-at
/// time, and an optional headcount cell with a teal accent), boxed in a
/// single [colorScheme.surfaceContainer] card with the community badge and a
/// conditional protected-species notice kept below the grid.
class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.selection,
    required this.now,
    required this.isProtectedSpecies,
  });

  final SelectedSpecies selection;
  final DateTime now;
  final bool isProtectedSpecies;

  static Widget _cell(
    BuildContext context, {
    required String label,
    String? value,
    String? subtitle,
    Color? subtitleColor,
    Widget? valueWidget,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          valueWidget ??
              Text(
                value!,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: subtitleColor ?? colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '최근 관측 정보',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selection.status == 'community') ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'eBird 관측',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _cell(
                  context,
                  label: '관측 위치',
                  value: shortSpotName(selection.spotName),
                  subtitle: '${selection.spotCoord.lat.toStringAsFixed(4)}, '
                      '${selection.spotCoord.lng.toStringAsFixed(4)}',
                  subtitleColor: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _cell(
                  context,
                  label: '관측 시각',
                  valueWidget: Text(
                    formatObservedAt(selection.obsDt, now),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (selection.count != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _cell(
                    context,
                    label: '군집 규모',
                    valueWidget: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${selection.count}',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.secondary,
                            ),
                          ),
                          TextSpan(
                            text: ' 개체',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isProtectedSpecies) ...[
            const SizedBox(height: 8),
            Text(
              '법정 보호종 — 접근·촬영 시 거리 유지',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Padded rounded media card (spec 031: Figma 62-35 visual hierarchy) that
/// replaces the old full-bleed hero: a fixed 176-height photo/loading/error
/// [Stack] so nothing ever shifts layout, with the species name/sci-name/
/// badges living only in the header above -- this card carries just the
/// photo, an optional Wikipedia source caption, and the pinned back button.
class _SpeciesMediaCard extends StatefulWidget {
  const _SpeciesMediaCard({
    required this.infoAsync,
    required this.onBack,
    required this.onRetry,
  });

  final AsyncValue<SpeciesInfo> infoAsync;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  State<_SpeciesMediaCard> createState() => _SpeciesMediaCardState();
}

class _SpeciesMediaCardState extends State<_SpeciesMediaCard> {
  bool _imageLoadFailed = false;

  @override
  void didUpdateWidget(_SpeciesMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.infoAsync.valueOrNull?.thumbnailUrl !=
        widget.infoAsync.valueOrNull?.thumbnailUrl) {
      _imageLoadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = widget.infoAsync;
    final onBack = widget.onBack;
    final onRetry = widget.onRetry;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final info = infoAsync.valueOrNull;
    final hasPhoto = info?.thumbnailUrl != null && !_imageLoadFailed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 176,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              Image.network(
                info!.thumbnailUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_imageLoadFailed) {
                      setState(() => _imageLoadFailed = true);
                    }
                  });
                  return const _SpeciesPhotoPlaceholder();
                },
              )
            else if (infoAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (infoAsync.hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('정보를 불러오지 못했어요'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            else
              const _SpeciesPhotoPlaceholder(),
            if (hasPhoto && info!.source.toLowerCase().contains('wikipedia'))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '출처: Wikipedia',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('obsmap_detail_back_button'),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: '뒤로 가기',
                  onPressed: onBack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain icon-plus-caption fallback shown in place of a species photo, used
/// both when [SpeciesInfo.thumbnailUrl] is null and when [Image.network]
/// fails to load it. Deliberately a stock [Icon], not a hand-drawn painter
/// like `BirdSilhouettePainter` -- this slot is about the missing photo, not
/// a species-agnostic bird glyph.
class _SpeciesPhotoPlaceholder extends StatelessWidget {
  const _SpeciesPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            '사진 준비 중',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
