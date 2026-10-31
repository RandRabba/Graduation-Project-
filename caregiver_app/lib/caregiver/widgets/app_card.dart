import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';

/// Rounded white (or dark navy) card with the soft shadow from the design.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1.5,
    this.radius = 20,
    this.shadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final bool shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: br, child: content);
    }
    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? pal.card,
        borderRadius: br,
        boxShadow: shadow ? pal.shadows : null,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
    if (onTap != null) {
      card = Semantics(button: true, label: semanticLabel, child: card);
    }
    return card;
  }
}

/// Pill-shaped label with custom colours.
class AppChip extends StatelessWidget {
  const AppChip(
    this.label, {
    super.key,
    required this.fg,
    required this.bg,
    this.icon,
    this.iconSize = 14,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  });

  final String label;
  final Color fg;
  final Color bg;
  final String? icon;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            AppIcon(icon!, size: iconSize, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w600, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip coloured by a status [Tone] (ok, controlled, high, low, critical).
class ToneChip extends StatelessWidget {
  const ToneChip(this.label, this.tone, {super.key, this.icon, this.fontSize = 12});

  final String label;
  final Tone tone;
  final String? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AppChip(label, fg: pal.fg(tone), bg: pal.bgOf(tone), icon: icon, fontSize: fontSize);
  }
}

/// Square rounded icon holder used in list rows.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    required this.fg,
    required this.bg,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
  });

  final String icon;
  final Color fg;
  final Color bg;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: AppIcon(icon, color: fg, size: iconSize),
    );
  }
}

/// Round avatar showing initials (the design uses initials in place of photos).
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 52, this.fontSize = 16, this.label});

  final String initials;
  final double size;
  final double fontSize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      image: true,
      label: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.soft, shape: BoxShape.circle),
        child: ExcludeSemantics(
          child: Text(
            initials,
            style: TextStyle(color: pal.pri, fontWeight: FontWeight.w700, fontSize: fontSize),
          ),
        ),
      ),
    );
  }
}
