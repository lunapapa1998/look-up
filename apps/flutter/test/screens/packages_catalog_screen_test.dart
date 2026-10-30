import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/models/stay_package.dart';
import 'package:lookup/screens/package_booking_preview_screen.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/utils/keep_all.dart';
import 'package:lookup/widgets/common/lookup_header.dart';
import 'package:lookup/widgets/common/mode_toggle.dart';
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
  // ProviderScope: the LookUpSliverHeader's ObsModeToggle watches
  // obsModeProvider.
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
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
  testWidgets('header is LookUpSliverHeader with the day/night toggle', (
    tester,
  ) async {
    await pumpPackages(tester);
    expect(find.byType(LookUpSliverHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LookUpSliverHeader),
        matching: find.byType(ObsModeToggle),
      ),
      findsOneWidget,
    );
  });

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

  testWidgets('intro headline uses new copy without duration wording', (
    tester,
  ) async {
    await pumpPackages(tester);
    final title = tester.widget<Text>(
      find.byKey(const Key('packages_intro_title')),
    );
    final subtitle = tester.widget<Text>(
      find.byKey(const Key('packages_intro_subtitle')),
    );
    expect(title.data, keepAll(packagesIntroTitle));
    expect(title.semanticsLabel, '낮에는 새를 만나고, 밤에는 별을 만나요.');
    expect(title.maxLines, 2);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.style!.height, 1.3);
    expect(subtitle.data, keepAll(packagesIntroSubtitle));
    expect(subtitle.semanticsLabel, '하늘을 따라 이어지는 여행');
    expect(subtitle.style!.fontWeight, FontWeight.w500);
    expect(find.textContaining('24시간'), findsNothing);
    expect(find.textContaining('수직적'), findsNothing);
    expect(find.text('낮에는 탐조, 밤에는 별자리'), findsNothing);
    expect(packagesIntroTitleFontSize(320), 22);
    expect(packagesIntroTitleFontSize(360), 22);
    expect(packagesIntroTitleFontSize(390), 24);
    expect(packagesIntroTitleFontSize(600), 28);
  });

  for (final size in [const Size(320, 568), const Size(360, 640)]) {
    for (final night in [true, false]) {
      testWidgets(
        'intro headline ${size.width.toInt()}x${size.height.toInt()} '
        '${night ? 'night' : 'day'} has no overflow',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await pumpPackages(tester, night: night);
          expect(tester.takeException(), isNull);
          final scaffold = tester.element(find.byType(Scaffold).first);
          expect(MediaQuery.sizeOf(scaffold), size);
          final title = tester.widget<Text>(
            find.byKey(const Key('packages_intro_title')),
          );
          expect(title.style!.fontSize, 22);
          expect(
            find.byKey(const Key('packages_intro_subtitle')).hitTestable(),
            findsOneWidget,
          );
        },
      );
    }
  }

  const packageAssets = [
    'assets/packages/inje.jpg',
    'assets/packages/heuksando.jpg',
    'assets/packages/binoculars.jpg',
    'assets/packages/guide.jpg',
    'assets/packages/headlamp.jpg',
    'assets/packages/notebook.jpg',
  ];

  Set<String> renderedPackageAssets() {
    final names = <String>{};
    final images = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          packageAssets.contains((w.image as AssetImage).assetName),
      skipOffstage: false,
    );
    for (final element in images.evaluate()) {
      final image = element.widget as Image;
      // Pixel art must stay crisp and use the minimal-crop cover fit.
      expect(image.filterQuality, FilterQuality.none);
      expect(image.fit, BoxFit.cover);
      names.add((image.image as AssetImage).assetName);
    }
    return names;
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(1280, 800),
  ]) {
    for (final night in [true, false]) {
      testWidgets(
        'all 6 package illustrations render at '
        '${size.width.toInt()}x${size.height.toInt()} '
        '${night ? 'night' : 'day'} without overflow',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await pumpPackages(tester, night: night);
          expect(tester.takeException(), isNull);
          final seen = <String>{...renderedPackageAssets()};
          for (var i = 0; i < 40; i++) {
            await tester.drag(
              find.byKey(const Key('packages_scroll')),
              const Offset(0, -300),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            seen.addAll(renderedPackageAssets());
          }
          expect(seen, packageAssets.toSet());
        },
      );
    }
  }

  testWidgets('package hero and kit tiles are square; hero capped on wide', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    await pumpPackages(tester);
    final card = tester.getSize(find.byKey(const Key('package_card_inje')));
    final hero = tester.getSize(find.byKey(const Key('package_hero_inje')));
    expect(hero.width, card.width);
    expect(hero.height, hero.width);

    for (final gear in ['binoculars', 'guide', 'headlamp', 'notebook']) {
      final tile = find.byKey(Key('package_kit_$gear'));
      await tester.dragUntilVisible(
        tile,
        find.byKey(const Key('packages_scroll')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final s = tester.getSize(tile);
      expect(s.height, s.width, reason: gear);
      expect(
        tester.getSize(
          find.descendant(of: tile, matching: find.byType(Image)),
        ),
        s,
        reason: gear,
      );
    }

    // Fresh tree so the scroll position resets to the top.
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(1280, 800);
    await pumpPackages(tester);
    final wideHero = tester.getSize(
      find.byKey(const Key('package_hero_inje')),
    );
    expect(wideHero, const Size(packageHeroMaxExtent, packageHeroMaxExtent));
    expect(tester.takeException(), isNull);
  });

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
