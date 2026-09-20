import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/models/stay_package.dart';
import 'package:lookup/screens/package_booking_preview_screen.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/widgets/packages/package_card.dart';

Future<void> pumpPackages(
  WidgetTester tester, {
  bool night = true,
  double scale = 1,
  List<StayPackage> packages = exampleStayPackages,
}) async {
  final colors = night
      ? AppTheme.nightColorScheme()
      : AppTheme.dayColorScheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: PackagesCatalogScreen(packages: packages),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 35 && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byKey(const Key('packages_scroll')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('category filter selects matching package and all resets', (
    tester,
  ) async {
    await pumpPackages(tester);
    await tester.tap(find.byKey(const Key('packages_filter_coastal')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PackageCard>(find.byType(PackageCard).first).package.id,
      'heuksando',
    );
    expect(find.byKey(const Key('package_card_inje')), findsNothing);
    await tester.tap(find.byKey(const Key('packages_filter_forest')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PackageCard>(find.byType(PackageCard).first).package.id,
      'inje',
    );
    await tester.tap(find.byKey(const Key('packages_filter_all')));
    await tester.pumpAndSettle();
    expect(find.text('전체 패키지 (2)'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('package_preview_heuksando')));
    expect(find.byKey(const Key('package_card_heuksando')), findsOneWidget);
  });

  testWidgets('no matching category has a clear empty state and can reset', (
    tester,
  ) async {
    await pumpPackages(tester, packages: [exampleStayPackages.first]);
    await tester.tap(find.byKey(const Key('packages_filter_coastal')));
    await tester.pumpAndSettle();
    expect(find.text('이 유형의 패키지가 없어요'), findsOneWidget);
    expect(find.byType(PackageCard), findsNothing);
    await tester.tap(find.byKey(const Key('packages_filter_all')));
    await tester.pumpAndSettle();
    expect(find.byType(PackageCard), findsOneWidget);
  });

  testWidgets(
    'help identifies sample prices and unavailable real reservation',
    (tester) async {
      await pumpPackages(tester);
      expect(find.text('패키지 · 서비스 준비 중'), findsOneWidget);
      await tester.tap(find.byKey(const Key('packages_help')));
      await tester.pumpAndSettle();
      expect(find.text('패키지 이용 안내'), findsOneWidget);
      expect(find.textContaining('실제 예약·결제·상담 접수는 지원하지 않습니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'preview keeps selected package and calculates sample price per person',
    (tester) async {
      await pumpPackages(tester);
      await tester.tap(find.byKey(const Key('packages_filter_coastal')));
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('package_preview_heuksando'));
      await reveal(tester, preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PackageBookingPreviewScreen>(
              find.byType(PackageBookingPreviewScreen),
            )
            .package
            .id,
        'heuksando',
      );
      expect(find.text('145,000원'), findsOneWidget);
      await tester.tap(find.byKey(const Key('package_booking_people')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3명').last);
      await tester.pumpAndSettle();
      expect(find.text('435,000원'), findsOneWidget);
      await tester.tap(find.byKey(const Key('package_booking_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('희망 출발일을 선택해주세요'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byKey(const Key('package_booking_date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('package_booking_confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('실제 예약이 접수되지 않았습니다.'), findsOneWidget);
      expect(find.textContaining('435,000원'), findsWidgets);
    },
  );

  for (final night in [true, false]) {
    testWidgets(
      '320px ${night ? 'night' : 'day'} with large text has no overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpPackages(tester, night: night, scale: 1.6);
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byKey(const Key('package_preview_inje')));
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('시민과학 기록 노트'));
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('탄소 배출 절감'));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('packages_help')));
        await tester.pumpAndSettle();
        expect(find.text('패키지 이용 안내'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
