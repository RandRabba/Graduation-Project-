import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/glucose_chart.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/segmented.dart';
import '../../widgets/state_view.dart';

/// Readings tab: the patient's glucose history. Read-only. There is no way to
/// add or edit a reading from the caregiver app.
class ReadingsScreen extends StatelessWidget {
  const ReadingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;

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

    final List<Widget> rows = <Widget>[
      if (showHba && hba != null) _HbaRow(record: hba),
      for (final GlucoseReading r in records) _ReadingRow(reading: r),
    ];

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(CgGap.page, CgGap.md, CgGap.page, CgGap.xl),
      children: <Widget>[
        PageHeader(s.t('tRead'), subtitle: c.repository.patient.name.of(ar)),
        PillTabs(
          semanticLabel: s.t('rangeLbl'),
          labels: <String>[s.t('rDay'), s.t('rWeek'), s.t('rMonth')],
          index: ChartRange.values.indexOf(c.range),
          onChanged: (int i) => c.setRange(ChartRange.values[i]),
        ),
        const SizedBox(height: CgGap.lg),
        if (series != null && stats != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            padding: const EdgeInsets.all(CgGap.xl),
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
                        Text(s.t('avg'), style: t.labelSmall),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: '${stats.average} ', style: t.titleMedium),
                              TextSpan(text: s.t('unit'), style: t.labelSmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    LabeledValue(label: s.t('tir'), value: '${stats.inRangePercent}%', valueSize: 17),
                    LabeledValue(label: s.t('readingsN'), value: '${stats.count}', valueSize: 17),
                  ],
                ),
                const SizedBox(height: CgGap.md),
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
                      Expanded(child: Text(s.t('target'), style: t.labelSmall)),
                      const SizedBox(width: CgGap.sm),
                      Flexible(child: AppChip(stats.trend.of(ar), fg: pal.pri, bg: pal.soft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(s.t('fType'), style: t.labelMedium!.copyWith(color: pal.sub)),
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
        const SizedBox(height: CgGap.md),
        Text(s.t('fSource'), style: t.labelMedium!.copyWith(color: pal.sub)),
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
        const SizedBox(height: CgGap.lg),
        if (rows.isNotEmpty)
          AppCard(
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < rows.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, thickness: 1, color: pal.line),
                  rows[i],
                ],
              ],
            ),
          )
        else
          EmptyState(
            icon: AppIcons.chart,
            title: s.t('noMatch'),
            message: s.t('readOnly'),
          ),
        if (rows.isNotEmpty) LockNote(s.t('readOnly'), center: true),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});

  final GlucoseReading reading;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final TextTheme t = Theme.of(context).textTheme;
    final GlucoseReading r = reading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${r.value}', style: t.titleLarge),
                Text(s.t('unit'), style: t.labelSmall),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.t(r.type.key), style: context.hStyle(14)),
                Text(
                  '${s.t(r.source.key)} · ${whenLabel(r.time, s)}',
                  style: t.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: CgGap.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: StatusPill(
              s.t(r.cls.key),
              glucoseColor(pal, r.cls),
              icon: glucoseIcon(r.cls),
            ),
          ),
        ],
      ),
    );
  }
}

class _HbaRow extends StatelessWidget {
  const _HbaRow({required this.record});

  final HbA1cRecord record;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
      child: Row(
        children: <Widget>[
          const IconCircle(AppIcons.drop, size: 40),
          const SizedBox(width: CgGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.t('hba1c'), style: context.hStyle(14)),
                Text(
                  '${s.t(record.source.key)} · ${whenLabel(record.time, s)}',
                  style: t.labelSmall,
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: record.percent.toStringAsFixed(1), style: t.titleLarge),
                TextSpan(text: ' %', style: t.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
