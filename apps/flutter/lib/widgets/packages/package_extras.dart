import 'package:flutter/material.dart';

import '../../theme/layout_tokens.dart';

class PackageKitSection extends StatelessWidget {
  const PackageKitSection({super.key});
  static const _gear = [
    ('binoculars', 'DAY GEAR', '8x42 방수 쌍안경', '밝고 선명한 시야로 새를 가까이 관찰해요'),
    ('guide', 'SPECIES GUIDE', '한국 텃새·철새 핸드북', '서식종을 알아보는 입문용 가이드'),
    ('headlamp', 'NIGHT VISION', '적색광 LED 헤드랜턴', '암순응을 유지하고 야생동물 교란을 줄여요'),
    ('notebook', 'CITIZEN SCIENCE', '시민과학 기록 노트', '발견한 새와 별을 기록하는 관찰 노트'),
  ];
  @override
  Widget build(BuildContext context) => _SectionSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('체류자 전용 입문 키트', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '시안의 대여 구성 예시 · 실제 대여 서비스는 준비 중입니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 1
                : 2;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.lg,
              children: [
                for (final gear in _gear)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.asset(
                            'assets/packages/${gear.$1}.jpg',
                            width: width,
                            height: width * 0.55,
                            fit: BoxFit.cover,
                            semanticLabel: gear.$3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          gear.$2,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          gear.$3,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          gear.$4,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class PackageImpactSection extends StatelessWidget {
  const PackageImpactSection({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGENERATIVE TOURISM',
            style: text.labelSmall?.copyWith(color: colors.secondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('착한 체류, 지역을 생각하는 여행', style: text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('아래 수치는 시안 예시이며 검증된 실적이 아닙니다.', style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                for (final item in [
                  ('68%', '지역 소상공인 기여 · 예시', colors.tertiary),
                  ('52%', '탄소 배출 절감 · 예시', colors.secondary),
                ])
                  SizedBox(
                    width:
                        constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.3
                        ? constraints.maxWidth
                        : (constraints.maxWidth - AppSpacing.lg) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: text.headlineMedium?.copyWith(color: item.$3),
                        ),
                        Text(item.$2, style: text.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '대중교통을 이용하고 로컬 식당과 해설사를 연결하는 여행을 지향합니다. 새와 서식지를 방해하지 않고 밤에는 불빛을 줄여주세요.',
            style: text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: child,
  );
}
