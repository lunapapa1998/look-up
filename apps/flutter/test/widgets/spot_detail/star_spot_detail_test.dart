import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/starlight_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/observation_map.dart';
import 'package:lookup/models/starlight_forecast.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/widgets/observation_spot_detail.dart';
import 'package:lookup/widgets/score_gauge.dart';
import 'package:lookup/widgets/spot_detail/star_spot_detail.dart';

class _FakeStarlightApi implements StarlightApi {
  _FakeStarlightApi({required this.forecast});

  final StarlightForecast forecast;

  @override
  Future<StarlightForecast> fetchForecast({
    required double lat,
    required double lng,
    String? date,
    String? time,
    String? target,
    double? sqm,
    int? moonIllumination,
    String? twilightEnd,
  }) async {
    return forecast;
  }
}

class _PendingStarlightApi implements StarlightApi {
  final Completer<StarlightForecast> completer =
      Completer<StarlightForecast>();

  @override
  Future<StarlightForecast> fetchForecast({
    required double lat,
    required double lng,
    String? date,
    String? time,
    String? target,
    double? sqm,
    int? moonIllumination,
    String? twilightEnd,
  }) {
    return completer.future;
  }
}

const _target = StarlightTarget(
  id: 'test-target-1',
  name: '테스트자리 성단',
  constellation: '테스트자리',
  targetType: 'cluster',
  altitudeDeg: 45.0,
  azimuthDeg: 180.0,
  direction: '남쪽',
  observationMode: 'naked_eye',
  description: '테스트용 관측 대상',
);

StarlightForecast _forecast({bool degraded = false}) {
  return StarlightForecast(
    title: '야간 전환 별빛 예보',
    summary: '오늘 밤은 맑아서 관측하기 좋아요',
    lat: 37.71,
    lng: 126.42,
    date: '2026-09-21',
    sunset: '18:30',
    astronomicalTwilightEnd: '20:00',
    target: _target,
    allVisibleTargets: const [_target],
    conditions: const StarlightConditions(
      lunarAgeDays: 5.0,
      moonIlluminationPct: 30,
      moonPhaseName: '상현달',
      sqmValue: 21.5,
      skyClass: 'Class 3',
      milkyWayVisible: true,
    ),
    degraded: degraded,
  );
}

StarlightForecast _emptyForecast() {
  return StarlightForecast(
    title: '야간 전환 별빛 예보',
    summary: '오늘 밤은 맑아서 관측하기 좋아요',
    lat: 37.71,
    lng: 126.42,
    date: '2026-09-21',
    sunset: '18:30',
    astronomicalTwilightEnd: '20:00',
    target: _target,
    allVisibleTargets: const <StarlightTarget>[],
    conditions: const StarlightConditions(
      lunarAgeDays: 5.0,
      moonIlluminationPct: 30,
      moonPhaseName: '상현달',
      sqmValue: 21.5,
      skyClass: 'Class 3',
      milkyWayVisible: true,
    ),
    degraded: false,
  );
}

const _spot = ObservationSpot(
  id: 'star-001',
  kind: 'star',
  name: '강화 천문인마을',
  coord: Coordinate(lat: 37.71, lng: 126.42),
  nightSky: NightSky(
    sqmValue: 21.7,
    bortleClass: 3,
    skyClass: 'Class 3 양호한 다크스카이',
    status: 'measured',
  ),
  birds: null,
  heritage: null,
);

Future<void> _pumpDetail(
  WidgetTester tester,
  StarlightForecast forecast,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        starlightApiProvider.overrideWithValue(
          _FakeStarlightApi(forecast: forecast),
        ),
        suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: StarSpotDetail(
              spot: _spot,
              scrollController: ScrollController(),
              onBack: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders the golden-time summary, sunset/twilight-end line, and at '
    'least one tonight-sky target name',
    (tester) async {
      await _pumpDetail(tester, _forecast());
      await tester.pumpAndSettle();

      expect(find.text('오늘 밤은 맑아서 관측하기 좋아요'), findsOneWidget);
      expect(find.text('일몰 18:30 · 관측 시작 20:00'), findsOneWidget);
      expect(find.text('테스트자리 성단'), findsOneWidget);
    },
  );

  testWidgets('degraded forecast shows a 추정치 label next to the heading', (
    tester,
  ) async {
    await _pumpDetail(tester, _forecast(degraded: true));
    await tester.pumpAndSettle();

    // Both the golden-time block and TonightSkySection show their own
    // 추정치 label when the forecast is degraded.
    expect(find.text('추정치'), findsNWidgets(2));
  });

  testWidgets('shows the loading skeleton before the forecast resolves', (
    tester,
  ) async {
    final pendingApi = _PendingStarlightApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          starlightApiProvider.overrideWithValue(pendingApi),
          suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: StarSpotDetail(
                spot: _spot,
                scrollController: ScrollController(),
                onBack: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('오늘 밤은 맑아서 관측하기 좋아요'), findsNothing);

    pendingApi.completer.complete(_forecast());
    await tester.pumpAndSettle();
  });

  testWidgets('empty allVisibleTargets shows the tonight-sky empty state', (
    tester,
  ) async {
    await _pumpDetail(tester, _emptyForecast());
    await tester.pumpAndSettle();

    expect(find.text('오늘 밤은 또렷이 보이는 대상이 적어요'), findsOneWidget);
  });

  testWidgets('star spot detail does not render the suitability score gauge', (
    tester,
  ) async {
    await _pumpDetail(tester, _forecast());
    await tester.pumpAndSettle();

    expect(find.byType(ScoreGauge), findsNothing);
    expect(find.byType(SuitabilityBlock), findsNothing);
  });
}
