import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import 'app_icon.dart';

/// Small padlock + muted sentence. Reminds the caregiver that the data is
/// read-only or restricted.
class LockNote extends StatelessWidget {
  const LockNote(this.text, {super.key, this.fontSize = 12.5, this.iconSize = 16, this.center = false});

  final String text;
  final double fontSize;
  final double iconSize;

  /// Vertically centre the icon against a single line of text.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: center ? 0 : 2),
          child: AppIcon(AppIcons.lock, size: iconSize, color: pal.sub),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.subStyle(fontSize))),
      ],
    );
  }
}
