import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/screens/home_discovery_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/mode_header.dart';

/// WCAG 2.x contrast ratio between two colors, computed from their relative
/// luminance: (lighter + 0.05) / (darker + 0.05).
double _contrastRatio(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  final lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Pumps a minimal [ModeHeader] harness driven by a local mutable
/// [ObsModeState], mirroring how [HomeDiscoveryScreen] wires the widget to
/// [obsModeProvider] without requiring the full screen/provider stack.
Widget _harness({
  required ObsModeState initialState,
  required ValueChanged<ObsMode> onModeChanged,
  required VoidCallback onResetToAuto,
}) {
  ObsModeState state = initialState;
  return MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => ModeHeader(
          state: state,
          collapsed: false,
          onModeChanged: (mode) {
            onModeChanged(mode);
            setState(
              () => state = ObsModeState(
                mode: mode,
                source: ObsModeSource.manual,
              ),
            );
          },
          onResetToAuto: () {
            onResetToAuto();
            setState(
              () => state = ObsModeState(
                mode: state.mode,
                source: ObsModeSource.auto,
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  test(
    'obsModeProvider initial state derives mode from local time via nowProvider, source auto',
    () {
      final morningContainer = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(DateTime(2026, 9, 9, 10, 0)),
        ],
      );
      addTearDown(morningContainer.dispose);

      final nightContainer = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(DateTime(2026, 9, 9, 22, 0)),
        ],
      );
      addTearDown(nightContainer.dispose);

      expect(morningContainer.read(obsModeProvider).mode, ObsMode.day);
      expect(
        morningContainer.read(obsModeProvider).source,
        ObsModeSource.auto,
      );

      expect(nightContainer.read(obsModeProvider).mode, ObsMode.night);
      expect(
        nightContainer.read(obsModeProvider).source,
        ObsModeSource.auto,
      );
    },
  );

  testWidgets('toggle tap switches mode and source to manual', (
    tester,
  ) async {
    ObsMode? lastChanged;

    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.day,
          source: ObsModeSource.auto,
        ),
        onModeChanged: (mode) => lastChanged = mode,
        onResetToAuto: () {},
      ),
    );

    await tester.tap(find.byKey(const Key('modeToggleNightExpanded')));
    await tester.pump();

    expect(lastChanged, ObsMode.night);
    expect(find.byKey(const Key('modeSourceBadgeManual')), findsOneWidget);
  });

  testWidgets('MANUAL badge tap resets to auto', (tester) async {
    var resetCalled = false;

    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.night,
          source: ObsModeSource.manual,
        ),
        onModeChanged: (_) {},
        onResetToAuto: () => resetCalled = true,
      ),
    );

    await tester.tap(find.byKey(const Key('modeSourceBadgeManual')));
    await tester.pump();

    expect(resetCalled, isTrue);
    expect(find.byKey(const Key('modeSourceBadgeAuto')), findsOneWidget);
  });

  testWidgets('first manual switch shows a one-time hint', (tester) async {
    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.day,
          source: ObsModeSource.auto,
        ),
        onModeChanged: (_) {},
        onResetToAuto: () {},
      ),
    );

    expect(find.byKey(const Key('modeManualHint')), findsNothing);

    await tester.tap(find.byKey(const Key('modeToggleNightExpanded')));
    await tester.pump();

    expect(find.byKey(const Key('modeManualHint')), findsOneWidget);
  });

  testWidgets(
    'pinned collapsed ModeHeader toggle survives scrolling far down',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
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
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: HomeDiscoveryScreen(onViewMapPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(find.byKey(const Key('modeToggleDayCollapsed')), findsOneWidget);
      expect(
        find.byKey(const Key('modeToggleNightCollapsed')),
        findsOneWidget,
      );
    },
  );

  testWidgets('toggles and badges expose semantics labels for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.day,
          source: ObsModeSource.auto,
        ),
        onModeChanged: (_) {},
        onResetToAuto: () {},
      ),
    );

    expect(find.bySemanticsLabel('낮 모드로 전환합니다'), findsOneWidget);
    expect(find.bySemanticsLabel('밤 모드로 전환합니다'), findsOneWidget);
    expect(find.bySemanticsLabel('자동 모드입니다'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.night,
          source: ObsModeSource.manual,
        ),
        onModeChanged: (_) {},
        onResetToAuto: () {},
      ),
    );

    expect(
      find.bySemanticsLabel('수동 모드입니다. 탭하면 자동 모드로 돌아갑니다.'),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('expanded day/night toggles meet the 44x44 minimum touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        initialState: const ObsModeState(
          mode: ObsMode.day,
          source: ObsModeSource.auto,
        ),
        onModeChanged: (_) {},
        onResetToAuto: () {},
      ),
    );

    final daySize = tester.getSize(
      find.byKey(const Key('modeToggleDayExpanded')),
    );
    final nightSize = tester.getSize(
      find.byKey(const Key('modeToggleNightExpanded')),
    );

    expect(daySize.width, greaterThanOrEqualTo(44.0));
    expect(daySize.height, greaterThanOrEqualTo(44.0));
    expect(nightSize.width, greaterThanOrEqualTo(44.0));
    expect(nightSize.height, greaterThanOrEqualTo(44.0));
  });

  test('mode toggle and badge text meet WCAG AA contrast (4.5:1)', () {
    final colorScheme = AppTheme.nightColorScheme();

    // Active expanded toggle: primary text on surfaceContainerHighest fill.
    expect(
      _contrastRatio(colorScheme.primary, colorScheme.surfaceContainerHighest),
      greaterThanOrEqualTo(4.5),
    );

    // Inactive/collapsed toggle text against the surrounding surface color.
    expect(
      _contrastRatio(colorScheme.onSurfaceVariant, colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );

    // MANUAL badge: onSecondary text on secondary fill.
    expect(
      _contrastRatio(colorScheme.onSecondary, colorScheme.secondary),
      greaterThanOrEqualTo(4.5),
    );

    // AUTO badge: border-only container, text sits on the surrounding surface.
    expect(
      _contrastRatio(colorScheme.onSurfaceVariant, colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('tapping ModeHeader flows through the real obsModeProvider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(DateTime(2026, 9, 9, 10, 0)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final modeState = ref.watch(obsModeProvider);
              return Scaffold(
                body: ModeHeader(
                  state: modeState,
                  collapsed: false,
                  onModeChanged: ref.read(obsModeProvider.notifier).setManual,
                  onResetToAuto:
                      ref.read(obsModeProvider.notifier).resetToAuto,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('modeToggleNightExpanded')));
    await tester.pump();

    expect(container.read(obsModeProvider).mode, ObsMode.night);
    expect(container.read(obsModeProvider).source, ObsModeSource.manual);

    await tester.tap(find.byKey(const Key('modeSourceBadgeManual')));
    await tester.pump();

    expect(container.read(obsModeProvider).source, ObsModeSource.auto);
    expect(
      container.read(obsModeProvider).mode,
      modeForHour(DateTime(2026, 9, 9, 10, 0).hour),
    );
  });

  testWidgets(
    'reduced motion: toggle tap settles the glyph morph in a single pump',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _harness(
            initialState: const ObsModeState(
              mode: ObsMode.day,
              source: ObsModeSource.auto,
            ),
            onModeChanged: (_) {},
            onResetToAuto: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('modeToggleNightExpanded')));
      await tester.pump();

      final nightOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('modeToggleNightExpanded')),
          matching: find.byType(Opacity),
        ),
      );
      final dayOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('modeToggleDayExpanded')),
          matching: find.byType(Opacity),
        ),
      );
      expect(nightOpacity.opacity, closeTo(1.0, 0.001));
      expect(dayOpacity.opacity, closeTo(0.82, 0.001));

      final nightTransforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byKey(const Key('modeToggleNightExpanded')),
          matching: find.byType(Transform),
        ),
      );
      final dayTransforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byKey(const Key('modeToggleDayExpanded')),
          matching: find.byType(Transform),
        ),
      );
      for (final transform in [...nightTransforms, ...dayTransforms]) {
        expect(transform.transform, Matrix4.identity());
      }

      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
