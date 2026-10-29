import 'package:flutter/painting.dart';

/// Arte brand palette (docs/design/arte.md) — for the brand homepage and
/// editorial content only (spec 053 Phase 2, defined ahead of spec 059).
///
/// MUST NOT be wired into `ThemeData` or general app UI; the app follows the
/// Flim monochrome scheme in `AppTheme` plus `LookUpColors`. Respect the
/// contrast limits in docs/design/README.md §4: e.g. [harvestCopper] text on
/// [wheatCream] is only ~2.5:1 (not for body text), and [citronBeam] text is
/// allowed only on dark backgrounds such as [deepMoss].
abstract final class BrandPalette {
  static const Color wheatCream = Color(0xFFE5DCCD);
  static const Color harvestCopper = Color(0xFFAB5700);
  static const Color citronBeam = Color(0xFFE8E359);
  static const Color morningGlory = Color(0xFF7997FF);
  static const Color amberGlow = Color(0xFFD99623);
  static const Color forestFloor = Color(0xFF214534);
  static const Color deepMoss = Color(0xFF103D26);
  static const Color oliveBranch = Color(0xFF568037);
  static const Color slateBloom = Color(0xFF3D549C);
  static const Color coralPetal = Color(0xFFE99686);
}
