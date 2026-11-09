import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/state_view.dart';
import '../routes.dart';
import 'report_detail_screen.dart';

/// List of daily, weekly or monthly health reports. Read-only.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;
    final List<HealthReport> reports = c.repository.reports(c.level, c.reportPeriod);

    return SubPage(
      title: s.t('reportsL'),
      children: <Widget>[
        PillTabs(
          semanticLabel: s.t('repPeriodLbl'),
          labels: <String>[s.t('pDaily'), s.t('pWeekly'), s.t('pMonthly')],
          index: ReportPeriod.values.indexOf(c.reportPeriod),
          onChanged: (int i) => c.setReportPeriod(ReportPeriod.values[i]),
        ),
        const SizedBox(height: CgGap.lg),
        if (reports.isEmpty)
          AppCard(
            child: EmptyState(
              icon: AppIcons.file,
              title: s.t('reportsL'),
              message: s.t('roReport'),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < reports.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: pal.line),
                  Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => pushScreen(context, ReportDetailScreen(report: reports[i])),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CgGap.lg,
                          vertical: CgGap.md,
                        ),
                        child: Row(
                          children: <Widget>[
                            const IconCircle(AppIcons.file, size: 38),
                            const SizedBox(width: CgGap.md + 2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    reports[i].label.of(ar),
                                    style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${s.t('avg')} ${reports[i].average} ${s.t('unit')}',
                                    style: t.labelSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: <Widget>[
                                      StatusPill(
                                        '${reports[i].abnormal} ${s.t('abnShort')}',
                                        pal.high,
                                      ),
                                      StatusPill(
                                        '${reports[i].criticalAlerts} ${s.t('critShort')}',
                                        reports[i].criticalAlerts > 0 ? pal.crit : pal.ok,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: CgGap.xs),
                            AppIcon(AppIcons.chev, size: 22, color: pal.hint, flip: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        LockNote(s.t('roReport')),
      ],
    );
  }
}
