import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/trails_api.dart';
import 'package:lookup/models/trails.dart';

void main() {
  group('TrailDetailResponse.fromJson', () {
    test('parses a fully-populated found-true example', () {
      final detail = TrailDetailResponse.fromJson({
        'crsIdx': 'T_CRS_MNG0000009999',
        'found': true,
        'description': '서해랑길 101코스 설명',
        'themeId': 'THEME01',
        'startName': '강화터미널',
        'endName': '동막해수욕장',
        'travelerInfo': '버스 이용<br>도보 3분',
        'tourInfo': '동막해수욕장<br>강화갯벌센터',
        'elevationProfile': [
          {'positionRatio': 0.0, 'elevationM': 5.0},
          {'positionRatio': 0.5, 'elevationM': 42.3},
          {'positionRatio': 1.0, 'elevationM': 12.1},
        ],
        'degraded': false,
      });

      expect(detail.crsIdx, 'T_CRS_MNG0000009999');
      expect(detail.found, isTrue);
      expect(detail.description, '서해랑길 101코스 설명');
      expect(detail.themeId, 'THEME01');
      expect(detail.startName, '강화터미널');
      expect(detail.endName, '동막해수욕장');
      expect(detail.travelerInfo, '버스 이용<br>도보 3분');
      expect(detail.tourInfo, '동막해수욕장<br>강화갯벌센터');
      expect(detail.elevationProfile, hasLength(3));
      expect(detail.elevationProfile[0].positionRatio, 0.0);
      expect(detail.elevationProfile[0].elevationM, 5.0);
      expect(detail.elevationProfile[1].positionRatio, 0.5);
      expect(detail.elevationProfile[1].elevationM, 42.3);
      expect(detail.elevationProfile[2].positionRatio, 1.0);
      expect(detail.elevationProfile[2].elevationM, 12.1);
      expect(detail.degraded, isFalse);
    });

    test('parses a found-false example', () {
      final detail = TrailDetailResponse.fromJson({
        'crsIdx': 'T_CRS_MNG0000000001',
        'found': false,
        'description': null,
        'themeId': null,
        'startName': null,
        'endName': null,
        'travelerInfo': null,
        'tourInfo': null,
        'elevationProfile': [],
        'degraded': false,
      });

      expect(detail.crsIdx, 'T_CRS_MNG0000000001');
      expect(detail.found, isFalse);
      expect(detail.description, isNull);
      expect(detail.themeId, isNull);
      expect(detail.startName, isNull);
      expect(detail.endName, isNull);
      expect(detail.travelerInfo, isNull);
      expect(detail.tourInfo, isNull);
      expect(detail.elevationProfile, isEmpty);
      expect(detail.degraded, isFalse);
    });
  });

  group('FakeTrailsApi.fetchTrailDetail', () {
    test('trailDetailShouldThrow true throws TrailsApiException', () {
      final api = FakeTrailsApi(trailDetailShouldThrow: true);

      expect(
        () => api.fetchTrailDetail(crsIdx: 'T_CRS_MNG0000009999'),
        throwsA(isA<TrailsApiException>()),
      );
    });

    test('trailDetailResponse left null echoes crsIdx into a found-false response', () async {
      final api = FakeTrailsApi();

      final detail = await api.fetchTrailDetail(crsIdx: 'T_CRS_MNG0000001234');

      expect(detail.crsIdx, 'T_CRS_MNG0000001234');
      expect(detail.found, isFalse);
      expect(detail.degraded, isFalse);
      expect(detail.description, isNull);
      expect(detail.elevationProfile, isEmpty);
    });
  });
}
