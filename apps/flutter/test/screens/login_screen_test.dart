import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/auth/auth_repository.dart';
import 'package:lookup/screens/login_screen.dart';
import 'package:lookup/state/auth_providers.dart';

const _title = '위를 봐요.';
const _subtitle = '여행이 시작됩니다.';
const _lead = '하늘을 보는 일이, 여행이 되도록.';
const _body = '하늘을 따라 시작되는 여정\n'
    '새가 날아드는 낮부터 별이 쏟아지는 밤까지\n'
    '하늘을 길잡이 삼아 그곳의 자연과 생태를 발견해보세요';
const _guestLabel = '로그인 없이 둘러보기 (체험 모드)';

Future<void> _pumpLogin(WidgetTester tester, {VoidCallback? onGuest}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Sign-in is not under test; the unavailable repository keeps auth inert.
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const UnavailableAuthRepository(),
        ),
      ],
      child: MaterialApp(home: LoginScreen(onGuestPressed: onGuest)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the new intro copy and drops the old wordmark/tagline',
      (tester) async {
    await _pumpLogin(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_subtitle), findsOneWidget);
    expect(find.text(_lead), findsOneWidget);
    expect(find.text(_body), findsOneWidget);

    expect(find.text('LOOK UP'), findsNothing);
    expect(find.textContaining('낮의 갯벌 철새부터'), findsNothing);
    expect(find.textContaining('24시간 생태 여정'), findsNothing);
    expect(find.textContaining('하늘의 변화를 따라'), findsNothing);
  });

  testWidgets('title sits above the logo, subtitle below, with equal size',
      (tester) async {
    await _pumpLogin(tester);

    final logo = find.image(const AssetImage('assets/auth/logo.png'));
    expect(logo, findsOneWidget);

    final titleY = tester.getTopLeft(find.text(_title)).dy;
    final logoY = tester.getTopLeft(logo).dy;
    final subtitleY = tester.getTopLeft(find.text(_subtitle)).dy;
    expect(titleY, lessThan(logoY));
    expect(logoY, lessThan(subtitleY));

    final titleSize = tester.widget<Text>(find.text(_title)).style?.fontSize;
    final subtitleSize =
        tester.widget<Text>(find.text(_subtitle)).style?.fontSize;
    expect(titleSize, isNotNull);
    expect(subtitleSize, titleSize);
  });

  for (final size in const [Size(360, 640), Size(320, 568), Size(1280, 720)]) {
    testWidgets(
        'no overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLogin(tester);

      expect(find.text(_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guest button calls onGuestPressed', (tester) async {
    var taps = 0;
    await _pumpLogin(tester, onGuest: () => taps++);

    final guest = find.text(_guestLabel);
    await tester.ensureVisible(guest);
    await tester.pump();
    await tester.tap(guest);
    await tester.pump();

    expect(taps, 1);
  });
}
