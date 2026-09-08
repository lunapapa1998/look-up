import 'package:flutter/material.dart';

import '../models/discovery.dart';
import '../state/discovery_providers.dart';

/// Day/night mode header control, meant to be embedded twice in the home
/// screen app bar: once in the expanded flexible space (`collapsed: false`)
/// and once in the thin pinned bar (`collapsed: true`).
///
/// Plain, dependency-free widget: no `ref.watch`/Riverpod inside — all state
/// comes from [state]/[collapsed], all side effects go through
/// [onModeChanged]/[onResetToAuto].
class ModeHeader extends StatefulWidget {
  const ModeHeader({
    super.key,
    required this.state,
    required this.collapsed,
    required this.onModeChanged,
    required this.onResetToAuto,
  });

  final ObsModeState state;
  final bool collapsed;
  final ValueChanged<ObsMode> onModeChanged;
  final VoidCallback onResetToAuto;

  @override
  State<ModeHeader> createState() => _ModeHeaderState();
}

class _ModeHeaderState extends State<ModeHeader> {
  bool _hasShownManualHint = false;

  @override
  void didUpdateWidget(covariant ModeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasShownManualHint &&
        oldWidget.state.source == ObsModeSource.auto &&
        widget.state.source == ObsModeSource.manual) {
      _hasShownManualHint = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final collapsed = widget.collapsed;
    final isDayActive = widget.state.mode == ObsMode.day;

    final toggles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleSegment(
          key: ValueKey(
            collapsed ? 'modeToggleDayCollapsed' : 'modeToggleDayExpanded',
          ),
          icon: Icons.light_mode,
          label: '낮',
          active: isDayActive,
          collapsed: collapsed,
          semanticsLabel: '낮 모드로 전환합니다',
          onTap: () => widget.onModeChanged(ObsMode.day),
        ),
        const SizedBox(width: 8),
        _ToggleSegment(
          key: ValueKey(
            collapsed ? 'modeToggleNightCollapsed' : 'modeToggleNightExpanded',
          ),
          icon: Icons.nightlight_round,
          label: '밤',
          active: !isDayActive,
          collapsed: collapsed,
          semanticsLabel: '밤 모드로 전환합니다',
          onTap: () => widget.onModeChanged(ObsMode.night),
        ),
        if (collapsed && widget.state.source == ObsModeSource.manual) ...[
          const SizedBox(width: 6),
          _buildManualDot(colorScheme),
        ],
      ],
    );

    if (collapsed) {
      return toggles;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            toggles,
            const SizedBox(width: 12),
            _buildBadge(colorScheme),
          ],
        ),
        if (_hasShownManualHint) _buildManualHint(colorScheme),
      ],
    );
  }

  Widget _buildManualDot(ColorScheme colorScheme) {
    return Semantics(
      label: '수동 모드 사용 중입니다',
      container: true,
      excludeSemantics: true,
      child: Container(
        key: const Key('modeManualDotCollapsed'),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildBadge(ColorScheme colorScheme) {
    if (widget.state.source == ObsModeSource.auto) {
      return Semantics(
        label: '자동 모드입니다',
        container: true,
        excludeSemantics: true,
        child: Container(
          key: const Key('modeSourceBadgeAuto'),
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
      onTap: widget.onResetToAuto,
      child: GestureDetector(
        key: const Key('modeSourceBadgeManual'),
        onTap: widget.onResetToAuto,
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

  Widget _buildManualHint(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'MANUAL 배지를 탭하면 자동 모드로 돌아갑니다.',
        key: const Key('modeManualHint'),
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Single tappable day/night toggle segment. Active state is signalled with
/// more than color alone (WCAG 1.4.1): filled background + bold weight when
/// expanded, accent underline + bold weight when collapsed.
class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool collapsed;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fontWeight = active ? FontWeight.bold : FontWeight.normal;
    final foreground = active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: collapsed ? 16 : 20, color: foreground),
        Text(
          label,
          style: TextStyle(fontWeight: fontWeight, fontSize: collapsed ? 11 : 13, color: foreground),
        ),
      ],
    );

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: active,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: collapsed
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? colorScheme.secondary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                )
              : BoxDecoration(
                  color: active ? colorScheme.surfaceContainerHighest : null,
                  borderRadius: BorderRadius.circular(8),
                ),
          child: content,
        ),
      ),
    );
  }
}
