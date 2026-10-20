import 'package:flutter/material.dart';

/// Change this once to rebrand the whole UI.
const kAppName = 'Ottai';

class AppColors {
  static const blue = Color(0xFF3B6EFF);
  static const sky = Color(0xFF5AA2FF);
  static const teal = Color(0xFF2FC4D8);
  static const mint = Color(0xFF2CC6A4);
  static const coral = Color(0xFFF2674F);
  static const amber = Color(0xFFF5A623);
  static const violet = Color(0xFF7C6CF0);
  static const page = Color(0xFFF3F6FB);
  static const tile = Color(0xFFF5F7FB);
  static const ink = Color(0xFF1B2333);
  static const muted = Color(0xFF6B7385);
  static const inactive = Color(0xFFB4BAC6);
  static const rangeBlue = Color(0xFFEAF2FF);
}

const brandGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [AppColors.teal, AppColors.blue],
);

const softShadow = [
  BoxShadow(color: Color(0x143B6EFF), blurRadius: 24, offset: Offset(0, 8)),
];

/// Rounded square icon on a softly tinted background.
class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, this.color, {super.key, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(32),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: color, size: size * .55),
      );
}

/// White rounded card with an icon, a title and an optional trailing widget.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accent = AppColors.blue,
    this.trailing,
  });
  final String title;
  final Widget child;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              IconBubble(icon!, accent, size: 38),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

/// Soft grey tile with a label and a value ("--" until real data arrives).
class StatTile extends StatelessWidget {
  const StatTile(
    this.label, {
    super.key,
    this.value = '--',
    this.unit,
    this.icon,
    this.color = AppColors.blue,
    this.info = false,
  });
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color color;
  final bool info;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.tile, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              IconBubble(icon!, color, size: 26),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted)),
            ),
            if (info)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.inactive),
              ),
          ]),
          const SizedBox(height: 10),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            if (unit != null)
              TextSpan(text: ' $unit', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ])),
        ]),
      );
}

/// A row of equally wide tiles.
Widget tileRow(List<Widget> tiles) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ]),
    );

/// Full-width gradient call-to-action button.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x553B6EFF), blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}