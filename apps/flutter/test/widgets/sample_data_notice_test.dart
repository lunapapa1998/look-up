import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/state/sample_data_provider.dart';
import 'package:lookup/utils/keep_all.dart';
import 'package:lookup/widgets/sample_data_notice.dart';

/// Pumps a [SampleDataNotice] watching [sources] inside a fresh container.
Future<ProviderContainer> _pumpNotice(
  WidgetTester tester, {
  Set<SampleSource> sources = const {SampleSource.trails},
  VoidCallback? onRetry,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SampleDataNotice(sources: sources, onRetry: onRetry ?? () {}),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('renders nothing while no source is served by sample data', (
    tester,
  ) async {
    await _pumpNotice(tester);

    expect(find.byKey(const Key('sample_data_notice')), findsNothing);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('shows the banner and retry once a watched source is sampled', (
    tester,
  ) async {
    final container = await _pumpNotice(tester);

    container
        .read(sampleSourcesProvider.notifier)
        .markSample(SampleSource.trails);
    await tester.pump();

    expect(find.byKey(const Key('sample_data_notice')), findsOneWidget);
    expect(find.text(keepAll(sampleDataNoticeText)), findsOneWidget);
    expect(sampleDataNoticeText, '서버에 연결할 수 없어 예시 데이터를 보여드려요');
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('ignores sampled sources the banner does not watch', (
    tester,
  ) async {
    final container = await _pumpNotice(
      tester,
      sources: const {SampleSource.trails, SampleSource.regions},
    );

    container
        .read(sampleSourcesProvider.notifier)
        .markSample(SampleSource.suitability);
    await tester.pump();

    expect(find.byKey(const Key('sample_data_notice')), findsNothing);
  });

  testWidgets('disappears again once the source is marked real', (
    tester,
  ) async {
    final container = await _pumpNotice(tester);
    final notifier = container.read(sampleSourcesProvider.notifier);

    notifier.markSample(SampleSource.trails);
    await tester.pump();
    expect(find.byKey(const Key('sample_data_notice')), findsOneWidget);

    notifier.markReal(SampleSource.trails);
    await tester.pump();
    expect(find.byKey(const Key('sample_data_notice')), findsNothing);
  });

  testWidgets('tapping retry calls onRetry', (tester) async {
    var retries = 0;
    final container = await _pumpNotice(tester, onRetry: () => retries++);

    container
        .read(sampleSourcesProvider.notifier)
        .markSample(SampleSource.trails);
    await tester.pump();
    await tester.tap(find.byKey(const Key('sample_data_notice_retry')));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('does not overflow at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = await _pumpNotice(tester);
    container
        .read(sampleSourcesProvider.notifier)
        .markSample(SampleSource.trails);
    await tester.pump();

    expect(find.byKey(const Key('sample_data_notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SampleMark renders the 예시 text in both sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [SampleMark(), SampleMark(compact: true)],
          ),
        ),
      ),
    );

    expect(find.text('예시'), findsNWidgets(2));
    expect(find.bySemanticsLabel('예시 데이터'), findsNWidgets(2));
  });
}
