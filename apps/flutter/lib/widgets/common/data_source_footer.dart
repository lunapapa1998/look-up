import 'package:flutter/material.dart';

import '../../theme/layout_tokens.dart';

/// One data provider credited by [DataSourceFooter] (spec 054-2b).
///
/// [name], [url] and [attribution] are rendered separately: the attribution
/// (license/credit notice) is its own line and is never merged into the
/// name. There is no default license text.
@immutable
class DataSource {
  const DataSource({required this.name, this.url, this.attribution});

  /// Display name, e.g. '기상청'.
  final String name;

  /// Optional link to the provider. Never invent one.
  final Uri? url;

  /// License/credit notice text, only when verified by the caller.
  final String? attribution;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSource &&
          other.name == name &&
          other.url == url &&
          other.attribution == attribution;

  @override
  int get hashCode => Object.hash(name, url, attribution);

  @override
  String toString() => 'DataSource($name, $url, $attribution)';
}

/// Trims and collapses inner whitespace (display form of a source name).
String _displayName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Removes blank names and duplicates (trim + collapsed whitespace +
/// lowercase); the first occurrence wins and keeps its url/attribution.
List<DataSource> dedupeDataSources(Iterable<DataSource> sources) {
  final seen = <String>{};
  final result = <DataSource>[];
  for (final source in sources) {
    final display = _displayName(source.name);
    if (display.isEmpty) continue;
    if (seen.add(display.toLowerCase())) result.add(source);
  }
  return result;
}

/// Collapsible "데이터 출처" footer (spec 054-2b).
///
/// Pass ONLY the sources the screen actually uses; never a fixed global
/// list. Per-source notice/license requirements (eBird, Wikipedia,
/// VIIRS/World Atlas, the KTO 공공누리 type, etc.) are UNVERIFIED and must be
/// reviewed before this is applied to a screen; do not invent URLs or
/// license text.
///
/// Collapsed: header "데이터 출처 · N" + one-line preview of the names.
/// Expanded: one row per source; a row is a link (underline + open-in-new
/// icon, focusable) only when it has a [DataSource.url] AND [onOpenSource]
/// is set — the caller opens the link (no url_launcher dependency).
///
/// Not yet applied to any screen (specs 055/058). Adds no outer margin or
/// page gutter.
class DataSourceFooter extends StatefulWidget {
  const DataSourceFooter({
    super.key,
    required this.sources,
    this.initiallyExpanded = false,
    this.onOpenSource,
  });

  final List<DataSource> sources;
  final bool initiallyExpanded;

  /// Called with the tapped source; the caller opens [DataSource.url].
  final ValueChanged<DataSource>? onOpenSource;

  static const Key rootKey = Key('data_source_footer');
  static const Key toggleKey = Key('data_source_footer_toggle');

  @override
  State<DataSourceFooter> createState() => _DataSourceFooterState();
}

class _DataSourceFooterState extends State<DataSourceFooter> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final sources = dedupeDataSources(widget.sources);
    if (sources.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = sources.length;
    final preview = sources.map((s) => _displayName(s.name)).join(' · ');

    final header = Semantics(
      container: true,
      button: true,
      expanded: _expanded,
      label: '데이터 출처 $count개',
      value: _expanded ? null : preview,
      hint: _expanded ? '접기' : '펼치기',
      child: InkWell(
        key: DataSourceFooter.toggleKey,
        onTap: _toggle,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '데이터 출처',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '· $count',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (!_expanded)
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Widget details = _expanded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [for (final s in sources) _sourceRow(s, theme)],
          )
        : const SizedBox(width: double.infinity);

    return Column(
      key: DataSourceFooter.rootKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (reduceMotion)
          details
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: details,
          ),
      ],
    );
  }

  Widget _sourceRow(DataSource source, ThemeData theme) {
    final scheme = theme.colorScheme;
    final name = _displayName(source.name);
    final nameStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface,
    );
    final onOpen = widget.onOpenSource;
    final attribution = source.attribution?.trim();

    final Widget nameWidget;
    if (source.url != null && onOpen != null) {
      nameWidget = Semantics(
        container: true,
        link: true,
        child: InkWell(
          onTap: () => onOpen(source),
          borderRadius: BorderRadius.circular(AppRadius.link),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: nameStyle?.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      nameWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(name, style: nameStyle),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        nameWidget,
        if (attribution != null && attribution.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              attribution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
