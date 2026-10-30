import 'package:flutter/material.dart';

import '../models/stay_package.dart';
import '../theme/layout_tokens.dart';
import '../widgets/app_sliver_header.dart';
import '../widgets/common/lookup_scroll_behavior.dart';
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
              '현재는 예시 패키지입니다. 일정·가격·교통·혜택·인증·환경 지표는 실제 상품이나 실시간 정보가 아닙니다.\n\n예약 미리보기에서 희망 날짜와 인원에 따른 예시 금액을 확인할 수 있습니다. 실제 예약·결제·상담 접수는 지원하지 않습니다.',
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
            const AppSliverHeader(),
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
                            selectedColor: colors.secondary,
                            labelStyle: text.labelMedium?.copyWith(
                              color: _category == category
                                  ? colors.onSecondary
                                  : colors.onSurfaceVariant,
                            ),
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

class _PackagesIntro extends StatelessWidget {
  const _PackagesIntro();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('낮에는 탐조, 밤에는 별자리', style: text.headlineSmall),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '24시간',
              style: text.displaySmall?.copyWith(color: colors.secondary),
            ),
            Text('수직적 여행', style: text.headlineSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '대지의 날갯짓에서 은하수까지. 소도시의 낮과 밤을 연결하는 생태 체류형 로컬 여행 코스.',
          style: text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
