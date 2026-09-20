import 'package:flutter/widgets.dart';

/// Shared brand mark shown at the top-right of each primary tab.
class AppHeaderLogo extends StatelessWidget {
  const AppHeaderLogo({super.key, this.excludeFromSemantics = false});

  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: excludeFromSemantics ? null : '위를 봐요 로고',
      image: !excludeFromSemantics,
      excludeSemantics: excludeFromSemantics,
      child: Image.asset(
        'assets/packages/logo.png',
        width: 32,
        height: 32,
        excludeFromSemantics: true,
      ),
    );
  }
}
