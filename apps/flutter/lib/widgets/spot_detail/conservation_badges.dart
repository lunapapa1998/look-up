import 'package:flutter/material.dart';

import '../../models/species.dart';

/// Small neutral-toned chip row summarizing a species' conservation status
/// (spec 023 Phase 2a). Renders at most one chip per [Conservation] field --
/// national natural monument designation, Korea's own endangered-species
/// grade, then IUCN Red List category -- skipping whichever are null.
/// Deliberately neutral (`surfaceContainerHigh`), never red/orange/error:
/// this is informational metadata, not a warning.
class ConservationBadges extends StatelessWidget {
  const ConservationBadges({super.key, required this.conservation});

  final Conservation conservation;

  static const _iucnLabels = {
    'EN': '위기',
    'VU': '취약',
    'NT': '준위협',
    'LC': '관심대상',
  };

  @override
  Widget build(BuildContext context) {
    final naturalMonument = conservation.naturalMonument;
    final koreaEndangered = conservation.koreaEndangered;
    final iucn = conservation.iucn;

    if (naturalMonument == null && koreaEndangered == null && iucn == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget chip(IconData icon, String label, String semanticLabel) {
      return Semantics(
        label: semanticLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final chips = <Widget>[];
    if (naturalMonument != null) {
      chips.add(
        chip(
          Icons.shield_outlined,
          naturalMonument,
          '천연기념물: $naturalMonument',
        ),
      );
    }
    if (koreaEndangered != null) {
      chips.add(
        chip(
          Icons.info_outline,
          koreaEndangered,
          '국내 멸종위기 등급: $koreaEndangered',
        ),
      );
    }
    if (iucn != null) {
      final label = _iucnLabels[iucn] ?? iucn;
      chips.add(chip(Icons.public, label, 'IUCN 적색목록 등급: $label'));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
