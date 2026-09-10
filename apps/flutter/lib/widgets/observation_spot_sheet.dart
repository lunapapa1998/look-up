import 'package:flutter/material.dart';

import '../models/observation_map.dart';
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
  });

  final List<ObservationSpot> spots;
  final ObservationSpot? selectedSpot;
  final void Function(ObservationSpot) onSelectSpot;
  final DraggableScrollableController sheetController;

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
              Expanded(
                child: selectedSpot == null
                    ? ListView.builder(
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
                                    color: kindColor(colorScheme, spot.kind),
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
                      )
                    : ObservationSpotDetail(
                        spot: selectedSpot!,
                        scrollController: scrollController,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
