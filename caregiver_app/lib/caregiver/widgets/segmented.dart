import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label);

  final T value;
  final String label;
}

/// Full-width (or compact) segmented control. The selected segment is filled
/// with the primary colour. Used for date range, report period and language.
class SegmentedBar<T> extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
    this.compact = false,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  /// Small variant used inside list rows (language switcher).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final double outer = compact ? 10 : 14;
    final double inner = compact ? 8 : 10;
    final double pad = compact ? 3 : 4;
    final double gap = compact ? 3 : 4;

    final List<Widget> kids = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      final SegmentOption<T> o = options[i];
      if (i > 0) kids.add(SizedBox(width: gap));
      final Widget seg = _Segment(
        label: o.label,
        selected: o.value == selected,
        radius: inner,
        minHeight: compact ? 36 : 40,
        fontSize: compact ? 13 : 13.5,
        horizontal: compact ? 12 : 4,
        stretch: !compact,
        onTap: () => onChanged(o.value),
      );
      kids.add(compact ? seg : Expanded(child: seg));
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: compact ? pal.bg : pal.card,
          borderRadius: BorderRadius.circular(outer),
          boxShadow: compact ? null : pal.shadows,
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: kids,
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.radius,
    required this.minHeight,
    required this.fontSize,
    required this.horizontal,
    required this.stretch,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double radius;
  final double minHeight;
  final double fontSize;
  final double horizontal;
  final bool stretch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? pal.pri : pal.card,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Center(
                widthFactor: stretch ? null : 1,
                heightFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: selected ? pal.onPri : pal.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapping row of pill-shaped single-choice filters (reading type, source).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.outlined = false,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Adds a thin border so pills stay visible on a card-coloured background.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final SegmentOption<T> o in options)
          _Pill(
            label: o.label,
            selected: o.value == selected,
            outlined: outlined,
            palette: pal,
            onTap: () => onChanged(o.value),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.outlined,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool outlined;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: pal.shadows,
          border: outlined ? Border.all(color: selected ? pal.pri : pal.line) : null,
        ),
        child: Material(
          color: selected ? pal.pri : pal.card,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? pal.onPri : pal.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
