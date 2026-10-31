import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// Scrollable page with the standard 20px gutters.
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

/// "< Back" row at the top of sub screens.
class BackRow extends StatelessWidget {
  const BackRow({super.key, this.onTap});

  /// Defaults to popping the current route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final label = context.s.t('back');
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppIcon(AppIcons.back, color: pal.sec, flip: true),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: pal.sec, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 22px bold page title.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: context.hStyle(22)),
    );
  }
}

/// Section title with an optional "See all" style link on the end side.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.linkLabel, this.onLink});

  final String title;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.hStyle(15)),
            ),
          ),
          if (linkLabel != null) TextLinkButton(linkLabel!, onPressed: onLink, fontSize: 13),
        ],
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

/// Thin divider line used inside cards.
class LineDivider extends StatelessWidget {
  const LineDivider({super.key, this.vertical = 12});

  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: Container(height: 1, color: context.pal.line),
    );
  }
}
