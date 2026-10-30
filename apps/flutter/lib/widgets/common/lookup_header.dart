import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/layout_tokens.dart';
import '../app_header_logo.dart';

/// Unified brand header (spec 054-3b): logo + title/subtitle on the leading
/// side, an optional mode toggle and optional trailing actions.
///
/// Provider-independent: the header never watches providers; callers pass
/// e.g. `modeToggle: const ObsModeToggle()` and actions (IconButtons with
/// their own tooltips/semantics).
///
/// Visual: matches [AppSliverHeader] (logo 32 + [AppSpacing.sm] + title
/// `titleMedium` / subtitle `labelSmall` in `colorScheme.onSurfaceVariant` with
/// letterSpacing 1.1), flat background = the theme's app bar background
/// (`appBarTheme.backgroundColor ?? colorScheme.surface`), no shadow, no
/// outer margin. The bar's own horizontal inset is [horizontalPadding].
///
/// Adaptive layout, decided at layout time from real intrinsic sizes (so
/// text scaling is accounted for):
/// - With a toggle: one row `[leading] ... [toggle][actions]` only when the
///   width is at least [oneRowMinWidth] AND
///   `leadingMin + gap + toggleMaxIntrinsicWidth + gap + actionsWidth` fits
///   the inner width. `leadingMin` = logo 32 + 8 + max([minTitleWidth],
///   measured width of the title's first two characters + '…' in the
///   title style at the current text scale). Otherwise two rows:
///   row 1 `[leading (ellipsis)][actions]`, row 2 `[toggle]` left-aligned
///   with [AppSpacing.sm] bottom padding.
/// - Without a toggle: always one row; the title ellipsizes.
/// - If the toggle alone is wider than the inner width (extreme text
///   scale) it is scaled down by a `FittedBox(BoxFit.scaleDown)`; at normal
///   scales the FittedBox is a no-op.
/// - Heights grow with content: row 1 is at least [toolbarHeight].
///
/// Accessibility: the title is a `header` semantics node, the logo is
/// excluded and the subtitle is decorative (excluded). Focus traversal is
/// geometric reading order inside the header, so one row = toggle then
/// actions, two rows = actions (row 1) then toggle (row 2).
///
/// Not applied to any screen yet (specs 055/058).
class LookUpHeader extends StatelessWidget {
  const LookUpHeader({
    super.key,
    this.title = '위를 봐요',
    this.subtitle = 'LOOK UP',
    this.modeToggle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? modeToggle;
  final List<Widget> actions;

  static const Key backgroundKey = Key('lookup_header_background');
  static const Key leadingKey = Key('lookup_header_leading');
  static const Key titleKey = Key('lookup_header_title');
  static const Key subtitleKey = Key('lookup_header_subtitle');
  static const Key toggleSlotKey = Key('lookup_header_toggle_slot');
  static const Key actionsKey = Key('lookup_header_actions');

  /// Minimum height of the first row (same as AppSliverHeader's toolbar).
  static const double toolbarHeight = 64;

  /// The bar's own horizontal inset (not a page gutter).
  static const double horizontalPadding = 16;

  /// Below this width a header with a toggle always uses two rows.
  static const double oneRowMinWidth = 480;

  /// Floor of the title's minimum width in the one-row decision.
  static const double minTitleWidth = 48;

  /// The header background: what a SliverAppBar would paint with the
  /// current theme. Shared by [LookUpHeader] and [LookUpSliverHeader].
  static Color backgroundColorOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final titleStyle = text.titleMedium;
    final subtitleText = subtitle;

    final leading = Row(
      key: leadingKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppHeaderLogo(excludeFromSemantics: true),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  title,
                  key: titleKey,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (subtitleText != null)
                ExcludeSemantics(
                  child: Text(
                    subtitleText,
                    key: subtitleKey,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final toggle = modeToggle;
    return Material(
      key: backgroundKey,
      color: backgroundColorOf(context),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      animationDuration: Duration.zero,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: _HeaderLayout(
          title: title,
          titleStyle: titleStyle,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          leading: leading,
          toggle: toggle == null
              ? null
              : FittedBox(
                  key: toggleSlotKey,
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: toggle,
                ),
          actions: actions.isEmpty
              ? null
              : Row(
                  key: actionsKey,
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
        ),
      ),
    );
  }
}

/// Sliver version of [LookUpHeader] (spec 054-3b), replacing the
/// `SliverAppBar(primary: false, floating: true, snap: true, pinned: false)`
/// behavior of [AppSliverHeader]: scrolls away with the content, floats back
/// in on scroll-up and snaps fully open (overlay) when the gesture ends.
///
/// Uses [SliverFloatingHeader], which sizes itself to its child, so the
/// two-row height needs no precomputation, and adds no status-bar padding
/// (same as `primary: false`). The snap is instant when animations are
/// disabled (MediaQuery.disableAnimations).
class LookUpSliverHeader extends StatelessWidget {
  const LookUpSliverHeader({
    super.key,
    this.title = '위를 봐요',
    this.subtitle = 'LOOK UP',
    this.modeToggle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? modeToggle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SliverFloatingHeader(
      snapMode: FloatingHeaderSnapMode.overlay,
      animationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
      child: LookUpHeader(
        title: title,
        subtitle: subtitle,
        modeToggle: modeToggle,
        actions: actions,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

enum _Slot { leading, toggle, actions }

/// Lays out [leading], optional [toggle] and optional [actions] in one or two
/// rows, decided from the children's measured intrinsic widths.
class _HeaderLayout
    extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _HeaderLayout({
    required this.title,
    required this.titleStyle,
    required this.textScaler,
    required this.textDirection,
    required this.leading,
    required this.toggle,
    required this.actions,
  });

  final String title;
  final TextStyle? titleStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Widget leading;
  final Widget? toggle;
  final Widget? actions;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) {
    return switch (slot) {
      _Slot.leading => leading,
      _Slot.toggle => toggle,
      _Slot.actions => actions,
    };
  }

  @override
  _RenderHeaderLayout createRenderObject(BuildContext context) {
    return _RenderHeaderLayout(title, titleStyle, textScaler, textDirection);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeaderLayout renderObject,
  ) {
    renderObject
      ..title = title
      ..titleStyle = titleStyle
      ..textScaler = textScaler
      ..textDirection = textDirection;
  }
}

typedef _HeaderGeometry = ({
  Size size,
  bool twoRows,
  Offset leading,
  Offset toggle,
  Offset actions,
});

class _RenderHeaderLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderHeaderLayout(
    this._title,
    this._titleStyle,
    this._textScaler,
    this._textDirection,
  );

  static const double _hPad = LookUpHeader.horizontalPadding;

  /// Logo (32) + gap between logo and title.
  static const double _logoAndGap = 32 + AppSpacing.sm;

  /// Gap between the leading block and the trailing group.
  static const double _leadGap = AppSpacing.md;

  /// Gap between the toggle and the actions.
  static const double _gap = AppSpacing.sm;

  String _title;
  set title(String value) {
    if (value == _title) return;
    _title = value;
    _leadingMinCache = null;
    markNeedsLayout();
  }

  TextStyle? _titleStyle;
  set titleStyle(TextStyle? value) {
    if (value == _titleStyle) return;
    _titleStyle = value;
    _leadingMinCache = null;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _leadingMinCache = null;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _leadingMinCache = null;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_Slot.leading);
  RenderBox? get _toggle => childForSlot(_Slot.toggle);
  RenderBox? get _actions => childForSlot(_Slot.actions);

  double? _leadingMinCache;

  /// Logo + gap + max(48, width of the title's first two characters + '…'
  /// measured in the title style at the current text scale).
  double get _leadingMinWidth {
    final cached = _leadingMinCache;
    if (cached != null) return cached;
    final chars = _title.characters;
    final probe = chars.length > 2 ? '${chars.take(2)}…' : _title;
    final painter = TextPainter(
      text: TextSpan(text: probe, style: _titleStyle),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return _leadingMinCache =
        _logoAndGap + math.max(LookUpHeader.minTitleWidth, width);
  }

  bool _twoRowsFor(double width) {
    final toggle = _toggle;
    if (toggle == null) return false;
    if (width < LookUpHeader.oneRowMinWidth) return true;
    final inner = width - 2 * _hPad;
    final actions = _actions;
    final need =
        _leadingMinWidth +
        _leadGap +
        toggle.getMaxIntrinsicWidth(double.infinity) +
        (actions == null
            ? 0
            : _gap + actions.getMaxIntrinsicWidth(double.infinity));
    return need > inner;
  }

  _HeaderGeometry _computeLayout(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final leading = _leading!;
    final toggle = _toggle;
    final actions = _actions;

    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(computeMaxIntrinsicWidth(double.infinity));
    final inner = math.max(0.0, width - 2 * _hPad);
    final twoRows = _twoRowsFor(width);

    final actionsSize = actions == null
        ? Size.zero
        : layoutChild(actions, BoxConstraints(maxWidth: inner));

    var trailing = actionsSize.width;
    var toggleSize = Size.zero;
    if (toggle != null) {
      if (twoRows) {
        toggleSize = layoutChild(toggle, BoxConstraints(maxWidth: inner));
      } else {
        final room = math.max(
          0.0,
          inner -
              _leadingMinWidth -
              _leadGap -
              (actions == null ? 0 : actionsSize.width + _gap),
        );
        toggleSize = layoutChild(toggle, BoxConstraints(maxWidth: room));
        trailing += toggleSize.width + (actions == null ? 0 : _gap);
      }
    }

    final leadMax = math.max(
      0.0,
      inner - (trailing > 0 ? trailing + _leadGap : 0),
    );
    final leadingSize = layoutChild(
      leading,
      BoxConstraints(maxWidth: leadMax),
    );

    var row1 = math.max(LookUpHeader.toolbarHeight, leadingSize.height);
    row1 = math.max(row1, actionsSize.height);
    if (toggle != null && !twoRows) {
      row1 = math.max(row1, toggleSize.height);
    }
    final height = twoRows
        ? row1 + toggleSize.height + AppSpacing.sm
        : row1;
    final size = constraints.constrain(Size(width, height));

    Offset at(double x, double y, Size child) => Offset(
      _textDirection == TextDirection.rtl ? size.width - x - child.width : x,
      y,
    );

    final leadingOffset = at(
      _hPad,
      (row1 - leadingSize.height) / 2,
      leadingSize,
    );
    final actionsOffset = at(
      size.width - _hPad - actionsSize.width,
      (row1 - actionsSize.height) / 2,
      actionsSize,
    );
    final Offset toggleOffset;
    if (twoRows) {
      toggleOffset = at(_hPad, row1, toggleSize);
    } else {
      toggleOffset = at(
        size.width -
            _hPad -
            (actions == null ? 0 : actionsSize.width + _gap) -
            toggleSize.width,
        (row1 - toggleSize.height) / 2,
        toggleSize,
      );
    }

    return (
      size: size,
      twoRows: twoRows,
      leading: leadingOffset,
      toggle: toggleOffset,
      actions: actionsOffset,
    );
  }

  @override
  void performLayout() {
    final geometry = _computeLayout(constraints, ChildLayoutHelper.layoutChild);
    size = geometry.size;
    void place(RenderBox? child, Offset offset) {
      if (child == null) return;
      (child.parentData! as BoxParentData).offset = offset;
    }

    place(_leading, geometry.leading);
    place(_toggle, geometry.toggle);
    place(_actions, geometry.actions);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _computeLayout(constraints, ChildLayoutHelper.dryLayoutChild).size;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final actions = _actions?.getMaxIntrinsicWidth(double.infinity);
    // The toggle can wrap to row 2 (and scale down), so it does not count.
    return 2 * _hPad +
        _leadingMinWidth +
        (actions == null ? 0 : _leadGap + actions);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final leading = _leading?.getMaxIntrinsicWidth(double.infinity) ?? 0;
    final toggle = _toggle?.getMaxIntrinsicWidth(double.infinity);
    final actions = _actions?.getMaxIntrinsicWidth(double.infinity);
    final trailing =
        (toggle ?? 0) +
        (actions ?? 0) +
        (toggle != null && actions != null ? _gap : 0);
    final natural =
        2 * _hPad + leading + (trailing > 0 ? _leadGap + trailing : 0);
    // A one-row header with a toggle needs at least [oneRowMinWidth].
    return toggle == null
        ? natural
        : math.max(natural, LookUpHeader.oneRowMinWidth);
  }

  double _intrinsicHeight(double width) {
    final leading = _leading;
    if (leading == null) return 0;
    final toggle = _toggle;
    final actions = _actions;
    var row1 = math.max(
      LookUpHeader.toolbarHeight,
      leading.getMaxIntrinsicHeight(double.infinity),
    );
    if (actions != null) {
      row1 = math.max(row1, actions.getMaxIntrinsicHeight(double.infinity));
    }
    if (toggle == null) return row1;
    final toggleHeight = toggle.getMaxIntrinsicHeight(double.infinity);
    final twoRows = width.isFinite && _twoRowsFor(width);
    return twoRows
        ? row1 + toggleHeight + AppSpacing.sm
        : math.max(row1, toggleHeight);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, offset + parentData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
