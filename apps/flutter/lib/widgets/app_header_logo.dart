import 'package:flutter/widgets.dart';

/// Shared brand mark shown at the top-right of each primary tab.
class AppHeaderLogo extends StatelessWidget {
  const AppHeaderLogo({super.key, this.excludeFromSemantics = false});

  /// Brand mark asset: the approved app icon's 128x128 UI copy.
  static const String assetPath = 'assets/brand/app_icon_ui.png';

  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: excludeFromSemantics ? null : '위를 봐요 로고',
      image: !excludeFromSemantics,
      excludeSemantics: excludeFromSemantics,
      // Approved app icon (128x128 UI copy), rounded like the launcher icon.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          assetPath,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
