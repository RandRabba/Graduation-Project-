import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/patient_style.dart';

/// Plain-language list of what the caregiver can see. Everything here is
/// read-only, and the patient controls what is shared.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final TextTheme t = Theme.of(context).textTheme;

    const List<String> can = <String>[
      'pv_name',
      'pv_latest',
      'pv_status',
      'pv_crit',
      'pv_emerg',
      'pv_hist',
      'pv_rep',
      'pv_rem',
      'pv_ins',
    ];

    return SubPage(
      title: s.t('privTitle'),
      children: <Widget>[
        AppCard(
          color: pal.soft,
          shadow: false,
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AppIcon(AppIcons.shield, color: pal.pri),
              ),
              const SizedBox(width: CgGap.md),
              Expanded(child: Text(s.t('privIntro'), style: t.bodyLarge)),
            ],
          ),
        ),
        GroupLabel(s.t('privCan')),
        AppCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < can.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 52, color: pal.line),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
                  child: Row(
                    children: <Widget>[
                      AppIcon(AppIcons.check, color: pal.ok),
                      const SizedBox(width: CgGap.md),
                      Expanded(child: Text(s.t(can[i]), style: t.bodyLarge)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        LockNote(s.t('pv_never')),
      ],
    );
  }
}
