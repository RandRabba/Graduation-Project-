import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/alert_widgets.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/glucose_chart.dart';
import '../../widgets/latest_reading_hero.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/sheets.dart';
import '../../widgets/state_view.dart';
import '../patient/instructions_screen.dart';
import '../patient/patient_info_screen.dart';
import '../reminders/reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../routes.dart';

/// Home. Same order as the Patient app's Summary tab, read-only:
/// greeting, latest reading (hero), latest alerts, quick access, then the
/// time in range and the glucose curve for the chosen range.
///
/// Left out on purpose because the caregiver cannot act on them: meals, the
/// sensor, the AI assistant and anything that adds or edits data.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final s = c.strings;
    final bool ar = c.arabic;
    final Patient patient = c.repository.patient;

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(CgGap.page, CgGap.md, CgGap.page, CgGap.xl),
      children: <Widget>[
        PageHeader(
          s.t('greet'),
          subtitle: '${s.t('monitoring')} ${patient.name.of(ar)}',
          leading: Semantics(
            button: true,
            label: s.t('ptInfo'),
            excludeSemantics: true,
            onTap: () => pushScreen(context, const PatientInfoScreen()),
            child: GestureDetector(
              onTap: () => pushScreen(context, const PatientInfoScreen()),
              child: Avatar(patient.initials.of(ar), size: 48, fontSize: 16),
            ),
          ),
        ),
        LatestReadingHero(onViewReadings: () => c.selectTab(1)),
        const _LatestAlerts(),
        const _QuickAccess(),
        const _RangeOverview(),
      ],
    );
  }
}

class _LatestAlerts extends StatelessWidget {
  const _LatestAlerts();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final s = c.strings;
    final List<CaregiverAlert> alerts = c.alerts;

    return Padding(
      padding: const EdgeInsets.only(bottom: CgGap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionTitle(
            s.t('latestAlerts'),
            action: s.t('seeAll'),
            onAction: () => c.selectTab(2),
          ),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CgGap.sm),
              child: AppCard(
                padding: const EdgeInsets.all(CgGap.xl),
                child: Column(
                  children: <Widget>[
                    Text(s.t('noAl_t'), textAlign: TextAlign.center, style: context.hStyle(15)),
                    const SizedBox(height: 4),
                    Text(s.t('noAl_b'), textAlign: TextAlign.center, style: context.subStyle(13)),
                  ],
                ),
              ),
            ),
          for (final CaregiverAlert a in alerts.take(2))
            AlertSummaryRow(alert: a, onTap: () => openAlertDetail(context, a)),
        ],
      ),
    );
  }
}

/// Shortcuts to everything the caregiver may open. Read-only destinations.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final Patient patient = c.repository.patient;
    final int unread = c.unreadCount;
    final int upcoming = c.repository
        .reminders(c.level)
        .where((Reminder r) => r.status == ReminderStatus.upcoming)
        .length;

    return SettingsGroup(s.t('quickAccess'), <Widget>[
      SettingsTile(
        AppIcons.bell,
        s.t('tAlerts'),
        value: unread > 0 ? '$unread ${s.t('newL')}' : null,
        onTap: () => c.selectTab(2),
      ),
      SettingsTile(
        AppIcons.clock,
        s.t('remT'),
        value: upcoming > 0 ? '$upcoming ${s.t('rs_upcoming')}' : null,
        onTap: () => pushScreen(context, const RemindersScreen()),
      ),
      SettingsTile(
        AppIcons.syringe,
        s.t('insT'),
        onTap: () => pushScreen(context, const InstructionsScreen()),
      ),
      SettingsTile(
        AppIcons.file,
        s.t('reportsL'),
        onTap: () => pushScreen(context, const ReportsScreen()),
      ),
      SettingsTile(
        AppIcons.user,
        s.t('ptInfo'),
        onTap: () => pushScreen(context, const PatientInfoScreen()),
      ),
      SettingsTile(
        AppIcons.phone,
        s.t('emerg'),
        iconColor: pal.crit,
        value: patient.emergencyContact.name.of(ar),
        onTap: () => showEmergencySheet(context),
      ),
    ]);
  }
}

/// Range tabs, time in range and the glucose curve.
class _RangeOverview extends StatelessWidget {
  const _RangeOverview();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;

    final ChartSeries? series = c.repository.chart(c.level, c.range);
    final RangeStats? stats = c.repository.rangeStats(c.level, c.range);
    final HbA1cRecord? hba = c.repository.hba1c(c.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PillTabs(
          semanticLabel: s.t('rangeLbl'),
          labels: <String>[s.t('rDay'), s.t('rWeek'), s.t('rMonth')],
          index: ChartRange.values.indexOf(c.range),
          onChanged: (int i) => c.setRange(ChartRange.values[i]),
        ),
        const SizedBox(height: CgGap.lg),
        if (stats != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            padding: const EdgeInsets.all(CgGap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(s.t('timeInRange'), subtitle: s.t('target')),
                const SizedBox(height: CgGap.lg),
                TimeInRangeBar(
                  low: stats.lowPercent,
                  inRange: stats.inRangePercent,
                  high: stats.highPercent,
                ),
                const SizedBox(height: CgGap.md + 2),
                Row(
                  children: <Widget>[
                    RangeLegend(s.t('c_low'), stats.lowPercent, pal.crit, AppIcons.down),
                    RangeLegend(s.t('c_ok'), stats.inRangePercent, pal.ok, AppIcons.check),
                    RangeLegend(s.t('c_high'), stats.highPercent, pal.high, AppIcons.up),
                  ],
                ),
                const SizedBox(height: CgGap.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        s.t('hba1c'),
                        AppIcons.drop,
                        value: hba == null ? '--' : hba.percent.toStringAsFixed(1),
                        unit: '%',
                      ),
                    ),
                    const SizedBox(width: CgGap.md),
                    Expanded(
                      child: StatTile(
                        s.t('avg'),
                        AppIcons.chart,
                        value: '${stats.average}',
                        unit: s.t('unit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CgGap.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        s.t('highest'),
                        AppIcons.up,
                        value: '${stats.highest}',
                        unit: s.t('unit'),
                      ),
                    ),
                    const SizedBox(width: CgGap.md),
                    Expanded(
                      child: StatTile(
                        s.t('lowest'),
                        AppIcons.down,
                        value: '${stats.lowest}',
                        unit: s.t('unit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (series != null && stats != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            padding: const EdgeInsets.all(CgGap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SectionTitle(
                  s.t('curve'),
                  action: s.t('tRead'),
                  onAction: () => c.selectTab(1),
                ),
                const SizedBox(height: CgGap.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${s.t('readingsN')}: ${stats.count}',
                        style: t.labelSmall,
                      ),
                    ),
                    const SizedBox(width: CgGap.sm),
                    Flexible(
                      child: AppChip(stats.trend.of(ar), fg: pal.pri, bg: pal.soft),
                    ),
                  ],
                ),
                const SizedBox(height: CgGap.md),
                GlucoseChart(
                  values: series.values,
                  height: 150,
                  semanticLabel: s.t('chartAlt'),
                ),
                ChartLabels(series.labels.map((LocalizedText l) => l.of(ar)).toList()),
              ],
            ),
          ),
      ],
    );
  }
}
