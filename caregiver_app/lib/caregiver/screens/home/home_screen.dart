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
import '../../widgets/glucose_chart.dart';
import '../../widgets/latest_glucose_card.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/sheets.dart';
import '../../widgets/state_view.dart';
import '../patient/instructions_screen.dart';
import '../patient/patient_info_screen.dart';
import '../reminders/reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../routes.dart';

/// Home dashboard: patient, latest reading, emergency contact, latest alerts
/// and (Extended only) trend, upcoming reminders and doctor instructions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final s = c.strings;
    final List<CaregiverAlert> alerts = c.alerts;
    final bool ext = c.isExtended;

    return PageFrame(
      padding: const EdgeInsets.only(bottom: 24),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _HomeHeader(),
        const _PatientCard(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: LatestGlucoseCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: EmergencyButton(
            label: s.t('emerg'),
            onPressed: () => showEmergencySheet(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHeader(
                title: s.t('latestAlerts'),
                linkLabel: s.t('seeAll'),
                onLink: () => c.selectTab(2),
              ),
              if (alerts.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      Text(s.t('noAl_t'), textAlign: TextAlign.center, style: context.hStyle(14)),
                      const SizedBox(height: 4),
                      Text(s.t('noAl_b'), textAlign: TextAlign.center, style: context.subStyle()),
                    ],
                  ),
                ),
              for (final CaregiverAlert a in alerts.take(2))
                AlertSummaryRow(alert: a, onTap: () => openAlertDetail(context, a)),
              if (ext) const _ExtendedSections(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final int unread = c.unreadCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${s.t('greet')} · ${s.t('dateStr')}', style: context.subStyle()),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(c.profileName(c.arabic), style: context.hStyle(22)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: unread > 0 ? '${s.t('bellLabel')}, $unread' : s.t('bellLabel'),
            excludeSemantics: true,
            onTap: () => c.selectTab(2),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.card,
                    shape: BoxShape.circle,
                    boxShadow: pal.shadows,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => c.selectTab(2),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Center(child: AppIcon(AppIcons.bell, color: pal.text)),
                      ),
                    ),
                  ),
                ),
                if (unread > 0)
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.alertRed,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final Patient p = c.repository.patient;
    final bool ar = c.arabic;

    final Tone statusTone;
    final String statusKey;
    switch (p.status) {
      case PatientStatus.normal:
        statusTone = Tone.ok;
        statusKey = 'stNormal';
        break;
      case PatientStatus.controlled:
        statusTone = Tone.ctl;
        statusKey = 'stCtl';
        break;
      case PatientStatus.critical:
        statusTone = Tone.crit;
        statusKey = 'stCrit';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Avatar(p.initials.of(ar), label: s.t('avatarAlt')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.t('monitoring'), style: context.subStyle()),
                      Text(p.name.of(ar), style: context.hStyle(17)),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: s.t('ptInfo'),
                  excludeSemantics: true,
                  onTap: () => pushScreen(context, const PatientInfoScreen()),
                  child: InkResponse(
                    onTap: () => pushScreen(context, const PatientInfoScreen()),
                    radius: 24,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: AppIcon(AppIcons.chev, color: pal.sub, flip: true)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                AppChip(
                  c.isExtended ? s.t('lvExt') : s.t('lvBasic'),
                  fg: pal.sec,
                  bg: pal.soft,
                  icon: AppIcons.shield,
                ),
                ToneChip('${s.t('ptStatus')}: ${s.t(statusKey)}', statusTone),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything below "Latest alerts" that only Extended monitoring may see.
class _ExtendedSections extends StatelessWidget {
  const _ExtendedSections();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;

    final ChartSeries? week = c.repository.chart(c.level, ChartRange.week);
    final List<Reminder> upcoming = c.repository
        .reminders(c.level)
        .where((Reminder r) => r.status == ReminderStatus.upcoming)
        .take(2)
        .toList();
    final List<DoctorInstruction> instructions = c.repository.instructions(c.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (week != null) ...<Widget>[
          SectionHeader(
            title: s.t('trend'),
            linkLabel: s.t('tRead'),
            onLink: () => c.selectTab(1),
          ),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GlucoseChart(
                  values: week.values,
                  height: 70,
                  dotDiameter: 7,
                  semanticLabel: s.t('chartAlt'),
                ),
                const SizedBox(height: 6),
                Text(s.t('trendWeek'), style: context.subStyle()),
              ],
            ),
          ),
        ],
        SectionHeader(
          title: s.t('upNext'),
          linkLabel: s.t('seeAll'),
          onLink: () => pushScreen(context, const RemindersScreen()),
        ),
        for (final Reminder r in upcoming)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  IconBox(icon: reminderIcon(r.type), fg: pal.sec, bg: pal.soft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(r.name.of(ar), style: context.hStyle(14)),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '⁦${r.time}⁩',
                              ),
                              TextSpan(text: ' · ${s.t(reminderRepeatKey(r.repeat))}'),
                            ],
                          ),
                          style: context.subStyle(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  reminderStatusChip(context, r.status),
                ],
              ),
            ),
          ),
        SectionHeader(
          title: s.t('insT'),
          linkLabel: s.t('seeAll'),
          onLink: () => pushScreen(context, const InstructionsScreen()),
        ),
        if (instructions.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(instructions.first.title.of(ar), style: context.hStyle(14)),
                const SizedBox(height: 4),
                Text(instructions.first.body.of(ar), style: context.bodyStyle(13.5)),
                const SizedBox(height: 8),
                Text(
                  '${s.t('sharedBy')} ${instructions.first.doctor.of(ar)} · '
                  '${monthDay(instructions.first.sharedOn, s)}',
                  style: context.subStyle(),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => pushScreen(context, const ReportsScreen()),
            child: Row(
              children: <Widget>[
                IconBox(icon: AppIcons.file, fg: pal.sec, bg: pal.soft),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t('reportsL'), style: context.hStyle(14))),
                AppIcon(AppIcons.chev, color: pal.sub, flip: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
