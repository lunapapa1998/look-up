import 'package:flutter/material.dart';

import '../models/starlight_forecast.dart';

const int _previewCount = 3;

IconData _iconForTargetType(String targetType) {
  switch (targetType) {
    case 'milky_way':
      return Icons.blur_on;
    case 'constellation':
      return Icons.star_border;
    case 'cluster':
      return Icons.scatter_plot;
    case 'star':
      return Icons.star;
    default:
      return Icons.auto_awesome;
  }
}

String _altitudeTier(double altitudeDeg) {
  if (altitudeDeg < 30) return '지평선 근처';
  if (altitudeDeg < 60) return '중간 높이';
  return '머리 위 가까이';
}

String _directionAltitudeLine(StarlightTarget target) {
  return '${target.direction} 하늘, ${_altitudeTier(target.altitudeDeg)}';
}

String _observationPillLabel(String observationMode) {
  if (observationMode.contains('망원경')) return '망원경';
  if (observationMode.contains('쌍안경')) return '쌍안경';
  if (observationMode.contains('육안')) return '맨눈';
  return observationMode;
}

/// Compact night-mode-only "오늘 밤 보이는 하늘" list, shown on the home
/// discovery screen. Takes an already-fetched, already-sorted target list so
/// it stays a pure presentation widget with no provider/ref access.
class TonightSkySection extends StatefulWidget {
  const TonightSkySection({
    super.key,
    required this.targets,
    this.isApprox = false,
  });

  final List<StarlightTarget> targets;
  final bool isApprox;

  @override
  State<TonightSkySection> createState() => _TonightSkySectionState();
}

class _TonightSkySectionState extends State<TonightSkySection> {
  bool _expanded = false;
  final Set<String> _expandedRowIds = {};

  void _toggleRow(String id) {
    setState(() {
      if (_expandedRowIds.contains(id)) {
        _expandedRowIds.remove(id);
      } else {
        _expandedRowIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final targets = widget.targets;
    final visibleTargets = _expanded || targets.length <= _previewCount
        ? targets
        : targets.take(_previewCount).toList();
    final remaining = targets.length - _previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TONIGHT'S SKY",
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.secondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        if (widget.isApprox)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('오늘 이 자리에서 보이는 하늘', style: textTheme.headlineSmall),
              const SizedBox(width: 6),
              Text('추정치', style: textTheme.labelSmall),
            ],
          )
        else
          Text('오늘 이 자리에서 보이는 하늘', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (targets.isEmpty)
          Text(
            '오늘 밤은 또렷이 보이는 대상이 적어요',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (var i = 0; i < visibleTargets.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _TonightSkyRow(
                target: visibleTargets[i],
                expanded: _expandedRowIds.contains(visibleTargets[i].id),
                onTap: () => _toggleRow(visibleTargets[i].id),
              ),
            ),
          if (!_expanded && remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  '$remaining개 더 보기',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TonightSkyRow extends StatelessWidget {
  const _TonightSkyRow({
    required this.target,
    required this.expanded,
    required this.onTap,
  });

  final StarlightTarget target;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final directionAltitudeLine = _directionAltitudeLine(target);
    final pillLabel = _observationPillLabel(target.observationMode);

    return Semantics(
      label: '${target.name}, $directionAltitudeLine, $pillLabel 관측',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 27,
                    child: Icon(
                      _iconForTargetType(target.targetType),
                      color: colorScheme.secondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.name,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          directionAltitudeLine,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      pillLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 35),
                  child: Text(
                    target.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
