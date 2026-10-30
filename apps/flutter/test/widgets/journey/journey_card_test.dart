import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/observation_map_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/observation.dart';
import 'package:lookup/screens/badges_screen.dart';
import 'package:lookup/screens/observation_form_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/state/journey_providers.dart';
import 'package:lookup/state/providers.dart';
import 'package:lookup/state/sample_data_provider.dart';
import 'package:lookup/utils/keep_all.dart';
import 'package:lookup/widgets/common/status_view.dart';
import 'package:lookup/widgets/journey/journey_card.dart';

Future<ProviderContainer> _pumpCard(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  ObservationMapApi? mapApi,
  void Function(ProviderContainer container)? setup,
  VoidCallback? onConditionsTap,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      observationMapApiProvider.overrideWithValue(
        mapApi ?? FakeObservationMapApi(),
      ),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(
          const ObservationLocation(
            lat: 37.5921,
            lng: 126.3984,
            placeName: null,
            isFallback: true,
          ),
        ),
      ),
      nowProvider.overrideWithValue(DateTime(2026, 9, 9, 10, 0)),
      ecologApiProvider.overrideWithValue(FakeEcologApi()),
    ],
  );
  addTearDown(container.dispose);
  setup?.call(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: JourneyCard(onConditionsTap: onConditionsTap),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('day: renders the five steps with reference wording', (
    tester,
  ) async {
    await _pumpCard(tester);

    for (var i = 1; i <= 5; i++) {
      expect(find.byKey(JourneyCard.stepKey(i)), findsOneWidget);
      expect(
        tester.getSize(find.byKey(JourneyCard.stepKey(i))).height,
        greaterThanOrEqualTo(44),
      );
    }
    expect(find.text('오늘의 관찰 여정'), findsOneWidget);
    // Region and detail lines render through keepAll (U+2060 inside words).
    expect(find.textContaining(keepAll('시연 지역: 강화')), findsOneWidget);
    expect(find.text(keepAll('매우 쾌적 (Prime) · 88점')), findsOneWidget);
    expect(find.text(keepAll('참고 지표 · 다음 관찰 시간 14:00')), findsOneWidget);
    expect(find.text(keepAll('강화도 동막갯벌')), findsOneWidget);
    expect(
      find.text(keepAll('최근 14일 시민과학 데이터(eBird) 기준 12종 기록')),
      findsOneWidget,
    );
    expect(find.text(keepAll('관찰한 새를 생태일기에 남겨요')), findsOneWidget);
    expect(find.text('시범'), findsOneWidget);
    expect(find.text('예시'), findsNothing);
    expect(find.textContaining(keepAll('볼 수 있어요')), findsNothing);
  });

  testWidgets('detail and region lines use keepAll with plain semantics', (
    tester,
  ) async {
    await _pumpCard(tester);

    const detail = '최근 14일 시민과학 데이터(eBird) 기준 12종 기록';
    final detailText = tester.widget<Text>(find.text(keepAll(detail)));
    expect(detailText.data, contains(kWordJoiner));
    expect(detailText.data!.replaceAll(kWordJoiner, ''), detail);
    expect(detailText.semanticsLabel, detail);

    const region = '시연 지역: 강화 · 낮 새 관찰';
    final regionText = tester.widget<Text>(find.text(keepAll(region)));
    expect(regionText.data, contains(kWordJoiner));
    expect(regionText.semanticsLabel, region);
  });

  testWidgets('night: star copy and SQM-based recommendation', (tester) async {
    await _pumpCard(
      tester,
      setup: (c) =>
          c.read(obsModeProvider.notifier).setManual(ObsMode.night),
    );

    expect(find.text(keepAll('시연 지역: 강화 · 밤 별 관찰')), findsOneWidget);
    expect(find.text(keepAll('천체관측 최적 (Prime) · 92점')), findsOneWidget);
    expect(find.text(keepAll('참고 지표 · 다음 관찰 시간 21:40')), findsOneWidget);
    expect(find.text(keepAll('영월 별마로')), findsOneWidget);
    expect(find.textContaining(keepAll('빛공해 참고 데이터')), findsOneWidget);
    expect(
      find.text(keepAll('관찰한 별·천체를 생태일기에 남겨요')),
      findsOneWidget,
    );
    expect(find.textContaining(keepAll('eBird')), findsNothing);
  });

  testWidgets('step 1 calls onConditionsTap', (tester) async {
    var taps = 0;
    await _pumpCard(tester, onConditionsTap: () => taps++);

    await tester.tap(find.byKey(JourneyCard.stepKey(1)));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('step 2 requests the spot on the map tab', (tester) async {
    final container = await _pumpCard(tester);

    await tester.tap(find.byKey(JourneyCard.stepKey(2)));
    await tester.pump();

    expect(container.read(pendingMapSpotIdProvider), 'bird-001');
    expect(container.read(appTabIndexProvider), AppTab.observationMap);
  });

  testWidgets('step 3 switches to the discover tab', (tester) async {
    final container = await _pumpCard(tester);

    await tester.tap(find.byKey(JourneyCard.stepKey(3)));
    await tester.pump();

    expect(container.read(appTabIndexProvider), AppTab.discover);
  });

  testWidgets('step 4 opens a new-record form prefilled by mode', (
    tester,
  ) async {
    await _pumpCard(tester);

    await tester.tap(find.byKey(JourneyCard.stepKey(4)));
    await tester.pumpAndSettle();

    final form = tester.widget<ObservationFormScreen>(
      find.byType(ObservationFormScreen),
    );
    expect(form.existing, isNull);
    expect(form.initialSpeciesType, SpeciesType.bird);
    expect(find.text('새 관찰 기록'), findsOneWidget);
  });

  testWidgets('step 5 opens the badges screen', (tester) async {
    await _pumpCard(tester);

    await tester.tap(find.byKey(JourneyCard.stepKey(5)));
    await tester.pumpAndSettle();

    expect(find.byType(BadgesScreen), findsOneWidget);
  });

  testWidgets('sample mode marks affected steps with 예시 and keeps 시범', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      setup: (c) {
        final notifier = c.read(sampleSourcesProvider.notifier);
        notifier.markSample(SampleSource.suitability);
        notifier.markSample(SampleSource.observationMap);
      },
    );

    expect(find.text('예시'), findsNWidgets(2));
    expect(find.text('시범'), findsOneWidget);
  });

  testWidgets('loading uses a static StatusView (no spinner)', (tester) async {
    await _pumpCard(tester, settle: false);

    expect(find.byKey(const Key('status_view_loading')), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('map data failure shows an honest empty state', (tester) async {
    await _pumpCard(
      tester,
      mapApi: FakeObservationMapApi(shouldThrow: true),
    );

    expect(find.byKey(const Key('status_view_empty')), findsOneWidget);
    expect(find.text('장소 데이터를 받지 못했어요 · 지도에서 둘러보세요'), findsOneWidget);
    expect(find.byKey(StatusView.retryKey), findsNothing);

    // The step still opens the map tab.
    await tester.tap(find.byKey(JourneyCard.stepKey(2)));
    await tester.pump();
  });

  for (final width in const [320.0, 1280.0]) {
    testWidgets('no overflow at ${width.toInt()}px (day and night)', (
      tester,
    ) async {
      final container = await _pumpCard(
        tester,
        size: Size(width, 1400),
        setup: (c) {
          final notifier = c.read(sampleSourcesProvider.notifier);
          notifier.markSample(SampleSource.suitability);
          notifier.markSample(SampleSource.observationMap);
        },
      );
      expect(tester.takeException(), isNull);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final (width, padding) in const [(360.0, 16.0), (800.0, 20.0)]) {
    testWidgets(
      'card padding ${padding.toInt()} at ${width.toInt()}px, '
      'step titles w700, steps >= 44 with 12 vertical padding',
      (tester) async {
        await _pumpCard(tester, size: Size(width, 1400));

        final card = tester.widget<Container>(find.byKey(JourneyCard.cardKey));
        expect(card.padding, EdgeInsets.all(padding));

        final title = tester.widget<Text>(find.text('기록하기'));
        expect(title.style!.fontWeight, FontWeight.w700);
        expect(title.maxLines, 1);

        final step = find.byKey(JourneyCard.stepKey(4));
        expect(tester.getSize(step).height, greaterThanOrEqualTo(44));
        final stepPadding = tester.widget<Padding>(
          find
              .descendant(of: step, matching: find.byType(Padding))
              .first,
        );
        expect(
          stepPadding.padding,
          const EdgeInsets.symmetric(vertical: 12),
        );
      },
    );
  }

  testWidgets('steps are semantic buttons with a label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCard(tester);

    expect(
      tester.getSemantics(find.byKey(JourneyCard.stepKey(5))),
      isSemantics(
        label: '5단계 오늘의 참여. 시범. 관찰 기록으로 배지 진행도를 확인해요',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
