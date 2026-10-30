import '../models/discovery.dart';
import '../models/observation_map.dart';

/// A spot suggested for today's observation journey plus a short, factual
/// reason (spec 058 Phase 2). The reason states what the data says, never
/// that something will be seen.
class JourneyRecommendation {
  const JourneyRecommendation({required this.spot, required this.reason});

  final ObservationSpot spot;
  final String reason;
}

/// Picks today's suggested spot from already-loaded observation-map data.
///
/// - Day: the bird spot with the most recorded species (eBird data, which
///   the backend fetches with a 14-day window); ties go to the most recent
///   observation (`mostRecentObsDt` is 'YYYY-MM-DD HH:mm', so string order
///   is time order).
/// - Night: the star spot with the highest SQM (light-pollution reference
///   data).
///
/// Returns null when no spot qualifies.
JourneyRecommendation? recommendJourneySpot(
  ObsMode mode,
  List<ObservationSpot> spots,
) {
  switch (mode) {
    case ObsMode.day:
      ObservationSpot? best;
      for (final spot in spots) {
        final birds = spot.birds;
        if (spot.kind != 'bird' || birds == null || birds.speciesCount <= 0) {
          continue;
        }
        final current = best?.birds;
        if (current == null ||
            birds.speciesCount > current.speciesCount ||
            (birds.speciesCount == current.speciesCount &&
                birds.mostRecentObsDt.compareTo(current.mostRecentObsDt) >
                    0)) {
          best = spot;
        }
      }
      if (best == null) return null;
      return JourneyRecommendation(
        spot: best,
        reason:
            '최근 14일 시민과학 데이터(eBird) 기준 ${best.birds!.speciesCount}종 기록',
      );
    case ObsMode.night:
      ObservationSpot? best;
      for (final spot in spots) {
        final sky = spot.nightSky;
        if (spot.kind != 'star' || sky == null) continue;
        final current = best?.nightSky;
        if (current == null || sky.sqmValue > current.sqmValue) best = spot;
      }
      if (best == null) return null;
      return JourneyRecommendation(
        spot: best,
        reason:
            'SQM ${best.nightSky!.sqmValue.toStringAsFixed(1)} · 빛공해 참고 데이터',
      );
  }
}

/// "지금/다음 관찰 시간" line for [mode] from the golden-hour ranges
/// ('HH:mm - HH:mm', may wrap past midnight) at [now].
///
/// - Inside the window: '지금 관찰 시간 · HH:mm까지'.
/// - Otherwise: '다음 관찰 시간 HH:mm'.
/// - Unparseable range: '관찰 시간 ' + the original range text.
/// - No golden hour for [mode]: null.
String? goldenTimeLine(
  List<GoldenHour> goldenHours,
  ObsMode mode,
  DateTime now,
) {
  GoldenHour? hour;
  for (final gh in goldenHours) {
    if (gh.mode == mode) {
      hour = gh;
      break;
    }
  }
  if (hour == null) return null;
  final range = _parseRange(hour.timeRange);
  if (range == null) return '관찰 시간 ${hour.timeRange.trim()}';
  final (start, end) = range;
  final minute = now.hour * 60 + now.minute;
  final bool inside;
  if (start <= end) {
    inside = minute >= start && minute < end;
  } else {
    // Wraps past midnight, e.g. 21:40 - 01:20.
    inside = minute >= start || minute < end;
  }
  if (inside) return '지금 관찰 시간 · ${_hhmm(end)}까지';
  return '다음 관찰 시간 ${_hhmm(start)}';
}

final RegExp _rangePattern = RegExp(
  r'^\s*(\d{1,2}):(\d{2})\s*[-~–]\s*(\d{1,2}):(\d{2})\s*$',
);

/// Minutes-of-day (start, end), or null when [text] is not 'HH:mm - HH:mm'.
(int, int)? _parseRange(String text) {
  final match = _rangePattern.firstMatch(text);
  if (match == null) return null;
  final values = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
  if (values[0] > 23 || values[2] > 23 || values[1] > 59 || values[3] > 59) {
    return null;
  }
  return (values[0] * 60 + values[1], values[2] * 60 + values[3]);
}

String _hhmm(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
