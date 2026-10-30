import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Small section label above a title (spec 054-2a).
///
/// Latin/number-only text uses the Flim mono label style
/// ([AppTheme.monoLabel]: uppercase, 0.06em tracking) and keeps the original
/// text as the semantics label so screen readers do not spell out capitals.
/// Any Hangul switches to `labelMedium` w600 with the theme's own
/// labelMedium letter spacing (Material default): no uppercase transform
/// and no tracking override (spec 054 invariant). Color defaults to
/// `onSurfaceVariant`.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key, this.color});

  final String text;

  /// Overrides the default `onSurfaceVariant` text color.
  final Color? color;

  static final RegExp _hangul = RegExp(r'[가-힣ㄱ-ㆎ]');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.onSurfaceVariant;

    if (_hangul.hasMatch(text)) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: resolvedColor,
        ),
      );
    }

    return Text(
      text.toUpperCase(),
      semanticsLabel: text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.monoLabel(theme).copyWith(color: resolvedColor),
    );
  }
}
