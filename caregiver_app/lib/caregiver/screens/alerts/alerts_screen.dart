import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/state_view.dart';
import '../routes.dart';

/// Alerts tab: new alerts first, then history. Alerts are read-only: opening
/// one only marks it as seen, it never resolves it.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final s = c.strings;
    final List<CaregiverAlert> all = c.alerts;
    final List<CaregiverAlert> fresh = all.where((CaregiverAlert a) => !c.isRead(a.id)).toList();
    final List<CaregiverAlert> old = all.where((CaregiverAlert a) => c.isRead(a.id)).toList();

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(CgGap.page, CgGap.md, CgGap.page, CgGap.xl),
      children: <Widget>[
        PageHeader(
          s.t('tAlerts'),
          subtitle: fresh.isNotEmpty ? '${fresh.length} ${s.t('newL')}' : null,
        ),
        if (all.isEmpty)
          AppCard(
            child: EmptyState(
              icon: AppIcons.bell,
              title: s.t('noAl_t'),
              message: s.t('noAl_b'),
            ),
          ),
        if (fresh.isNotEmpty) GroupLabel(s.t('newL')),
        for (final CaregiverAlert a in fresh)
          AlertCard(alert: a, unread: true, onTap: () => openAlertDetail(context, a)),
        if (old.isNotEmpty) GroupLabel(s.t('earlier'), top: CgGap.xl),
        for (final CaregiverAlert a in old)
          AlertCard(alert: a, unread: false, onTap: () => openAlertDetail(context, a)),
      ],
    );
  }
}
