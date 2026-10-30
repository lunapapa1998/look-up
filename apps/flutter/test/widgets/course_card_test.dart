import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart' show ObsMode;
import 'package:lookup/models/trails.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/course_card.dart';

const _dayAccent = Color(0xFFF4C247);
const _nightAccent = Color(0xFF9CA3F5);

const _course = TrailCourse(
  crsIdx: 'T_TEST_1',
  name: '테스트 코스',
  sigun: '강화군',
  distanceKm: 12.3,
  durationMin: 240,
  level: 2,
  cycle: '순환형',
  gpxUrl: '',
  start: Coordinate(lat: 37.70, lng: 126.40),
  end: Coordinate(lat: 37.72, lng: 126.45),
  nightSky: NightSky(
    sqmValue: 21.2,
    bortleClass: 3,
    skyClass: 'Class 3',
    status: 'live',
  ),
  heritageEats: [],
  daySuitability: CourseSuitability(score: 82, label: '낮 쾌적', status: 'live'),
  nightSuitability: CourseSuitability(
    score: 64,
    label: '밤 보통',
    status: 'approx',
  ),
);

void main() {
  for (final theme in ObsMode.values) {
    testWidgets(
      'featured day/night suitability panels use yellow / lavender '
      '(${theme.name} theme)',
      (tester) async {
        tester.view.physicalSize = const Size(420, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeFor(theme),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CourseCard(
                  course: _course,
                  featured: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.widget<Icon>(find.byIcon(Icons.wb_sunny_outlined)).color,
          _dayAccent,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.nightlight_round)).color,
          _nightAccent,
        );

        final bars = tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .toList();
        expect(bars, hasLength(2));
        expect(bars[0].color, _dayAccent);
        expect(bars[0].backgroundColor, _dayAccent.withValues(alpha: 0.12));
        expect(bars[1].color, _nightAccent);
        expect(
          bars[1].backgroundColor,
          _nightAccent.withValues(alpha: 0.12),
        );

        Color? textColor(String s) =>
            tester.widget<Text>(find.text(s)).style?.color;
        // Readability: accent-colored text only on the dark (night) theme;
        // the light (day) theme draws it in onSurface.
        final onSurface = Theme.of(
          tester.element(find.byType(CourseCard)),
        ).colorScheme.onSurface;
        final isNight = theme == ObsMode.night;
        expect(textColor('낮 적합도'), isNight ? _dayAccent : onSurface);
        expect(textColor('82 / 100'), isNight ? _dayAccent : onSurface);
        expect(textColor('밤 적합도'), isNight ? _nightAccent : onSurface);
        expect(textColor('64 / 100'), isNight ? _nightAccent : onSurface);
        if (!isNight) {
          expect(textColor('82 / 100'), isNot(_dayAccent));
          expect(textColor('64 / 100'), isNot(_nightAccent));
        }
        // Provenance copy unchanged.
        expect(find.text('실시간'), findsOneWidget);
        expect(find.text('참고값'), findsOneWidget);
      },
    );
  }
}
