import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

import '../api/gpx_api.dart';
import '../api/observation_map_api.dart';
import '../api/species_api.dart';
import '../api/suitability_api.dart';
import '../api/tide_api.dart';
import '../api/trails_api.dart';
import '../config.dart';
import '../models/discovery.dart';
import '../models/observation_map.dart';
import '../models/species.dart';
import '../models/tide.dart';
import '../models/trails.dart';
import '../services/location_service.dart';

/// Wiring for the suitability engine backend API.
///
/// [discoveryProvider] fetches live data via [SuitabilityApi]; [hotspotsProvider]
/// still returns hardcoded mock data pending its own backend contract.

/// Wall-clock provider so tests can override the clock deterministically.
/// Read exactly once per provider build, not polled.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

enum ObsModeSource { auto, manual }

class ObsModeState {
  const ObsModeState({required this.mode, required this.source});

  final ObsMode mode;
  final ObsModeSource source;
}

ObsMode modeForHour(int hour) {
  return (hour < 6 || hour >= 19) ? ObsMode.night : ObsMode.day;
}

class ObsModeController extends Notifier<ObsModeState> {
  @override
  ObsModeState build() {
    return ObsModeState(
      mode: modeForHour(ref.read(nowProvider).hour),
      source: ObsModeSource.auto,
    );
  }

  void setManual(ObsMode mode) {
    state = ObsModeState(mode: mode, source: ObsModeSource.manual);
  }

  void resetToAuto() {
    state = ObsModeState(
      mode: modeForHour(ref.read(nowProvider).hour),
      source: ObsModeSource.auto,
    );
  }
}

/// Currently selected observation mode (day/night), driving which mock
/// content the discovery screen surfaces.
final obsModeProvider = NotifierProvider<ObsModeController, ObsModeState>(
  ObsModeController.new,
);

final suitabilityApiProvider = Provider<SuitabilityApi>((ref) {
  return HttpSuitabilityApi(defaultApiBaseUrl);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

class LocationNotifier extends AsyncNotifier<ObservationLocation> {
  @override
  Future<ObservationLocation> build() async {
    final service = ref.watch(locationServiceProvider);
    return service.currentLocation();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(locationServiceProvider).currentLocation(),
    );
  }
}

final locationProvider =
    AsyncNotifierProvider<LocationNotifier, ObservationLocation>(
      LocationNotifier.new,
    );

class DiscoveryNotifier
    extends FamilyAsyncNotifier<DiscoveryOverview, ObsMode> {
  @override
  Future<DiscoveryOverview> build(ObsMode mode) async {
    ref.keepAlive();
    final api = ref.watch(suitabilityApiProvider);
    final location = await ref.watch(locationProvider.future);
    final overview = await api.fetchSuitability(
      lat: location.lat,
      lng: location.lng,
      mode: mode,
    );
    if (overview.weatherRefreshing) {
      unawaited(_pollWeather(api, location, mode));
    }
    return overview;
  }

  Future<void> _pollWeather(
    SuitabilityApi api,
    ObservationLocation location,
    ObsMode mode,
  ) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final updated = await api.fetchSuitability(
          lat: location.lat,
          lng: location.lng,
          mode: mode,
        );
        state = AsyncData(updated);
        if (!updated.weatherRefreshing) return;
      } catch (_) {
        // Keep the already-rendered partial data and try again briefly.
      }
    }
  }
}

final discoveryProvider =
    AsyncNotifierProvider.family<DiscoveryNotifier, DiscoveryOverview, ObsMode>(
      DiscoveryNotifier.new,
    );

final trailsApiProvider = Provider<TrailsApi>((ref) {
  return HttpTrailsApi(defaultApiBaseUrl);
});

final speciesApiProvider = Provider<SpeciesApi>((ref) {
  return HttpSpeciesApi(defaultApiBaseUrl);
});

typedef SpeciesQuery = ({String? sci, String? ko});

final speciesInfoProvider = FutureProvider.family<SpeciesInfo, SpeciesQuery>((
  ref,
  query,
) {
  final api = ref.watch(speciesApiProvider);
  return api.fetchSpecies(sci: query.sci, ko: query.ko);
});

final tideApiProvider = Provider<TideApi>((ref) {
  return HttpTideApi(defaultApiBaseUrl);
});

typedef TideQuery = ({double lat, double lng});

final tideTodayProvider = FutureProvider.family<TodayTides, TideQuery>((
  ref,
  query,
) {
  final api = ref.watch(tideApiProvider);
  return api.fetchTodayTides(lat: query.lat, lng: query.lng);
});

class TrailsNotifier extends AsyncNotifier<TrailsResponse> {
  @override
  Future<TrailsResponse> build() async {
    final api = ref.watch(trailsApiProvider);
    final location = await ref.watch(locationProvider.future);
    return api.fetchTrails(lat: location.lat, lng: location.lng);
  }
}

final trailsProvider = AsyncNotifierProvider<TrailsNotifier, TrailsResponse>(
  TrailsNotifier.new,
);

final trailDetailProvider = FutureProvider.family<TrailDetailResponse, String>((
  ref,
  crsIdx,
) {
  final api = ref.watch(trailsApiProvider);
  return api.fetchTrailDetail(crsIdx: crsIdx);
});

final gpxApiProvider = Provider<GpxApi>((ref) {
  return HttpGpxApi();
});

typedef TrailTrack = ({TrailCourse course, List<LatLng> points});

final observationTrailTracksProvider = FutureProvider<List<TrailTrack>>((
  ref,
) async {
  final trails = await ref.watch(trailsProvider.future);
  final courses = trails.courses;
  final gpxApi = ref.watch(gpxApiProvider);
  final tracks = await Future.wait(
    courses.map((course) => gpxApi.fetchGpxTrack(course.gpxUrl)),
  );
  return [
    for (var i = 0; i < courses.length; i++)
      (course: courses[i], points: tracks[i]),
  ];
});

final hotspotsProvider = Provider<List<Hotspot>>((ref) {
  return const [
    Hotspot(
      mode: ObsMode.day,
      badges: ['환경부 인증 생태관광지', 'EAAF 철새 핵심 경로'],
      suitabilityScore: 94,
      scoreIcon: Icons.trending_up,
      overlayIcon: Icons.visibility,
      overlayHeadline: '저어새 & 검은머리물떼새 140+',
      overlayTimestamp: '14분 전 기록',
      title: '강화도 동막갯벌 & 여차리 도래지',
      subtitle: '서울 58km',
      description:
          '만조 2시간 전 갯골을 따라 물이 차오르며 수백 마리의 도요물떼새가 둑방 50m 지점까지 접근하고 있습니다. 가을 이동기 최고의 관측 창구입니다.',
      metas: [
        HotspotMeta(icon: Icons.schedule, label: '14:00~17:00'),
        HotspotMeta(icon: Icons.lens_blur, label: '배율 8x-10x 권장'),
      ],
      ctaLabel: '관찰 루트 >',
    ),
    Hotspot(
      mode: ObsMode.night,
      badges: ['빛공해 1등급 보호구역', '페르세우스 극대기'],
      suitabilityScore: 92,
      scoreIcon: Icons.auto_awesome,
      overlayIcon: Icons.flare,
      overlayHeadline: '은하수 아치 · 시간당 유성 15+',
      overlayTimestamp: '달 위상 8% (삭)',
      title: '영월 별마로 & 봉래산 다크스카이',
      subtitle: '해발 799m',
      description:
          '습도 38%, 운량 5% 미만의 맑은 상공입니다. 22시 30분 이후 궁수자리부터 백조자리까지 육안으로 은하수 분기대를 뚜렷하게 관측할 수 있습니다.',
      metas: [
        HotspotMeta(icon: Icons.schedule, label: '22:30~02:00'),
        HotspotMeta(icon: Icons.bedtime, label: '암적응 15분 필수'),
      ],
      ctaLabel: '관측 스팟 >',
    ),
  ];
});

final observationMapApiProvider = Provider<ObservationMapApi>((ref) {
  return HttpObservationMapApi(defaultApiBaseUrl);
});

class ObservationMapNotifier extends AsyncNotifier<ObservationMapResponse> {
  @override
  Future<ObservationMapResponse> build() async {
    final api = ref.watch(observationMapApiProvider);
    final location = await ref.watch(locationProvider.future);
    return api.fetchObservationMap(lat: location.lat, lng: location.lng);
  }

  Future<void> refreshAtCenter({
    required double lat,
    required double lng,
  }) async {
    state = const AsyncLoading();
    final api = ref.read(observationMapApiProvider);
    state = await AsyncValue.guard(
      () => api.fetchObservationMap(lat: lat, lng: lng),
    );
  }
}

final observationMapProvider =
    AsyncNotifierProvider<ObservationMapNotifier, ObservationMapResponse>(
      ObservationMapNotifier.new,
    );

typedef SpotSuitabilityQuery = ({double lat, double lng, ObsMode mode});

final spotSuitabilityProvider =
    FutureProvider.family<DiscoveryOverview, SpotSuitabilityQuery>((
      ref,
      query,
    ) {
      final api = ref.watch(suitabilityApiProvider);
      return api.fetchSuitability(
        lat: query.lat,
        lng: query.lng,
        mode: query.mode,
      );
    });
