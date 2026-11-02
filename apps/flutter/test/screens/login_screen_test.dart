import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/api/ecolog_api.dart';
import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/auth/auth_repository.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/screens/app_shell.dart';
import 'package:lookup/screens/auth_gate.dart';
import 'package:lookup/screens/login_screen.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/auth_providers.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/state/providers.dart';
import 'package:lookup/theme/app_theme.dart';

const _title = '위를 봐요.';
const _subtitle = '고개를 들면 여행이 시작됩니다.';
const _body = '새가 날아드는 낮부터\n'
    '별이 쏟아지는 밤까지\n'
    '모두 당신을 위해 펼쳐져 있어요.';
const _guestLabel = '로그인 없이 둘러보기';
const _kakaoLabel = '카카오로 시작하기';
const _googleLabel = 'Google로 계속하기';

Future<void> _pumpLogin(
  WidgetTester tester, {
  VoidCallback? onGuest,
  ObsMode? mode,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Sign-in is not under test; the unavailable repository keeps auth inert.
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const UnavailableAuthRepository(),
        ),
      ],
      child: MaterialApp(
        theme: mode == null ? null : AppTheme.themeFor(mode),
        home: LoginScreen(onGuestPressed: onGuest),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the brand copy and drops the old intro copy',
      (tester) async {
    await _pumpLogin(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_subtitle), findsOneWidget);
    expect(find.text(_body), findsOneWidget);

    expect(find.text('LOOK UP'), findsNothing);
    expect(find.text('여행이 시작됩니다.'), findsNothing);
    expect(find.text('하늘을 보는 일이, 여행이 되도록.'), findsNothing);
    expect(find.textContaining('하늘을 따라 시작되는 여정'), findsNothing);
    expect(find.text('소셜 계정으로 3초 만에 시작하기'), findsNothing);
    expect(find.text('Kakao로 시작하기'), findsNothing);
    expect(find.text('로그인 없이 둘러보기 (체험 모드)'), findsNothing);
  });

  testWidgets('no logo; title -> subtitle -> body, title is a large header',
      (tester) async {
    await _pumpLogin(tester);

    expect(find.image(const AssetImage('assets/auth/logo.png')), findsNothing);

    final titleY = tester.getTopLeft(find.text(_title)).dy;
    final subtitleY = tester.getTopLeft(find.text(_subtitle)).dy;
    final bodyY = tester.getTopLeft(find.text(_body)).dy;
    expect(titleY, lessThan(subtitleY));
    expect(subtitleY, lessThan(bodyY));

    final titleStyle = tester.widget<Text>(find.text(_title)).style!;
    final subtitleStyle = tester.widget<Text>(find.text(_subtitle)).style!;
    final bodyStyle = tester.widget<Text>(find.text(_body)).style!;
    expect(titleStyle.fontSize, 44);
    // Capped at Bithumb Gothic's only real face (700): no synthetic bold.
    expect(titleStyle.fontWeight, FontWeight.w700);
    expect(titleStyle.fontFamily, AppTheme.bithumbGothic);
    expect(subtitleStyle.fontSize, 20);
    expect(subtitleStyle.fontWeight, FontWeight.w500);
    expect(bodyStyle.fontSize, 16);
    expect(bodyStyle.height, 1.5);

    final header = find.ancestor(
      of: find.text(_title),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.header ?? false),
      ),
    );
    expect(header, findsOneWidget);
  });

  testWidgets('title sits inside the illustration arc on a 390x844 phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester, onGuest: () {}, mode: ObsMode.day);

    // Title starts at 30% of the full-width 3:4 intro image (~156 of 844).
    final titleTop = tester.getTopLeft(find.text(_title)).dy;
    expect(titleTop / 844, inInclusiveRange(0.15, 0.25));
    final guestTop =
        tester.getTopLeft(find.byKey(LoginScreen.guestButtonKey)).dy;
    expect(guestTop / 844, inInclusiveRange(0.62, 0.78));
    expect(tester.takeException(), isNull);
  });

  for (final mode in ObsMode.values) {
    for (final size in const [Size(360, 740), Size(430, 932)]) {
      testWidgets(
          'copy and buttons fit without overlap at '
          '${size.width.toInt()}x${size.height.toInt()} (${mode.name})',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewPadding = FakeViewPadding.zero;
        addTearDown(tester.view.reset);

        await _pumpLogin(tester, onGuest: () {}, mode: mode);
        expect(tester.takeException(), isNull);

        // Title and subtitle fully on screen.
        for (final text in [_title, _subtitle]) {
          final rect = tester.getRect(find.text(text));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }

        final guest = tester.getRect(find.byKey(LoginScreen.guestButtonKey));
        final kakao = tester.getRect(find.byKey(LoginScreen.kakaoButtonKey));
        final google =
            tester.getRect(find.byKey(LoginScreen.googleButtonKey));

        // Last copy block ends above the guest button.
        final body = tester.getRect(find.text(_body));
        expect(body.bottom, lessThanOrEqualTo(guest.top));

        // Buttons fully on screen, stacked without overlap.
        for (final button in [guest, kakao, google]) {
          expect(button.top, greaterThanOrEqualTo(0));
          expect(button.bottom, lessThanOrEqualTo(size.height));
        }
        expect(guest.bottom, lessThanOrEqualTo(kakao.top));
        expect(kakao.bottom, lessThanOrEqualTo(google.top));
      });
    }
  }

  testWidgets('day and night share the same layout on a 390x844 phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    Future<(Offset, double)> measure(ObsMode mode) async {
      // Fresh tree per mode so no state carries over between themes.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpLogin(tester, onGuest: () {}, mode: mode);
      expect(tester.takeException(), isNull);
      return (
        tester.getTopLeft(find.text(_title)),
        tester.getTopLeft(find.byKey(LoginScreen.guestButtonKey)).dy,
      );
    }

    final (dayTitle, dayGuestTop) = await measure(ObsMode.day);
    final (nightTitle, nightGuestTop) = await measure(ObsMode.night);
    expect(nightTitle.dx, closeTo(dayTitle.dx, 0.5));
    expect(nightTitle.dy, closeTo(dayTitle.dy, 0.5));
    expect(nightGuestTop, closeTo(dayGuestTop, 0.5));
  });

  for (final mode in ObsMode.values) {
    testWidgets('copy colors match the mockup (${mode.name})', (tester) async {
      await _pumpLogin(tester, mode: mode);
      final night = mode == ObsMode.night;
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(
        colorOf(_title),
        night ? const Color(0xFFFFFFFF) : const Color(0xFF1F2A44),
      );
      expect(colorOf(_subtitle), colorOf(_title));
      expect(
        colorOf(_body),
        night ? const Color(0xD9FFFFFF) : const Color(0xFF3A4560),
      );
    });

    testWidgets(
        'buttons: guest (white, chevron) -> Kakao -> Google (navy) '
        '(${mode.name})', (tester) async {
      await _pumpLogin(tester, onGuest: () {}, mode: mode);
      final night = mode == ObsMode.night;

      // The old teal FilledButton is gone.
      expect(find.byType(FilledButton), findsNothing);

      final guest = find.byKey(LoginScreen.guestButtonKey);
      final kakao = find.byKey(LoginScreen.kakaoButtonKey);
      final google = find.byKey(LoginScreen.googleButtonKey);
      expect(find.descendant(of: guest, matching: find.text(_guestLabel)),
          findsOneWidget);
      expect(find.descendant(of: kakao, matching: find.text(_kakaoLabel)),
          findsOneWidget);
      expect(find.descendant(of: google, matching: find.text(_googleLabel)),
          findsOneWidget);

      final guestY = tester.getTopLeft(guest).dy;
      final kakaoY = tester.getTopLeft(kakao).dy;
      final googleY = tester.getTopLeft(google).dy;
      expect(guestY, lessThan(kakaoY));
      expect(kakaoY, lessThan(googleY));
      // 12px gaps between 56-high buttons.
      expect(kakaoY - guestY, closeTo(56 + 12, 0.5));
      expect(googleY - kakaoY, closeTo(56 + 12, 0.5));

      // Full column width (24px gutters, column capped at 480).
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      final expectedWidth =
          (screenWidth - 48).clamp(0.0, LoginScreen.maxContentWidth);
      for (final button in [guest, kakao, google]) {
        final size = tester.getSize(button);
        expect(size.height, 56);
        expect(size.width, closeTo(expectedWidth, 0.5));
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
      }

      final guestMaterial = tester.widget<Material>(guest);
      expect(guestMaterial.color, const Color(0xFFFFFFFF));
      expect(guestMaterial.elevation, 0);
      final guestShape = guestMaterial.shape! as RoundedRectangleBorder;
      expect(guestShape.borderRadius, BorderRadius.circular(12));
      expect(
        tester.widget<Text>(find.text(_guestLabel)).style?.color,
        const Color(0xFF141414),
      );

      for (final button in [kakao, google]) {
        final material = tester.widget<Material>(button);
        final shape = material.shape! as RoundedRectangleBorder;
        if (night) {
          expect(material.color, const Color(0xD91E2333));
          expect(shape.side.width, 1);
          expect(shape.side.color, const Color(0x40FFFFFF));
        } else {
          expect(material.color, const Color(0xFF1E2333));
          expect(shape.side, BorderSide.none);
        }
      }

      // Brand marks are kept on the social buttons.
      expect(
        find.descendant(
          of: kakao,
          matching:
              find.image(const AssetImage('assets/auth/kakao_symbol.png')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: google,
          matching: find.image(const AssetImage('assets/auth/google_g.png')),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('day theme shows the day intro background', (tester) async {
    await _pumpLogin(tester, mode: ObsMode.day);

    expect(
      find.image(const AssetImage(LoginScreen.introDayAsset)),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage(LoginScreen.introNightAsset)),
      findsNothing,
    );
    expect(
      find.image(const AssetImage('assets/auth/starfield_bg.png')),
      findsNothing,
    );
  });

  testWidgets('night theme shows the night intro background', (tester) async {
    await _pumpLogin(tester, mode: ObsMode.night);

    expect(
      find.image(const AssetImage(LoginScreen.introNightAsset)),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage(LoginScreen.introDayAsset)),
      findsNothing,
    );
  });

  for (final mode in ObsMode.values) {
    for (final size in const [
      Size(390, 844),
      Size(360, 640),
      Size(320, 568),
      Size(1280, 720),
    ]) {
      testWidgets(
          'no overflow at ${size.width.toInt()}x${size.height.toInt()} '
          '(${mode.name})', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpLogin(tester, onGuest: () {}, mode: mode);

        expect(find.text(_title), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Every button is reachable (content scrolls on short screens).
        for (final label in [_guestLabel, _kakaoLabel, _googleLabel]) {
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
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

  for (final mode in ObsMode.values) {
    testWidgets('AuthGate: guest button enters AppShell (${mode.name})',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              const UnavailableAuthRepository(),
            ),
            ecologApiProvider.overrideWithValue(FakeEcologApi()),
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
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(mode),
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      final guest = find.text(_guestLabel);
      await tester.ensureVisible(guest);
      await tester.pump();
      await tester.tap(guest);
      await tester.pump();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });
  }
}
