import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';

/// Filled primary button (navy in light mode, cyan in dark mode).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background,
    this.foreground,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color? background;
  final Color? foreground;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = foreground ?? pal.onPri;
    final br = BorderRadius.circular(14);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background ?? pal.pri,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    AppIcon(icon!, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined button. Pass [color] for a coloured outline (for example red for
/// destructive actions or the secondary colour for edit actions).
class OutlineAppButton extends StatelessWidget {
  const OutlineAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.background,
    this.minHeight = 52,
    this.borderWidth = 1.5,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final Color? color;
  final Color? background;
  final double minHeight;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = color ?? pal.text;
    final br = BorderRadius.circular(14);
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: br,
          border: Border.all(color: color ?? pal.inputBorder, width: borderWidth),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      AppIcon(icon!, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text-only link button in the secondary colour.
class TextLinkButton extends StatelessWidget {
  const TextLinkButton(this.label, {super.key, required this.onPressed, this.color, this.fontSize = 14});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: TextStyle(color: color ?? pal.sec, fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width red "Emergency contact" button used on Home and Patient info.
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.solid = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Solid red (used inside critical alert details) instead of the tinted style.
  final bool solid;

  /// Slightly smaller variant used inside the patient information card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = solid ? Colors.white : pal.crit;
    final br = BorderRadius.circular(compact ? 14 : 16);
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: solid ? AppPalette.alertRed : pal.critBg,
          borderRadius: br,
          border: solid ? null : Border.all(color: pal.crit, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 46 : 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AppIcon(AppIcons.phone, color: fg),
                    SizedBox(width: compact ? 8 : 10),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
