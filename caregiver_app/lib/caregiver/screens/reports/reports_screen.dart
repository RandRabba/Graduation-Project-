import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/segmented.dart';
import '../../widgets/state_view.dart';
import '../patient/restricted_screen.dart';
import '../routes.dart';
import 'report_detail_screen.dart';

/// List of daily, weekly or monthly health reports. Extended access only.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();
    if (c.isBasic) return const RestrictedScreen();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final List<HealthReport> reports = c.repository.reports(c.level, c.reportPeriod);

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('reportsL')),
        const SizedBox(height: 14),
        SegmentedBar<ReportPeriod>(
          semanticLabel: s.t('repPeriodLbl'),
          options: <SegmentOption<ReportPeriod>>[
            SegmentOption<ReportPeriod>(ReportPeriod.daily, s.t('pDaily')),
            SegmentOption<ReportPeriod>(ReportPeriod.weekly, s.t('pWeekly')),
            SegmentOption<ReportPeriod>(ReportPeriod.monthly, s.t('pMonthly')),
          ],
          selected: c.reportPeriod,
          onChanged: c.setReportPeriod,
        ),
        for (final HealthReport r in reports)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              onTap: () => pushScreen(context, ReportDetailScreen(report: r)),
              child: Row(
                children: <Widget>[
                  IconBox(icon: AppIcons.file, fg: pal.sec, bg: pal.soft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(r.label.of(ar), style: context.hStyle(14)),
                        Text(
                          '${s.t('avg')} ${r.average} ${s.t('unit')}',
                          style: context.subStyle(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            ToneChip('${r.abnormal} ${s.t('abnShort')}', Tone.high),
                            ToneChip(
                              '${r.criticalAlerts} ${s.t('critShort')}',
                              r.criticalAlerts > 0 ? Tone.crit : Tone.ok,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIcon(AppIcons.chev, color: pal.sub, flip: true),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        LockNote(s.t('roReport')),
      ],
    );
  }
}
