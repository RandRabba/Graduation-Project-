import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'app_icon.dart';

/// Building blocks that mirror the Patient app's `common.dart`, so the
/// Caregiver screens read as the same product: same spacing, same page header,
/// same pill tabs, same grouped list rows.
///
/// They are re-created here (not imported) because `caregiver_app` is a
/// separate package. If the two apps ever share a package, replace this file
/// with the shared widgets.

/// Spacing scale of the Patient app (`Gap` in `patient_interface/lib/theme.dart`).
abstract final class CgGap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Side padding of every page.
  static const double page = 20;
}

/// Page title with an optional subtitle, leading and trailing widget.
class PageHeader extends StatelessWidget {
  const PageHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: CgGap.sm, bottom: CgGap.xl),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: CgGap.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(header: true, child: Text(title, style: t.headlineMedium)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodyMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: CgGap.sm), trailing!],
        ],
      ),
    );
  }
}

/// A pushed screen: app bar with the title and back arrow, then a scrolling
/// list. Same structure as the Patient app's `SubPage`.
///
/// The bottom safe area is left to the shell, which keeps the navigation bar
/// visible under every sub screen.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.bg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CgGap.page, CgGap.sm, CgGap.page, CgGap.xl),
          children: children,
        ),
      ),
    );
  }
}

/// Small muted heading above a list or group of cards.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: CgGap.xs, bottom: CgGap.sm, top: top),
      child: Semantics(
        header: true,
        child: Text(text, style: t.labelMedium!.copyWith(color: context.pal.sub)),
      ),
    );
  }
}

/// Card title with an optional caption and a text action on the end side.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final pal = context.pal;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(header: true, child: Text(title, style: t.titleMedium)),
              if (subtitle != null) Text(subtitle!, style: t.labelSmall),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: pal.pri,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: CgGap.md),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// Segmented pill selector (Day / Week / Month and similar).
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.semanticLabel,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(CgGap.xs),
        decoration: BoxDecoration(
          color: pal.input,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: pal.line),
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 40,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: CgGap.xs),
                      decoration: BoxDecoration(
                        color: i == index ? pal.pri : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.lg - CgGap.xs),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: i == index ? pal.onPri : pal.sub,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round tinted icon holder used in list rows and empty states.
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.color, this.size = 44});

  /// An [AppIcons] path.
  final String icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? context.pal.pri;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.withAlpha(32)),
      child: AppIcon(icon, color: c, size: size * .5),
    );
  }
}

/// Status chip: an icon (or dot) plus a text label, so colour is never the
/// only signal. Use [onDark] on top of a hero gradient.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label,
    this.color, {
    super.key,
    this.icon,
    this.onDark = false,
  });

  final String label;
  final Color color;

  /// An [AppIcons] path. A dot is drawn when null.
  final String? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color fg = onDark ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CgGap.md, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withAlpha(36) : color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null)
            AppIcon(icon!, size: 16, color: fg)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small caption with a bold value under it, on a tinted tile.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.icon, {super.key, required this.value, this.unit});

  final String label;

  /// An [AppIcons] path.
  final String icon;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(CgGap.md + 2),
      decoration: BoxDecoration(
        color: pal.input,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIcon(icon, size: 20, color: pal.pri),
          const SizedBox(height: CgGap.sm),
          Text(label, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: value, style: t.titleMedium),
                if (unit != null)
                  TextSpan(text: ' $unit', style: t.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped list: a small muted title above one card of [SettingsTile] rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.title, this.children, {super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: CgGap.xs, bottom: CgGap.sm),
          child: Semantics(
            header: true,
            child: Text(title, style: t.labelMedium!.copyWith(color: pal.sub)),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: pal.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Row inside a [SettingsGroup]: round icon, title, optional value and an
/// arrow when it can be opened.
class SettingsTile extends StatelessWidget {
  const SettingsTile(
    this.icon,
    this.title, {
    super.key,
    this.value,
    this.valueColor,
    this.onTap,
    this.iconColor,
    this.trailing,
  });

  /// An [AppIcons] path.
  final String icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  /// Replaces the value and the arrow, for example with a language switch.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final TextTheme t = Theme.of(context).textTheme;
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
        child: Row(
          children: <Widget>[
            IconCircle(icon, size: 38, color: iconColor),
            const SizedBox(width: CgGap.md + 2),
            Expanded(
              child: Text(
                title,
                style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: CgGap.sm),
                child: trailing!,
              )
            else if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: CgGap.sm),
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium!.copyWith(color: valueColor),
                  ),
                ),
              ),
            if (onTap != null && trailing == null) ...<Widget>[
              const SizedBox(width: CgGap.xs),
              AppIcon(AppIcons.chev, size: 22, color: pal.hint, flip: true),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Icon, title and message for a screen or section with nothing to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final String icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgGap.xl, horizontal: CgGap.lg),
      child: Column(
        children: <Widget>[
          IconCircle(icon, size: 72),
          const SizedBox(height: CgGap.lg),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: CgGap.sm),
          Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// The three-colour "time in range" bar: low, in range, high.
class TimeInRangeBar extends StatelessWidget {
  const TimeInRangeBar({
    super.key,
    required this.low,
    required this.inRange,
    required this.high,
  });

  /// Percentages (0 to 100).
  final int low;
  final int inRange;
  final int high;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final List<(int, Color)> segments = <(int, Color)>[
      (low, pal.crit),
      (inRange, pal.ok),
      (high, pal.high),
    ].where(((int, Color) s) => s.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        // Charts and bars read left to right in both languages.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: segments.isEmpty
              ? ColoredBox(color: pal.line, child: const SizedBox.expand())
              : Row(
                  children: <Widget>[
                    for (final (int v, Color c) in segments)
                      Expanded(
                        flex: (v * 10).clamp(1, 1000).toInt(),
                        child: ColoredBox(color: c),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One legend entry under the [TimeInRangeBar].
class RangeLegend extends StatelessWidget {
  const RangeLegend(this.label, this.percent, this.color, this.icon, {super.key});

  final String label;
  final int percent;
  final Color color;

  /// An [AppIcons] path.
  final String icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIcon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$percent%', style: t.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps a glucose class to the colour the Patient app uses for it.
/// Low readings read as critical (red), high readings as caution.
Color glucoseColor(AppPalette pal, GlucoseClass c) {
  switch (c) {
    case GlucoseClass.ok:
      return pal.ok;
    case GlucoseClass.high:
      return pal.high;
    case GlucoseClass.low:
      return pal.low;
    case GlucoseClass.critHigh:
    case GlucoseClass.critLow:
      return pal.crit;
  }
}

/// Icon (an [AppIcons] path) that goes with a glucose class.
String glucoseIcon(GlucoseClass c) {
  switch (c) {
    case GlucoseClass.ok:
      return AppIcons.check;
    case GlucoseClass.high:
    case GlucoseClass.critHigh:
      return AppIcons.up;
    case GlucoseClass.low:
    case GlucoseClass.critLow:
      return AppIcons.down;
  }
}
