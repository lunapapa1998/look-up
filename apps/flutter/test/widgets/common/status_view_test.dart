import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';
import 'package:lookup/widgets/common/status_view.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Spec 054-2b: StatusView texts, retry, colors, semantics, motion, 320px.
void main() {
  final at = DateTime(2026, 10, 30, 9, 5);

  Widget harness(
    ObsMode mode,
    Widget child, {
    double width = 360,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: AppTheme.themeFor(mode),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    );
  }

  void setNarrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Color surfaceColor(WidgetTester tester) =>
      (tester.widget<Container>(find.byKey(StatusView.surfaceKey)).decoration!
              as BoxDecoration)
          .color!;

  /// Texts owned by the view (not the button labels).
  List<Text> viewTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(StatusView),
          matching: find.byType(Text),
        ),
      )
      .where((t) => t.style?.color != null)
      .toList();

  Color leadingColor(WidgetTester tester) {
    final leading = find.byKey(StatusView.leadingKey);
    final widget = tester.widget(leading);
    if (widget is Icon) return widget.color!;
    return tester
        .widget<CircularProgressIndicator>(
          find.descendant(
            of: leading,
            matching: find.byType(CircularProgressIndicator),
          ),
        )
        .color!;
  }

  for (final mode in ObsMode.values) {
    group('StatusView (${mode.name})', () {
      testWidgets('default texts per kind; custom message replaces them', (
        tester,
      ) async {
        await tester.pumpWidget(harness(mode, const StatusView.loading()));
        expect(find.text('불러오는 중이에요'), findsOneWidget);
        expect(find.byKey(const Key('status_view_loading')), findsOneWidget);

        await tester.pumpWidget(
          harness(mode, const StatusView.loading(message: '별 정보를 찾는 중')),
        );
        expect(find.text('별 정보를 찾는 중'), findsOneWidget);
        expect(find.text('불러오는 중이에요'), findsNothing);

        await tester.pumpWidget(
          harness(mode, const StatusView.empty(message: '저장한 장소가 없어요')),
        );
        expect(find.text('저장한 장소가 없어요'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
        expect(find.byKey(const Key('status_view_empty')), findsOneWidget);

        await tester.pumpWidget(harness(mode, const StatusView.error()));
        expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byKey(const Key('status_view_error')), findsOneWidget);

        await tester.pumpWidget(
          harness(mode, const StatusView.error(detail: '네트워크 연결을 확인해 주세요')),
        );
        expect(find.text('네트워크 연결을 확인해 주세요'), findsOneWidget);

        await tester.pumpWidget(harness(mode, const StatusView.degraded()));
        expect(find.text('일부 정보를 불러오지 못했어요'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.byKey(const Key('status_view_degraded')), findsOneWidget);
      });

      testWidgets('text style is bodySmall of the ambient theme', (
        tester,
      ) async {
        await tester.pumpWidget(harness(mode, const StatusView.error()));
        final bodySmall = Theme.of(
          tester.element(find.byType(StatusView)),
        ).textTheme.bodySmall!;
        final message = tester.widget<Text>(find.text('정보를 불러오지 못했어요'));
        expect(message.style!.fontSize, bodySmall.fontSize);
        expect(message.style!.fontFamily, bodySmall.fontFamily);
        expect(message.maxLines, 3);
      });

      testWidgets('retry only when onRetry given; enabled, tappable, >= 44', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(harness(mode, const StatusView.error()));
        expect(find.byKey(StatusView.retryKey), findsNothing);
        expect(find.text('다시 시도'), findsNothing);

        await tester.pumpWidget(harness(mode, const StatusView.degraded()));
        expect(find.byKey(StatusView.retryKey), findsNothing);

        for (final build in <Widget Function(VoidCallback)>[
          (cb) => StatusView.error(onRetry: cb),
          (cb) => StatusView.degraded(onRetry: cb),
        ]) {
          var calls = 0;
          await tester.pumpWidget(harness(mode, build(() => calls++)));
          final retry = find.byKey(StatusView.retryKey);
          expect(retry, findsOneWidget);
          expect(find.text('다시 시도'), findsOneWidget);
          expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
          expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
          expect(
            tester.getSemantics(retry),
            isSemantics(
              label: '다시 시도',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          await tester.tap(retry);
          await tester.pump();
          expect(calls, 1);
        }
        handle.dispose();
      });

      testWidgets('degraded time only with lastUpdated; never says 지연', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(mode, StatusView.degraded(onRetry: () {})),
        );
        expect(find.textContaining('마지막 갱신'), findsNothing);
        expect(find.textContaining(':'), findsNothing);

        await tester.pumpWidget(
          harness(mode, StatusView.degraded(lastUpdated: at)),
        );
        expect(find.text('마지막 갱신 09:05'), findsOneWidget);

        for (final view in <Widget>[
          const StatusView.loading(),
          const StatusView.empty(message: '비어 있어요'),
          StatusView.error(onRetry: () {}, detail: '서버 응답 없음'),
          StatusView.degraded(lastUpdated: at, onRetry: () {}),
        ]) {
          await tester.pumpWidget(harness(mode, view));
          expect(find.textContaining('지연'), findsNothing);
        }
      });

      testWidgets('background colors per kind', (tester) async {
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;
        final colors = theme.extension<LookUpColors>()!;

        await tester.pumpWidget(harness(mode, const StatusView.error()));
        expect(surfaceColor(tester), scheme.errorContainer);

        await tester.pumpWidget(harness(mode, const StatusView.degraded()));
        expect(surfaceColor(tester), colors.warningContainer);

        for (final view in const <Widget>[
          StatusView.loading(),
          StatusView.empty(message: '비어 있어요'),
        ]) {
          await tester.pumpWidget(harness(mode, view));
          expect(surfaceColor(tester), scheme.surfaceContainer);
          final decoColors = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(StatusView),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((d) => d.decoration)
              .whereType<BoxDecoration>()
              .map((d) => d.color);
          expect(decoColors, isNot(contains(scheme.errorContainer)));
          expect(decoColors, isNot(contains(colors.warningContainer)));
          for (final text in viewTexts(tester)) {
            expect(text.style!.color, isNot(scheme.onErrorContainer));
          }
        }

        // Flat: no shadow on the surface.
        final deco =
            tester
                    .widget<Container>(find.byKey(StatusView.surfaceKey))
                    .decoration!
                as BoxDecoration;
        expect(deco.boxShadow, isNull);
        expect(
          deco.borderRadius,
          BorderRadius.circular(8),
        );
      });

      testWidgets('contrast: text >= 4.5, icon >= 3.0 for every kind', (
        tester,
      ) async {
        final views = <Widget>[
          const StatusView.loading(),
          const StatusView.empty(message: '비어 있어요'),
          StatusView.error(detail: '서버 응답 없음', onRetry: () {}),
          StatusView.degraded(lastUpdated: at, onRetry: () {}),
        ];
        for (final view in views) {
          await tester.pumpWidget(harness(mode, view));
          final bg = surfaceColor(tester);
          final texts = viewTexts(tester);
          expect(texts, isNotEmpty);
          for (final text in texts) {
            expect(
              contrastRatio(text.style!.color!, bg),
              greaterThanOrEqualTo(4.5),
              reason: '${text.data} on $bg',
            );
          }
          expect(
            contrastRatio(leadingColor(tester), bg),
            greaterThanOrEqualTo(3.0),
          );
        }

        // Same check under reduce motion (static hourglass icon).
        await tester.pumpWidget(
          harness(mode, const StatusView.loading(), reduceMotion: true),
        );
        expect(
          contrastRatio(leadingColor(tester), surfaceColor(tester)),
          greaterThanOrEqualTo(3.0),
        );
      });

      testWidgets('reduce motion: static icon, no spinner, settles', (
        tester,
      ) async {
        await tester.pumpWidget(harness(mode, const StatusView.loading()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.strokeWidth, 2);
        expect(tester.getSize(find.byType(CircularProgressIndicator)).width, 16);

        await tester.pumpWidget(
          harness(mode, const StatusView.loading(), reduceMotion: true),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.hourglass_empty)).color,
          AppTheme.themeFor(mode).colorScheme.onSurfaceVariant,
        );
        await tester.pumpAndSettle();
        expect(find.text('불러오는 중이에요'), findsOneWidget);
      });

      testWidgets('liveRegion for loading/error/degraded, not empty', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final cases = <Widget, (String, bool)>{
          const StatusView.loading(): ('status_view_loading', true),
          const StatusView.error(): ('status_view_error', true),
          const StatusView.degraded(): ('status_view_degraded', true),
          const StatusView.empty(message: '비어 있어요'): (
            'status_view_empty',
            false,
          ),
        };
        for (final entry in cases.entries) {
          await tester.pumpWidget(
            harness(mode, entry.key, reduceMotion: true),
          );
          final (key, live) = entry.value;
          expect(
            tester.getSemantics(find.byKey(Key(key))),
            isSemantics(isLiveRegion: live),
            reason: key,
          );
        }
        expect(find.bySemanticsLabel('비어 있어요'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('empty action only with label + callback', (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          harness(mode, const StatusView.empty(message: '없음', actionLabel: '추가')),
        );
        expect(find.byKey(StatusView.actionKey), findsNothing);
        expect(find.byType(TextButton), findsNothing);

        await tester.pumpWidget(
          harness(mode, StatusView.empty(message: '없음', onAction: () {})),
        );
        expect(find.byKey(StatusView.actionKey), findsNothing);

        await tester.pumpWidget(
          harness(
            mode,
            StatusView.empty(
              message: '없음',
              actionLabel: '추가',
              onAction: () => calls++,
            ),
          ),
        );
        expect(find.byKey(StatusView.actionKey), findsOneWidget);
        expect(find.widgetWithText(TextButton, '추가'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(
          tester.getSize(find.byKey(StatusView.actionKey)).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.byKey(StatusView.actionKey));
        await tester.pump();
        expect(calls, 1);
      });

      testWidgets('320px: every kind with retry renders without exception', (
        tester,
      ) async {
        setNarrowView(tester);
        const longMessage =
            '아주 긴 안내 문구가 들어와도 줄바꿈으로 처리되어야 하며 화면 밖으로 넘치지 않아야 합니다. '
            '세 줄을 넘으면 말줄임으로 잘립니다. 더 길게 더 길게 더 길게 더 길게';
        final views = <Widget>[
          const StatusView.loading(),
          const StatusView.loading(message: longMessage),
          StatusView.empty(
            message: longMessage,
            actionLabel: '새로 고침',
            onAction: () {},
          ),
          StatusView.error(onRetry: () {}),
          StatusView.error(
            message: longMessage,
            detail: longMessage,
            onRetry: () {},
          ),
          StatusView.degraded(lastUpdated: at, onRetry: () {}),
          StatusView.degraded(message: longMessage, onRetry: () {}),
        ];
        for (final view in views) {
          await tester.pumpWidget(harness(mode, view, width: 320));
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byKey(StatusView.surfaceKey)).width, 320);
        }
      });

      testWidgets('below 300px the retry button moves under the text', (
        tester,
      ) async {
        setNarrowView(tester);
        await tester.pumpWidget(
          harness(mode, StatusView.error(onRetry: () {}), width: 320),
        );
        final wideText = tester.getRect(find.text('정보를 불러오지 못했어요'));
        final wideButton = tester.getRect(find.byKey(StatusView.retryKey));
        expect(wideButton.left, greaterThan(wideText.left));
        expect(wideButton.top, lessThan(wideText.bottom));

        await tester.pumpWidget(
          harness(mode, StatusView.degraded(onRetry: () {}), width: 280),
        );
        expect(tester.takeException(), isNull);
        final text = tester.getRect(find.text('일부 정보를 불러오지 못했어요'));
        final button = tester.getRect(find.byKey(StatusView.retryKey));
        expect(button.top, greaterThanOrEqualTo(text.bottom));
        expect(button.height, greaterThanOrEqualTo(44));
      });
    });
  }
}
