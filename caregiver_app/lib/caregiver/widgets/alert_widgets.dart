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

/// One colour per severity, so the list reads at a glance: critical is red,
/// a warning is orange (the Patient palette's `elevated`).
Color severityColor(AppPalette pal, CaregiverAlert a) => a.isCritical ? pal.crit : pal.low;

/// Severity pill: tinted background, coloured text, and a glyph so it does not
/// rely on colour alone.
class SeverityChip extends StatelessWidget {
  const SeverityChip(this.alert, {super.key});

  final CaregiverAlert alert;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final Color fg = severityColor(pal, alert);
    return AppChip(
      severityLabel(alert, context.s),
      fg: fg,
      bg: fg.withAlpha(30),
      icon: alert.isCritical ? AppIcons.alert : null,
    );
  }
}

/// Compact alert row used in "Latest alerts" on the home screen.
class AlertSummaryRow extends StatelessWidget {
  const AlertSummaryRow({super.key, required this.alert, required this.onTap});

  final CaregiverAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final Color fg = severityColor(pal, alert);
    final Color bg = fg.withAlpha(30);
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
            SeverityChip(alert),
          ],
        ),
      ),
    );
  }
}

/// Full notification card used in the Notifications tab. The severity shows as
/// a soft tint and a coloured bar on the leading edge, not as a heavy outline.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.unread, required this.onTap});

  final CaregiverAlert alert;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final Color fg = severityColor(pal, alert);
    final Color tint = Color.alphaBlend(fg.withAlpha(alert.isCritical ? 26 : 16), pal.card);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        color: tint,
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 5, color: fg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SeverityChip(alert),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(whenLabel(alert.time, s), style: context.subStyle()),
                          ),
                          if (unread) ...<Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: pal.pri, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              s.t('newL'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: pal.pri,
                              ),
                            ),
                          ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
