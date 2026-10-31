import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../widgets/app_icon.dart';

/// One row of the settings list: icon, label and either a chevron or a
/// custom trailing control (language switch, dark mode switch).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.isLast = false,
    this.color,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLast;

  /// Overrides the icon and label colour (used for "Log out").
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: <Widget>[
          AppIcon(icon, color: color ?? pal.sec),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color ?? pal.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (trailing == null && onTap != null) AppIcon(AppIcons.chev, color: pal.sub, flip: true),
        ],
      ),
    );

    return Container(
      decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
      child: onTap == null
          ? row
          : Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(onTap: onTap, child: row),
            ),
    );
  }
}
