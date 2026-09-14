import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.watch(nowProvider);
    final query = (sci: selection.nameSci, ko: selection.nameKo);
    final infoAsync = ref.watch(speciesInfoProvider(query));
    final tidesAsync = ref.watch(
      tideTodayProvider((lat: selection.spotCoord.lat, lng: selection.spotCoord.lng)),
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('obsmap_detail_back_button'),
              icon: const Icon(Icons.arrow_back),
              tooltip: '뒤로 가기',
              onPressed: onBack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        infoAsync.when(
          loading: () => const _SpeciesPhotoBox(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _SpeciesPhotoBox(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('정보를 불러오지 못했어요'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(speciesInfoProvider(query)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          data: (info) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.conservation != null) ...[
                ConservationBadges(conservation: info.conservation!),
                const SizedBox(height: 12),
              ],
              _SpeciesPhotoBox(
                child: info.thumbnailUrl != null
                    ? Image.network(
                        info.thumbnailUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const _SpeciesPhotoPlaceholder(),
                      )
                    : const _SpeciesPhotoPlaceholder(),
              ),
              if (info.source.toLowerCase().contains('wikipedia')) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    '출처: Wikipedia',
                    textAlign: TextAlign.end,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
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
        const Divider(),
        if (selection.count != null)
          Text(
            '관측 ${selection.count}마리',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text('관측 ${formatRelativeTime(selection.obsDt, now)}'),
        Text(
          '${shortSpotName(selection.spotName)} '
          '(${selection.spotCoord.lat.toStringAsFixed(4)}, '
          '${selection.spotCoord.lng.toStringAsFixed(4)})',
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
          data: (tides) =>
              tides.found ? TodayTidesSection(tides: tides) : const SizedBox.shrink(),
        ),
      ],
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

/// Fixed 240-height photo slot shared by [SpeciesDetail]'s loading/error/data
/// states, so the layout doesn't jump as [speciesInfoProvider] resolves. Tall
/// enough that a `BoxFit.contain` wiki thumbnail shows in full without cropping.
class _SpeciesPhotoBox extends StatelessWidget {
  const _SpeciesPhotoBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 240,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
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
