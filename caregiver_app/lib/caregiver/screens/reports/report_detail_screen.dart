import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glucose_chart.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/state_view.dart';
import '../../widgets/toast.dart';
import '../patient/restricted_screen.dart';

/// One health report: statistics, chart, reading summary and alert summary.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report});

  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();
    if (c.isBasic) return const RestrictedScreen();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final ChartSeries? chart = c.repository.reportChart(c.level, report);

    // Reading summary segments: in range, high, low, critical.
    final List<_Segment> segments = <_Segment>[
      _Segment('✓ ${s.t('c_ok')}', report.inRange, pal.ok),
      _Segment('↑ ${s.t('c_high')}', report.high, pal.high),
      _Segment('↓ ${s.t('c_low')}', report.low, pal.low),
      _Segment('! ${s.t('sevCrit')}', report.critical, pal.crit),
    ];

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('rp_${report.period.name}')),
        const SizedBox(height: 12),
        AppCard(
          child: ColumnGrid(
            children: <Widget>[
              LabeledValue(label: s.t('patientL'), value: c.repository.patient.name.of(ar)),
              LabeledValue(label: s.t('period'), value: report.label.of(ar)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('statsL'), style: context.subStyle(12.5, FontWeight.w700)),
              const SizedBox(height: 10),
              ColumnGrid(
                columns: 4,
                gap: 8,
                children: <Widget>[
                  LabeledValue(label: s.t('avg'), value: '${report.average}', valueSize: 19, labelSize: 11.5),
                  LabeledValue(label: s.t('lowest'), value: '${report.lowest}', valueSize: 19, labelSize: 11.5),
                  LabeledValue(label: s.t('highest'), value: '${report.highest}', valueSize: 19, labelSize: 11.5),
                  LabeledValue(label: s.t('readingsN'), value: '${report.count}', valueSize: 19, labelSize: 11.5),
                ],
              ),
              const SizedBox(height: 2),
              Text(s.t('unit'), style: context.subStyle()),
              if (chart != null) ...<Widget>[
                const SizedBox(height: 10),
                GlucoseChart(values: chart.values, height: 130, semanticLabel: s.t('chartAlt')),
                ChartLabels(chart.labels.map((LocalizedText l) => l.of(ar)).toList()),
              ],
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(child: Text(s.t('target'), style: context.subStyle())),
                    const SizedBox(width: 8),
                    Flexible(child: AppChip(report.trend.of(ar), fg: pal.sec, bg: pal.soft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('sumRead'), style: context.subStyle(12.5, FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  height: 14,
                  color: pal.line,
                  child: Row(
                    children: <Widget>[
                      for (final _Segment seg in segments)
                        if (seg.count > 0)
                          Expanded(flex: seg.count, child: Container(color: seg.color)),
                    ],
                  ),
                ),
              ),
              for (final _Segment seg in segments)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: seg.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(seg.label, style: context.bodyStyle())),
                      Text('${seg.count}', style: context.hStyle(14)),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${report.count == 0 ? 0 : (seg.count / report.count * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: context.subStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('sumAlert'), style: context.subStyle(12.5, FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _AlertTile(
                      value: report.criticalAlerts,
                      label: s.t('critAl'),
                      fg: pal.crit,
                      bg: pal.critBg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AlertTile(
                      value: report.abnormal,
                      label: s.t('abnR'),
                      fg: pal.high,
                      bg: pal.highBg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: s.t('pdf'),
          icon: AppIcons.file,
          onPressed: () => showToast(context, s.t('pdfStarted'), aboveNav: true),
        ),
        const SizedBox(height: 12),
        LockNote(s.t('roReport')),
      ],
    );
  }
}

class _Segment {
  const _Segment(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.value, required this.label, required this.fg, required this.bg});

  final int value;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800, height: 1.1),
          ),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
