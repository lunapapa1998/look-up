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
}
