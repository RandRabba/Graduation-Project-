import 'package:flutter/material.dart';
import 'api.dart' show ApiException;
import 'l10n.dart';
import 'theme.dart';

/// Change these once to rebrand the whole UI.
const kAppName = 'DMS';
const kSensorName = 'Dexcom G7';
const kAppVersion = '1.0.0';

/// Glucose target range in mg/dL, used by the charts, time in range and level labels.
const kTargetLow = 70, kTargetHigh = 180;

/// Glucose bands. Colour is always shown together with [icon] and a text label.
enum GlucoseLevel {
  veryLow(Icons.keyboard_double_arrow_down_rounded),
  low(Icons.south_rounded),
  inRange(Icons.check_circle_rounded),
  high(Icons.north_rounded),
  veryHigh(Icons.keyboard_double_arrow_up_rounded);

  const GlucoseLevel(this.icon);
  final IconData icon;

  static GlucoseLevel of(double mgdl) => mgdl < 54
      ? veryLow
      : mgdl < kTargetLow
      ? low
      : mgdl <= kTargetHigh
      ? inRange
      : mgdl <= 250
      ? high
      : veryHigh;

  Color color(AppPalette p) => switch (this) {
    veryLow => p.critical,
    low || veryHigh => p.elevated,
    inRange => p.normal,
    high => p.caution,
  };

  String get labelKey => 'level_$name';
}

/// Rounded surface with a hairline border and a soft shadow. Pass [gradient] for a hero card.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.margin = const EdgeInsets.only(bottom: Gap.lg),
    this.gradient,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding, margin;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(Radii.lg);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? p.surface : null,
        gradient: gradient,
        borderRadius: radius,
        border: gradient == null ? Border.all(color: p.border) : null,
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Page title with an optional subtitle and trailing widget.
class PageHeader extends StatelessWidget {
  const PageHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xl),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: Gap.md)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: context.text.headlineMedium),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.text.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Gap.sm), trailing!],
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle, action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.titleMedium),
            ),
            if (subtitle != null)
              Text(subtitle!, style: context.text.labelSmall),
          ],
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(action!),
        ),
    ],
  );
}

/// A label with a big value underneath ("--" until real data arrives).
class Stat extends StatelessWidget {
  const Stat(
    this.label, {
    super.key,
    this.value = '--',
    this.unit,
    this.compact = false,
  });
  final String label;
  final String value;
  final String? unit;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: context.text.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: Gap.xs),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: context.text.titleLarge!.copyWith(
                fontSize: compact ? 19 : 24,
              ),
            ),
            if (unit != null)
              TextSpan(text: ' $unit', style: context.text.labelSmall),
          ],
        ),
      ),
    ],
  );
}

/// Stats side by side, separated by thin vertical lines.
class StatRow extends StatelessWidget {
  const StatRow(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: Gap.md),
              color: context.palette.border,
            ),
          Expanded(child: children[i]),
        ],
      ],
    ),
  );
}

/// A stat on its own tinted tile, with a leading icon.
class StatTile extends StatelessWidget {
  const StatTile(
    this.label,
    this.icon, {
    super.key,
    this.value = '--',
    this.unit,
  });
  final String label;
  final IconData icon;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Gap.md + 2),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.primary),
          const SizedBox(height: Gap.sm),
          Stat(label, value: value, unit: unit, compact: true),
        ],
      ),
    );
  }
}

/// Segmented pill selector (used for 1D/7D/... and Quick/Smart).
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Gap.xs),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
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
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                    decoration: BoxDecoration(
                      color: i == index ? p.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.lg - Gap.xs),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: i == index ? p.onPrimary : p.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.color, this.size = 44});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.withAlpha(32)),
      child: Icon(icon, color: c, size: size * .5),
    );
  }
}

/// Status chip: an icon (or dot) plus a text label, so colour is never the only signal.
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
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withAlpha(36) : color.withAlpha(30),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: fg)
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Soon" tag for features that aren't built yet.
class SoonTag extends StatelessWidget {
  const SoonTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        context.tr('soon'),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.muted,
        ),
      ),
    );
  }
}

/// Big pill-shaped main action. Pass null to disable.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: enabled ? p.cta : null,
          color: enabled ? null : p.border,
          shadows: enabled
              ? [
                  BoxShadow(
                    color: p.ctaEnd.withAlpha(70),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: p.onPrimary,
            disabledForegroundColor: p.muted,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _ButtonLabel(label, icon),
        ),
      ),
    );
  }
}

/// Quieter secondary action.
class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.primarySoft,
          foregroundColor: p.primary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: _ButtonLabel(label, icon),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.label, this.icon);
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 20),
        const SizedBox(width: Gap.sm),
      ],
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// Centered icon, title and message for screens or sections with nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.soon = false,
  });
  final IconData icon;
  final String title, message;
  final bool soon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.lg),
    child: Column(
      children: [
        IconCircle(icon, size: 72),
        const SizedBox(height: Gap.lg),
        Text(
          title,
          style: context.text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          message,
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (soon) ...[const SizedBox(height: Gap.md), const SoonTag()],
      ],
    ),
  );
}

/// The DMS logo: a drop inside a gradient badge.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: context.palette.cta,
      borderRadius: BorderRadius.circular(size * .32),
      boxShadow: [
        BoxShadow(
          color: context.palette.shadow,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(
      Icons.water_drop_rounded,
      color: context.palette.onPrimary,
      size: size * .55,
    ),
  );
}

/// Titled card holding a list of [SettingsTile]s separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          start: Gap.xs,
          bottom: Gap.sm,
        ),
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: context.text.labelMedium!.copyWith(
              color: context.palette.muted,
            ),
          ),
        ),
      ),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: 68),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

/// Settings row: leading icon, title, optional value, trailing arrow (or "Soon" tag).
class SettingsTile extends StatelessWidget {
  const SettingsTile(
    this.icon,
    this.title, {
    super.key,
    this.value,
    this.onTap,
    this.soon = false,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              IconCircle(icon, size: 38),
              const SizedBox(width: Gap.md + 2),
              Expanded(
                child: Text(
                  title,
                  style: context.text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: Gap.sm),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                ),
              if (soon) ...[const SizedBox(width: Gap.sm), const SoonTag()],
              if (onTap != null && !soon) ...[
                const SizedBox(width: Gap.xs),
                Icon(Icons.chevron_right_rounded, color: p.hint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Short message at the bottom of the screen.
void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// What to tell the user about a failed backend call.
String errorText(BuildContext context, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return context.tr('error_network');
    if (error.status >= 500) return context.tr('error_server');
    return error.message; // validation / conflict detail from the server
  }
  return context.tr('error_generic');
}

/// "Mar 4 · 9:30 AM" in the current locale.
String dateTimeLabel(BuildContext context, DateTime t) {
  final loc = MaterialLocalizations.of(context);
  return '${loc.formatShortMonthDay(t)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

String timeLabel(BuildContext context, DateTime t) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(TimeOfDay.fromDateTime(t));

/// Spinner for a screen or section that is still loading.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: Gap.xxl * 2),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Like [EmptyState], for a load that failed, with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.lg),
    child: Column(
      children: [
        IconCircle(
          Icons.cloud_off_rounded,
          size: 72,
          color: context.palette.critical,
        ),
        const SizedBox(height: Gap.lg),
        Text(
          context.tr('load_failed'),
          style: context.text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          message,
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.lg),
        SoftButton(
          context.tr('retry'),
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

/// Inline error line under a form.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.critical.withAlpha(20),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.critical.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: p.critical),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium!.copyWith(color: p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard pushed page: app bar plus a padded scrolling body.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.onRefresh,
    this.controller,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: children,
    );
    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: list),
    );
  }
}
