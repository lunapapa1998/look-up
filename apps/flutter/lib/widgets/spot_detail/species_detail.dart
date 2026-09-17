import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        _SpeciesHero(
          selection: selection,
          infoAsync: infoAsync,
          onBack: onBack,
          onRetry: () => ref.invalidate(speciesInfoProvider(query)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              infoAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (info) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WikiSummaryText(
                      text: info.summaryLong ?? info.summary ?? '설명 준비 중이에요',
                    ),
                    if (info.wikiUrl != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () {
                          final url = info.wikiUrl ?? '';
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('링크를 복사했어요')),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('위키백과에서 보기'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ObservationCard(
                selection: selection,
                now: now,
                isProtectedSpecies: isProtectedSpecies,
              ),
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Observation-facts card (spec 029 Phase 2) replacing the old divider-plus-
/// text block: the same real data (headcount/relative-time/spot+coords),
/// now icon-prefixed and boxed in a single [colorScheme.surfaceContainer]
/// card, with the community badge and a conditional protected-species notice
/// kept inside.
class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.selection,
    required this.now,
    required this.isProtectedSpecies,
  });

  final SelectedSpecies selection;
  final DateTime now;
  final bool isProtectedSpecies;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selection.count != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '관측 ${selection.count}마리',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('관측 ${formatRelativeTime(selection.obsDt, now)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${shortSpotName(selection.spotName)} '
                  '(${selection.spotCoord.lat.toStringAsFixed(4)}, '
                  '${selection.spotCoord.lng.toStringAsFixed(4)})',
                ),
              ),
            ],
          ),
          if (selection.status == 'community') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '커뮤니티 관측',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
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

/// Full-bleed 240-height hero banner (spec 029 Phase 1) replacing the old
/// small centered photo card: a fixed-size [Stack] so the loading/error/photo
/// backgrounds never shift layout, with the species name/sci-name/badges
/// overlaid at the bottom and the back button always pinned top-left.
class _SpeciesHero extends StatefulWidget {
  const _SpeciesHero({
    required this.selection,
    required this.infoAsync,
    required this.onBack,
    required this.onRetry,
  });

  final SelectedSpecies selection;
  final AsyncValue<SpeciesInfo> infoAsync;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  State<_SpeciesHero> createState() => _SpeciesHeroState();
}

class _SpeciesHeroState extends State<_SpeciesHero> {
  bool _imageLoadFailed = false;

  @override
  void didUpdateWidget(_SpeciesHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.infoAsync.valueOrNull?.thumbnailUrl !=
        widget.infoAsync.valueOrNull?.thumbnailUrl) {
      _imageLoadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final infoAsync = widget.infoAsync;
    final onBack = widget.onBack;
    final onRetry = widget.onRetry;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final info = infoAsync.valueOrNull;
    final hasPhoto = info?.thumbnailUrl != null && !_imageLoadFailed;

    return SizedBox(
      height: 240,
      width: double.infinity,
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
            Container(
              color: colorScheme.surfaceContainer,
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (infoAsync.hasError)
            Container(
              color: colorScheme.surfaceContainer,
              child: Center(
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
              ),
            )
          else
            const _SpeciesPhotoPlaceholder(),
          if (hasPhoto)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selection.nameKo,
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      selection.nameSci,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (info!.conservation != null) ...[
                      const SizedBox(height: 8),
                      ConservationBadges(conservation: info.conservation!),
                    ],
                    if (info.source.toLowerCase().contains('wikipedia')) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          '출처: Wikipedia',
                          textAlign: TextAlign.end,
                          style: textTheme.labelSmall
                              ?.copyWith(color: Colors.white60),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selection.nameKo,
                      style: textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      selection.nameSci,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (info?.conservation != null) ...[
                      const SizedBox(height: 8),
                      ConservationBadges(conservation: info!.conservation!),
                    ],
                  ],
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
    );
  }
}

/// Collapsible wiki summary paragraph: starts clamped to 4 lines with a
/// "더보기" toggle, matching long wiki extracts ([SpeciesInfo.summaryLong])
/// without pushing the rest of the sheet down until the user asks for it.
class _WikiSummaryText extends StatefulWidget {
  const _WikiSummaryText({required this.text});

  final String text;

  @override
  State<_WikiSummaryText> createState() => _WikiSummaryTextState();
}

class _WikiSummaryTextState extends State<_WikiSummaryText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: expanded ? null : 4,
          overflow: expanded ? null : TextOverflow.ellipsis,
        ),
        Semantics(
          toggled: expanded,
          label: expanded ? '요약 접기' : '요약 더보기',
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(expanded ? '접기' : '더보기'),
          ),
        ),
      ],
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
