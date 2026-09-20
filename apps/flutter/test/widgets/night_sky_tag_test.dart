import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/trails.dart';
import 'package:lookup/widgets/night_sky_tag.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('compact mode renders the plain-language label for a given bortleClass', (
    tester,
  ) async {
    const nightSky = NightSky(
      sqmValue: 20.15,
      bortleClass: 3,
      skyClass: 'Class 3 양호한 다크스카이',
      status: 'live',
    );

    await tester.pumpWidget(_wrap(const NightSkyTag(nightSky: nightSky)));

    expect(find.text('별이 잘 보여요'), findsOneWidget);
    expect(find.text('맑으면 은하수도 보여요'), findsOneWidget);
    expect(find.textContaining('SQM'), findsNothing);
    expect(find.textContaining('Bortle'), findsNothing);
  });

  testWidgets('large mode additionally renders the SQM/Bortle expert line', (
    tester,
  ) async {
    const nightSky = NightSky(
      sqmValue: 20.15,
      bortleClass: 3,
      skyClass: 'Class 3 양호한 다크스카이',
      status: 'live',
    );

    await tester.pumpWidget(
      _wrap(const NightSkyTag(nightSky: nightSky, large: true)),
    );

    expect(find.text('별이 잘 보여요'), findsOneWidget);
    expect(find.text('SQM 20.15 · Bortle 3'), findsOneWidget);
    expect(find.textContaining('전문가용'), findsNothing);
  });

  testWidgets('isApprox true renders the 추정치 badge next to the SQM/Bortle line', (
    tester,
  ) async {
    const nightSky = NightSky(
      sqmValue: 18.2,
      bortleClass: 4,
      skyClass: 'Class 4 도시외곽 다크스카이',
      status: 'approx',
    );

    await tester.pumpWidget(
      _wrap(const NightSkyTag(nightSky: nightSky, large: true)),
    );

    expect(find.text('추정치'), findsOneWidget);
    expect(find.text('SQM 18.20 · Bortle 4'), findsOneWidget);
  });

  testWidgets(
    'hasNoData true renders 정보 없음 and never the SQM/Bortle line, even in large mode',
    (tester) async {
      const nightSky = NightSky(
        sqmValue: 0,
        bortleClass: 1,
        skyClass: 'Class 1',
        status: 'none',
      );

      await tester.pumpWidget(
        _wrap(const NightSkyTag(nightSky: nightSky, large: true)),
      );

      expect(find.text('정보 없음'), findsOneWidget);
      expect(find.textContaining('SQM'), findsNothing);
      expect(find.textContaining('Bortle'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    },
  );

  testWidgets(
    'tapping the info affordance opens a bottom sheet explaining SQM/Bortle',
    (tester) async {
      const nightSky = NightSky(
        sqmValue: 20.15,
        bortleClass: 3,
        skyClass: 'Class 3 양호한 다크스카이',
        status: 'live',
      );

      await tester.pumpWidget(_wrap(const NightSkyTag(nightSky: nightSky)));

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('SQM과 Bortle 등급이란?'), findsOneWidget);
    },
  );

  final bortleTierLabels = <int, String>{
    2: '별이 쏟아져요',
    4: '별이 잘 보여요',
    6: '별이 조금 보여요',
    8: '별이 흐릿해요',
    9: '도시 불빛이 강해요',
  };

  for (final entry in bortleTierLabels.entries) {
    testWidgets(
      'compact mode renders the plain-language label for bortleClass ${entry.key}',
      (tester) async {
        final nightSky = NightSky(
          sqmValue: 19.0,
          bortleClass: entry.key,
          skyClass: 'Class ${entry.key}',
          status: 'live',
        );

        await tester.pumpWidget(_wrap(NightSkyTag(nightSky: nightSky)));

        expect(find.text(entry.value), findsOneWidget);
      },
    );
  }

  testWidgets('compact mode renders exactly five star icons', (tester) async {
    const nightSky = NightSky(
      sqmValue: 20.15,
      bortleClass: 3,
      skyClass: 'Class 3 양호한 다크스카이',
      status: 'live',
    );

    await tester.pumpWidget(_wrap(const NightSkyTag(nightSky: nightSky)));

    expect(find.byIcon(Icons.auto_awesome), findsNWidgets(5));
  });

  testWidgets(
    'combined Semantics label contains the star count, label, and 추정치 for an approx status',
    (tester) async {
      const nightSky = NightSky(
        sqmValue: 18.2,
        bortleClass: 4,
        skyClass: 'Class 4 도시외곽 다크스카이',
        status: 'approx',
      );

      await tester.pumpWidget(_wrap(const NightSkyTag(nightSky: nightSky)));

      expect(
        find.bySemanticsLabel(
          RegExp(r'5점 중 4점.*별이 잘 보여요.*추정치'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'approx status renders filled stars with lower opacity than live status at the same bortleClass',
    (tester) async {
      const approxNightSky = NightSky(
        sqmValue: 18.2,
        bortleClass: 4,
        skyClass: 'Class 4 도시외곽 다크스카이',
        status: 'approx',
      );
      const liveNightSky = NightSky(
        sqmValue: 18.2,
        bortleClass: 4,
        skyClass: 'Class 4 도시외곽 다크스카이',
        status: 'live',
      );

      await tester.pumpWidget(
        _wrap(const NightSkyTag(nightSky: approxNightSky)),
      );
      final approxIcons = tester
          .widgetList<Icon>(find.byIcon(Icons.auto_awesome))
          .toList();

      await tester.pumpWidget(
        _wrap(const NightSkyTag(nightSky: liveNightSky)),
      );
      final liveIcons = tester
          .widgetList<Icon>(find.byIcon(Icons.auto_awesome))
          .toList();

      final approxFilledAlpha = approxIcons[0].color!.a;
      final liveFilledAlpha = liveIcons[0].color!.a;

      expect(approxFilledAlpha, lessThan(liveFilledAlpha));
    },
  );
}
