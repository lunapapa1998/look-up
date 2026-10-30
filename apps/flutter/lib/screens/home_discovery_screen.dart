import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/discovery.dart';
import '../models/trails.dart';
import '../state/discovery_providers.dart';
import '../state/sample_data_provider.dart';
import '../theme/layout_tokens.dart';
import '../theme/lookup_colors.dart';
import '../utils/keep_all.dart';
import '../widgets/common/lookup_header.dart';
import '../widgets/common/mode_toggle.dart';
import '../widgets/journey/journey_card.dart';
import '../widgets/night_sky_scale.dart';
import '../widgets/night_sky_tag.dart';
import '../widgets/sample_data_notice.dart';
import '../widgets/score_gauge.dart';
import '../widgets/tonight_sky_section.dart';
import 'account_screen.dart';

/// Home page title (UI finishing pass, 2026-10-31). Rendered through
/// [keepAll] so lines only break between words.
const String homeGreetingTitle = '오늘은 하늘을 보기 좋은 날이에요.';

/// Home page description under [homeGreetingTitle].
const String homeGreetingDescription =
    '갯벌을 찾은 새부터 밤하늘의 별까지, 오늘의 관찰을 시작해 보세요.';

const Key homeGreetingTitleKey = Key('home_greeting_title');
const Key homeGreetingDescriptionKey = Key('home_greeting_description');

/// Night-mode moon row: title ('오늘의 달 · …') and right-aligned times.
const Key homeMoonTitleKey = Key('home_moon_title');
const Key homeMoonsetKey = Key('home_moonset');
const Key homeMoonriseKey = Key('home_moonrise');

/// Night-mode night-sky label ('오늘 밤 · …'), rendered through [keepAll].
const Key homeNightSkyLabelKey = Key('home_night_sky_label');

/// Responsive home page title size: 22 at <=360, 24 below 600, 28 wider.
double homeTitleFontSize(double width) {
  if (width <= AppBreakpoints.narrowMax) return 22;
  if (width < AppBreakpoints.mediumMin) return 24;
  return 28;
}

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
  static const _staggerTotalDuration = Duration(milliseconds: 620);

  late final AnimationController _staggerController;
  final Set<ObsMode> _degradedModes = {};
  final GlobalKey _conditionsKey = GlobalKey();

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
    final sampleSources = ref.watch(sampleSourcesProvider);
    final isSuitabilitySample = sampleSources.contains(
      SampleSource.suitability,
    );
    final isStarlightSample = sampleSources.contains(SampleSource.starlight);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.mediumMin;
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
        // Keep the notch/status-bar band fixed so scrolling content never
        // slides under it; only the header below scrolls away.
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LookUpSliverHeader(
              modeToggle: const ObsModeToggle(),
              actions: [
                // Capped so a long place name ellipsizes instead of
                // squeezing the brand title out of row 1 at 320px.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
            SliverPadding(
              // One horizontal page gutter (20 at <=360, 24 phone, 32-40
              // wide, capped at maxContentWidth) shared by every card.
              padding: AppLayout.pageInsets(
                width,
              ).copyWith(top: AppSpacing.lg, bottom: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SampleDataNotice(
                    sources: const {
                      SampleSource.suitability,
                      SampleSource.starlight,
                    },
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    onRetry: () {
                      ref.invalidate(discoveryProvider(currentMode));
                      ref.invalidate(tonightSkyForecastProvider);
                    },
                  ),
                  JourneyCard(onConditionsTap: _showConditions),
                  const SizedBox(height: AppSpacing.xl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keepAll(homeGreetingTitle),
                        key: homeGreetingTitleKey,
                        semanticsLabel: homeGreetingTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: homeTitleFontSize(width),
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        keepAll(homeGreetingDescription),
                        key: homeGreetingDescriptionKey,
                        semanticsLabel: homeGreetingDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: _conditionsKey,
                    child: AnimatedSwitcher(
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
                                        colorScheme.onSurface.withValues(
                                          alpha: currentMode == ObsMode.night
                                              ? 0.03
                                              : 0.10,
                                        ),
                                        colorScheme.onSurface.withValues(
                                          alpha: 0.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(
                                isWide ? 20 : AppSpacing.lg,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: overviewAsync.when(
                                data: (overview) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isSuitabilitySample)
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: AppSpacing.sm,
                                          ),
                                          child: SampleMark(),
                                        ),
                                      ),
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
                                            progressColor:
                                                colorScheme.onSurface,
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
                                                                  .onSurface,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.verified,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _StaggerReveal(
                                      controller: _staggerController,
                                      startMs: 100,
                                      child: currentMode == ObsMode.night
                                          ? _NightSkySection(
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
                                            )
                                          : _NightSkyDayLine(
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
                                              // Day/night-meaning accents
                                              // (yellow / lavender), same in
                                              // both themes.
                                              final modeColors =
                                                  LookUpColors.of(context);
                                              final accent = isDay
                                                  ? modeColors.modeDayAccent
                                                  : modeColors.modeNightAccent;
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
                                                                          color: accentText(
                                                                            context,
                                                                            accent,
                                                                          ),
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
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (currentMode == ObsMode.night) ...[
                    _StaggerReveal(
                      controller: _staggerController,
                      startMs: 180,
                      child: ref
                          .watch(tonightSkyForecastProvider)
                          .when(
                            data: (forecast) {
                              final section = TonightSkySection(
                                targets: forecast.allVisibleTargets,
                                isApprox: forecast.degraded,
                              );
                              if (!isStarlightSample) return section;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SampleMark(),
                                  const SizedBox(height: AppSpacing.sm),
                                  section,
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (err, st) => const SizedBox.shrink(),
                          ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ]),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Journey step ①: brings the conditions section into view (jump, no
  /// animation).
  void _showConditions() {
    final target = _conditionsKey.currentContext;
    if (target != null) Scrollable.ensureVisible(target);
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
    final nightAccent = LookUpColors.of(context).modeNightAccent;
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
                color: nightAccent,
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
                  keepAll('오늘의 달 · ${moon.phaseName}'),
                  key: homeMoonTitleKey,
                  semanticsLabel: '오늘의 달 · ${moon.phaseName}',
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
          // Keeps the wrapping title clear of the right-aligned times.
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '월몰 ${moon.moonset ?? '—'}',
                key: homeMoonsetKey,
                style: (textTheme.bodyMedium ?? textTheme.labelMedium)
                    ?.copyWith(
                      color: accentText(context, nightAccent),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '월출 ${moon.moonrise ?? '—'}',
                key: homeMoonriseKey,
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

class _NightSkySection extends StatelessWidget {
  const _NightSkySection({required this.nightSky});

  final NightSky nightSky;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = mapNightSky(
      bortleClass: nightSky.bortleClass,
      status: nightSky.status ?? '',
    );
    // Star-observation icon means night (lavender); the star rating row is
    // neutral grey — only the filled count carries the tier.
    final guideColor = LookUpColors.of(context).modeNightAccent;
    final tierColor = colorScheme.onSurfaceVariant;

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
            child: Icon(
              Icons.auto_awesome,
              size: 28,
              color: display.hasNoData
                  ? colorScheme.outline
                  : display.isApprox
                  ? guideColor.withValues(alpha: 0.6)
                  : guideColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: display.hasNoData
                  ? const [Text('밤하늘 밝기 정보 없음')]
                  : [
                      Text(
                        keepAll('오늘 밤 · ${display.label}'),
                        key: homeNightSkyLabelKey,
                        semanticsLabel: '오늘 밤 · ${display.label}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (display.expectation.isNotEmpty)
                        Text(
                          display.expectation,
                          style: textTheme.bodySmall,
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'SQM ${nightSky.sqmValue.toStringAsFixed(2)} · Bortle ${nightSky.bortleClass}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (display.isApprox) ...[
                            const SizedBox(width: 6),
                            Text('추정치', style: textTheme.labelSmall),
                          ],
                        ],
                      ),
                    ],
            ),
          ),
          if (!display.hasNoData)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final filled = index < display.filledStars;
                    return Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: filled
                          ? (display.isApprox
                                ? tierColor.withValues(alpha: 0.6)
                                : tierColor)
                          : colorScheme.outline.withValues(alpha: 0.3),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                NightSkyInfoButton(nightSky: nightSky),
              ],
            ),
        ],
      ),
    );
  }
}

class _NightSkyDayLine extends StatelessWidget {
  const _NightSkyDayLine({required this.nightSky});

  final NightSky nightSky;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = mapNightSky(
      bortleClass: nightSky.bortleClass,
      status: nightSky.status ?? '',
    );
    final guideColor = LookUpColors.of(context).modeNightAccent;
    final tierColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: display.hasNoData ? colorScheme.outline : guideColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: display.hasNoData
                    ? const [TextSpan(text: '오늘 밤 · 밤하늘 밝기 정보 없음')]
                    : [
                        TextSpan(
                          text:
                              '오늘 밤 · ${display.label} · SQM ${nightSky.sqmValue.toStringAsFixed(2)} · Bortle ${nightSky.bortleClass}',
                        ),
                        if (display.isApprox) ...[
                          const WidgetSpan(child: SizedBox(width: 4)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Text('추정치', style: textTheme.labelSmall),
                          ),
                        ],
                      ],
              ),
              key: const Key('nightSkyDayLineText'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ),
          if (!display.hasNoData) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < 5; index++) ...[
                  if (index > 0) const SizedBox(width: 2),
                  Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: index < display.filledStars
                        ? (display.isApprox
                              ? tierColor.withValues(alpha: 0.6)
                              : tierColor)
                        : colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            NightSkyInfoButton(nightSky: nightSky),
          ],
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
