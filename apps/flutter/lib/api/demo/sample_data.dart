import '../../models/discovery.dart';
import '../../models/observation_map.dart';
import '../../models/region.dart';
import '../../models/species.dart';
import '../../models/starlight_forecast.dart';
import '../../models/tide.dart';
import '../../models/trails.dart';

// Demo-only sample responses returned by the `Fallback*Api` wrappers when
// the real backend call fails (spec 052, `DEMO_FALLBACK` builds only).
//
// Every value must read as an obvious example: names say '예시', ids carry a
// `sample-` / `SAMPLE_` prefix, and numbers are round. Never use real
// business names, real people, or precise measured-looking values here.

/// Suitability overview for [mode]. `degraded` and `weatherRefreshing` stay
/// false so the discovery screen doesn't start its weather polling loop.
DiscoveryOverview sampleDiscoveryOverview(ObsMode mode) {
  final isDay = mode == ObsMode.day;
  return DiscoveryOverview(
    suitabilityIndex: SuitabilityIndex(
      score: isDay ? 80 : 85,
      label: isDay ? '쾌적 (예시)' : '천체관측 양호 (예시)',
      sqmValue: 20.0,
      skyClass: 'Class 3 (예시)',
      bortleClass: 3,
      nightSkyStatus: 'approx',
    ),
    goldenHours: const [
      GoldenHour(
        mode: ObsMode.day,
        label: '낮 · 탐조 골든타임 (예시)',
        timeRange: '14:00 - 17:00',
        description: '예시 시간대입니다',
      ),
      GoldenHour(
        mode: ObsMode.night,
        label: '밤 · 천체 골든타임 (예시)',
        timeRange: '22:00 - 01:00',
        description: '예시 시간대입니다',
      ),
    ],
    telemetry: const [
      TelemetryReading(kind: 'sky', label: '하늘 상태', value: '맑음 (예시)'),
      TelemetryReading(kind: 'humidity', label: '습도', value: '50% (예시)'),
      TelemetryReading(kind: 'wind', label: '풍속·풍향', value: '2 m/s (예시)'),
      TelemetryReading(kind: 'precip', label: '강수확률', value: '0% (예시)'),
      TelemetryReading(kind: 'tide', label: '조위 상태', value: '만조 12:00 (예시)'),
    ],
    degraded: false,
    weatherRefreshing: false,
    moon: Moon(
      illumination: isDay ? 50 : 10,
      phaseName: isDay ? '반달 (예시)' : '초승달 (예시)',
      moonrise: isDay ? '12:00' : '06:00',
      moonset: isDay ? '00:00' : '18:00',
      status: 'approx',
    ),
  );
}

const _sampleVega = StarlightTarget(
  id: 'sample-vega',
  name: '베가',
  constellation: '거문고자리',
  targetType: 'star',
  altitudeDeg: 60.0,
  azimuthDeg: 90.0,
  direction: '동쪽',
  observationMode: '육안',
  description: '예시 관측 대상입니다.',
);

const _sampleAltair = StarlightTarget(
  id: 'sample-altair',
  name: '알타이르',
  constellation: '독수리자리',
  targetType: 'star',
  altitudeDeg: 45.0,
  azimuthDeg: 135.0,
  direction: '남동쪽',
  observationMode: '육안',
  description: '예시 관측 대상입니다.',
);

const _sampleDeneb = StarlightTarget(
  id: 'sample-deneb',
  name: '데네브',
  constellation: '백조자리',
  targetType: 'star',
  altitudeDeg: 50.0,
  azimuthDeg: 45.0,
  direction: '북동쪽',
  observationMode: '쌍안경',
  description: '예시 관측 대상입니다.',
);

/// Tonight's starlight forecast at ([lat], [lng]).
StarlightForecast sampleStarlightForecast({
  required double lat,
  required double lng,
}) {
  return StarlightForecast(
    title: '야간 전환 별빛 예보 (예시)',
    summary: '예시 예보입니다. 서버에 연결되면 실제 예보가 표시돼요.',
    lat: lat,
    lng: lng,
    date: '2026-01-01',
    sunset: '18:00',
    astronomicalTwilightEnd: '19:30',
    target: _sampleVega,
    allVisibleTargets: const [_sampleVega, _sampleAltair, _sampleDeneb],
    conditions: const StarlightConditions(
      lunarAgeDays: 3.0,
      moonIlluminationPct: 10,
      moonPhaseName: '초승달 (예시)',
      sqmValue: 20.0,
      skyClass: 'Class 3 (예시)',
      milkyWayVisible: true,
    ),
    degraded: false,
  );
}

ObservationSpot _sampleBirdSpot(String suffix, double lat, double lng) {
  return ObservationSpot(
    id: 'sample-bird-$suffix',
    kind: 'bird',
    name: '예시 탐조 스팟 $suffix',
    coord: Coordinate(lat: lat, lng: lng),
    nightSky: null,
    birds: const BirdObservation(
      speciesCount: 2,
      topSpecies: [
        BirdSpecies(
          nameKo: '저어새',
          nameSci: 'Platalea minor',
          speciesCode: 'sample-sp-1',
          count: 10,
          obsDt: '2026-01-01 09:00',
        ),
        BirdSpecies(
          nameKo: '검은머리물떼새',
          nameSci: 'Haematopus ostralegus',
          speciesCode: 'sample-sp-2',
          count: null,
          obsDt: '2026-01-01 09:00',
        ),
      ],
      mostRecentObsDt: '2026-01-01 09:00',
      status: 'community',
    ),
    heritage: null,
  );
}

ObservationSpot _sampleStarSpot(String suffix, double lat, double lng) {
  return ObservationSpot(
    id: 'sample-star-$suffix',
    kind: 'star',
    name: '예시 별 관측지 $suffix',
    coord: Coordinate(lat: lat, lng: lng),
    nightSky: const NightSky(
      sqmValue: 20.0,
      bortleClass: 3,
      skyClass: 'Class 3 (예시)',
      status: 'approx',
    ),
    birds: null,
    heritage: null,
  );
}

ObservationSpot _sampleHeritageSpot(String suffix, double lat, double lng) {
  return ObservationSpot(
    id: 'sample-heritage-$suffix',
    kind: 'heritage',
    name: '예시 식당 $suffix',
    coord: Coordinate(lat: lat, lng: lng),
    nightSky: null,
    birds: null,
    heritage: HeritageInfo(
      addr: '예시 주소',
      distanceM: 1000,
      contentId: 'sample-heritage-$suffix',
    ),
  );
}

/// Observation-map spots around Ganghwa: birds, stars, and heritage eats.
/// There is no 'trail' spot kind — trails are drawn from [sampleTrails].
ObservationMapResponse sampleObservationMap() {
  return ObservationMapResponse(
    region: '예시 지역',
    degraded: false,
    spots: [
      _sampleBirdSpot('A', 37.59, 126.42),
      _sampleBirdSpot('B', 37.61, 126.45),
      _sampleStarSpot('A', 37.70, 126.40),
      _sampleStarSpot('B', 37.66, 126.36),
      _sampleHeritageSpot('A', 37.60, 126.43),
      _sampleHeritageSpot('B', 37.63, 126.41),
    ],
  );
}

HeritageEat _sampleEat(String suffix, int n, double lat, double lng) {
  return HeritageEat(
    name: '예시 식당 $suffix',
    addr: '예시 주소',
    distanceM: 1000,
    lat: lat,
    lng: lng,
    contentId: 'sample-eat-$n',
  );
}

/// Three trail courses with no GPX (empty `gpxUrl`) — only start/end coords.
/// Day/night suitability is set on the first course only.
TrailsResponse sampleTrails() {
  return TrailsResponse(
    region: '예시 지역',
    degraded: false,
    courses: [
      TrailCourse(
        crsIdx: 'SAMPLE_CRS_1',
        name: '예시 둘레길 1코스',
        sigun: '예시 지역',
        distanceKm: 10.0,
        durationMin: 180,
        level: 1,
        cycle: '비순환형',
        gpxUrl: '',
        start: const Coordinate(lat: 37.70, lng: 126.42),
        end: const Coordinate(lat: 37.60, lng: 126.41),
        nightSky: const NightSky(
          sqmValue: 20.0,
          bortleClass: 3,
          skyClass: 'Class 3 (예시)',
          status: 'approx',
        ),
        heritageEats: [_sampleEat('A', 1, 37.61, 126.41)],
        daySuitability: const CourseSuitability(
          score: 80,
          label: '쾌적 (예시)',
          status: 'approx',
        ),
        nightSuitability: const CourseSuitability(
          score: 70,
          label: '천체관측 양호 (예시)',
          status: 'approx',
        ),
      ),
      TrailCourse(
        crsIdx: 'SAMPLE_CRS_2',
        name: '예시 둘레길 2코스',
        sigun: '예시 지역',
        distanceKm: 15.0,
        durationMin: 300,
        level: 2,
        cycle: '순환형',
        gpxUrl: '',
        start: const Coordinate(lat: 37.74, lng: 126.45),
        end: const Coordinate(lat: 37.69, lng: 126.38),
        nightSky: const NightSky(
          sqmValue: 19.0,
          bortleClass: 4,
          skyClass: 'Class 4 (예시)',
          status: 'approx',
        ),
        heritageEats: [_sampleEat('B', 2, 37.69, 126.38)],
        daySuitability: null,
        nightSuitability: null,
      ),
      TrailCourse(
        crsIdx: 'SAMPLE_CRS_3',
        name: '예시 둘레길 3코스',
        sigun: '예시 지역',
        distanceKm: 12.0,
        durationMin: 240,
        level: 2,
        cycle: '비순환형',
        gpxUrl: '',
        start: const Coordinate(lat: 37.78, lng: 126.33),
        end: const Coordinate(lat: 37.65, lng: 126.35),
        nightSky: const NightSky(
          sqmValue: 18.0,
          bortleClass: 5,
          skyClass: 'Class 5 (예시)',
          status: 'approx',
        ),
        heritageEats: [_sampleEat('C', 3, 37.65, 126.35)],
        daySuitability: null,
        nightSuitability: null,
      ),
    ],
  );
}

/// Detail for a sample course ([crsIdx] starting with `SAMPLE_`); any other
/// course id resolves to `found: false`.
TrailDetailResponse sampleTrailDetail(String crsIdx) {
  final isSample = crsIdx.startsWith('SAMPLE_');
  return TrailDetailResponse(
    crsIdx: crsIdx,
    found: isSample,
    description: isSample ? '예시 코스 설명입니다. 서버에 연결되면 실제 코스 정보가 표시돼요.' : null,
    themeId: null,
    startName: isSample ? '예시 출발점' : null,
    endName: isSample ? '예시 도착점' : null,
    travelerInfo: null,
    tourInfo: null,
    elevationProfile: const [],
    degraded: false,
  );
}

/// Region list with Ganghwa as the nearest region. Ids match the backend
/// registry so a selected region still works once the server recovers.
RegionsResponse sampleRegions() {
  return const RegionsResponse(
    nearestId: 'ganghwa',
    regions: [
      RegionSummary(
        id: 'ganghwa',
        label: '인천 강화군',
        distanceKm: 0.0,
        center: RegionCenter(lat: 37.70, lng: 126.45),
        hasStarSpot: true,
      ),
      RegionSummary(
        id: 'seosan',
        label: '충남 서산시',
        distanceKm: 100.0,
        center: RegionCenter(lat: 36.78, lng: 126.45),
        hasStarSpot: false,
      ),
    ],
  );
}

/// Today's tides: one high and one low at round times, no levels.
TodayTides sampleTodayTides() {
  return const TodayTides(
    found: true,
    degraded: false,
    stationName: '예시 관측소',
    extremes: [
      TideExtreme(time: '06:00', kind: 'high', levelCm: null),
      TideExtreme(time: '12:00', kind: 'low', levelCm: null),
    ],
  );
}

/// Species info echoing the queried names with a placeholder summary.
SpeciesInfo sampleSpecies({String? sci, String? ko}) {
  return SpeciesInfo(
    nameKo: ko,
    nameSci: sci,
    summary: '예시 설명입니다. 서버에 연결되면 실제 도감 정보가 표시돼요.',
    thumbnailUrl: null,
    wikiUrl: null,
    source: 'sample',
  );
}
