import 'package:flutter/material.dart';

import '../theme/layout_tokens.dart';
import 'app_header_logo.dart';

/// Brand header for the scrolling catalog tabs (발견, 낮-밤 패키지).
///
/// Rendered as a [SliverAppBar] so it scrolls away with the page content and
/// snaps back into view on scroll-up, instead of staying pinned to the top.
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      // The notch/status-bar band is kept fixed by the SafeArea(top: true)
      // wrapping the scroll view, so this bar must not also reserve/paint the
      // status bar area — otherwise content scrolls under the notch.
      primary: false,
      floating: true,
      snap: true,
      pinned: false,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      title: Row(
        children: [
          const AppHeaderLogo(),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('위를 봐요', style: text.titleMedium),
              Text(
                'LOOK UP',
                style: text.labelSmall?.copyWith(
                  color: colors.secondary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
