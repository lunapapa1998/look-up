import 'dart:async';

import 'package:flutter/foundation.dart';
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
  TrailCourse? _selectedTrail;
  SelectedSpecies? _selectedSpecies;
  String _searchQuery = '';
  SpotSort _sortBy = SpotSort.distance;
  bool _sqmFilterActive = false;
  // Which spot's scatter is currently mounted -- may stay non-null briefly
  // during a fade-out even after _selectedSpot changes (spec 017 P3).
  ObservationSpot? _scatterSpot;
  bool _scatterVisible = false;
  // Center the observation-map data was last fetched at (spec 019 P4) --
  // compared against the live camera center to decide when the map has
  // drifted far enough to offer a "search again here" re-fetch.
  LatLng? _lastFetchCenter;
  // When true, the next observationMapProvider result must NOT move/fit the
  // camera (owner: "이 지역에서 검색"/recenter re-fetch was zooming the map out).
  // Only the very first automatic load fits to the spot bounds.
  bool _skipNextAutoFit = false;
  bool _showResearchButton = false;
  bool _isResearching = false;
  StreamSubscription<MapEvent>? _mapEventSub;
  // True while the sheet is programmatically animating to mid-snap from
  // _selectSpot -- suppresses _handleScatterSheetSize so the collapse
  // animation itself doesn't revert the scatter _selectSpot just activated
  // (spec 017 P3 bugfix).
  bool _sheetSnappingToMidSnap = false;
  // Debug-only min/max zoom stepper state (spec 019), lifted here so the
  // stepper in _DebugZoomOverlay actually drives the live MapOptions instead
  // of just a local label.
  double _debugMinZoom = 7.0;
  // maxZoom 18 with TileLayer.maxNativeZoom 16 = overzoom: past z16 the last
  // Esri tiles are upscaled (slightly soft) instead of showing "Map data not
  // yet available", so users can zoom in closer than the tile source's z16.
  double _debugMaxZoom = 18.0;
  static const _hardMaxDebugZoom = 19.0;

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
    _selectTrail(hit.hitValues.first.course);
  }

  /// Selects a trail course into the sheet's detail view, mirroring the
  /// non-bird branch of [_selectSpot]: mid-snap the sheet and drop any
  /// active bird scatter.
  void _selectTrail(TrailCourse course) {
    setState(() {
      _selectedTrail = course;
      _selectedSpot = null;
      _selectedSpecies = null;
    });
    _sheetSnappingToMidSnap = true;
    _sheetController
        .animateTo(
          _sheetMidSnap,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _sheetSnappingToMidSnap = false);
    _revertScatter();
  }

  /// Steps the sheet back one level of its list -> spot/trail detail ->
  /// species detail stack: clears just the species selection when one is
  /// active, otherwise clears both the selected spot and trail to return to
  /// the list view.
  void _handleSheetBack() {
    if (_selectedSpecies != null) {
      // Species detail -> back to the parent spot/trail detail; keep the bird
      // scatter so the spot detail still shows its individuals.
      setState(() => _selectedSpecies = null);
      return;
    }
    // Spot/trail detail -> back to the list. Also drop any lingering bird
    // scatter: otherwise its markers stay on the map and, once tapped, would
    // open SpeciesDetail with no selected spot, collapsing the back stack.
    setState(() {
      _selectedSpot = null;
      _selectedTrail = null;
    });
    _revertScatter();
  }

  void _selectSpecies(SelectedSpecies species) {
    // Refresh "now" at the moment a marker's data is opened (owner: the "지금"
    // tide marker / relative times should reflect the tap time, not app start).
    ref.invalidate(nowProvider);
    setState(() => _selectedSpecies = species);
  }

  void _selectSpot(ObservationSpot spot) {
    ref.invalidate(nowProvider);
    setState(() {
      _selectedSpot = spot;
      _selectedTrail = null;
      _selectedSpecies = null;
    });
    _sheetSnappingToMidSnap = true;
    _sheetController
        .animateTo(
          _sheetMidSnap,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _sheetSnappingToMidSnap = false);
    if (spot.kind == 'bird') {
      // Zoom-in on tap, centering the pin on screen. (Zoom itself is fine per
      // owner; the earlier bug was the pin scrolling off-screen after the
      // zoom, which looked like an error.)
      _revealAboveSheet(spot, targetZoom: 14);
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
    final spotLatLng = LatLng(spot.coord.lat, spot.coord.lng);
    // Zoom-in reveal: center the pin on screen. The pixel round-trip below is
    // computed in the CURRENT camera projection, so mixing it with a zoom
    // change lands the pin off-screen (owner saw the pin vanish = "error").
    // When zooming, just center the spot so it's always visible.
    if (targetZoom != null) {
      _mapController.move(spotLatLng, targetZoom);
      return;
    }
    final camera = _mapController.camera;
    final screenSize = camera.nonRotatedSize;
    final spotOffset = camera.latLngToScreenOffset(spotLatLng);
    final visibleTop = screenSize.height * (1 - _sheetMidSnap);
    final targetY = visibleTop / 2;
    final shiftY = spotOffset.dy - targetY;
    final center = screenSize.center(Offset.zero);
    final newCenter = camera.screenOffsetToLatLng(
      Offset(center.dx, center.dy + shiftY),
    );
    _mapController.move(newCenter, camera.zoom);
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

    if (event is MapEventMoveEnd && _lastFetchCenter != null) {
      const distanceCalc = Distance();
      final camera = _mapController.camera;
      final bounds = camera.visibleBounds;
      final diagonal =
          distanceCalc.distance(bounds.northEast, bounds.southWest);
      final drift = distanceCalc.distance(_lastFetchCenter!, camera.center);
      final shouldShow = drift > diagonal * 0.3;
      if (shouldShow != _showResearchButton) {
        setState(() => _showResearchButton = shouldShow);
      }
    }
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
    final lat = location?.lat ?? defaultObservationLat;
    final lng = location?.lng ?? defaultObservationLng;
    _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
    _lastFetchCenter = LatLng(lat, lng);
    _skipNextAutoFit = true;
    setState(() => _showResearchButton = false);
    ref.read(observationMapProvider.notifier).refreshAtCenter(lat: lat, lng: lng);
  }

  /// Re-fetches observation-map data centered on the current camera position
  /// (spec 019 P4 "이곳에서 다시 검색"). Clears the current selection/scatter
  /// afterward since they may not exist in the newly fetched spot set.
  Future<void> _researchHere() async {
    setState(() => _isResearching = true);
    final center = _mapController.camera.center;
    _skipNextAutoFit = true; // keep the current camera; don't zoom out to fit
    await ref
        .read(observationMapProvider.notifier)
        .refreshAtCenter(lat: center.latitude, lng: center.longitude);
    if (!mounted) return;
    setState(() {
      _isResearching = false;
      _showResearchButton = false;
      _lastFetchCenter = center;
      _selectedSpot = null;
      _scatterSpot = null;
      _scatterVisible = false;
    });
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

  void _adjustDebugMinZoom(double delta) {
    setState(() {
      _debugMinZoom = (_debugMinZoom + delta).clamp(1.0, _debugMaxZoom);
    });
  }

  void _adjustDebugMaxZoom(double delta) {
    setState(() {
      _debugMaxZoom =
          (_debugMaxZoom + delta).clamp(_debugMinZoom, _hardMaxDebugZoom);
    });
  }

  /// Fades the compass/tide-moon overlays out once the sheet is dragged
  /// meaningfully past its [kObsSheetPeek] resting peek, so they never
  /// visually collide with the expanding sheet. [_sheetController] only
  /// reports a valid [DraggableScrollableController.size] once attached to
  /// its sheet.
  double _peekOverlayOpacity() {
    if (!_sheetController.isAttached) return 1.0;
    return _sheetController.size > kObsSheetPeek + 0.04 ? 0.0 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(observationMapProvider, (previous, next) {
      if (_lastFetchCenter == null) {
        final loc = ref.read(locationProvider).valueOrNull;
        if (loc != null) _lastFetchCenter = LatLng(loc.lat, loc.lng);
      }

      final spots = next.valueOrNull?.spots;
      if (spots == null || spots.isEmpty) return;

      // Re-search / recenter re-fetches must not move the camera.
      if (_skipNextAutoFit) {
        _skipNextAutoFit = false;
        return;
      }

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
          MediaQuery.sizeOf(context).height * kObsSheetPeek + 40;
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
            speciesCount: scatterSpot.birds!.speciesCount,
            seed: scatterSpot.id,
          )
        : null;
    // Depth-sort so lower-latitude (visually lower on screen) markers draw
    // last and appear on top of higher-latitude ones when they overlap.
    final sortedScatterIndividuals = scatterResult == null
        ? const <ScatteredBird>[]
        : ([...scatterResult.individuals]
            ..sort((a, b) => b.coord.lat.compareTo(a.coord.lat)));
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
    final peekHeight = MediaQuery.sizeOf(context).height * kObsSheetPeek;

    return Scaffold(
      key: const Key('obsmap_screen'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(defaultObservationLat, defaultObservationLng),
              initialZoom: 12,
              minZoom: _debugMinZoom,
              // Esri World_Dark_Gray_Base tiles only exist up to z16.
              maxZoom: _debugMaxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(33.0, 124.5),
                  const LatLng(38.7, 131.9),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
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
                // Esri tiles exist to z16; beyond that flutter_map upscales
                // the z16 tile (overzoom) instead of blanking to "not yet
                // available", so MapOptions.maxZoom can exceed 16.
                maxNativeZoom: 16,
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
                      i < sortedScatterIndividuals.length;
                      i++
                    )
                      Marker(
                        point: LatLng(
                          sortedScatterIndividuals[i].coord.lat,
                          sortedScatterIndividuals[i].coord.lng,
                        ),
                        width: ScatteredBirdMarker.markerBoxWidth,
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
                              nameKo: sortedScatterIndividuals[i].nameKo,
                              onTap: () {
                                final bird = sortedScatterIndividuals[i];
                                _selectSpecies((
                                  nameKo: bird.nameKo,
                                  nameSci: bird.nameSci,
                                  count: bird.count,
                                  obsDt: bird.obsDt,
                                  spotName: _scatterSpot!.name,
                                  spotCoord: _scatterSpot!.coord,
                                  status: _scatterSpot!.birds!.status,
                                ));
                              },
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
                          onTap: () => _selectTrail(track.course),
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
                    if (_showResearchButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: _ResearchHereButton(
                            researching: _isResearching,
                            onTap: _researchHere,
                          ),
                        ),
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
          // TODO(019): 값 확정 후 제거
          if (kDebugMode)
            Positioned(
              right: 16,
              bottom: peekHeight + 16,
              child: _DebugZoomOverlay(
                mapController: _mapController,
                minZoom: _debugMinZoom,
                maxZoom: _debugMaxZoom,
                onMinZoomDelta: _adjustDebugMinZoom,
                onMaxZoomDelta: _adjustDebugMaxZoom,
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
                  totalSpeciesCount: scatterResult.totalSpeciesCount,
                  displayedSpeciesCount: scatterResult.individuals.length,
                ),
              ),
            ),
          ObservationSpotSheet(
            spots: filteredSpots,
            selectedSpot: _selectedSpot,
            selectedTrail: _selectedTrail,
            selectedSpecies: _selectedSpecies,
            onSelectSpot: _selectSpot,
            onSelectSpecies: _selectSpecies,
            onBack: _handleSheetBack,
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

// TODO(019): 값 확정 후 제거
/// Debug-only panel showing live zoom/center and a min/max zoom stepper, so
/// the owner can screenshot-review candidate zoom/camera constraint values
/// before they're hardcoded into [MapOptions]. Never rendered outside
/// [kDebugMode]; the stepper here drives the lifted zoom state in
/// [_ObservationMapScreenState] via [onMinZoomDelta]/[onMaxZoomDelta], which
/// in turn feeds the real map's [MapOptions.minZoom]/[MapOptions.maxZoom].
class _DebugZoomOverlay extends StatelessWidget {
  const _DebugZoomOverlay({
    required this.mapController,
    required this.minZoom,
    required this.maxZoom,
    required this.onMinZoomDelta,
    required this.onMaxZoomDelta,
  });

  final MapController mapController;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onMinZoomDelta;
  final ValueChanged<double> onMaxZoomDelta;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final camera = mapController.camera;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'zoom ${camera.zoom.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '${camera.center.latitude.toStringAsFixed(4)}, '
                '${camera.center.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('min', style: Theme.of(context).textTheme.labelSmall),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onMinZoomDelta(-1),
                  ),
                  Text(
                    minZoom.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onMinZoomDelta(1),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('max', style: Theme.of(context).textTheme.labelSmall),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onMaxZoomDelta(-1),
                  ),
                  Text(
                    maxZoom.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onMaxZoomDelta(1),
                  ),
                ],
              ),
              Text(
                '타일 z16까지',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
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

/// Pill button offered once the camera has drifted well past the last
/// fetched center (spec 019 P4), letting the user explicitly re-fetch
/// observation-map data for the area they've panned to instead of always
/// tracking their GPS location.
class _ResearchHereButton extends StatelessWidget {
  const _ResearchHereButton({required this.researching, required this.onTap});

  final bool researching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '이 지역에서 다시 검색',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Material(
          key: const Key('obsmap_research_button'),
          color: colorScheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: researching ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: researching
                    ? const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('검색 중'),
                      ]
                    : const [
                        Icon(Icons.refresh, size: 18),
                        SizedBox(width: 8),
                        Text('이 지역에서 검색'),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caption shown while a bird spot's scatter only displays its top species
/// (spec 019 P2): [totalSpeciesCount] is [ScatterResult.totalSpeciesCount],
/// the spot's real total species count, while [displayedSpeciesCount] is how
/// many of those are actually shown as markers. Not shown when the scatter
/// wasn't reduced (every species is already shown, so no caption is needed).
class _ScatteredBirdCaptionBanner extends StatelessWidget {
  const _ScatteredBirdCaptionBanner({
    required this.totalSpeciesCount,
    required this.displayedSpeciesCount,
  });

  final int totalSpeciesCount;
  final int displayedSpeciesCount;

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
        '관측 $totalSpeciesCount종 중 상위 $displayedSpeciesCount종 표시',
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
