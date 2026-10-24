import 'package:flutter/material.dart';

/// Change these once to rebrand the whole UI.
const kAppName = 'Ottai';
const kSensorName = 'Dexcom G7';

class AppColors {
  static const accent = Color(0xFF0B8A5A);
  static const accentDark = Color(0xFF06684A);
  static const accentSoft = Color(0xFFE3F2EA);
  static const bg = Color(0xFFF6F7F5);
  static const line = Color(0xFFE5E9E6);
  static const ink = Color(0xFF15221C);
  static const muted = Color(0xFF6A766F);
  static const hint = Color(0xFFA7B0AA);
  static const low = Color(0xFFE0564A);
  static const high = Color(0xFFF0A020);
}

class AppText {
  static const h1 = TextStyle(
      fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.6, height: 1.15);
  static const h2 = TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.2);
  static const body = TextStyle(fontSize: 16, height: 1.4, color: AppColors.ink);
  static const label = TextStyle(fontSize: 14, color: AppColors.muted);
  static const value =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.4);
}

/// Flat white card with a hairline border (no heavy shadows).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 14),
    this.color = Colors.white,
    this.bordered = true,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding, margin;
  final Color color;
  final bool bordered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: bordered ? Border.all(color: AppColors.line) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: AppText.h2)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ]);
}

/// A label with a big value underneath ("--" until real data arrives).
class Stat extends StatelessWidget {
  const Stat(this.label, {super.key, this.value = '--', this.unit, this.compact = false});
  final String label;
  final String value;
  final String? unit;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: AppText.value.copyWith(fontSize: compact ? 20 : 26)),
            if (unit != null) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ])),
        ],
      );
}

/// Stats side by side, separated by thin vertical lines.
class StatRow extends StatelessWidget {
  const StatRow(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: AppColors.line),
            Expanded(child: children[i]),
          ],
        ]),
      );
}

/// Segmented pill selector (used for 1D/7D/... and Quick/Smart).
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFE9EEEB), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: i == index
                        ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: i == index ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.color = AppColors.accent, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(28)),
        child: Icon(icon, color: color, size: size * .5),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key, this.onDark = false});
  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: onDark ? const Color(0x26FFFFFF) : color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onDark ? Colors.white : color)),
        ]),
      );
}

/// Big pill-shaped main action. Pass null to disable.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.line,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ]),
        ),
      );
}

/// Quieter secondary action.
class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentSoft,
            foregroundColor: AppColors.accentDark,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ]),
        ),
      );
}
