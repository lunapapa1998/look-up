import 'package:flutter/material.dart';

import '../models/stay_package.dart';
import '../theme/app_theme.dart';
import '../theme/layout_tokens.dart';
import '../utils/keep_all.dart';
import '../widgets/common/lookup_header.dart';
import '../widgets/common/lookup_scroll_behavior.dart';
import '../widgets/common/mode_toggle.dart';
import '../widgets/packages/package_card.dart';
import '../widgets/packages/package_extras.dart';
import 'package_booking_preview_screen.dart';

class PackagesCatalogScreen extends StatefulWidget {
  const PackagesCatalogScreen({super.key, this.packages = exampleStayPackages});
  final List<StayPackage> packages;
  @override
  State<PackagesCatalogScreen> createState() => _PackagesCatalogScreenState();
}

class _PackagesCatalogScreenState extends State<PackagesCatalogScreen> {
  PackageCategory? _category;

  void _showHelp() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('패키지 이용 안내', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '현재는 예시 패키지입니다. 일정·가격·교통·혜택·인증·환경 지표는 실제 상품이나 실시간 정보가 아닙니다.\n\n예약 미리보기에서 희망 출발일과 인원에 따른 예시 금액을 확인할 수 있습니다. 실제 예약·결제·상담 접수는 지원하지 않습니다.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final packages = widget.packages
        .where((p) => _category == null || p.category == _category)
        .toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const Key('packages_scroll'),
          slivers: [
            const LookUpSliverHeader(modeToggle: ObsModeToggle()),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(child: _PackagesIntro()),
            ),
            SliverToBoxAdapter(
              child: ScrollConfiguration(
                behavior: const LookUpScrollBehavior(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Row(
                    children: [
                      for (final category in [null, ...PackageCategory.values])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            key: Key(
                              'packages_filter_${category?.name ?? 'all'}',
                            ),
                            label: Text(
                              category?.label ??
                                  '전체 패키지 (${widget.packages.length})',
                            ),
                            selected: _category == category,
                            // Neutral (black/white) selected fill.
                            selectedColor: colors.primary,
                            // Bundled Bithumb Gothic labelLarge (14/1.43). The
                            // former `labelMedium` was runtime-loaded
                            // JetBrains Mono (Google Fonts): on web the chip
                            // measured the label before that font arrived,
                            // then painted wider mono spaces/digits/'·' and
                            // the label faded out at the chip edge.
                            labelStyle: text.labelLarge?.copyWith(
                              color: _category == category
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                            padding: catalogChipPadding,
                            labelPadding: catalogChipLabelPadding,
                            visualDensity: VisualDensity.standard,
                            materialTapTargetSize:
                                MaterialTapTargetSize.padded,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (packages.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.page),
                sliver: SliverToBoxAdapter(
                  child: Text('이 유형의 패키지가 없어요', style: text.bodyMedium),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                0,
              ),
              sliver: SliverList.builder(
                itemCount: packages.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: PackageCard(
                    key: Key('package_card_${packages[i].id}'),
                    package: packages[i],
                    onPreview: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PackageBookingPreviewScreen(package: packages[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
              sliver: SliverToBoxAdapter(child: PackageKitSection()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(child: PackageImpactSection()),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.legacyBar),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('패키지 · 서비스 준비 중', style: text.bodySmall),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const Key('packages_help'),
                  onPressed: _showHelp,
                  child: const Text('이용 안내'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const packagesIntroTitle = '낮에는 새를 만나고, 밤에는 별을 만나요.';
const packagesIntroSubtitle = '하늘을 따라 이어지는 여행';
const packagesIntroDescription =
    '새들의 날갯짓에서 은하수까지. 소도시의 낮과 밤을 연결하는 생태 체류형 로컬 여행 코스.';

/// Intro headline size: 22 (≤360), 24 (<600), 28 (≥600).
double packagesIntroTitleFontSize(double width) =>
    width <= 360 ? 22 : (width < 600 ? 24 : 28);

class _PackagesIntro extends StatelessWidget {
  const _PackagesIntro();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          keepAll(packagesIntroTitle),
          key: const Key('packages_intro_title'),
          semanticsLabel: packagesIntroTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(
            fontFamily: AppTheme.bithumbGothic,
            fontSize: packagesIntroTitleFontSize(width),
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          keepAll(packagesIntroSubtitle),
          key: const Key('packages_intro_subtitle'),
          semanticsLabel: packagesIntroSubtitle,
          style: text.bodyLarge?.copyWith(
            fontFamily: AppTheme.bithumbGothic,
            fontSize: width >= 600 ? 18 : 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          keepAll(packagesIntroDescription),
          semanticsLabel: packagesIntroDescription,
          style: text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
