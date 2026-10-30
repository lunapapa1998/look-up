import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// [MaterialScrollBehavior] plus plain mouse drag (spec 054-2d).
///
/// On web/desktop Flutter's default behavior ignores mouse drags, so a
/// horizontal chip row wider than the viewport can only be scrolled with
/// Shift+wheel or a trackpad. This behavior adds [PointerDeviceKind.mouse] to
/// [dragDevices] and inherits everything else (scrollbars, Shift+wheel via
/// `pointerAxisModifiers`, trackpad, touch, stylus).
///
/// Apply it ONLY locally, via `ScrollConfiguration` wrapped directly around a
/// horizontal chip/filter `SingleChildScrollView` whose subtree contains
/// nothing but the chip row. Never register it globally
/// (`MaterialApp.scrollBehavior`): that would make vertical pages, the
/// observation map's DraggableScrollableSheet and text fields
/// mouse-draggable, fighting text selection and map panning.
///
/// Call sites (054-2d):
/// - `screens/observation_map_screen.dart` — map layer chips
/// - `screens/packages_catalog_screen.dart` — package category filter
/// - `screens/trails_catalog_screen.dart` — trail region filter
/// - `widgets/observation_spot_sheet.dart` — sheet sort/SQM filter chips
class LookUpScrollBehavior extends MaterialScrollBehavior {
  const LookUpScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
