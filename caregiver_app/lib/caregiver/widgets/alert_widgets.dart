import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import 'app_icon.dart';

/// Arrow icon for an alert: down for low, repeat for repeated, up for high.
String alertIconPath(CaregiverAlert a) {
  if (a.isLowSide) return AppIcons.down;
  if (a.kind == AlertKind.repeated) return AppIcons.repeat;
  return AppIcons.up;
}

/// "342 mg/dL", or "3 readings" for repeated abnormal readings.
String alertValueText(CaregiverAlert a, AppStrings s) {
  final int? v = a.value;
  return (v != null && v > 0) ? '$v ${s.t('unit')}' : s.t('rep3');
}

String severityLabel(CaregiverAlert a, AppStrings s) =>
    a.isCritical ? s.t('sevCrit') : s.t('sevWarn');

/// Compact alert row used in "Latest alerts" on the home screen.
class AlertSummaryRow extends StatelessWidget {
  const AlertSummaryRow({super.key, required this.alert, required this.onTap});

  final CaregiverAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final Color fg = pal.fg(alert.tone);
    final Color bg = pal.bgOf(alert.tone);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            IconBox(icon: alertIconPath(alert), fg: fg, bg: bg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.t(alert.titleKey), style: context.hStyle(14)),
                  Text(
                    '${alertValueText(alert, s)} · ${whenLabel(alert.time, s)}',
                    style: context.subStyle(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ToneChip(severityLabel(alert, s), alert.tone),
          ],
        ),
      ),
    );
  }
}

/// Full alert card used in the Alerts tab. Critical alerts get a red outline.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.unread, required this.onTap});

  final CaregiverAlert alert;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final bool crit = alert.isCritical;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        color: crit ? pal.critBg : null,
        borderColor: crit ? pal.crit : null,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ToneChip(severityLabel(alert, s), alert.tone),
                const SizedBox(width: 8),
                Expanded(child: Text(whenLabel(alert.time, s), style: context.subStyle())),
                if (unread)
                  Semantics(
                    label: s.t('newL'),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: pal.sec, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.t(alert.titleKey), style: context.hStyle(15)),
            const SizedBox(height: 2),
            Text(alertValueText(alert, s), style: context.hStyle(22, FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s.t(alert.explKey), style: context.subStyle()),
          ],
        ),
      ),
    );
  }
}
