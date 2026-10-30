import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/discovery.dart';
import '../../models/observation.dart' show SpeciesType;
import '../../screens/badges_screen.dart';
import '../../screens/observation_form_screen.dart';
import '../../state/discovery_providers.dart';
import '../../state/journey_providers.dart';
import '../../state/sample_data_provider.dart';
import '../../theme/layout_tokens.dart';
import '../../utils/journey_recommender.dart';
import '../../utils/keep_all.dart';
import '../common/eyebrow_label.dart';
import '../common/status_view.dart';
import '../sample_data_notice.dart';

/// Home '오늘의 관찰 여정' card (spec 058 Phase 3): five tappable steps that
/// link existing screens/tabs — ① 오늘 조건 → ② 추천 장소 → ③ 주변 코스·음식점
/// → ④ 기록하기 → ⑤ 오늘의 참여(시범).
///
/// Flat (AppRadius.card, 1px outline, no shadow), no animations. Values are
/// reference indicators / recorded data, never a promise of what will be
/// seen. The demo location (강화) is stated on the card.
class JourneyCard extends ConsumerWidget {
  const JourneyCard({super.key, this.onConditionsTap});

  /// Step ① tap: e.g. bring the home conditions section into view.
  final VoidCallback? onConditionsTap;

  static const Key cardKey = Key('journey_card');
  static Key stepKey(int number) => Key('journey_step_$number');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final mode = ref.watch(obsModeProvider).mode;
    final isDay = mode == ObsMode.day;
    final overviewAsync = ref.watch(discoveryProvider(mode));
    final mapAsync = ref.watch(observationMapProvider);
    final now = ref.watch(nowProvider);
    final sampleSources = ref.watch(sampleSourcesProvider);

    // ① 오늘 조건
    final _StepDetail conditions;
    final overview = overviewAsync.valueOrNull;
    if (overview != null) {
      final index = overview.suitabilityIndex;
      final golden = goldenTimeLine(overview.goldenHours, mode, now);
      final lines = [
        '${index.label} · ${index.score}점',
        golden == null ? '참고 지표' : '참고 지표 · $golden',
      ];
      conditions = _StepDetail.lines(lines);
    } else if (overviewAsync.isLoading) {
      conditions = const _StepDetail.loading('오늘 조건을 불러오는 중이에요');
    } else {
      conditions = const _StepDetail.empty('오늘 조건 정보를 아직 받지 못했어요');
    }

    // ② 추천 장소
    final _StepDetail place;
    String? recommendedSpotId;
    final spots = mapAsync.valueOrNull?.spots;
    if (spots != null) {
      final rec = recommendJourneySpot(mode, spots);
      if (rec != null) {
        recommendedSpotId = rec.spot.id;
        place = _StepDetail.lines([rec.spot.name, rec.reason]);
      } else {
        place = _StepDetail.empty(
          isDay ? '새 관찰 기록이 있는 장소가 아직 없어요' : '밤하늘 밝기 데이터가 있는 장소가 아직 없어요',
        );
      }
    } else if (mapAsync.isLoading) {
      place = const _StepDetail.loading('추천 장소를 찾는 중이에요');
    } else {
      place = const _StepDetail.empty('장소 데이터를 받지 못했어요 · 지도에서 둘러보세요');
    }

    void openTab(int index) =>
        ref.read(appTabIndexProvider.notifier).state = index;

    final steps = <Widget>[
      _JourneyStep(
        number: 1,
        icon: Icons.insights,
        title: '오늘 조건',
        detail: conditions,
        sample: sampleSources.contains(SampleSource.suitability),
        onTap: onConditionsTap ?? () {},
      ),
      _JourneyStep(
        number: 2,
        icon: Icons.place_outlined,
        title: isDay ? '추천 장소 · 새 관찰' : '추천 장소 · 별 관찰',
        detail: place,
        sample: sampleSources.contains(SampleSource.observationMap),
        onTap: () {
          if (recommendedSpotId != null) {
            ref.read(pendingMapSpotIdProvider.notifier).state =
                recommendedSpotId;
          }
          openTab(AppTab.observationMap);
        },
      ),
      _JourneyStep(
        number: 3,
        icon: Icons.hiking,
        title: '주변 코스·음식점',
        detail: const _StepDetail.lines([
          '두루누비 공공데이터 기준 둘레길 코스와 종점 주변 음식점',
        ]),
        sample: sampleSources.contains(SampleSource.trails),
        onTap: () => openTab(AppTab.discover),
      ),
      _JourneyStep(
        number: 4,
        icon: Icons.edit_note,
        title: '기록하기',
        detail: _StepDetail.lines([
          isDay ? '관찰한 새를 생태일기에 남겨요' : '관찰한 별·천체를 생태일기에 남겨요',
        ]),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ObservationFormScreen(
              initialSpeciesType: isDay ? SpeciesType.bird : SpeciesType.star,
            ),
          ),
        ),
      ),
      _JourneyStep(
        number: 5,
        icon: Icons.emoji_events_outlined,
        title: '오늘의 참여',
        pilot: true,
        detail: const _StepDetail.lines(['관찰 기록으로 배지 진행도를 확인해요']),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
        ),
      ),
    ];

    final region = isDay ? '시연 지역: 강화 · 낮 새 관찰' : '시연 지역: 강화 · 밤 별 관찰';

    return Container(
      key: cardKey,
      width: double.infinity,
      // Card padding 16, 20 from the medium breakpoint (UI finishing pass).
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mediumMin
            ? 20
            : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel('오늘의 관찰 여정'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            keepAll(region),
            semanticsLabel: region,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...steps,
        ],
      ),
    );
  }
}

enum _DetailKind { lines, loading, empty }

class _StepDetail {
  const _StepDetail.lines(this.lines)
    : kind = _DetailKind.lines,
      _message = null;
  const _StepDetail.loading(String message)
    : kind = _DetailKind.loading,
      lines = const [],
      _message = message;
  const _StepDetail.empty(String message)
    : kind = _DetailKind.empty,
      lines = const [],
      _message = message;

  final _DetailKind kind;
  final List<String> lines;
  final String? _message;

  String get message => _message ?? lines.join('. ');
}

/// One journey step row: number, icon, title (+ '예시'/'시범' tags), detail
/// and a chevron. At least 44px tall, keyboard focusable (InkWell), exposed
/// as a single semantics button.
class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.sample = false,
    this.pilot = false,
  });

  final int number;
  final IconData icon;
  final String title;
  final _StepDetail detail;
  final VoidCallback onTap;
  final bool sample;
  final bool pilot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    final Widget detailWidget;
    switch (detail.kind) {
      case _DetailKind.lines:
        detailWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in detail.lines)
              Text(
                keepAll(line),
                semanticsLabel: line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        );
      case _DetailKind.loading:
        // Static hourglass: the journey card has no animations.
        detailWidget = MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: StatusView.loading(message: detail.message),
        );
      case _DetailKind.empty:
        detailWidget = StatusView.empty(message: detail.message);
    }

    final label = [
      '$number단계 $title',
      if (pilot) '시범',
      detail.message,
      if (sample) '예시 데이터',
    ].join('. ');

    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: JourneyCard.stepKey(number),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline, width: 1),
                      ),
                      child: Text(
                        '$number',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (pilot) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const _PilotTag(),
                              ],
                              if (sample) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const SampleMark(compact: true),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          detailWidget,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small outlined '시범' tag: the feature is a pilot (no server-side
/// missions or account link yet).
class _PilotTag extends StatelessWidget {
  const _PilotTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('journey_pilot_tag'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.link),
      ),
      child: Text(
        '시범',
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
