import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/widgets/spot_detail/trail_spot_detail.dart';

/// [TrailsApi] fake whose `fetchTrailDetail` future never resolves, so tests
/// can observe the provider's loading state without a race against a real
/// response.
class _PendingTrailsApi implements TrailsApi {
  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({required String crsIdx}) {
    return Completer<TrailDetailResponse>().future;
  }
}

/// [TrailsApi] fake that always throws and counts calls, so the retry test
/// can prove tapping the retry button actually re-invokes the provider.
class _RetryTrailsApi implements TrailsApi {
  int callCount = 0;

  @override
  Future<TrailsResponse> fetchTrails({
    required double lat,
    required double lng,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrailDetailResponse> fetchTrailDetail({required String crsIdx}) async {
    callCount++;
    throw TrailsApiException(500, 'fake trail detail failure');
  }
}

const _testCourse = TrailCourse(
  crsIdx: 'T_CRS_MNG0000009999',
  name: '서해랑길 101코스',
  sigun: '인천 강화군',
  distanceKm: 11.0,
  durationMin: 210,
  level: 1,
  cycle: '비순환형',
  gpxUrl: 'https://www.durunubi.kr/courseInfo/101.gpx',
  start: Coordinate(lat: 37.71, lng: 126.42),
  end: Coordinate(lat: 37.60, lng: 126.41),
  nightSky: NightSky(
    sqmValue: 20.15,
    bortleClass: 3,
    skyClass: 'Class 3 양호한 다크스카이',
    status: 'approx',
  ),
  heritageEats: [],
  daySuitability: null,
  nightSuitability: null,
);

const _fullDetail = TrailDetailResponse(
  crsIdx: 'T_CRS_MNG0000009999',
  found: true,
  description: '서해랑길 101코스는 강화도 해안을 따라 이어지는 길입니다.',
  themeId: 'THEME01',
  startName: '강화터미널',
  endName: '동막해수욕장',
  travelerInfo: '버스 이용<br>도보 3분',
  tourInfo: '동막해수욕장<br/>강화갯벌센터',
  elevationProfile: [
    ElevationPoint(positionRatio: 0.0, elevationM: 5.0),
    ElevationPoint(positionRatio: 0.5, elevationM: 42.3),
    ElevationPoint(positionRatio: 1.0, elevationM: 12.1),
  ],
  degraded: false,
);

const _emptyDetail = TrailDetailResponse(
  crsIdx: 'T_CRS_MNG0000009999',
  found: false,
  description: null,
  themeId: null,
  startName: null,
  endName: null,
  travelerInfo: null,
  tourInfo: null,
  elevationProfile: [],
  degraded: false,
);

Future<void> _pumpTrailSpotDetail(
  WidgetTester tester, {
  required TrailsApi trailsApi,
}) async {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [trailsApiProvider.overrideWithValue(trailsApi)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: TrailSpotDetail(
              course: _testCourse,
              scrollController: scrollController,
              onBack: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TrailSpotDetail Phase 3: durunubi rich detail', () {
    testWidgets(
      'fully-populated detail renders description/travelerInfo/tourInfo '
      '(br tags normalized to newlines) and an elevation summary',
      (tester) async {
        await _pumpTrailSpotDetail(
          tester,
          trailsApi: FakeTrailsApi(trailDetailResponse: _fullDetail),
        );
        await tester.pumpAndSettle();

        expect(find.text('코스 안내'), findsOneWidget);
        expect(find.text(_fullDetail.description!), findsOneWidget);

        expect(find.text('오시는 길'), findsOneWidget);
        expect(find.text('버스 이용\n도보 3분'), findsOneWidget);

        expect(find.text('주변 볼거리'), findsOneWidget);
        expect(find.text('동막해수욕장\n강화갯벌센터'), findsOneWidget);

        expect(find.textContaining('<br'), findsNothing);

        expect(find.text('고도 프로필'), findsOneWidget);
        expect(find.text('최저 표고'), findsOneWidget);
        expect(find.text('5m'), findsOneWidget);
        expect(find.text('최고 표고'), findsOneWidget);
        expect(find.text('42m'), findsOneWidget);
      },
    );

    testWidgets(
      'a found-false detail with everything null renders the neutral '
      'no-data note and none of the section headings',
      (tester) async {
        await _pumpTrailSpotDetail(
          tester,
          trailsApi: FakeTrailsApi(trailDetailResponse: _emptyDetail),
        );
        await tester.pumpAndSettle();

        expect(find.text('두루누비 상세 정보가 없어요'), findsOneWidget);
        expect(find.text('코스 안내'), findsNothing);
        expect(find.text('오시는 길'), findsNothing);
        expect(find.text('주변 볼거리'), findsNothing);
        expect(find.text('고도 프로필'), findsNothing);
      },
    );

    testWidgets('loading state shows a progress indicator', (tester) async {
      await _pumpTrailSpotDetail(tester, trailsApi: _PendingTrailsApi());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'error state shows the retry button, and tapping it re-invokes the '
      'provider',
      (tester) async {
        final api = _RetryTrailsApi();
        await _pumpTrailSpotDetail(tester, trailsApi: api);
        await tester.pumpAndSettle();

        expect(find.text('상세 정보를 불러오지 못했어요'), findsOneWidget);
        final retryButton = find.widgetWithText(FilledButton, '다시 시도');
        expect(retryButton, findsOneWidget);
        expect(api.callCount, 1);

        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        expect(api.callCount, 2);
      },
    );
  });
}
