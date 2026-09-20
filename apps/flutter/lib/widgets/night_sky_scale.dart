class NightSkyDisplay {
  final int filledStars;
  final String label;
  final String expectation;
  final bool isApprox;
  final bool hasNoData;

  const NightSkyDisplay({
    required this.filledStars,
    required this.label,
    required this.expectation,
    required this.isApprox,
    required this.hasNoData,
  });
}

NightSkyDisplay mapNightSky({required int bortleClass, required String status}) {
  if (status == 'none' || status.isEmpty) {
    return const NightSkyDisplay(
      filledStars: 0,
      label: '정보 없음',
      expectation: '',
      isApprox: false,
      hasNoData: true,
    );
  }

  final int clamped = bortleClass < 1 ? 1 : (bortleClass > 9 ? 9 : bortleClass);

  late final int filledStars;
  late final String label;
  late final String expectation;

  if (clamped <= 2) {
    filledStars = 5;
    label = '별이 쏟아져요';
    expectation = '은하수까지 선명해요';
  } else if (clamped <= 4) {
    filledStars = 4;
    label = '별이 잘 보여요';
    expectation = '맑으면 은하수도 보여요';
  } else if (clamped <= 6) {
    filledStars = 3;
    label = '별이 조금 보여요';
    expectation = '밝은 별과 별자리 위주로 보여요';
  } else if (clamped <= 8) {
    filledStars = 2;
    label = '별이 흐릿해요';
    expectation = '아주 밝은 별만 보여요';
  } else {
    filledStars = 1;
    label = '도시 불빛이 강해요';
    expectation = '별 관측은 어려워요';
  }

  return NightSkyDisplay(
    filledStars: filledStars,
    label: label,
    expectation: expectation,
    isApprox: status == 'approx',
    hasNoData: false,
  );
}
