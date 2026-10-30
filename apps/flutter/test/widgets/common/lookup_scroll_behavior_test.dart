import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/common/lookup_scroll_behavior.dart';

/// Spec 054-2d: local mouse-drag scrolling for horizontal chip/filter lists.
void main() {
  void useNarrowSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget chipList({
    required ScrollController controller,
    required ValueChanged<int> onSelected,
    bool wrapped = true,
  }) {
    final list = SingleChildScrollView(
      key: const Key('h_list'),
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < 12; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('chip_$i'),
                label: Text('칩 $i'),
                selected: i == 0,
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    );
    return wrapped
        ? ScrollConfiguration(
            behavior: const LookUpScrollBehavior(),
            child: list,
          )
        : list;
  }

  Widget harness(Widget body) => MaterialApp(
    theme: AppTheme.themeFor(ObsMode.day),
    home: Scaffold(body: body),
  );

  Future<void> mouseDrag(
    WidgetTester tester,
    Offset start,
    Offset delta,
  ) async {
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    const steps = 15;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await gesture.removePointer();
    // Fixed pumps instead of pumpAndSettle so a focused TextField's blinking
    // cursor cannot keep the test from settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  test('dragDevices is the MaterialScrollBehavior set plus mouse', () {
    const behavior = LookUpScrollBehavior();
    final base = const MaterialScrollBehavior().dragDevices;
    expect(behavior.dragDevices, containsAll(base));
    expect(
      behavior.dragDevices,
      containsAll(<PointerDeviceKind>{
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      }),
    );
    expect(base, isNot(contains(PointerDeviceKind.mouse)));
  });

  test('pointerAxisModifiers are inherited (Shift+wheel kept)', () {
    expect(
      const LookUpScrollBehavior().pointerAxisModifiers,
      const MaterialScrollBehavior().pointerAxisModifiers,
    );
  });

  testWidgets('wrapped: mouse drag scrolls without selecting a chip', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final selected = <int>[];
    await tester.pumpWidget(
      harness(chipList(controller: controller, onSelected: selected.add)),
    );

    await mouseDrag(
      tester,
      tester.getCenter(find.byKey(const Key('chip_1'))),
      const Offset(-150, 0),
    );

    expect(controller.offset, greaterThan(0));
    expect(selected, isEmpty);
  });

  testWidgets('unwrapped: mouse drag does not scroll (Flutter default)', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        chipList(controller: controller, onSelected: (_) {}, wrapped: false),
      ),
    );

    await mouseDrag(
      tester,
      tester.getCenter(find.byKey(const Key('chip_1'))),
      const Offset(-150, 0),
    );

    expect(controller.offset, 0);
  });

  testWidgets('wrapped: short mouse click selects the chip once', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final selected = <int>[];
    await tester.pumpWidget(
      harness(chipList(controller: controller, onSelected: selected.add)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chip_1'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await gesture.removePointer();
    await tester.pumpAndSettle();

    expect(selected, [1]);
    expect(controller.offset, 0);
  });

  testWidgets('wrapped: touch drag still scrolls', (tester) async {
    useNarrowSurface(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(chipList(controller: controller, onSelected: (_) {})),
    );

    await tester.drag(
      find.byKey(const Key('chip_1')),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('wrapped: Shift + mouse wheel scrolls the horizontal list', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(chipList(controller: controller, onSelected: (_) {})),
    );

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byKey(const Key('h_list')));
    // Position the (not added) mouse pointer, as Flutter's own scrollable
    // tests do; only the scroll signal is dispatched.
    pointer.hover(center);

    // Plain vertical wheel does not move a horizontal list.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('wrapper does not leak to a neighbouring vertical list or a '
      'TextField', (tester) async {
    useNarrowSurface(tester);
    final hController = ScrollController();
    final vController = ScrollController();
    final textController = TextEditingController();
    addTearDown(hController.dispose);
    addTearDown(vController.dispose);
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      harness(
        Column(
          children: [
            SizedBox(
              height: 56,
              child: chipList(controller: hController, onSelected: (_) {}),
            ),
            TextField(key: const Key('field'), controller: textController),
            Expanded(
              child: ListView.builder(
                key: const Key('v_list'),
                controller: vController,
                itemCount: 60,
                itemBuilder: (context, i) =>
                    SizedBox(height: 48, child: Text('행 $i')),
              ),
            ),
          ],
        ),
      ),
    );

    // Neither the vertical list nor the text field sees LookUpScrollBehavior.
    expect(
      ScrollConfiguration.of(tester.element(find.byKey(const Key('v_list')))),
      isNot(isA<LookUpScrollBehavior>()),
    );
    expect(
      ScrollConfiguration.of(tester.element(find.byType(EditableText))),
      isNot(isA<LookUpScrollBehavior>()),
    );
    // The chip list itself does.
    expect(
      ScrollConfiguration.of(tester.element(find.byKey(const Key('chip_1')))),
      isA<LookUpScrollBehavior>(),
    );

    // Mouse drag on the vertical list keeps Flutter's default: no scroll.
    await mouseDrag(
      tester,
      tester.getCenter(find.byKey(const Key('v_list'))),
      const Offset(0, -150),
    );
    expect(vController.offset, 0);
    expect(hController.offset, 0);

    // The text field still accepts typing, and a mouse drag over its text
    // scrolls nothing outside it.
    await tester.enterText(find.byKey(const Key('field')), '관측 메모 입력');
    await tester.pump();
    expect(textController.text, '관측 메모 입력');

    final fieldRect = tester.getRect(find.byKey(const Key('field')));
    await mouseDrag(
      tester,
      fieldRect.centerLeft + const Offset(12, 0),
      const Offset(150, 0),
    );
    expect(textController.text, '관측 메모 입력');
    expect(vController.offset, 0);
    expect(hController.offset, 0);
  });
}
