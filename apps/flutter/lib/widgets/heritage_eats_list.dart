import 'package:flutter/material.dart';

import '../models/trails.dart';
import '../utils/trail_format.dart';

/// Read-only list of nearby heritage restaurants for the course-detail
/// screen. Renders nothing when [eats] is empty — the caller decides
/// whether to show this section at all. Rows are not tappable: there is
/// no onTap callback and no navigation/detail-push behavior.
class HeritageEatsList extends StatelessWidget {
  const HeritageEatsList({super.key, required this.eats});

  final List<HeritageEat> eats;

  @override
  Widget build(BuildContext context) {
    if (eats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < eats.length; i++) ...[
          _HeritageEatRow(eat: eats[i]),
          if (i < eats.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HeritageEatRow extends StatelessWidget {
  const _HeritageEatRow({required this.eat});

  final HeritageEat eat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eat.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  eat.addr,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatDistanceM(eat.distanceM),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
