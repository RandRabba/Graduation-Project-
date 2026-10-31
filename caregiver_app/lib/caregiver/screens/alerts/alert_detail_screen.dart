import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/sheets.dart';
import '../../widgets/state_view.dart';

/// Details of one alert: what happened, the related reading and generic
/// safety guidance. Opening an alert never marks it as resolved.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;

    CaregiverAlert? alert;
    for (final CaregiverAlert a in c.alerts) {
      if (a.id == alertId) alert = a;
    }

    if (alert == null) {
      return PageFrame(
        children: <Widget>[
          const BackRow(),
          const SizedBox(height: 16),
          AppCard(
            child: Text(s.t('notVis'), textAlign: TextAlign.center, style: context.subStyle(13.5)),
          ),
        ],
      );
    }

    final CaregiverAlert a = alert;
    final GlucoseReading? reading = c.repository.readingForAlert(a);
    final bool crit = a.isCritical;
    final bool showEmergency = crit || a.kind == AlertKind.low;

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: crit ? pal.critBg : pal.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: crit ? pal.crit : pal.line, width: crit ? 2 : 1),
            boxShadow: crit ? null : pal.shadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (crit)
                    AppChip(
                      severityLabel(a, s),
                      fg: Colors.white,
                      bg: AppPalette.alertRed,
                      icon: alertIconPath(a),
                    )
                  else
                    ToneChip(severityLabel(a, s), a.tone, icon: alertIconPath(a)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(whenLabel(a.time, s), style: context.subStyle())),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(header: true, child: Text(s.t(a.titleKey), style: context.hStyle(22))),
              const SizedBox(height: 4),
              Text(
                alertValueText(a, s),
                style: context.hStyle(34, FontWeight.w800).copyWith(height: 1.15),
              ),
              const SizedBox(height: 6),
              Text(s.t(a.explKey), style: context.bodyStyle(13.5)),
            ],
          ),
        ),
        if (reading != null) ...<Widget>[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(s.t('dRelated'), style: context.subStyle(12.5, FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '${reading.value}',
                      style: context.hStyle(30, FontWeight.w800).copyWith(height: 1),
                    ),
                    const SizedBox(width: 8),
                    Text(s.t('unit'), style: context.subStyle()),
                    const Spacer(),
                    ToneChip(classLabel(reading.cls, s), reading.cls.tone),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                  child: ColumnGrid(
                    gap: 10,
                    children: <Widget>[
                      LabeledValue(label: s.t('rtype'), value: s.t(reading.type.key)),
                      LabeledValue(label: s.t('rsrc'), value: s.t(reading.source.key)),
                      LabeledValue(label: s.t('rtime'), value: whenLabel(reading.time, s)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('dWhat'), style: context.subStyle(12.5, FontWeight.w700)),
              const SizedBox(height: 6),
              Text(s.t(a.detailKey), style: context.bodyStyle()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          color: pal.soft,
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppIcon(AppIcons.shield, color: pal.pri),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('dGuide'),
                      style: TextStyle(color: pal.pri, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(s.t(crit ? 'g_crit' : 'g_warn'), style: context.bodyStyle()),
              const SizedBox(height: 8),
              Text(s.t('g_disc'), style: context.subStyle()),
            ],
          ),
        ),
        if (showEmergency) ...<Widget>[
          const SizedBox(height: 14),
          EmergencyButton(
            label: s.t('emerg'),
            solid: true,
            onPressed: () => showEmergencySheet(context),
          ),
        ],
        const SizedBox(height: 14),
        LockNote(s.t('resolveNote')),
      ],
    );
  }
}
