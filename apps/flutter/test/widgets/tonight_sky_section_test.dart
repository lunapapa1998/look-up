import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/starlight_forecast.dart';
import 'package:lookup/widgets/tonight_sky_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

StarlightTarget _target(String id, {String name = ''}) {
  return StarlightTarget(
    id: id,
    name: name.isEmpty ? '대상 $id' : name,
    constellation: '오리온자리',
    targetType: 'constellation',
    altitudeDeg: 45,
    azimuthDeg: 120,
    direction: '남동쪽',
    observationMode: '육안 관측',
    description: '$id 설명 텍스트',
  );
}

void main() {
  testWidgets('renders top 3 of a 5-item list plus a see-more affordance', (
    tester,
  ) async {
    final targets = List.generate(5, (i) => _target('t$i'));

    await tester.pumpWidget(_wrap(TonightSkySection(targets: targets)));

    expect(find.text('대상 t0'), findsOneWidget);
    expect(find.text('대상 t1'), findsOneWidget);
    expect(find.text('대상 t2'), findsOneWidget);
    expect(find.text('대상 t3'), findsNothing);
    expect(find.text('대상 t4'), findsNothing);
    expect(find.text('2개 더 보기'), findsOneWidget);
  });

  testWidgets('tapping see-more reveals the remaining items', (tester) async {
    final targets = List.generate(5, (i) => _target('t$i'));

    await tester.pumpWidget(_wrap(TonightSkySection(targets: targets)));
    await tester.tap(find.text('2개 더 보기'));
    await tester.pumpAndSettle();

    expect(find.text('대상 t3'), findsOneWidget);
    expect(find.text('대상 t4'), findsOneWidget);
  });

  testWidgets('renders the empty-state sentence when given an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(const _EmptyTonightSkySection());

    expect(find.text('오늘 밤은 또렷이 보이는 대상이 적어요'), findsOneWidget);
    expect(find.text("TONIGHT'S SKY"), findsOneWidget);
    expect(find.text('오늘 이 자리에서 보이는 하늘'), findsOneWidget);
  });

  testWidgets('a row Semantics label includes the target name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final target = _target('t0', name: '오리온성운');

    await tester.pumpWidget(_wrap(TonightSkySection(targets: [target])));

    final semantics = tester.getSemantics(find.text('오리온성운').first);
    expect(semantics.label, contains('오리온성운'));
    handle.dispose();
  });

  testWidgets(
    'tapping a row reveals its description text that was not visible before the tap',
    (tester) async {
      final target = _target('t0', name: '오리온성운');

      await tester.pumpWidget(_wrap(TonightSkySection(targets: [target])));

      expect(find.text('t0 설명 텍스트'), findsNothing);

      await tester.tap(find.text('오리온성운'));
      await tester.pumpAndSettle();

      expect(find.text('t0 설명 텍스트'), findsOneWidget);
    },
  );

  testWidgets('shows an approx indicator when isApprox is true', (
    tester,
  ) async {
    final targets = [_target('t0')];

    await tester.pumpWidget(
      _wrap(TonightSkySection(targets: targets, isApprox: true)),
    );

    expect(find.text('추정치'), findsOneWidget);
  });

  testWidgets('does not show an approx indicator by default', (tester) async {
    final targets = [_target('t0')];

    await tester.pumpWidget(_wrap(TonightSkySection(targets: targets)));

    expect(find.text('추정치'), findsNothing);
  });
}

class _EmptyTonightSkySection extends StatelessWidget {
  const _EmptyTonightSkySection();

  @override
  Widget build(BuildContext context) {
    return _wrap(const TonightSkySection(targets: []));
  }
}
