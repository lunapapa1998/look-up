/// Human-readable formatting helpers for trail data — screen-reader-friendly
/// phrasing for raw numeric/enum fields, per the trails spec's
/// accessibility section.
library;

String formatDistanceM(int distanceM) {
  if (distanceM < 1000) return '${distanceM}m';
  return '${(distanceM / 1000).toStringAsFixed(1)}km';
}

String formatDurationMin(int durationMin) {
  final hours = durationMin ~/ 60;
  final minutes = durationMin % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}

String formatLevel(int level) {
  switch (level) {
    case 1:
      return '쉬움';
    case 3:
      return '어려움';
    default:
      return '보통';
  }
}
