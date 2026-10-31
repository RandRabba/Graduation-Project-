import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/glucose_chart.dart';
import '../../widgets/latest_glucose_card.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/segmented.dart';
import '../../widgets/state_view.dart';
import '../profile/privacy_screen.dart';
import '../reports/reports_screen.dart';
import '../routes.dart';

/// Readings tab. Basic caregivers see only the latest reading and a
/// "not shared" card. Extended caregivers get the chart, filters and history.
class ReadingsScreen extends StatelessWidget {
  const ReadingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: ScreenTitle(s.t('tRead'))),
            if (c.isExtended)
              Semantics(
                button: true,
                label: s.t('reportsL'),
                excludeSemantics: true,
                onTap: () => pushScreen(context, const ReportsScreen()),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: pal.shadows,
                  ),
                  child: Material(
                    color: pal.card,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => pushScreen(context, const ReportsScreen()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AppIcon(AppIcons.file, size: 16, color: pal.sec),
                            const SizedBox(width: 5),
                            Text(
                              s.t('reportsL'),
                              style: TextStyle(
                                color: pal.sec,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (c.isBasic) ...<Widget>[
          const SizedBox(height: 14),
          const LatestGlucoseCard(variant: LatestVariant.readings),
          const SizedBox(height: 14),
          RestrictedCard(onPrivacy: () => pushScreen(context, const PrivacyScreen())),
        ] else
          const _ExtendedReadings(),
      ],
    );
  }
}

class _ExtendedReadings extends StatelessWidget {
  const _ExtendedReadings();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;

    final ChartSeries? series = c.repository.chart(c.level, c.range);
    final RangeStats? stats = c.repository.rangeStats(c.level, c.range);
    final HbA1cRecord? hba = c.repository.hba1c(c.level);

    final DateTime now = MockClock.now;
    final List<GlucoseReading> records = c.typeFilter == 'HbA1c'
        ? const <GlucoseReading>[]
        : c.repository.readingHistory(c.level).where((GlucoseReading r) {
            final bool typeOk = c.typeFilter == 'all' || r.type.code == c.typeFilter;
            final bool sourceOk = c.sourceFilter == 'all' || r.source.name == c.sourceFilter;
            final bool dayOk = c.range != ChartRange.day ||
                (r.time.year == now.year && r.time.month == now.month && r.time.day == now.day);
            return typeOk && sourceOk && dayOk;
          }).toList();

    final bool showHba = hba != null &&
        (c.typeFilter == 'all' || c.typeFilter == 'HbA1c') &&
        (c.sourceFilter == 'all' || c.sourceFilter == hba.source.name) &&
        c.range != ChartRange.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 14),
        SegmentedBar<ChartRange>(
          semanticLabel: s.t('rangeLbl'),
          options: <SegmentOption<ChartRange>>[
            SegmentOption<ChartRange>(ChartRange.day, s.t('rDay')),
            SegmentOption<ChartRange>(ChartRange.week, s.t('rWeek')),
            SegmentOption<ChartRange>(ChartRange.month, s.t('rMonth')),
          ],
          selected: c.range,
          onChanged: c.setRange,
        ),
        const SizedBox(height: 12),
        if (series != null && stats != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ColumnGrid(
                  columns: 3,
                  gap: 10,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(s.t('avg'), style: context.subStyle()),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: '${stats.average} '),
                              TextSpan(
                                text: s.t('unit'),
                                style: context.subStyle(11, FontWeight.w500),
                              ),
                            ],
                          ),
                          style: context.hStyle(18),
                        ),
                      ],
                    ),
                    LabeledValue(label: s.t('tir'), value: '${stats.inRangePercent}%', valueSize: 18),
                    LabeledValue(label: s.t('readingsN'), value: '${stats.count}', valueSize: 18),
                  ],
                ),
                const SizedBox(height: 12),
                GlucoseChart(
                  values: series.values,
                  height: 150,
                  semanticLabel: s.t('chartAlt'),
                ),
                ChartLabels(series.labels.map((LocalizedText l) => l.of(ar)).toList()),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(child: Text(s.t('target'), style: context.subStyle())),
                      const SizedBox(width: 8),
                      Flexible(child: AppChip(stats.trend.of(ar), fg: pal.sec, bg: pal.soft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(s.t('fType'), style: context.subStyle(12.5, FontWeight.w600)),
        const SizedBox(height: 6),
        ChoicePills<String>(
          options: <SegmentOption<String>>[
            SegmentOption<String>('all', s.t('fAll')),
            const SegmentOption<String>('FBS', 'FBS'),
            const SegmentOption<String>('RBS', 'RBS'),
            const SegmentOption<String>('PPBS', 'PPBS'),
            const SegmentOption<String>('HbA1c', 'HbA1c'),
          ],
          selected: c.typeFilter,
          onChanged: c.setTypeFilter,
        ),
        const SizedBox(height: 12),
        Text(s.t('fSource'), style: context.subStyle(12.5, FontWeight.w600)),
        const SizedBox(height: 6),
        ChoicePills<String>(
          options: <SegmentOption<String>>[
            SegmentOption<String>('all', s.t('fAll')),
            SegmentOption<String>(ReadingSource.sensor.name, s.t(ReadingSource.sensor.key)),
            SegmentOption<String>(ReadingSource.manual.name, s.t(ReadingSource.manual.key)),
            SegmentOption<String>(ReadingSource.simulator.name, s.t(ReadingSource.simulator.key)),
          ],
          selected: c.sourceFilter,
          onChanged: c.setSourceFilter,
        ),
        if (showHba && hba != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  IconBox(icon: AppIcons.drop, fg: pal.sec, bg: pal.soft),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(s.t('hba1c'), style: context.hStyle(14)),
                        Text(
                          '${s.t(hba.source.key)} · ${whenLabel(hba.time, s)}',
                          style: context.subStyle(),
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: hba.percent.toStringAsFixed(1)),
                        TextSpan(text: ' %', style: context.subStyle(14, FontWeight.w400)),
                      ],
                    ),
                    style: context.hStyle(24, FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        for (final GlucoseReading r in records)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 62,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${r.value}',
                          style: context.hStyle(22, FontWeight.w800).copyWith(height: 1.1),
                        ),
                        Text(s.t('unit'), style: context.subStyle(11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(s.t(r.type.key), style: context.hStyle(13.5)),
                        Text(
                          '${s.t(r.source.key)} · ${whenLabel(r.time, s)}',
                          style: context.subStyle(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToneChip(classLabel(r.cls, s), r.cls.tone),
                ],
              ),
            ),
          ),
        if (records.isEmpty && !showHba)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: Text(
                s.t('noMatch'),
                textAlign: TextAlign.center,
                style: context.subStyle(13),
              ),
            ),
          ),
        const SizedBox(height: 14),
        LockNote(s.t('readOnly'), center: true),
      ],
    );
  }
}
