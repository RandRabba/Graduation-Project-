import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'dashed_border.dart';

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

/// "Not shared by the patient" inline line with a padlock (patient info rows).
class NotSharedLine extends StatelessWidget {
  const NotSharedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          AppIcon(AppIcons.lock, size: 15, color: pal.sub),
          const SizedBox(width: 6),
          Expanded(child: Text(context.s.t('notShared'), style: context.subStyle(13))),
        ],
      ),
    );
  }
}

/// Dashed "Not shared with you" card with a link to the privacy screen.
class RestrictedCard extends StatelessWidget {
  const RestrictedCard({super.key, required this.onPrivacy});

  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    return DashedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconBox(icon: AppIcons.lock, fg: pal.sec, bg: pal.soft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.t('restr_t'), style: context.hStyle(14)),
                const SizedBox(height: 2),
                Text(s.t('restr_hist'), style: context.subStyle(13)),
                const SizedBox(height: 4),
                TextLinkButton(s.t('privTitle'), onPressed: onPrivacy, fontSize: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
