/// Pure relative-time formatter (spec 019 P2-2). [now] is a parameter rather
/// than an internal [DateTime.now] call so this stays unit-testable; call
/// sites should source it from the app's `nowProvider` rather than reading
/// the wall clock directly.
String formatRelativeTime(String obsDt, DateTime now) {
  final parsed = DateTime.tryParse(obsDt);
  if (parsed == null) return obsDt;
  if (parsed.isAfter(now)) return obsDt;

  final diff = now.difference(parsed);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

/// Formats [obsDt] as an absolute observed date/time (오늘/어제/N월 N일),
/// falling back to the raw string when unparsable or in the future.
String formatObservedAt(String obsDt, DateTime now) {
  final parsed = DateTime.tryParse(obsDt);
  if (parsed == null) return obsDt;
  if (parsed.isAfter(now)) return obsDt;

  final localParsed = parsed.toLocal();

  final hasTime = obsDt.contains(':');

  final today = DateTime(now.year, now.month, now.day);
  final parsedDay = DateTime(localParsed.year, localParsed.month, localParsed.day);
  final dayDiff = today.difference(parsedDay).inDays;

  final timePart =
      '${localParsed.hour.toString().padLeft(2, '0')}:${localParsed.minute.toString().padLeft(2, '0')}';

  String datePart;
  if (dayDiff == 0) {
    datePart = '오늘';
  } else if (dayDiff == 1) {
    datePart = '어제';
  } else {
    datePart = '${localParsed.month}월 ${localParsed.day}일';
  }

  return hasTime ? '$datePart $timePart' : datePart;
}
