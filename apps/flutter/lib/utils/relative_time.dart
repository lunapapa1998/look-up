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
