import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/discovery.dart';
import '../state/discovery_providers.dart';
import '../widgets/mode_header.dart';
import '../widgets/score_gauge.dart';

class HomeDiscoveryScreen extends ConsumerWidget {
  const HomeDiscoveryScreen({super.key, required this.onViewMapPressed});

  final VoidCallback onViewMapPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final modeState = ref.watch(obsModeProvider);
    final currentMode = modeState.mode;
    final overviewAsync = ref.watch(discoveryProvider(currentMode));
    final hotspots = ref.watch(hotspotsProvider);
    final locationAsync = ref.watch(locationProvider);
    final locationLabel = locationAsync.when(
      data: (loc) => loc.placeName ?? fallbackPlaceName,
      loading: () => '위치 확인 중',
      error: (_, _) => fallbackPlaceName,
    );
    final modeTransitionDuration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            toolbarHeight: 52,
            expandedHeight: 160,
            flexibleSpace: Builder(
              builder: (context) {
                final settings = context
                    .dependOnInheritedWidgetOfExactType<
                      FlexibleSpaceBarSettings
                    >()!;
                final extentRange = settings.maxExtent - settings.minExtent;
                final collapseFraction = extentRange <= 0
                    ? 0.0
                    : ((settings.maxExtent - settings.currentExtent) /
                              extentRange)
                          .clamp(0.0, 1.0)
                          .toDouble();

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      ignoring: collapseFraction >= 0.5,
                      child: Opacity(
                        key: const Key('modeHeaderExpandedLayerOpacity'),
                        opacity: 1.0 - collapseFraction,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 28,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '위를 봐요',
                                        style: textTheme.headlineSmall,
                                      ),
                                      Text(
                                        'LOOK UP',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.explore,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              locationLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ModeHeader(
                                state: modeState,
                                collapsed: false,
                                onModeChanged: ref
                                    .read(obsModeProvider.notifier)
                                    .setManual,
                                onResetToAuto: ref
                                    .read(obsModeProvider.notifier)
                                    .resetToAuto,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 52,
                      child: IgnorePointer(
                        ignoring: collapseFraction < 0.5,
                        child: Opacity(
                          key: const Key('modeHeaderCollapsedLayerOpacity'),
                          opacity: collapseFraction,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ModeHeader(
                                state: modeState,
                                collapsed: true,
                                onModeChanged: ref
                                    .read(obsModeProvider.notifier)
                                    .setManual,
                                onResetToAuto: ref
                                    .read(obsModeProvider.notifier)
                                    .resetToAuto,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE FIELD TELEMETRY',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          ' | 강화 · 영월 실시간 기상망',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '하늘을 올려다보기 완벽한 하루예요, '),
                          TextSpan(
                            text: '지은님',
                            style: TextStyle(color: colorScheme.secondary),
                          ),
                        ],
                      ),
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '지상 갯벌의 날갯짓부터 성운의 심연까지, 오늘 관찰의 최적 기점입니다.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: modeTransitionDuration,
                  child: KeyedSubtree(
                    key: ValueKey(currentMode),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: overviewAsync.when(
                        data: (overview) => Column(
                          children: [
                            if (overview.degraded)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '일부 데이터를 불러오지 못했어요',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Row(
                              children: [
                                ScoreGauge(
                                  score: overview.suitabilityIndex.score,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '오늘의 통합 관찰 적합도',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              overview.suitabilityIndex.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme.secondary,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified,
                                            color: colorScheme.secondary,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.wb_twilight,
                                            color: colorScheme.tertiary,
                                            size: 16,
                                          ),
                                          Flexible(
                                            child: Text(
                                              'SQM ${overview.suitabilityIndex.sqmValue}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.labelMedium
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme.tertiary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        overview.suitabilityIndex.skyClass,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: List.generate(
                                overview.goldenHours.length,
                                (i) {
                                  final gh = overview.goldenHours[i];
                                  final isDay = gh.mode == ObsMode.day;
                                  final accent = isDay
                                      ? colorScheme.tertiary
                                      : colorScheme.secondary;
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        left: i == 0 ? 0 : 8,
                                        right:
                                            i == overview.goldenHours.length -
                                                    1
                                                ? 0
                                                : 8,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  gh.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                        color: accent,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            isDay
                                                ? Icons.forest
                                                : Icons.dark_mode,
                                            color: accent,
                                          ),
                                          Text(
                                            gh.timeRange,
                                            style: textTheme.labelMedium
                                                ?.copyWith(
                                                  color: accent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            gh.description,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (
                                    var i = 0;
                                    i < overview.telemetry.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      Container(
                                        width: 1,
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        color: colorScheme.outlineVariant,
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 20,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _iconForTelemetryKind(
                                              overview.telemetry[i].kind,
                                            ),
                                            size: 16,
                                            color: colorScheme.outline,
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                overview.telemetry[i].label,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              Text(
                                                overview.telemetry[i].value,
                                                style: textTheme.labelMedium
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurface,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        loading: () => const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, st) => Column(
                          children: [
                            Text(
                              '적합도 정보를 불러오지 못했어요',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(
                                discoveryProvider(currentMode),
                              ),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('지금 시선의 초점', style: textTheme.headlineSmall),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '필터 맞춤 설정',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'INTEGRATED RADAR',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '실시간 생태 · 성운 핫스팟',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: onViewMapPressed,
                      child: Text(
                        '지도에서 보기 →',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: hotspots
                      .map(
                        (hotspot) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AnimatedOpacity(
                            duration: modeTransitionDuration,
                            opacity: hotspot.mode == currentMode ? 1.0 : 0.45,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              color: colorScheme.surfaceContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          colorScheme.surfaceContainerHigh,
                                          colorScheme.surfaceContainerHighest,
                                        ],
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Icon(
                                            hotspot.mode == ObsMode.day
                                                ? Icons.landscape
                                                : Icons.nightlight,
                                            size: 48,
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          right: 8,
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: hotspot.badges
                                                .map(
                                                  (b) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      b,
                                                      style: textTheme
                                                          .labelSmall,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hotspot.scoreIcon,
                                                  size: 14,
                                                  color:
                                                      hotspot.mode ==
                                                          ObsMode.day
                                                      ? colorScheme.tertiary
                                                      : colorScheme.secondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '적합도 ${hotspot.suitabilityScore}점',
                                                  style: textTheme.labelMedium
                                                      ?.copyWith(
                                                        color:
                                                            hotspot.mode ==
                                                                ObsMode.day
                                                            ? colorScheme
                                                                  .tertiary
                                                            : colorScheme
                                                                  .secondary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            color: colorScheme.scrim
                                                .withValues(alpha: 0.35),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  hotspot.overlayIcon,
                                                  size: 14,
                                                  color: colorScheme.onSurface,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        hotspot
                                                            .overlayHeadline,
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  colorScheme
                                                                      .onSurface,
                                                            ),
                                                      ),
                                                      Text(
                                                        hotspot
                                                            .overlayTimestamp,
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.7,
                                                                  ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: colorScheme.outline,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                hotspot.title,
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          hotspot.subtitle,
                                          style: textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.outline,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          hotspot.description,
                                          style: textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: hotspot.metas
                                              .map(
                                                (m) => Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      m.icon,
                                                      size: 14,
                                                      color:
                                                          colorScheme.outline,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      m.label,
                                                      style: textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton(
                                            onPressed: () {},
                                            child: Text(hotspot.ctaLabel),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForTelemetryKind(String kind) {
  switch (kind) {
    case 'sky':
      return Icons.wb_sunny;
    case 'humidity':
      return Icons.water_drop;
    case 'wind':
      return Icons.air;
    case 'precip':
      return Icons.grain;
    case 'tide':
      return Icons.waves;
    default:
      return Icons.help_outline;
  }
}
