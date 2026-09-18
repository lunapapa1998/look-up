import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/utils/relative_time.dart';

void main() {
  final now = DateTime(2026, 9, 13, 12, 0, 0);

  test('30초 전 obsDt는 "방금"을 반환한다', () {
    final obsDt = now.subtract(const Duration(seconds: 30)).toIso8601String();
    expect(formatRelativeTime(obsDt, now), '방금');
  });

  test('10분 전 obsDt는 "10분 전"을 반환한다', () {
    final obsDt = now.subtract(const Duration(minutes: 10)).toIso8601String();
    expect(formatRelativeTime(obsDt, now), '10분 전');
  });

  test('3시간 전 obsDt는 "3시간 전"을 반환한다', () {
    final obsDt = now.subtract(const Duration(hours: 3)).toIso8601String();
    expect(formatRelativeTime(obsDt, now), '3시간 전');
  });

  test('2일 전 obsDt는 "2일 전"을 반환한다', () {
    final obsDt = now.subtract(const Duration(days: 2)).toIso8601String();
    expect(formatRelativeTime(obsDt, now), '2일 전');
  });

  test('파싱 불가능한 문자열은 원문 그대로 반환한다', () {
    expect(formatRelativeTime('이상한값', now), '이상한값');
  });

  test('미래시각 obsDt는 원문 문자열을 그대로 반환한다', () {
    final obsDt = now.add(const Duration(hours: 1)).toIso8601String();
    expect(formatRelativeTime(obsDt, now), obsDt);
  });

  test('formatObservedAt: 오늘 + 시간 있음은 "오늘 HH:mm"을 반환한다', () {
    expect(formatObservedAt('2026-09-13 09:05', now), '오늘 09:05');
  });

  test('formatObservedAt: 어제 + 시간 있음은 "어제 HH:mm"을 반환한다', () {
    expect(formatObservedAt('2026-09-12 19:39', now), '어제 19:39');
  });

  test('formatObservedAt: 다른 날 + 시간 있음은 "N월 N일 HH:mm"을 반환한다', () {
    expect(formatObservedAt('2026-08-07 19:39', now), '8월 7일 19:39');
  });

  test('formatObservedAt: 오늘 + 시간 없음은 "오늘"만 반환한다', () {
    expect(formatObservedAt('2026-09-13', now), '오늘');
  });

  test('formatObservedAt: 어제 + 시간 없음은 "어제"만 반환한다', () {
    expect(formatObservedAt('2026-09-12', now), '어제');
  });

  test('formatObservedAt: 다른 날 + 시간 없음은 "N월 N일"을 반환한다', () {
    expect(formatObservedAt('2026-08-07', now), '8월 7일');
  });

  test('formatObservedAt: 미래시각은 원문 문자열을 그대로 반환한다', () {
    expect(formatObservedAt('2026-09-14 09:05', now), '2026-09-14 09:05');
  });

  test('formatObservedAt: 파싱 불가능한 문자열은 원문 그대로 반환한다', () {
    expect(formatObservedAt('이상한값', now), '이상한값');
  });

  test('formatObservedAt: UTC Z suffix obsDt는 UTC가 아닌 로컬 기준 날짜/시간으로 표시된다', () {
    // obsDt는 UTC 09-13 15:30(오후)이지만 KST(+9)로 변환하면 09-14 00:30(자정 직후)이 된다.
    // UTC 필드를 그대로 쓰면 "어제 15:30"이 되지만, 로컬 변환 시 "오늘 00:30"이어야 한다.
    final localNow = DateTime(2026, 9, 14, 20, 0, 0);
    expect(
      formatObservedAt('2026-09-13T15:30:00Z', localNow),
      '오늘 00:30',
    );
  });
}
