import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/text_styles.dart';

/// Scrollable page with the standard 20px gutters (the Patient app's page padding).
///
/// Inside the shell the bottom navigation bar already handles the bottom
/// safe area, so [bottomSafe] stays false there. Auth screens set it to true.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.bottomSafe = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool bottomSafe;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: SafeArea(
        bottom: bottomSafe,
        child: SingleChildScrollView(
          padding: padding,
          child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
        ),
      ),
    );
  }
}

/// Small muted label above a bold value.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.valueSize = 14,
    this.labelSize = 12.5,
    this.ltrValue = false,
  });

  final String label;
  final String value;
  final double valueSize;
  final double labelSize;

  /// Force left-to-right text for phone numbers and times.
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.subStyle(labelSize)),
        Text(
          value,
          textDirection: ltrValue ? TextDirection.ltr : null,
          style: context.hStyle(valueSize),
        ),
      ],
    );
  }
}

/// Lays children out in equal-width columns (the prototype's CSS grid).
class ColumnGrid extends StatelessWidget {
  const ColumnGrid({super.key, required this.children, this.columns = 2, this.gap = 12});

  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final List<Widget> cells = <Widget>[];
      for (int j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        final int idx = i + j;
        cells.add(Expanded(child: idx < children.length ? children[idx] : const SizedBox.shrink()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
    }
    return Column(children: rows);
  }
}
