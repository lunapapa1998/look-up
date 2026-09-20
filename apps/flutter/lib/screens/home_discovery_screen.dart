import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/discovery.dart';
import '../models/trails.dart';
import '../state/auth_providers.dart';
import '../state/discovery_providers.dart';
import '../widgets/app_header_logo.dart';
import '../widgets/night_sky_tag.dart';
import '../widgets/score_gauge.dart';
import 'account_screen.dart';

class HomeDiscoveryScreen extends ConsumerStatefulWidget {
  const HomeDiscoveryScreen({super.key, required this.onViewMapPressed});

  final VoidCallback onViewMapPressed;

  @override
  ConsumerState<HomeDiscoveryScreen> createState() =>
      _HomeDiscoveryScreenState();
}

/// Owns the manual-transition content stagger: [_staggerController] is a
/// 420ms container animation carved into four 200ms sub-intervals (one per
/// content group, via [_StaggerReveal]) at +80/120/160/200ms offsets. Only
/// manual mode switches replay it from 0; auto switches and reduce-motion
/// leave it settled at 1.0 so content never blanks out mid-transition. See
/// `specs/011-scene-transition-flutter.md` §4 for the timing source of truth.
class _HomeDiscoveryScreenState extends ConsumerState<HomeDiscoveryScreen>
    with TickerProviderStateMixin {
  static const _staggerTotalDuration = Duration(milliseconds: 420);

  late final AnimationController _staggerController;
  final Set<ObsMode> _degradedModes = {};

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: _staggerTotalDuration,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _refreshDiscovery(ObsMode mode) async {
    ref.invalidate(discoveryProvider(mode));
    await ref.read(discoveryProvider(mode).future);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final modeState = ref.watch(obsModeProvider);
    final currentMode = modeState.mode;
    final overviewAsync = ref.watch(discoveryProvider(currentMode));
    final user = ref.watch(authUserProvider);
    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : '관찰자';
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

    ref.listen<ObsModeState>(obsModeProvider, (previous, next) {
      final modeChanged = previous == null || previous.mode != next.mode;
      if (!modeChanged) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (next.source == ObsModeSource.manual && !reduceMotion) {
        _staggerController.forward(from: 0);
      } else {
        // Auto-sourced changes and reduce-motion settle instantly: content
        // must show the new values with no fade/slide.
        _staggerController.value = 1.0;
      }
    });

    ref.listen<AsyncValue<DiscoveryOverview>>(discoveryProvider(currentMode), (
      previous,
      next,
    ) {
      final overview = next.valueOrNull;
      if (overview == null) return;
      if (overview.degraded) {
        _degradedModes.add(currentMode);
        return;
      }
      _degradedModes.remove(currentMode);
      final otherMode = currentMode == ObsMode.day
          ? ObsMode.night
          : ObsMode.day;
      if (_degradedModes.remove(otherMode)) {
        ref.invalidate(discoveryProvider(otherMode));
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refreshDiscovery(currentMode),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              toolbarHeight: 64,
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const AppHeaderLogo(),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('위를 봐요', style: textTheme.headlineSmall),
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
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.explore, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                locationLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '내 계정',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountScreen(),
                        ),
                      ),
                      icon: const CircleAvatar(child: Icon(Icons.person)),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '하늘을 올려다보기 완벽한 하루예요, '),
                            TextSpan(
                              text: '$displayName님',
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
                  Row(
                    children: [
                      Text('지금 시선의 초점', style: textTheme.headlineSmall),
                      const Spacer(),
                      _buildFocusModeSourceBadge(colorScheme, modeState),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _FocusModeSegmentButton(
                          buttonKey: const Key('focusModeDaySegment'),
                          icon: Icons.light_mode,
                          label: '낮의 새를 찾아서',
                          active: currentMode == ObsMode.day,
                          activeBackground: colorScheme.tertiary,
                          activeForeground: colorScheme.onTertiary,
                          semanticsLabel: '낮 모드로 전환합니다',
                          onTap: () => ref
                              .read(obsModeProvider.notifier)
                              .setManual(ObsMode.day),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FocusModeSegmentButton(
                          buttonKey: const Key('focusModeNightSegment'),
                          icon: Icons.nightlight_round,
                          label: '밤의 별을 보러',
                          active: currentMode == ObsMode.night,
                          activeBackground: colorScheme.secondary,
                          activeForeground: colorScheme.onSecondary,
                          semanticsLabel: '밤 모드로 전환합니다',
                          onTap: () => ref
                              .read(obsModeProvider.notifier)
                              .setManual(ObsMode.night),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: modeTransitionDuration,
                    child: KeyedSubtree(
                      key: ValueKey(currentMode),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -40,
                              right: -40,
                              child: IgnorePointer(
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        colorScheme.secondary.withValues(
                                          alpha: currentMode == ObsMode.night
                                              ? 0.03
                                              : 0.10,
                                        ),
                                        colorScheme.secondary.withValues(
                                          alpha: 0.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: overviewAsync.when(
                                data: (overview) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (overview.weatherRefreshing)
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              colorScheme.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(child: Text('기상 정보 갱신 중')),
                                          ],
                                        ),
                                      ),
                                    if (overview.degraded)
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.errorContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 16,
                                              color:
                                                  colorScheme.onErrorContainer,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '일부 데이터를 불러오지 못했어요',
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onErrorContainer,
                                                    ),
                                              ),
                                            ),
                                            TextButton(
                                              key: const Key(
                                                'discovery_degraded_retry',
                                              ),
                                              onPressed: () =>
                                                  _refreshDiscovery(
                                                    currentMode,
                                                  ),
                                              child: const Text('다시 불러오기'),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    _StaggerReveal(
                                      controller: _staggerController,
                                      startMs: 80,
                                      child: Row(
                                        children: [
                                          ScoreGauge(
                                            score:
                                                overview.suitabilityIndex.score,
                                            size: 56,
                                            scoreFontSize: 20,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '오늘의 통합 관찰 적합도',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        overview
                                                            .suitabilityIndex
                                                            .label,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .secondary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.verified,
                                                      color:
                                                          colorScheme.secondary,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 170,
                                            ),
                                            child: NightSkyTag(
                                              nightSky: NightSky(
                                                sqmValue: overview
                                                    .suitabilityIndex
                                                    .sqmValue,
                                                bortleClass: overview
                                                    .suitabilityIndex
                                                    .bortleClass,
                                                skyClass: overview
                                                    .suitabilityIndex
                                                    .skyClass,
                                                status: overview
                                                    .suitabilityIndex
                                                    .nightSkyStatus,
                                              ),
                                              large: false,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _StaggerReveal(
                                      controller: _staggerController,
                                      startMs: 120,
                                      child: Builder(
                                        builder: (context) {
                                          final sortedGoldenHours =
                                              List<GoldenHour>.of(
                                                overview.goldenHours,
                                              )..sort((a, b) {
                                                final aOrder =
                                                    a.mode == ObsMode.day
                                                    ? 0
                                                    : 1;
                                                final bOrder =
                                                    b.mode == ObsMode.day
                                                    ? 0
                                                    : 1;
                                                return aOrder.compareTo(bOrder);
                                              });
                                          return Column(
                                            children: List.generate(sortedGoldenHours.length, (
                                              i,
                                            ) {
                                              final gh = sortedGoldenHours[i];
                                              final isDay =
                                                  gh.mode == ObsMode.day;
                                              final accent = isDay
                                                  ? colorScheme.tertiary
                                                  : colorScheme.secondary;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  top: i == 0 ? 0 : 8,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .surfaceContainerLow
                                                        .withValues(alpha: 0.9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      SizedBox(
                                                        width: 27,
                                                        child: Icon(
                                                          isDay
                                                              ? Icons.forest
                                                              : Icons.dark_mode,
                                                          color: accent,
                                                          size: 28,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    gh.label,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: textTheme
                                                                        .labelSmall
                                                                        ?.copyWith(
                                                                          color:
                                                                              accent,
                                                                          fontSize:
                                                                              12,
                                                                          height:
                                                                              16 /
                                                                              12,
                                                                        ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Container(
                                                                  width: 6,
                                                                  height: 6,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        accent,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Text(
                                                              gh.timeRange,
                                                              style: textTheme
                                                                  .labelMedium
                                                                  ?.copyWith(
                                                                    color: colorScheme
                                                                        .onSurface,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14,
                                                                    height:
                                                                        18 / 14,
                                                                  ),
                                                            ),
                                                            Text(
                                                              gh.description,
                                                              style: textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: colorScheme
                                                                        .onSurfaceVariant,
                                                                    fontSize:
                                                                        13,
                                                                    height:
                                                                        18 / 13,
                                                                  ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentMode == ObsMode.night &&
                                        overview.moon != null &&
                                        overview.moon!.status != 'unavailable')
                                      _StaggerReveal(
                                        controller: _staggerController,
                                        startMs: 140,
                                        child: _TodayMoonSection(
                                          moon: overview.moon!,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    _StaggerReveal(
                                      controller: _staggerController,
                                      startMs: 160,
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < overview.telemetry.length;
                                              i++
                                            )
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 44,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .surfaceContainerHigh,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _iconForTelemetryKind(
                                                            overview
                                                                .telemetry[i]
                                                                .kind,
                                                          ),
                                                          size: 14,
                                                          color: colorScheme
                                                              .outline,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          overview
                                                              .telemetry[i]
                                                              .label,
                                                          style: textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      overview
                                                          .telemetry[i]
                                                          .value,
                                                      style: textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurface,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                loading: () => const SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
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
                          ],
                        ),
                      ),
                    ),
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
                        onPressed: widget.onViewMapPressed,
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
                  _StaggerReveal(
                    controller: _staggerController,
                    startMs: 200,
                    child: Column(
                      children: hotspots
                          .map(
                            (hotspot) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AnimatedOpacity(
                                duration: modeTransitionDuration,
                                opacity: hotspot.mode == currentMode
                                    ? 1.0
                                    : 0.45,
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: colorScheme.surfaceContainer,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              colorScheme
                                                  .surfaceContainerHighest,
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
                                                color: colorScheme
                                                    .onSurfaceVariant,
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      hotspot.scoreIcon,
                                                      size: 14,
                                                      color:
                                                          hotspot.mode ==
                                                              ObsMode.day
                                                          ? colorScheme.tertiary
                                                          : colorScheme
                                                                .secondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '적합도 ${hotspot.suitabilityScore}점',
                                                      style: textTheme
                                                          .labelMedium
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
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                color: colorScheme.scrim
                                                    .withValues(alpha: 0.35),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      hotspot.overlayIcon,
                                                      size: 14,
                                                      color:
                                                          colorScheme.onSurface,
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
                                                                  color: colorScheme
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
                                                                        alpha:
                                                                            0.7,
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
                                                          color: colorScheme
                                                              .outline,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
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
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusModeSourceBadge(
    ColorScheme colorScheme,
    ObsModeState modeState,
  ) {
    if (modeState.source == ObsModeSource.auto) {
      return Semantics(
        label: '자동 모드입니다',
        container: true,
        excludeSemantics: true,
        child: Container(
          key: const Key('focusModeSourceBadgeAuto'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            'AUTO',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Semantics(
      label: '수동 모드입니다. 탭하면 자동 모드로 돌아갑니다.',
      container: true,
      excludeSemantics: true,
      onTap: () => ref.read(obsModeProvider.notifier).resetToAuto(),
      child: GestureDetector(
        key: const Key('focusModeSourceBadgeManual'),
        onTap: () => ref.read(obsModeProvider.notifier).resetToAuto(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            'MANUAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width day/night focus-mode segment button, shown in pairs below the
/// suitability card. Active state uses a filled accent background (not color
/// alone) so it stays legible without relying on hue perception.
class _FocusModeSegmentButton extends StatelessWidget {
  const _FocusModeSegmentButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.activeBackground,
    required this.activeForeground,
    required this.semanticsLabel,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final Color activeBackground;
  final Color activeForeground;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = active
        ? activeBackground
        : colorScheme.surfaceContainerHigh;
    final foreground = active ? activeForeground : colorScheme.onSurfaceVariant;

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: active,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: buttonKey,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData moonPhaseIcon(String phaseName) {
  switch (phaseName) {
    case '삭':
      return Icons.circle_outlined;
    case '초승달':
      return Icons.nights_stay;
    case '상현 반달':
      return Icons.brightness_3;
    case '차오르는 달':
      return Icons.brightness_2;
    case '보름달':
      return Icons.circle;
    case '기우는 달':
      return Icons.brightness_2;
    case '하현 반달':
      return Icons.brightness_3;
    case '그믐달':
      return Icons.nights_stay;
    default:
      return Icons.dark_mode;
  }
}

/// Shows today's moon phase, illumination, moonset, and moonrise below the
/// golden-hour cards in night mode (see `specs/039-moon-section-flutter.md`).
/// Visually consistent with the golden-hour card styling above it.
class _TodayMoonSection extends StatelessWidget {
  const _TodayMoonSection({required this.moon});

  final Moon moon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 27,
            child: Semantics(
              label: '${moon.phaseName}, 달빛 ${moon.illumination} 퍼센트',
              child: Icon(
                moonPhaseIcon(moon.phaseName),
                color: colorScheme.secondary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 달 · ${moon.phaseName}',
                  style: (textTheme.titleSmall ?? textTheme.labelLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
                Text(
                  '달빛 ${moon.illumination}%',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '월몰 ${moon.moonset ?? '—'}',
                style: (textTheme.bodyMedium ?? textTheme.labelMedium)
                    ?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '월출 ${moon.moonrise ?? '—'}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] in a 200ms opacity+translateY reveal carved out of
/// [controller]'s timeline via [Interval], starting at [startMs] into the
/// controller's total duration. Used for the four staggered content groups
/// on the manual mode-switch reveal (see
/// `specs/011-scene-transition-flutter.md` §4). [child] stays mounted at all
/// times — only its opacity/offset animate — so data is never torn down
/// mid-transition.
class _StaggerReveal extends StatefulWidget {
  const _StaggerReveal({
    required this.controller,
    required this.startMs,
    required this.child,
  });

  final AnimationController controller;
  final double startMs;
  final Widget child;

  static const double _groupDurationMs = 200.0;

  @override
  State<_StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<_StaggerReveal> {
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    final totalMs = widget.controller.duration!.inMilliseconds.toDouble();
    final begin = widget.startMs / totalMs;
    final end = (widget.startMs + _StaggerReveal._groupDurationMs) / totalMs;
    _curved = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        return Opacity(
          opacity: _curved.value,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - _curved.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
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
