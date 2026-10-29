import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/theme/layout_tokens.dart';

void main() {
  group('AppLayout.pageGutter', () {
    test('follows the breakpoint table', () {
      expect(AppLayout.pageGutter(320), 20);
      expect(AppLayout.pageGutter(360), 20);
      expect(AppLayout.pageGutter(412), 24);
      expect(AppLayout.pageGutter(800), closeTo(35.77, 0.01));
      expect(AppLayout.pageGutter(1280), 40);
    });

    test('is 32 at 600 and 40 at 1024', () {
      expect(AppLayout.pageGutter(600), 32);
      expect(AppLayout.pageGutter(1024), 40);
    });
  });

  group('AppLayout.pageInsets', () {
    test('wide windows center content at maxContentWidth', () {
      final insets = AppLayout.pageInsets(1280);
      expect(insets.left, 80);
      expect(insets.right, 80);
      expect(1280 - 2 * insets.left, 1120);
      expect(insets.top, 0);
      expect(insets.bottom, 0);
    });

    test('narrow/medium windows use the gutter', () {
      for (final width in <double>[320, 360, 412, 800]) {
        final insets = AppLayout.pageInsets(width);
        expect(insets.left, AppLayout.pageGutter(width), reason: '$width');
        expect(insets.right, AppLayout.pageGutter(width), reason: '$width');
      }
    });

    test('content width never exceeds maxContentWidth', () {
      for (var width = 1024.0; width <= 2560; width += 8) {
        final insets = AppLayout.pageInsets(width);
        expect(
          width - insets.horizontal,
          lessThanOrEqualTo(AppLayout.maxContentWidth + 1e-9),
          reason: '$width',
        );
      }
    });

    test('width constants', () {
      expect(AppLayout.maxContentWidth, 1120);
      expect(AppLayout.maxReadingWidth, 680);
    });
  });

  group('AppLayout.overlayInsets', () {
    test('adds viewPadding exactly once', () {
      final insets = AppLayout.overlayInsets(
        412,
        const EdgeInsets.fromLTRB(10, 30, 10, 20),
      );
      expect(insets.left, 34);
      expect(insets.right, 34);
      expect(insets.top, 30);
      expect(insets.bottom, 20);
    });
  });

  group('AppRadius', () {
    test('values', () {
      expect(AppRadius.link, 4);
      expect(AppRadius.button, 8);
      expect(AppRadius.card, 16);
      expect(AppRadius.pill, 999);
      expect(AppRadius.md, 12);
      expect(AppRadius.sm, 4);
      expect(AppRadius.lg, 16);
      expect(AppRadius.legacyBar, 20);
    });
  });

  group('AppSpacing / AppBreakpoints', () {
    test('values', () {
      expect(AppSpacing.x40, 40);
      expect(AppSpacing.x52, 52);
      expect(AppSpacing.x64, 64);
      expect(AppSpacing.x80, 80);
      expect(AppBreakpoints.narrowMax, 360);
      expect(AppBreakpoints.mediumMin, 600);
      expect(AppBreakpoints.expandedMin, 1024);
    });
  });

  testWidgets('pageInsetsOf/overlayInsetsOf read MediaQuery', (
    WidgetTester tester,
  ) async {
    late EdgeInsets page;
    late EdgeInsets overlay;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 800),
          viewPadding: EdgeInsets.fromLTRB(10, 30, 10, 20),
        ),
        child: Builder(
          builder: (context) {
            page = AppLayout.pageInsetsOf(context);
            overlay = AppLayout.overlayInsetsOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(page, AppLayout.pageInsets(1280));
    expect(page.left, 80);
    expect(
      overlay,
      AppLayout.overlayInsets(1280, const EdgeInsets.fromLTRB(10, 30, 10, 20)),
    );
    expect(overlay.left, 90);
    expect(overlay.right, 90);
    expect(overlay.top, 30);
    expect(overlay.bottom, 20);
  });
}
