import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/state_view.dart';
import '../routes.dart';

/// Alerts tab: new alerts first, then history. Basic access shows critical
/// alerts only.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final List<CaregiverAlert> all = c.alerts;
    final List<CaregiverAlert> fresh = all.where((CaregiverAlert a) => !c.isRead(a.id)).toList();
    final List<CaregiverAlert> old = all.where((CaregiverAlert a) => c.isRead(a.id)).toList();

    Widget sectionLabel(String text, double top) => Padding(
          padding: EdgeInsets.only(top: top),
          child: Text(
            text.toUpperCase(),
            style: context.subStyle(11.5, FontWeight.w700).copyWith(letterSpacing: 0.5),
          ),
        );

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: <Widget>[
        ScreenTitle(s.t('tAlerts')),
        if (c.isBasic)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LockNote(s.t('basicAlerts'), center: true),
          ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pal.soft, shape: BoxShape.circle),
                    child: AppIcon(AppIcons.bell, color: pal.sec),
                  ),
                  const SizedBox(height: 12),
                  Text(s.t('noAl_t'), textAlign: TextAlign.center, style: context.hStyle(16)),
                  const SizedBox(height: 4),
                  Text(s.t('noAl_b'), textAlign: TextAlign.center, style: context.subStyle(13)),
                ],
              ),
            ),
          ),
        if (fresh.isNotEmpty) sectionLabel(s.t('newL'), 18),
        for (final CaregiverAlert a in fresh)
          AlertCard(alert: a, unread: true, onTap: () => openAlertDetail(context, a)),
        if (old.isNotEmpty) sectionLabel(s.t('earlier'), 22),
        for (final CaregiverAlert a in old)
          AlertCard(alert: a, unread: false, onTap: () => openAlertDetail(context, a)),
      ],
    );
  }
}
