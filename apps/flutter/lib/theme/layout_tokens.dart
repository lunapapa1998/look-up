import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Shared layout values aligned with the app's Figma spacing scale, extended
/// with the Flim spacing steps (40/52/64/80) in spec 053 Phase 3.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Fixed page padding. Will be replaced by [AppLayout.pageInsets] in
  /// spec 055.
  static const page = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const x40 = 40.0;
  static const x52 = 52.0;
  static const x64 = 64.0;
  static const x80 = 80.0;
}

/// Corner radius scale (spec 053 Phase 3). Role tokens ([link], [button],
/// [card], [pill]) are preferred for new code; [md] is kept unchanged until
/// its call sites are reclassified in spec 055.
abstract final class AppRadius {
  static const sm = 4.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Inline links / tiny tags.
  static const link = 4.0;

  /// Buttons (FilledButton default shape).
  static const button = 8.0;

  /// Cards (CardTheme default shape).
  static const card = 16.0;

  /// Fully rounded stadium for small chips/badges.
  static const pill = 999.0;

  /// Keeps the pre-053 shape of the packages notice bar (height > 40);
  /// reclassify in 055.
  static const legacyBar = 20.0;
}

/// Window-width breakpoints for responsive layout (spec 053 Phase 3).
abstract final class AppBreakpoints {
  /// Widths at or below this are "narrow" phones.
  static const narrowMax = 360.0;

  /// Widths at or above this are "medium" (large phones landscape, tablets).
  static const mediumMin = 600.0;

  /// Widths at or above this are "expanded" (desktop/web).
  static const expandedMin = 1024.0;
}

/// Responsive page layout helpers (spec 053 Phase 3; applied to screens in
/// spec 055).
abstract final class AppLayout {
  /// Max width of page content and card grids.
  static const maxContentWidth = 1120.0;

  /// Max width of long body text. Apply left-aligned (do not center) so the
  /// text keeps the same start line as titles and cards.
  static const maxReadingWidth = 680.0;

  /// Horizontal page gutter for a window of [width]: 20 up to 360, 24 below
  /// 600, linear 32 -> 40 across [600, 1024), and 40 from 1024.
  static double pageGutter(double width) {
    if (width <= AppBreakpoints.narrowMax) return 20;
    if (width < AppBreakpoints.mediumMin) return 24;
    if (width >= AppBreakpoints.expandedMin) return 40;
    final t =
        (width - AppBreakpoints.mediumMin) /
        (AppBreakpoints.expandedMin - AppBreakpoints.mediumMin);
    return (32 + t * 8).clamp(32.0, 40.0).toDouble();
  }

  /// The ONLY horizontal page padding a screen applies at its root (one
  /// padding, no extra Center/ConstrainedBox); cards and children must not
  /// add outer page padding. Content is capped at [maxContentWidth] by
  /// growing the side insets. Vertical is 0.
  ///
  /// Does NOT include safe-area insets: screens using this sit inside
  /// Scaffold/SafeArea as today. For content floating over full-bleed
  /// surfaces use [overlayInsets] instead.
  static EdgeInsets pageInsets(double width) {
    final horizontal = math.max(
      pageGutter(width),
      (width - maxContentWidth) / 2,
    );
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  /// [pageInsets] for the current MediaQuery width.
  static EdgeInsets pageInsetsOf(BuildContext context) =>
      pageInsets(MediaQuery.sizeOf(context).width);

  /// Insets for controls/text floating over full-bleed content (e.g. the
  /// map): [pageInsets] horizontally plus [viewPadding] on every side.
  ///
  /// Includes the safe area itself, so it must NOT be combined with
  /// SafeArea or another MediaQuery padding. Responsibility split:
  /// [pageInsets] = no safe area; [overlayInsets] = safe area included
  /// exactly once.
  static EdgeInsets overlayInsets(double width, EdgeInsets viewPadding) {
    final page = pageInsets(width);
    return EdgeInsets.fromLTRB(
      page.left + viewPadding.left,
      viewPadding.top,
      page.right + viewPadding.right,
      viewPadding.bottom,
    );
  }

  /// [overlayInsets] for the current MediaQuery width and view padding.
  static EdgeInsets overlayInsetsOf(BuildContext context) => overlayInsets(
    MediaQuery.sizeOf(context).width,
    MediaQuery.viewPaddingOf(context),
  );
}
