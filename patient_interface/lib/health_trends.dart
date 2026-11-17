import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';
import 'l10n.dart';
import 'theme.dart';

/// Bars for daily totals (food), a line for levels (glucose, weight, HbA1c).
enum TrendStyle { line, bars }

/// Something the patient can chart in the Summary's trends card.
enum HealthMetric {
  glucose('mg/dL', Icons.water_drop_rounded, TrendStyle.line, 0),
  carbs('g', Icons.bakery_dining_rounded, TrendStyle.bars, 0),
  protein('g', Icons.egg_alt_rounded, TrendStyle.bars, 0),
  fat('g', Icons.opacity_rounded, TrendStyle.bars, 0),
  calories('kcal', Icons.local_fire_department_rounded, TrendStyle.bars, 0),
  weight('kg', Icons.monitor_weight_rounded, TrendStyle.line, 1),
  hba1c('%', Icons.bloodtype_rounded, TrendStyle.line, 1);

  const HealthMetric(this.unit, this.icon, this.style, this.digits);
  final String unit;
  final IconData icon;
  final TrendStyle style;
  final int digits;

  String get labelKey => 'metric_$name';

  /// What one point means: a daily average, a daily total, or a single result.
  String get basisKey => switch (this) {
    glucose => 'basis_avg',
    weight || hba1c => 'basis_result',
    _ => 'basis_total',
  };

  /// Healthy band drawn behind the chart, when there's a standard one.
  (double, double)? get band => switch (this) {
    glucose => (kTargetLow.toDouble(), kTargetHigh.toDouble()),
    _ => null,
  };
}

typedef TrendPoint = ({DateTime day, double value});

/// Sample records for the trends card (UI demo — not loaded from the server).
/// Seeded, so the same chart shows on every launch.
abstract final class SampleTrends {
  static final _cache = <HealthMetric, List<TrendPoint>>{};

  static List<TrendPoint> of(HealthMetric m) => _cache[m] ??= _make(m);

  static List<TrendPoint> _make(HealthMetric m) {
    final rnd = math.Random(m.index + 7);
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    DateTime day(int ago) => DateTime(today.year, today.month, today.day - ago);
    double wobble(double base, double spread) =>
        base + (rnd.nextDouble() * 2 - 1) * spread;
    switch (m) {
      case HealthMetric.hba1c:
        // a lab result every month or so: none in the last week
        return [
          (day: day(70), value: 7.8),
          (day: day(41), value: 7.4),
          (day: day(12), value: 7.1),
        ];
      case HealthMetric.weight:
        return [
          for (var ago = 89; ago >= 0; ago -= 3)
            (day: day(ago), value: 80.2 + ago * .025 + wobble(0, .35)),
        ];
      default:
        final (base, spread) = switch (m) {
          HealthMetric.glucose => (142.0, 28.0),
          HealthMetric.carbs => (175.0, 45.0),
          HealthMetric.protein => (82.0, 18.0),
          HealthMetric.fat => (64.0, 16.0),
          _ => (1900.0, 280.0),
        };
        return [
          for (var ago = 89; ago >= 0; ago--)
            // a gentle improvement over the three months
            (day: day(ago), value: wobble(base + ago * spread * .004, spread)),
        ];
    }
  }
}

/// Lets the patient pick a measurement and a period, and charts it.
class HealthTrendsCard extends StatefulWidget {
  const HealthTrendsCard({super.key, this.data = SampleTrends.of});

  /// Where the points come from. Defaults to the built-in sample records.
  final List<TrendPoint> Function(HealthMetric) data;

  @override
  State<HealthTrendsCard> createState() => _HealthTrendsCardState();
}

class _HealthTrendsCardState extends State<HealthTrendsCard> {
  static const _periods = [7, 30, 90];

  HealthMetric _metric = HealthMetric.glucose;
  int _period = 0;
  int? _selected;

  /// Points inside the period. 3 months of daily values are grouped by week so bars stay readable.
  List<TrendPoint> get _points {
    final days = _periods[_period];
    final n = DateTime.now();
    final from = DateTime(n.year, n.month, n.day - (days - 1));
    final inRange = [
      for (final p in widget.data(_metric))
        if (!p.day.isBefore(from)) p,
    ];
    final daily =
        _metric != HealthMetric.weight && _metric != HealthMetric.hba1c;
    if (days < 90 || !daily) return inRange;
    final weeks = <int, List<TrendPoint>>{};
    for (final p in inRange) {
      weeks.putIfAbsent(p.day.difference(from).inDays ~/ 7, () => []).add(p);
    }
    return [
      for (final w in weeks.values)
        (
          day: w.first.day,
          value: w.map((p) => p.value).reduce((a, b) => a + b) / w.length,
        ),
    ];
  }

  void _pick(HealthMetric m) => setState(() {
    _metric = m;
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final points = _points;
    final values = [for (final x in points) x.value];
    String fmt(double v) => v.toStringAsFixed(_metric.digits);
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final selected = _selected != null && _selected! < points.length
        ? points[_selected!]
        : null;
    final loc = MaterialLocalizations.of(context);
    final weekly =
        _periods[_period] == 90 && _metric.basisKey != 'basis_result';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            context.tr('trend_title', {'metric': context.tr(_metric.labelKey)}),
            subtitle:
                '${context.tr(weekly ? 'basis_weekly' : _metric.basisKey)} · ${_metric.unit}',
          ),
          const SizedBox(height: Gap.md),
          // measurement picker: horizontally scrolling chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in HealthMetric.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                    child: _chip(m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          PillTabs(
            labels: [for (final d in _periods) context.tr('period_$d')],
            index: _period,
            onChanged: (i) => setState(() {
              _period = i;
              _selected = null;
            }),
          ),
          const SizedBox(height: Gap.md),
          StatRow([
            Stat(
              context.tr(selected == null ? 'average' : 'selected_value'),
              value: selected != null
                  ? fmt(selected.value)
                  : (avg == null ? '--' : fmt(avg)),
              unit: _metric.unit,
              compact: true,
            ),
            Stat(
              context.tr('lowest'),
              value: values.isEmpty ? '--' : fmt(values.reduce(math.min)),
              unit: _metric.unit,
              compact: true,
            ),
            Stat(
              context.tr('highest'),
              value: values.isEmpty ? '--' : fmt(values.reduce(math.max)),
              unit: _metric.unit,
              compact: true,
            ),
          ]),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                loc.formatMediumDate(selected.day),
                style: context.text.labelSmall!.copyWith(color: p.primary),
              ),
            ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            height: 220,
            child: points.isEmpty
                ? _empty()
                : _TrendChart(
                    key: ValueKey('${_metric.name}-$_period'),
                    points: points,
                    metric: _metric,
                    selected: _selected,
                    onSelect: (i) =>
                        setState(() => _selected = i == _selected ? null : i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(HealthMetric m) {
    final p = context.palette;
    final on = m == _metric;
    return ChoiceChip(
      key: ValueKey('metric-${m.name}'),
      avatar: Icon(m.icon, size: 18, color: on ? p.onPrimary : p.primary),
      label: Text(context.tr(m.labelKey)),
      selected: on,
      showCheckmark: false,
      selectedColor: p.primary,
      backgroundColor: p.surface,
      side: BorderSide(color: on ? p.primary : p.border),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: on ? p.onPrimary : p.ink,
      ),
      onSelected: (_) => _pick(m),
    );
  }

  Widget _empty() {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconCircle(_metric.icon, size: 44, color: p.muted),
          const SizedBox(height: Gap.md),
          Text(
            context.tr('trend_empty', {'metric': context.tr(_metric.labelKey)}),
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            context.tr('trend_empty_body'),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    super.key,
    required this.points,
    required this.metric,
    required this.selected,
    required this.onSelect,
  });
  final List<TrendPoint> points;
  final HealthMetric metric;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final painter = _TrendPainter(
          points: points,
          metric: metric,
          palette: context.palette,
          selected: selected,
          dateLabel: loc.formatShortMonthDay,
        );
        return Semantics(
          label: context.tr('trend_semantics', {
            'metric': context.tr(metric.labelKey),
            'n': points.length,
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                onSelect(painter.nearest(d.localPosition.dx, c.maxWidth)),
            child: CustomPaint(size: Size.infinite, painter: painter),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.metric,
    required this.palette,
    required this.selected,
    required this.dateLabel,
  });
  final List<TrendPoint> points;
  final HealthMetric metric;
  final AppPalette palette;
  final int? selected;
  final String Function(DateTime) dateLabel;

  static const _left = 42.0, _right = 12.0, _top = 10.0, _bottom = 26.0;

  /// Rounded axis bounds with a little headroom.
  (double, double) get _bounds {
    final vs = [for (final p in points) p.value];
    var lo = vs.reduce(math.min), hi = vs.reduce(math.max);
    final band = metric.band;
    if (band != null) {
      lo = math.min(lo, band.$1);
      hi = math.max(hi, band.$2);
    }
    if (metric.style == TrendStyle.bars) lo = 0;
    final pad = math.max((hi - lo) * .15, metric.digits > 0 ? .5 : 5);
    final step = _step(hi - lo + 2 * pad);
    final min = metric.style == TrendStyle.bars
        ? 0.0
        : ((lo - pad) / step).floor() * step;
    return (math.max(0, min), ((hi + pad) / step).ceil() * step);
  }

  static double _step(double range) {
    final raw = range / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (raw <= m * mag) return m * mag;
    }
    return 10 * mag;
  }

  double _x(int i, double w) => points.length == 1
      ? _left + w / 2
      : metric.style == TrendStyle.bars
      ? _left + w * (i + .5) / points.length
      : _left + w * i / (points.length - 1);

  int nearest(double dx, double width) {
    final w = width - _left - _right;
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((_x(i, w) - dx).abs() < (_x(best, w) - dx).abs()) best = i;
    }
    return best;
  }

  void _text(Canvas c, String s, Offset at, {bool centered = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 11, color: palette.hint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centered ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left - _right;
    final h = size.height - _top - _bottom;
    final (lo, hi) = _bounds;
    double y(double v) => _top + h * (1 - (v - lo) / (hi - lo));

    final band = metric.band;
    if (band != null) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          _left,
          y(band.$2),
          _left + w,
          y(band.$1),
          const Radius.circular(6),
        ),
        Paint()..color = palette.primarySoft,
      );
    }

    final grid = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      canvas.drawLine(Offset(_left, y(v)), Offset(_left + w, y(v)), grid);
      final label = hi - lo < 10 ? v.toStringAsFixed(1) : '${v.round()}';
      _text(canvas, label, Offset(0, y(v) - 7));
    }

    // first, middle and last dates along the bottom
    final idx = {0, points.length ~/ 2, points.length - 1};
    for (final i in idx) {
      _text(
        canvas,
        dateLabel(points[i].day),
        Offset(_x(i, w), size.height - 18),
        centered: true,
      );
    }

    final color = palette.primaryBright;
    if (metric.style == TrendStyle.bars) {
      final slot = w / points.length;
      final bw = math.max(2.0, math.min(22.0, slot * .62));
      for (var i = 0; i < points.length; i++) {
        final x = _x(i, w);
        final on = selected == null || selected == i;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            x - bw / 2,
            y(points[i].value),
            x + bw / 2,
            y(lo),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = on ? color : color.withAlpha(90),
        );
      }
    } else {
      if (points.length > 1) {
        final line = Path()..moveTo(_x(0, w), y(points.first.value));
        for (var i = 1; i < points.length; i++) {
          line.lineTo(_x(i, w), y(points[i].value));
        }
        final area = Path.from(line)
          ..lineTo(_x(points.length - 1, w), y(lo))
          ..lineTo(_x(0, w), y(lo))
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(60), color.withAlpha(0)],
            ).createShader(Rect.fromLTRB(_left, _top, _left + w, _top + h)),
        );
        canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      // dots when points are sparse (lab results, weigh-ins), plus the latest one
      final dots = points.length <= 31;
      for (var i = 0; i < points.length; i++) {
        if (!dots && i != points.length - 1) continue;
        final c = Offset(_x(i, w), y(points[i].value));
        canvas.drawCircle(c, 5.5, Paint()..color = palette.surface);
        canvas.drawCircle(c, 3.5, Paint()..color = color);
      }
    }

    final s = selected;
    if (s != null && s < points.length) {
      final x = _x(s, w);
      canvas.drawLine(
        Offset(x, _top),
        Offset(x, _top + h),
        Paint()
          ..color = palette.primary.withAlpha(120)
          ..strokeWidth = 1.5,
      );
      final c = Offset(x, y(points[s].value));
      canvas.drawCircle(c, 8, Paint()..color = palette.surface);
      canvas.drawCircle(c, 5.5, Paint()..color = palette.primary);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.metric != metric ||
      old.selected != selected ||
      old.palette != palette;
}
