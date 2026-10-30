import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lookup/models/discovery.dart';
import 'package:lookup/models/region.dart';
import 'package:lookup/models/stay_package.dart';
import 'package:lookup/models/trails.dart';
import 'package:lookup/screens/packages_catalog_screen.dart';
import 'package:lookup/screens/trails_catalog_screen.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';

/// Catalog filter chips (발견 region row, 패키지 category row) must size to
/// their full label at narrow widths in both themes: no fade/clip, the
/// bundled Bithumb Gothic label (not the runtime-loaded mono font that clipped
/// labels on web), >= 40px visual height and a >= 44px tap target.
const _regions = RegionsResponse(
  nearestId: 'ganghwa',
  regions: [
    RegionSummary(
      id: 'ganghwa',
      label: '인천 강화군',
      distanceKm: 0,
      center: RegionCenter(lat: 37.7469, lng: 126.4878),
      hasStarSpot: true,
    ),
    RegionSummary(
      id: 'seosan',
      label: '충남 서산시',
      distanceKm: 90,
      center: RegionCenter(lat: 36.7845, lng: 126.4503),
      hasStarSpot: true,
    ),
    RegionSummary(
      id: 'pyeongchang',
      label: '강원 평창군',
      distanceKm: 150,
      center: RegionCenter(lat: 37.3706, lng: 128.3904),
      hasStarSpot: true,
    ),
    RegionSummary(
      id: 'suncheon',
      label: '전남 순천시',
      distanceKm: 300,
      center: RegionCenter(lat: 34.9506, lng: 127.4874),
      hasStarSpot: true,
    ),
  ],
);

class _Trails extends TrailsNotifier {
  @override
  Future<TrailsResponse> build() async =>
      const TrailsResponse(region: '강화·서해안', degraded: false, courses: []);
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> _pumpTrails(WidgetTester tester, ObsMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trailsProvider.overrideWith(_Trails.new),
        regionsProvider.overrideWith((ref) async => _regions),
      ],
      child: MaterialApp(
        theme: AppTheme.themeFor(mode),
        home: const TrailsCatalogScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpPackages(WidgetTester tester, ObsMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.themeFor(mode),
        home: const PackagesCatalogScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectChipFits(WidgetTester tester, Key chipKey, String label) {
  final chip = find.byKey(chipKey);
  expect(chip, findsOneWidget, reason: label);
  final textFinder = find.descendant(of: chip, matching: find.text(label));
  expect(textFinder, findsOneWidget, reason: label);
  final paragraph = tester.renderObject<RenderParagraph>(textFinder);

  expect(paragraph.didExceedMaxLines, isFalse, reason: label);
  final intrinsic = paragraph.getMaxIntrinsicWidth(double.infinity);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(intrinsic - 0.01),
    reason: '$label: laid out ${paragraph.size.width} < intrinsic $intrinsic',
  );
  final style = paragraph.text.style!;
  expect(style.fontFamily, AppTheme.bithumbGothic, reason: label);
  expect(style.fontSize, greaterThanOrEqualTo(14), reason: label);

  // Visual chip (its Material) contains the whole label and is >= 40 tall;
  // the chip widget (incl. tap target padding) is >= 44 tall.
  final material = find
      .descendant(of: chip, matching: find.byType(Material))
      .first;
  final chipRect = tester.getRect(material);
  final labelRect = tester.getRect(textFinder);
  expect(chipRect.height, greaterThanOrEqualTo(40), reason: label);
  expect(tester.getSize(chip).height, greaterThanOrEqualTo(44), reason: label);
  expect(labelRect.left, greaterThanOrEqualTo(chipRect.left + 8 - 0.01));
  expect(labelRect.right, lessThanOrEqualTo(chipRect.right - 8 + 0.01));
}

void main() {
  const sizes = [Size(320, 568), Size(360, 640), Size(390, 844)];
  final packageLabels = <Key, String>{
    const Key('packages_filter_all'):
        '전체 패키지 (${exampleStayPackages.length})',
    for (final c in PackageCategory.values)
      Key('packages_filter_${c.name}'): c.label,
  };
  final regionLabels = <Key, String>{
    for (final r in _regions.regions) Key('trail_region_${r.id}'): r.label,
  };

  for (final size in sizes) {
    for (final mode in ObsMode.values) {
      final tag =
          '${size.width.toInt()}x${size.height.toInt()} ${mode.name}';

      testWidgets('packages category chips show full labels at $tag', (
        tester,
      ) async {
        _setSize(tester, size);
        await _pumpPackages(tester, mode);
        expect(tester.takeException(), isNull);
        packageLabels.forEach((k, l) => _expectChipFits(tester, k, l));

        // Selected (inverted) state keeps the full label too and filters.
        final last = packageLabels.keys.last;
        await tester.ensureVisible(find.byKey(last));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(last));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(find.byKey(last)).selected, isTrue);
        packageLabels.forEach((k, l) => _expectChipFits(tester, k, l));
        expect(tester.takeException(), isNull);
      });

      testWidgets('trails region chips show full labels at $tag', (
        tester,
      ) async {
        _setSize(tester, size);
        await _pumpTrails(tester, mode);
        expect(tester.takeException(), isNull);
        regionLabels.forEach((k, l) => _expectChipFits(tester, k, l));
        expect(
          find.descendant(
            of: find.byKey(const Key('trail_region_ganghwa')),
            matching: find.byIcon(Icons.near_me),
          ),
          findsOneWidget,
        );

        final last = regionLabels.keys.last;
        await tester.ensureVisible(find.byKey(last));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(last));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(find.byKey(last)).selected, isTrue);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const Key('trail_region_ganghwa')),
              )
              .selected,
          isFalse,
        );
        regionLabels.forEach((k, l) => _expectChipFits(tester, k, l));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
