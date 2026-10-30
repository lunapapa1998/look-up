import 'package:flutter/material.dart';

import '../models/observation_map.dart';
import '../models/trails.dart';
import '../theme/layout_tokens.dart';
import '../utils/observation_spot_filter.dart';
import '../utils/spot_name.dart';
import '../utils/trail_format.dart';
import 'observation_spot_detail.dart';
import 'sample_data_notice.dart';
import 'spot_detail/species_detail.dart';

/// Resting ("peek") extent of [ObservationSpotSheet] as a fraction of screen
/// height -- also the lower bound for handle-drag resizing and one of the
/// three snap points. Shared with observation_map_screen.dart so the peek
/// overlay fade threshold and the sheet's own peek stay in sync.
const double kObsSheetPeek = 0.24;

/// One bird species tapped from a bird spot's measurement list or its
/// on-map scatter marker -- carries both the species' own observation
/// fields and the spot context needed to render [SpeciesDetail] without a
/// back-reference to the originating [ObservationSpot]/[ScatteredBird].
typedef SelectedSpecies = ({
  String nameKo,
  String nameSci,
  int? count,
  String obsDt,
  String spotName,
  Coordinate spotCoord,
  String status,
});

/// 3-snap draggable bottom sheet over the observation map: a spot list at
/// rest, expandable to a half/full sheet, swapping to
/// [ObservationSpotDetail] once a spot is selected, or to [SpeciesDetail]
/// once a species is selected from within that detail view.
///
/// Measurement values (species count, SQM, distance) and the suitability
/// score live in strictly separate blocks inside [ObservationSpotDetail] --
/// never on the same row -- per the trail-screen precedent.
class ObservationSpotSheet extends StatelessWidget {
  const ObservationSpotSheet({
    super.key,
    required this.spots,
    required this.selectedSpot,
    this.selectedTrail,
    this.selectedSpecies,
    required this.onSelectSpot,
    required this.onSelectSpecies,
    required this.onBack,
    required this.sheetController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.sqmFilterActive,
    required this.onSqmFilterChanged,
    this.isSample = false,
  });

  final List<ObservationSpot> spots;
  final ObservationSpot? selectedSpot;
  final TrailCourse? selectedTrail;
  final SelectedSpecies? selectedSpecies;
  final void Function(ObservationSpot) onSelectSpot;
  final ValueChanged<SelectedSpecies> onSelectSpecies;
  final VoidCallback onBack;
  final DraggableScrollableController sheetController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final SpotSort sortBy;
  final ValueChanged<SpotSort> onSortChanged;
  final bool sqmFilterActive;
  final ValueChanged<bool> onSqmFilterChanged;

  /// [spots] come from demo sample data (spec 052): each list row gets a
  /// [SampleMark].
  final bool isSample;

  /// Same kind -> color mapping as [ObservationMarker]'s pins.
  static Color kindColor(ColorScheme colorScheme, String kind) {
    switch (kind) {
      case 'bird':
        return colorScheme.secondary;
      case 'star':
        return colorScheme.tertiary;
      case 'heritage':
      default:
        return const Color(0xFF8A7A68);
    }
  }

  String _measurementSummary(ObservationSpot spot) {
    switch (spot.kind) {
      case 'bird':
        return '조류 ${spot.birds!.speciesCount}종';
      case 'star':
        return 'SQM ${spot.nightSky!.sqmValue.toStringAsFixed(2)}';
      case 'heritage':
      default:
        final distanceM = spot.heritage!.distanceM;
        return distanceM != null
            ? formatDistanceM(distanceM)
            : spot.heritage!.addr;
    }
  }

  int _countKind(String kind) => spots.where((s) => s.kind == kind).length;

  /// Drives handle-drag resizing: dragging up (negative `dy`) grows the
  /// sheet, dragging down shrinks it, clamped to [kObsSheetPeek, 0.9].
  void _handleHandleDragUpdate(BuildContext context, DragUpdateDetails details) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final newSize = sheetController.size - details.delta.dy / screenHeight;
    sheetController.jumpTo(newSize.clamp(kObsSheetPeek, 0.9));
  }

  /// Snaps to whichever of the three stops is closest to where the drag let go.
  void _handleHandleDragEnd(DragEndDetails details) {
    const snapSizes = [kObsSheetPeek, 0.45, 0.9];
    final currentSize = sheetController.size;
    final nearest = snapSizes.reduce(
      (a, b) => (a - currentSize).abs() < (b - currentSize).abs() ? a : b,
    );
    sheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFilteredEmpty =
        spots.isEmpty && (searchQuery.trim().isNotEmpty || sqmFilterActive);
    final isDetail =
        selectedSpot != null || selectedTrail != null || selectedSpecies != null;

    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: kObsSheetPeek,
      minChildSize: kObsSheetPeek,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [kObsSheetPeek, 0.45, 0.9],
      builder: (context, scrollController) {
        return Material(
          // Sheet sits one elevation below its cards so the rounded card
          // sections (오늘의 물때 / 최근 관측 정보 = surfaceContainer) stay
          // visible against it -- matching Figma's darker-panel hierarchy.
          color: colorScheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              GestureDetector(
                key: const Key('obsmap_sheet_handle'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) =>
                    _handleHandleDragUpdate(context, details),
                onVerticalDragEnd: _handleHandleDragEnd,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (!isDetail)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관찰 스팟 ${spots.length}곳',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '조류 ${_countKind('bird')} · 별 ${_countKind('star')} · '
                              '노포 ${_countKind('heritage')}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!isDetail)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _SpotSearchField(
                    searchQuery: searchQuery,
                    onSearchChanged: onSearchChanged,
                  ),
                ),
              Expanded(
                // The sort/SQM chips live INSIDE the scroll view (not the
                // search field, which is a fixed sibling above) so the
                // collapsed peek (kObsSheetPeek) never overflows: at peek
                // only the grabber+header+search field fit and everything
                // below scrolls. Non-lazy list is fine (spots <= ~18).
                child: selectedSpecies != null
                    ? SpeciesDetail(
                        selection: selectedSpecies!,
                        scrollController: scrollController,
                        onBack: onBack,
                      )
                    : isDetail
                    ? ObservationSpotDetail(
                        spot: selectedSpot,
                        trail: selectedTrail,
                        scrollController: scrollController,
                        onBack: onBack,
                        onSelectSpecies: onSelectSpecies,
                      )
                    : ListView(
                        controller: scrollController,
                        children: [
                          _SpotFilterChips(
                            sortBy: sortBy,
                            onSortChanged: onSortChanged,
                            sqmFilterActive: sqmFilterActive,
                            onSqmFilterChanged: onSqmFilterChanged,
                          ),
                          if (isFilteredEmpty)
                            const _EmptyFilterResult()
                          else
                            for (final spot in spots)
                              InkWell(
                                key: Key('obsmap_spot_item_${spot.id}'),
                                onTap: () => onSelectSpot(spot),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 10,
                                        color:
                                            kindColor(colorScheme, spot.kind),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          shortSpotName(spot.name),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSample) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        const SampleMark(compact: true),
                                      ],
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _measurementSummary(spot),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                          style: textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Search field shown above the spot list as a fixed (non-scrolling) sibling
/// of the scroll view, so it stays visible at every sheet size -- own widget
/// class per this codebase's no-private-build-method convention, see
/// `_LocationFallbackBanner` in observation_map_screen.dart for the pattern.
class _SpotSearchField extends StatelessWidget {
  const _SpotSearchField({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '스팟 이름으로 검색',
      child: TextField(
        key: const Key('obsmap_search_field'),
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: '스팟 이름으로 검색',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Sort/SQM-filter chip row shown as the top item of the scrollable spot
/// list (list view only, never above [ObservationSpotDetail]).
class _SpotFilterChips extends StatelessWidget {
  const _SpotFilterChips({
    required this.sortBy,
    required this.onSortChanged,
    required this.sqmFilterActive,
    required this.onSqmFilterChanged,
  });

  final SpotSort sortBy;
  final ValueChanged<SpotSort> onSortChanged;
  final bool sqmFilterActive;
  final ValueChanged<bool> onSqmFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              height: 44,
              child: Center(
                child: ChoiceChip(
                  key: const Key('obsmap_sort_distance'),
                  label: const Text('거리순'),
                  selected: sortBy == SpotSort.distance,
                  onSelected: (_) => onSortChanged(SpotSort.distance),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: Center(
                child: ChoiceChip(
                  key: const Key('obsmap_sort_recent'),
                  label: const Text('최신순'),
                  selected: sortBy == SpotSort.recent,
                  onSelected: (_) => onSortChanged(SpotSort.recent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: Center(
                child: ChoiceChip(
                  key: const Key('obsmap_sort_sqm'),
                  label: const Text('SQM순'),
                  selected: sortBy == SpotSort.sqm,
                  onSelected: (_) => onSortChanged(SpotSort.sqm),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: Center(
                child: FilterChip(
                  key: const Key('obsmap_filter_sqm'),
                  showCheckmark: true,
                  label: const Text('SQM 21.5 이상 · 빛공해 적음'),
                  selected: sqmFilterActive,
                  onSelected: onSqmFilterChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral surfaceContainer-toned empty-result message shown when an active
/// search/SQM filter narrows the spot list to zero -- never errorContainer,
/// since an empty filtered result is not an error state (see
/// `_EmptyStatusBanner` in observation_map_screen.dart for the same rule
/// applied to the "zero spots in the region" case).
class _EmptyFilterResult extends StatelessWidget {
  const _EmptyFilterResult();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '조건에 맞는 관찰 스팟이 없어요',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
