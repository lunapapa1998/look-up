import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/widgets/night_sky_scale.dart';

void main() {
  group('mapNightSky bortleClass boundaries', () {
    void expectTier(
      int bortleClass, {
      required int filledStars,
      required String label,
      required String expectation,
    }) {
      final result = mapNightSky(bortleClass: bortleClass, status: 'live');
      expect(result.filledStars, filledStars);
      expect(result.label, label);
      expect(result.expectation, expectation);
      expect(result.isApprox, false);
      expect(result.hasNoData, false);
    }

    test('bortleClass 1 -> tier 1-2', () {
      expectTier(1, filledStars: 5, label: '별이 쏟아져요', expectation: '은하수까지 선명해요');
    });

    test('bortleClass 2 -> tier 1-2', () {
      expectTier(2, filledStars: 5, label: '별이 쏟아져요', expectation: '은하수까지 선명해요');
    });

    test('bortleClass 3 -> tier 3-4', () {
      expectTier(3, filledStars: 4, label: '별이 잘 보여요', expectation: '맑으면 은하수도 보여요');
    });

    test('bortleClass 4 -> tier 3-4', () {
      expectTier(4, filledStars: 4, label: '별이 잘 보여요', expectation: '맑으면 은하수도 보여요');
    });

    test('bortleClass 5 -> tier 5-6', () {
      expectTier(5,
          filledStars: 3, label: '별이 조금 보여요', expectation: '밝은 별과 별자리 위주로 보여요');
    });

    test('bortleClass 6 -> tier 5-6', () {
      expectTier(6,
          filledStars: 3, label: '별이 조금 보여요', expectation: '밝은 별과 별자리 위주로 보여요');
    });

    test('bortleClass 7 -> tier 7-8', () {
      expectTier(7, filledStars: 2, label: '별이 흐릿해요', expectation: '아주 밝은 별만 보여요');
    });

    test('bortleClass 8 -> tier 7-8', () {
      expectTier(8, filledStars: 2, label: '별이 흐릿해요', expectation: '아주 밝은 별만 보여요');
    });

    test('bortleClass 9 -> tier 9', () {
      expectTier(9, filledStars: 1, label: '도시 불빛이 강해요', expectation: '별 관측은 어려워요');
    });
  });

  group('mapNightSky out-of-range clamping', () {
    test('bortleClass 0 clamps to tier 1-2 without throwing', () {
      final result = mapNightSky(bortleClass: 0, status: 'live');
      expect(result.filledStars, 5);
      expect(result.label, '별이 쏟아져요');
      expect(result.expectation, '은하수까지 선명해요');
    });

    test('bortleClass 10 clamps to tier 9 without throwing', () {
      final result = mapNightSky(bortleClass: 10, status: 'live');
      expect(result.filledStars, 1);
      expect(result.label, '도시 불빛이 강해요');
      expect(result.expectation, '별 관측은 어려워요');
    });
  });

  group('mapNightSky status handling', () {
    test('status approx sets isApprox true without changing filledStars', () {
      final normal = mapNightSky(bortleClass: 3, status: 'live');
      final approx = mapNightSky(bortleClass: 3, status: 'approx');

      expect(approx.isApprox, true);
      expect(approx.hasNoData, false);
      expect(approx.filledStars, normal.filledStars);
      expect(approx.label, normal.label);
      expect(approx.expectation, normal.expectation);
    });

    test('status none sets hasNoData true with filledStars 0 regardless of bortleClass', () {
      final result = mapNightSky(bortleClass: 1, status: 'none');
      expect(result.hasNoData, true);
      expect(result.filledStars, 0);
      expect(result.label, '정보 없음');
      expect(result.expectation, '');
    });

    test('empty status behaves like none', () {
      final result = mapNightSky(bortleClass: 9, status: '');
      expect(result.hasNoData, true);
      expect(result.filledStars, 0);
      expect(result.label, '정보 없음');
      expect(result.expectation, '');
    });

    test('status live behaves like the normal case', () {
      final result = mapNightSky(bortleClass: 5, status: 'live');
      expect(result.isApprox, false);
      expect(result.hasNoData, false);
      expect(result.filledStars, 3);
    });

    test('unrecognized status string behaves like the normal case', () {
      final result = mapNightSky(bortleClass: 5, status: 'weird-value');
      expect(result.isApprox, false);
      expect(result.hasNoData, false);
      expect(result.filledStars, 3);
    });
  });
}
