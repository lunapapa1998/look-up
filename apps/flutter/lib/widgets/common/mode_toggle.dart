import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/discovery.dart' show ObsMode;
import '../../state/discovery_providers.dart';
import '../../theme/layout_tokens.dart';
import '../../theme/lookup_colors.dart';

/// Day/night observation-mode toggle (spec 054-3a).
///
/// A two-segment group [낮][밤] plus a separate '자동' button. Pure
/// presentational: no Riverpod, no haptics (the app root fires the haptic
/// once per accepted manual change, spec 060), no animations. Flat, no
/// shadow, no outer margin.
///
/// - Selected segment: ModeToggle-only accent fill from [LookUpColors]
///   (day `modeDayAccent` #9CA3F5, night `modeNightAccent` #F4C247, the
///   same in both themes) with dark `onMode*Accent` (#141414) text/icon
///   w700 (7.87:1 / 11.10:1); no border. Selection = fill + w700 +
///   semantics. Known limitation (user decision, no border): on the white
///   day page the fill is only ~2.34:1 / ~1.66:1, below the 3:1 non-text
///   target; on the night page (#141414) it is 7.87:1 / 11.10:1.
///   Unselected: transparent, `onSurface` w500 text, `onSurfaceVariant`
///   icon. Exposed as `selected` + `inMutuallyExclusiveGroup` semantics.
/// - '자동': filled inverted mono (`onSurface` bg, `surface` fg) when
///   [source] is auto ("active"), outlined when manual ("available").
///   Tapping always calls [onAutoSelected].
/// - Every control is an [InkWell] (hover, focus, Enter/Space), at least
///   44x44, with a visible two-tone focus ring (2px `onSurface` outside,
///   2px `surface` inside) while focused.
///
/// Not applied to any screen yet (specs 055/058).
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    super.key,
    required this.mode,
    required this.source,
    required this.onModeSelected,
    required this.onAutoSelected,
  });

  final ObsMode mode;
  final ObsModeSource source;

  /// Day/night segment tap.
  final ValueChanged<ObsMode> onModeSelected;

  /// Explicit '자동' button tap (idempotent when already auto).
  final VoidCallback onAutoSelected;

  static const Key groupKey = Key('mode_toggle_group');
  static const Key dayKey = Key('mode_toggle_day');
  static const Key nightKey = Key('mode_toggle_night');
  static const Key autoKey = Key('mode_toggle_auto');

  /// Present only while the control it belongs to is focused.
  static const Key focusRingKey = Key('mode_toggle_focus_ring');

  /// Minimum touch target of each control.
  static const double minTarget = 44;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAuto = source == ObsModeSource.auto;

    final group = Semantics(
      container: true,
      label: '관찰 모드',
      child: Container(
        key: groupKey,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button - 1),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _segment(context, ObsMode.day),
                SizedBox(width: 1, child: ColoredBox(color: scheme.outline)),
                _segment(context, ObsMode.night),
              ],
            ),
          ),
        ),
      ),
    );

    final autoButton = Semantics(
      container: true,
      button: true,
      selected: isAuto,
      label: isAuto ? '자동 모드 켜짐' : '자동 모드로 돌아가기',
      hint: '시간에 따라 낮·밤이 자동으로 바뀝니다',
      child: _ToggleControl(
        materialKey: autoKey,
        icon: Icons.schedule,
        text: '자동',
        background: isAuto ? scheme.onSurface : Colors.transparent,
        foreground: isAuto ? scheme.surface : scheme.onSurface,
        iconColor: isAuto ? scheme.surface : scheme.onSurface,
        bold: isAuto,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: isAuto
              ? BorderSide.none
              : BorderSide(color: scheme.outline, width: 1),
        ),
        radius: AppRadius.button,
        onTap: onAutoSelected,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [group, const SizedBox(width: AppSpacing.sm), autoButton],
    );
  }

  Widget _segment(BuildContext context, ObsMode segmentMode) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LookUpColors.of(context);
    final selected = segmentMode == mode;
    final isDay = segmentMode == ObsMode.day;
    final fill = isDay ? colors.modeDayAccent : colors.modeNightAccent;
    final onFill = isDay ? colors.onModeDayAccent : colors.onModeNightAccent;
    final String hint;
    if (selected) {
      hint = source == ObsModeSource.auto ? '자동으로 선택됨' : '직접 선택됨';
    } else {
      hint = '눌러서 직접 선택';
    }

    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: isDay ? '낮 모드' : '밤 모드',
      hint: hint,
      child: _ToggleControl(
        materialKey: isDay ? dayKey : nightKey,
        icon: isDay ? Icons.light_mode : Icons.nightlight_round,
        text: isDay ? '낮' : '밤',
        background: selected ? fill : Colors.transparent,
        foreground: selected ? onFill : scheme.onSurface,
        iconColor: selected ? onFill : scheme.onSurfaceVariant,
        bold: selected,
        // Plain shape, no border, selected or not (user decision).
        shape: const RoundedRectangleBorder(),
        // Inside the group's clip (radius - 1px border).
        radius: AppRadius.button - 1,
        onTap: () => onModeSelected(segmentMode),
      ),
    );
  }
}

/// One focusable control: flat [Material] fill + [InkWell] + icon/text,
/// with a two-tone focus ring painted over it while focused.
class _ToggleControl extends StatefulWidget {
  const _ToggleControl({
    required this.materialKey,
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    required this.iconColor,
    required this.bold,
    required this.shape,
    required this.radius,
    required this.onTap,
  });

  final Key materialKey;
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final Color iconColor;
  final bool bold;
  final ShapeBorder shape;
  final double radius;
  final VoidCallback onTap;

  @override
  State<_ToggleControl> createState() => _ToggleControlState();
}

class _ToggleControlState extends State<_ToggleControl> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ringRadius = BorderRadius.circular(widget.radius);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: ModeToggle.minTarget,
        minHeight: ModeToggle.minTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: widget.iconColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: theme.textTheme.labelLarge?.copyWith(
                color: widget.foreground,
                fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      key: widget.materialKey,
      color: widget.background,
      shape: widget.shape,
      clipBehavior: Clip.antiAlias,
      // No implicit animations (reduce-motion safe by construction).
      animationDuration: Duration.zero,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) {
          if (focused != _focused) setState(() => _focused = focused);
        },
        borderRadius: ringRadius,
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.center,
            children: [
              content,
              if (_focused) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: ModeToggle.focusRingKey,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.onSurface, width: 2),
                        borderRadius: ringRadius,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  left: 2,
                  top: 2,
                  right: 2,
                  bottom: 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.surface, width: 2),
                        borderRadius: BorderRadius.circular(
                          widget.radius > 2 ? widget.radius - 2 : 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [ModeToggle] bound to [obsModeProvider] (spec 054-3a). Day/night taps
/// call [ObsModeController.setManual]; '자동' calls
/// [ObsModeController.resetToAuto]. The scene transition and haptic are
/// handled by the app root listening to [obsModeProvider].
class ObsModeToggle extends ConsumerWidget {
  const ObsModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(obsModeProvider);
    return ModeToggle(
      mode: state.mode,
      source: state.source,
      onModeSelected: (m) => ref.read(obsModeProvider.notifier).setManual(m),
      onAutoSelected: () => ref.read(obsModeProvider.notifier).resetToAuto(),
    );
  }
}
