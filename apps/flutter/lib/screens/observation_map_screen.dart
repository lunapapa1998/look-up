import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/discovery.dart';
import '../models/observation_map.dart';
import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../utils/bird_scatter.dart';
import '../utils/observation_spot_filter.dart';
import '../widgets/observation_map_overlays.dart';
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
  final LayerHitNotifier<TrailTrack> _trailHitNotifier = ValueNotifier(null);
  ObservationSpot? _selectedSpot;
  String _searchQuery = '';
  SpotSort _sortBy = SpotSort.distance;
  bool _sqmFilterActive = false;
  // Which spot's scatter is currently mounted -- may stay non-null briefly
  // during a fade-out even after _selectedSpot changes (spec 017 P3).
  ObservationSpot? _scatterSpot;
  bool _scatterVisible = false;
  StreamSubscription<MapEvent>? _mapEventSub;
  // True while the sheet is programmatically animating to mid-snap from
  // _selectSpot -- suppresses _handleScatterSheetSize so the collapse
  // animation itself doesn't revert the scatter _selectSpot just activated
  // (spec 017 P3 bugfix).
  bool _sheetSnappingToMidSnap = false;

  static const _layerKinds = ['bird', 'star', 'heritage', 'trail'];
  static const _layerLabels = {
    'bird': '조류',
    'star': '별',
    'heritage': '노포',
    'trail': '탐방로',
  };
  static const _sheetMidSnap = 0.45;
  static const _trailColor = Color(0xFF5C8A72);

  @override
  void initState() {
    super.initState();
    _trailHitNotifier.addListener(_handleTrailHit);
    _mapEventSub =
        _mapController.mapEventStream.listen(_handleScatterMapEvent);
    _sheetController.addListener(_handleScatterSheetSize);
  }

  @override
  void dispose() {
    _trailHitNotifier.removeListener(_handleTrailHit);
    _trailHitNotifier.dispose();
    _mapEventSub?.cancel();
    _sheetController.removeListener(_handleScatterSheetSize);
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _handleTrailHit() {
    final hit = _trailHitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    _showTrailInfo(hit.hitValues.first.course);
  }

  void _showTrailInfo(TrailCourse course) {
    showDialog<void>(
      context: context,
      builder: (_) => _TrailInfoDialog(course: course),
    );
  }

  void _selectSpot(ObservationSpot spot) {
    setState(() => _selectedSpot = spot);
    _sheetSnappingToMidSnap = true;
    _sheetController
        .animateTo(
          _sheetMidSnap,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _sheetSnappingToMidSnap = false);
    if (spot.kind == 'bird') {
      _revealAboveSheet(spot, targetZoom: 15);
      if (_scatterSpot != null && _scatterSpot!.id != spot.id) {
        _revertScatter();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _selectedSpot?.id == spot.id) {
            _activateScatter(spot);
          }
        });
      } else {
        _activateScatter(spot);
      }
    } else {
      _revealAboveSheet(spot);
      _revertScatter();
    }
  }

  /// Shifts the camera (via [MapCamera.latLngToScreenOffset] /
  /// [MapCamera.screenOffsetToLatLng] pixel-space round trip) so [spot]
  /// lands in the vertical center of the area still visible above the
  /// mid-snap sheet, instead of underneath it.
  void _revealAboveSheet(ObservationSpot spot, {double? targetZoom}) {
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
    _mapController.move(newCenter, targetZoom ?? camera.zoom);
  }

  /// Mounts [spot]'s scatter and fades it in (spec 017 P3).
  void _activateScatter(ObservationSpot spot) {
    setState(() {
      _scatterSpot = spot;
      _scatterVisible = true;
    });
  }

  /// Fades the current scatter out, then unmounts it once the fade
  /// finishes -- guarded so repeated calls (e.g. from both the map-event and
  /// sheet-size listeners) are harmless.
  void _revertScatter() {
    if (_scatterSpot == null || !_scatterVisible) return;
    setState(() => _scatterVisible = false);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && !_scatterVisible) {
        setState(() => _scatterSpot = null);
      }
    });
  }

  /// Reverts the scatter once the user zooms back out past the zoom-15
  /// reveal threshold, so it doesn't linger detached from its trigger.
  void _handleScatterMapEvent(MapEvent event) {
    if (_mapController.camera.zoom < 13) _revertScatter();
  }

  /// Reverts the scatter once the sheet is dragged well past its mid-snap
  /// resting point, so it doesn't sit under the expanding sheet.
  void _handleScatterSheetSize() {
    if (_sheetSnappingToMidSnap) return;
    if (_sheetController.isAttached &&
        _sheetController.size > _sheetMidSnap + 0.02) {
      _revertScatter();
    }
  }

  /// Shows a brief species-name tooltip for a tapped scattered individual
  /// (spec 017 P4) -- appends the reduced-caption phrase when the scatter
  /// was capped, so the tap target itself explains why the individual might
  /// represent more than one real bird.
  void _showBirdSpeciesTooltip(
    ScatteredBird bird,
    bool wasReduced,
    int totalCount,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasReduced
              ? '${bird.nameKo} · 관측 $totalCount마리 · 대표 표시'
              : bird.nameKo,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

  void _setSearchQuery(String value) {
    setState(() => _searchQuery = value);
  }

  void _setSortBy(SpotSort value) {
    setState(() => _sortBy = value);
  }

  void _toggleSqmFilter(bool value) {
    setState(() => _sqmFilterActive = value);
  }

  /// Fades the compass/tide-moon overlays out once the sheet is dragged
  /// meaningfully past its 0.16 resting peek, so they never visually collide
  /// with the expanding sheet. [_sheetController] only reports a valid
  /// [DraggableScrollableController.size] once attached to its sheet.
  double _peekOverlayOpacity() {
    if (!_sheetController.isAttached) return 1.0;
    return _sheetController.size > 0.2 ? 0.0 : 1.0;
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
    final currentLocation = locationAsync.valueOrNull;
    final isFallbackLocation = currentLocation?.isFallback ?? false;
    final origin = currentLocation == null
        ? null
        : Coordinate(lat: currentLocation.lat, lng: currentLocation.lng);
    final filteredSpots = sortObservationSpots(
      filterObservationSpotsBySqm(
        filterObservationSpotsByQuery(spots, _searchQuery),
        active: _sqmFilterActive,
      ),
      _sortBy,
      origin: origin,
    );
    // Individual scatter is a pure derivation of the mounted scatter spot
    // (spec 017 P3 state machine), not a fresh derivation of the selection --
    // it must keep rendering during the fade-out even after _scatterSpot's
    // owning selection has already changed.
    final scatterSpot = _scatterSpot;
    final scatterResult = scatterSpot != null
        ? scatterBirds(
            center: scatterSpot.coord,
            topSpecies: scatterSpot.birds!.topSpecies,
            seed: scatterSpot.id,
          )
        : null;
    // Conditional watch, not unconditional-then-filter: keeps the GPX
    // fetch lazy so it never fires while the trail chip is off.
    final trailTracks = _activeKinds.contains('trail')
        ? ref.watch(observationTrailTracksProvider).valueOrNull ??
            const <TrailTrack>[]
        : const <TrailTrack>[];

    final obsMode = ref.watch(obsModeProvider).mode;
    final discoveryOverview =
        ref.watch(discoveryProvider(obsMode)).valueOrNull;
    final tideText = discoveryOverview == null
        ? null
        : _telemetryValueFor(discoveryOverview.telemetry, 'tide');
    final moonText = discoveryOverview == null
        ? null
        : _goldenHourDescriptionFor(discoveryOverview.goldenHours, obsMode);
    final peekHeight = MediaQuery.sizeOf(context).height * 0.16;

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
                // Esri "World Dark Gray Base" — genuinely key-less dark raster
                // tiles. (CARTO dark_matter now stamps an "API KEY REQUIRED"
                // watermark on its no-key tiles, so it is unusable here.)
                // Note the {z}/{y}/{x} (row/col) order and no {s} subdomains.
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.lookup.app',
              ),
              // Rebuilds on every camera change (pan/zoom/rotate) -- the
              // standard flutter_map pattern for reading live zoom/camera
              // into marker-building logic -- so the on-map label display
              // rules (spec 016 P1-1: zoom-gated, collision-suppressed) stay
              // in sync with what's actually on screen.
              StreamBuilder<MapEvent>(
                stream: _mapController.mapEventStream,
                builder: (context, snapshot) {
                  final camera = _mapController.camera;
                  return MarkerLayer(
                    markers: buildObservationMarkers(
                      spots: filteredSpots,
                      activeKinds: _activeKinds,
                      selectedSpotId: _selectedSpot?.id,
                      onSpotTap: _selectSpot,
                      zoom: camera.zoom,
                      screenOffsetOf: (spot) => camera.latLngToScreenOffset(
                        LatLng(spot.coord.lat, spot.coord.lng),
                      ),
                      scatterActive: _scatterSpot != null,
                    ),
                  );
                },
              ),
              if (scatterResult != null)
                MarkerLayer(
                  markers: [
                    for (
                      var i = 0;
                      i < scatterResult.individuals.length;
                      i++
                    )
                      Marker(
                        point: LatLng(
                          scatterResult.individuals[i].coord.lat,
                          scatterResult.individuals[i].coord.lng,
                        ),
                        width: ScatteredBirdMarker.markerBoxSize,
                        height: ScatteredBirdMarker.markerBoxSize,
                        child: AnimatedOpacity(
                          opacity: _scatterVisible ? 1 : 0,
                          duration: _scatterVisible
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          child: _StaggeredBirdEntrance(
                            key: ValueKey('${scatterSpot!.id}_$i'),
                            index: i,
                            child: ScatteredBirdMarker(
                              nameKo: scatterResult.individuals[i].nameKo,
                              onTap: () => _showBirdSpeciesTooltip(
                                scatterResult.individuals[i],
                                scatterResult.wasReduced,
                                scatterResult.totalCount,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (_activeKinds.contains('trail')) ...[
                PolylineLayer<TrailTrack>(
                  hitNotifier: _trailHitNotifier,
                  polylines: [
                    for (final track in trailTracks)
                      if (track.points.isNotEmpty)
                        Polyline<TrailTrack>(
                          points: track.points,
                          strokeWidth: 3,
                          color: _trailColor,
                          pattern: StrokePattern.dashed(
                            segments: const [8, 6],
                          ),
                          hitValue: track,
                        ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final track in trailTracks)
                      Marker(
                        point: LatLng(
                          track.course.start.lat,
                          track.course.start.lng,
                        ),
                        width: 44,
                        height: 44,
                        child: _TrailheadMarker(
                          course: track.course,
                          onTap: () => _showTrailInfo(track.course),
                        ),
                      ),
                  ],
                ),
              ],
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
                      TextSourceAttribution('Tiles © Esri'),
                      TextSourceAttribution('© OpenStreetMap contributors'),
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
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Semantics(
                          label: _activeKinds.length == _layerKinds.length
                              ? '전체 레이어 끄기'
                              : '전체 레이어 켜기',
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: FilterChip(
                                key: const Key('obsmap_chip_all'),
                                label: const Text('전체'),
                                selected:
                                    _activeKinds.length == _layerKinds.length,
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _activeKinds.addAll(_layerKinds);
                                  } else {
                                    _activeKinds.clear();
                                  }
                                }),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              ],
                            ),
                          ),
                        ),
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
          Positioned(
            right: 16,
            bottom: peekHeight + 16,
            child: AnimatedBuilder(
              animation: _sheetController,
              builder: (context, _) {
                final opacity = _peekOverlayOpacity();
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: opacity,
                  child: IgnorePointer(
                    ignoring: opacity == 0,
                    child: StreamBuilder<MapEvent>(
                      stream: _mapController.mapEventStream,
                      builder: (context, snapshot) {
                        return CompassButton(
                          rotationDegrees: _mapController.camera.rotation,
                          onTap: () => _mapController.rotate(0),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            bottom: peekHeight + 16,
            child: AnimatedBuilder(
              animation: _sheetController,
              builder: (context, _) {
                final opacity = _peekOverlayOpacity();
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: opacity,
                  child: IgnorePointer(
                    ignoring: opacity == 0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: TideMoonOverlay(
                        tideText: tideText,
                        moonText: moonText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (scatterResult != null && scatterResult.wasReduced)
            Positioned(
              left: 16,
              bottom:
                  MediaQuery.sizeOf(context).height * _sheetMidSnap + 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: _ScatteredBirdCaptionBanner(
                  totalCount: scatterResult.totalCount,
                ),
              ),
            ),
          ObservationSpotSheet(
            spots: filteredSpots,
            selectedSpot: _selectedSpot,
            onSelectSpot: _selectSpot,
            sheetController: _sheetController,
            searchQuery: _searchQuery,
            onSearchChanged: _setSearchQuery,
            sortBy: _sortBy,
            onSortChanged: _setSortBy,
            sqmFilterActive: _sqmFilterActive,
            onSqmFilterChanged: _toggleSqmFilter,
          ),
        ],
      ),
    );
  }
}

/// Staggers a scattered bird marker's reveal-in by [index] * 25ms, then
/// fades and scales it up from 0.6x -- the per-marker entrance look (spec
/// 017 P3), independent of the flat whole-group revert fade applied by its
/// parent [AnimatedOpacity] in [_ObservationMapScreenState.build].
class _StaggeredBirdEntrance extends StatefulWidget {
  const _StaggeredBirdEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_StaggeredBirdEntrance> createState() =>
      _StaggeredBirdEntranceState();
}

class _StaggeredBirdEntranceState extends State<_StaggeredBirdEntrance> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 25), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: _revealed ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Null-safe [TelemetryReading.value] lookup by [kind] -- returns null
/// instead of throwing when no matching reading is present.
String? _telemetryValueFor(List<TelemetryReading> telemetry, String kind) {
  for (final reading in telemetry) {
    if (reading.kind == kind) return reading.value;
  }
  return null;
}

/// Null-safe [GoldenHour.description] lookup by [mode] -- returns null
/// instead of throwing when no matching golden hour entry is present.
String? _goldenHourDescriptionFor(List<GoldenHour> goldenHours, ObsMode mode) {
  for (final hour in goldenHours) {
    if (hour.mode == mode) return hour.description;
  }
  return null;
}

/// Small always-visible pin marking a [TrailCourse.start] point, independent
/// of whether that course's GPX track fetch succeeded -- the trailhead must
/// stay visible even when [TrailTrack.points] is empty.
class _TrailheadMarker extends StatelessWidget {
  const _TrailheadMarker({required this.course, required this.onTap});

  final TrailCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '탐방로 시작점, ${course.name}',
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: _ObservationMapScreenState._trailColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hiking,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight tap tooltip for a trailhead marker or polyline segment: just
/// the course name and distance -- full course detail is a future deep-link
/// to the trails tab, out of scope here.
class _TrailInfoDialog extends StatelessWidget {
  const _TrailInfoDialog({required this.course});

  final TrailCourse course;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(course.name),
      content: Text('${course.distanceKm.toStringAsFixed(1)}km'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
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

/// Caption shown while a bird spot's individual scatter was reduced (spec
/// 017 P1-3): [totalCount] is [ScatterResult.totalCount], the honest
/// uncapped real count, never [ScatterResult.individuals.length] -- the map
/// shows at most `maxIndividuals` markers as a representative sample while
/// this caption keeps the real number visible. Not shown when the scatter
/// wasn't reduced (individuals already equal the real count, so no caption
/// is needed).
class _ScatteredBirdCaptionBanner extends StatelessWidget {
  const _ScatteredBirdCaptionBanner({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '관측 $totalCount마리 · 대표 표시',
        style: Theme.of(context).textTheme.bodySmall,
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
