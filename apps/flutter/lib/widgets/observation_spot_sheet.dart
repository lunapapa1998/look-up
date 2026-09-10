import 'package:flutter/material.dart';

import '../models/observation_map.dart';
import '../utils/observation_spot_filter.dart';
import '../utils/trail_format.dart';
import 'observation_spot_detail.dart';

/// 3-snap draggable bottom sheet over the observation map: a spot list at
/// rest, expandable to a half/full sheet, swapping to
/// [ObservationSpotDetail] once a spot is selected.
///
/// Measurement values (species count, SQM, distance) and the suitability
/// score live in strictly separate blocks inside [ObservationSpotDetail] --
/// never on the same row -- per the trail-screen precedent.
class ObservationSpotSheet extends StatelessWidget {
  const ObservationSpotSheet({
    super.key,
    required this.spots,
    required this.selectedSpot,
    required this.onSelectSpot,
    required this.sheetController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.sqmFilterActive,
    required this.onSqmFilterChanged,
  });

  final List<ObservationSpot> spots;
  final ObservationSpot? selectedSpot;
  final void Function(ObservationSpot) onSelectSpot;
  final DraggableScrollableController sheetController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final SpotSort sortBy;
  final ValueChanged<SpotSort> onSortChanged;
  final bool sqmFilterActive;
  final ValueChanged<bool> onSqmFilterChanged;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFilteredEmpty =
        spots.isEmpty && (searchQuery.trim().isNotEmpty || sqmFilterActive);

    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.16,
      minChildSize: 0.16,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.16, 0.45, 0.9],
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
              if (selectedSpot == null)
                _SpotSearchAndFilterBar(
                  searchQuery: searchQuery,
                  onSearchChanged: onSearchChanged,
                  sortBy: sortBy,
                  onSortChanged: onSortChanged,
                  sqmFilterActive: sqmFilterActive,
                  onSqmFilterChanged: onSqmFilterChanged,
                ),
              Expanded(
                child: selectedSpot != null
                    ? ObservationSpotDetail(
                        spot: selectedSpot!,
                        scrollController: scrollController,
                      )
                    : isFilteredEmpty
                        ? const _EmptyFilterResult()
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: spots.length,
                            itemBuilder: (context, index) {
                              final spot = spots[index];
                              return InkWell(
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
                                          spot.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
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
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Search field + sort/filter chip row shown above the spot list (list view
/// only, never above [ObservationSpotDetail]) -- own widget class per this
/// codebase's no-private-build-method convention, see
/// `_LocationFallbackBanner` in observation_map_screen.dart for the pattern.
class _SpotSearchAndFilterBar extends StatelessWidget {
  const _SpotSearchAndFilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.sqmFilterActive,
    required this.onSqmFilterChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final SpotSort sortBy;
  final ValueChanged<SpotSort> onSortChanged;
  final bool sqmFilterActive;
  final ValueChanged<bool> onSqmFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
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
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
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
                      label: const Text('SQM 21.5 이상 · 빛공해 적음'),
                      selected: sqmFilterActive,
                      onSelected: onSqmFilterChanged,
                    ),
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
