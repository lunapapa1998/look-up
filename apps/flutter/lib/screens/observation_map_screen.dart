import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/discovery.dart';
import '../models/observation_map.dart';
import '../state/discovery_providers.dart';
import '../widgets/observation_marker.dart';
import '../widgets/observation_spot_sheet.dart';

/// Map scaffold for the observation map tab: the tile floor, the day-mode
/// tint overlay, the top layer-toggle bar, the observation spot markers, and
/// the [ObservationSpotSheet] bottom sheet for browsing/selecting a spot.
class ObservationMapScreen extends ConsumerStatefulWidget {
  const ObservationMapScreen({super.key});

  @override
  ConsumerState<ObservationMapScreen> createState() =>
      _ObservationMapScreenState();
}

class _ObservationMapScreenState extends ConsumerState<ObservationMapScreen> {
  final MapController _mapController = MapController();
  final Set<String> _activeKinds = {'bird', 'star', 'heritage'};
  late final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  ObservationSpot? _selectedSpot;

  static const _layerKinds = ['bird', 'star', 'heritage'];
  static const _layerLabels = {
    'bird': '조류',
    'star': '별',
    'heritage': '노포',
  };
  static const _sheetMidSnap = 0.45;

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _selectSpot(ObservationSpot spot) {
    setState(() => _selectedSpot = spot);
    _sheetController.animateTo(
      _sheetMidSnap,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _revealAboveSheet(spot);
  }

  /// Shifts the camera (via [MapCamera.latLngToScreenOffset] /
  /// [MapCamera.screenOffsetToLatLng] pixel-space round trip) so [spot]
  /// lands in the vertical center of the area still visible above the
  /// mid-snap sheet, instead of underneath it.
  void _revealAboveSheet(ObservationSpot spot) {
    final camera = _mapController.camera;
    final screenSize = camera.nonRotatedSize;
    final spotOffset = camera.latLngToScreenOffset(
      LatLng(spot.coord.lat, spot.coord.lng),
    );
    final visibleTop = screenSize.height * (1 - _sheetMidSnap);
    final targetY = visibleTop / 2;
    final shiftY = spotOffset.dy - targetY;
    final center = screenSize.center(Offset.zero);
    final newCenter = camera.screenOffsetToLatLng(
      Offset(center.dx, center.dy + shiftY),
    );
    _mapController.move(newCenter, camera.zoom);
  }

  void _toggleKind(String kind, bool selected) {
    setState(() {
      if (selected) {
        _activeKinds.add(kind);
      } else {
        _activeKinds.remove(kind);
      }
    });
  }

  void _recenter() {
    final location = ref.read(locationProvider).valueOrNull;
    _mapController.move(
      LatLng(
        location?.lat ?? defaultObservationLat,
        location?.lng ?? defaultObservationLng,
      ),
      _mapController.camera.zoom,
    );
  }

  void _retryObservationMap() {
    ref.invalidate(observationMapProvider);
  }

  void _enableLocation() {
    ref.read(locationProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(observationMapProvider, (previous, next) {
      final spots = next.valueOrNull?.spots;
      if (spots == null || spots.isEmpty) return;

      final bounds = LatLngBounds.fromPoints(
        spots.map((s) => LatLng(s.coord.lat, s.coord.lng)).toList(),
      );
      final isDegenerateBounds =
          bounds.north == bounds.south && bounds.east == bounds.west;
      if (isDegenerateBounds) {
        _mapController.move(bounds.center, 14);
        return;
      }

      final minSheetHeight =
          MediaQuery.sizeOf(context).height * 0.16 + 40;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.only(
            top: 40,
            left: 40,
            right: 40,
            bottom: minSheetHeight,
          ),
        ),
      );
    });

    final mapAsync = ref.watch(observationMapProvider);
    final spots = mapAsync.valueOrNull?.spots ?? const <ObservationSpot>[];
    final locationAsync = ref.watch(locationProvider);
    final isFallbackLocation = locationAsync.valueOrNull?.isFallback ?? false;

    return Scaffold(
      key: const Key('obsmap_screen'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter:
                  LatLng(defaultObservationLat, defaultObservationLng),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.lookup.app',
              ),
              MarkerLayer(
                markers: buildObservationMarkers(
                  spots: spots,
                  activeKinds: _activeKinds,
                  selectedSpotId: _selectedSpot?.id,
                  onSpotTap: _selectSpot,
                ),
              ),
              // flutter_map 8.x's AttributionAlignment only supports
              // bottomLeft/bottomRight (RichAttributionWidget otherwise
              // expands to fill the map and self-aligns its content), so
              // top-right placement is achieved by constraining its box
              // and anchoring that box to the top-right corner instead.
              Align(
                alignment: Alignment.topRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 260,
                    maxHeight: 160,
                  ),
                  child: RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                      TextSourceAttribution('© CARTO'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final obsMode = ref.watch(obsModeProvider).mode;
              if (obsMode != ObsMode.day) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: colorScheme.surface.withValues(alpha: 0.15),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (final kind in _layerKinds) ...[
                          Semantics(
                            label: '${_layerLabels[kind]} 레이어 '
                                '${_activeKinds.contains(kind) ? '끄기' : '켜기'}',
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: FilterChip(
                                  key: Key('obsmap_chip_$kind'),
                                  label: Text(_layerLabels[kind]!),
                                  selected: _activeKinds.contains(kind),
                                  onSelected: (selected) =>
                                      _toggleKind(kind, selected),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        Semantics(
                          label: '현재 위치로 이동',
                          child: IconButton(
                            key: const Key('obsmap_gps_button'),
                            icon: const Icon(Icons.my_location),
                            onPressed: _recenter,
                          ),
                        ),
                      ],
                    ),
                    if (isFallbackLocation)
                      _LocationFallbackBanner(onEnableLocation: _enableLocation),
                    _ObservationMapStatusBanner(
                      mapAsync: mapAsync,
                      onRetry: _retryObservationMap,
                    ),
                    if (_activeKinds.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '표시할 레이어를 선택하세요',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ObservationSpotSheet(
            spots: spots,
            selectedSpot: _selectedSpot,
            onSelectSpot: _selectSpot,
            sheetController: _sheetController,
          ),
        ],
      ),
    );
  }
}

/// Non-intrusive banner shown when [ObservationLocation.isFallback] is true:
/// device location couldn't be resolved, so results are centered on the
/// fixed Ganghwa reference point instead. Not an error state -- surfaceContainer
/// tone, never errorContainer.
class _LocationFallbackBanner extends StatelessWidget {
  const _LocationFallbackBanner({required this.onEnableLocation});

  final VoidCallback onEnableLocation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '현재 위치를 못 찾아 강화 기준으로 표시 중',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onEnableLocation,
            child: const Text('위치 켜기'),
          ),
        ],
      ),
    );
  }
}

/// Data-state banner for [observationMapProvider]: loading spinner,
/// errorContainer-toned error/degraded banners (both retryable), or a
/// neutral surfaceContainer empty-state banner. Renders nothing once data
/// has loaded successfully with spots.
class _ObservationMapStatusBanner extends StatelessWidget {
  const _ObservationMapStatusBanner({
    required this.mapAsync,
    required this.onRetry,
  });

  final AsyncValue<ObservationMapResponse> mapAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return mapAsync.when(
      loading: () => const _LoadingStatusBanner(),
      error: (_, _) => _ErrorStatusBanner(
        message: '관찰 스팟을 불러오지 못했어요',
        onRetry: onRetry,
      ),
      data: (response) {
        if (response.degraded) {
          return _ErrorStatusBanner(
            message: '데이터를 일부 불러오지 못했어요',
            onRetry: onRetry,
          );
        }
        if (response.spots.isEmpty) {
          return const _EmptyStatusBanner();
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _LoadingStatusBanner extends StatelessWidget {
  const _LoadingStatusBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '관찰 스팟 불러오는 중',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// errorContainer-toned banner for both hard errors (AsyncError) and
/// degraded responses (partial-data). Both are retryable via [onRetry].
class _ErrorStatusBanner extends StatelessWidget {
  const _ErrorStatusBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// Neutral surfaceContainer banner for the "no spots nearby" empty state.
/// Must never use errorContainer tones: an empty result set is not an error.
class _EmptyStatusBanner extends StatelessWidget {
  const _EmptyStatusBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '주변에 표시할 관찰 스팟이 없어요',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
