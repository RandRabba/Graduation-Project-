import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'alerts_screen.dart';
import 'app_state.dart';
import 'caregiver_screen.dart' show sendEmergency;
import 'common.dart';
import 'l10n.dart';
import 'sensor_screen.dart' show SensorStatusPill, mmss, sensorStatus;
import 'theme.dart';

/// Summary numbers derived from the readings. Every field is null when there's no data.
class GlucoseStats {
  GlucoseStats(List<Offset> points) : count = points.length {
    if (points.isEmpty) return;
    final v = points.map((p) => p.dy).toList();
    average = v.reduce((a, b) => a + b) / v.length;
    highest = v.reduce((a, b) => a > b ? a : b);
    lowest = v.reduce((a, b) => a < b ? a : b);
    low = 100 * v.where((x) => x < kTargetLow).length / v.length;
    high = 100 * v.where((x) => x > kTargetHigh).length / v.length;
    inRange = 100 - low! - high!;
    ehba1c = (average! + 46.7) / 28.7; // ADAG estimate from average glucose
  }

  final int count;
  double? average, highest, lowest, low, inRange, high, ehba1c;

  static String fmt(double? v, {int digits = 0}) =>
      v == null ? '--' : v.toStringAsFixed(digits);
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  static const _ranges = [1, 7, 14, 30, 90];

  int _range = 0;
  late DateTime _date;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _date == _today;

  @override
  void initState() {
    super.initState();
    _date = _today;
  }

  String get _label {
    final loc = MaterialLocalizations.of(context);
    final n = _ranges[_range];
    final end = _isToday ? context.tr('today') : loc.formatShortMonthDay(_date);
    if (n == 1) return end;
    final start = DateTime(_date.year, _date.month, _date.day - (n - 1));
    return '${loc.formatShortMonthDay(start)} – $end';
  }

  void _shift(int dir) {
    final n = _ranges[_range];
    final next = DateTime(_date.year, _date.month, _date.day + dir * n);
    setState(() => _date = next.isAfter(_today) ? _today : next);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _today,
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  void _soon() => showSnack(context, context.tr('not_available'));

  void _expandChart() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(ctx.tr('glucose_curve'))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: GlucoseChart(
              points: AppScope.of<SensorSession>(ctx).readings,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.sensor;
    final stats = GlucoseStats(s.readings);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'greet_morning'
        : hour < 18
        ? 'greet_afternoon'
        : 'greet_evening';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
        children: [
          PageHeader(
            context.tr(greeting),
            subtitle: context.tr('summary_subtitle'),
            leading: const BrandMark(),
          ),
          _hero(s),
          _quickAccess(s),
          PillTabs(
            labels: [for (final n in _ranges) context.tr('range_$n')],
            index: _range,
            onChanged: (i) => setState(() => _range = i),
          ),
          _dateRow(),
          _overview(stats),
          _curve(s, stats),
          _logs(),
          _weight(),
        ],
      ),
    );
  }

  Widget _dateRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
    child: Row(
      children: [
        IconButton(
          tooltip: context.tr('prev_period'),
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        Expanded(
          child: Center(
            child: TextButton.icon(
              onPressed: _pickDate,
              style: TextButton.styleFrom(foregroundColor: context.palette.ink),
              icon: Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: context.palette.primary,
              ),
              label: Text(
                _label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.tr('next_period'),
          onPressed: _isToday ? null : () => _shift(1),
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
        ),
      ],
    ),
  );

  // ---------- quick access: meals, sensor, chatbot ----------
  Widget _quickAccess(SensorSession s) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: SettingsGroup(context.tr('quick_access'), [
      SettingsTile(
        Icons.restaurant_rounded,
        context.tr('todays_meals'),
        value: context.tr('n_analyzed', {'n': context.meals.today.length}),
        onTap: () => widget.onNavigate(2),
      ),
      SettingsTile(
        Icons.sensors_rounded,
        kSensorName,
        value: context.tr(sensorStatus(s, context.palette).$1),
        onTap: () => widget.onNavigate(0),
      ),
      SettingsTile(
        Icons.smart_toy_outlined,
        context.tr('ask_chatbot'),
        onTap: () => widget.onNavigate(3),
      ),
      SettingsTile(
        Icons.notifications_none_rounded,
        context.tr('alerts_title'),
        value: context.inbox.unread > 0
            ? context.tr('n_new', {'n': context.inbox.unread})
            : null,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
      ),
      SettingsTile(
        Icons.sos_rounded,
        context.tr('sos_title'),
        onTap: () => sendEmergency(context),
      ),
    ]),
  );

  // ---------- hero: latest reading ----------
  Widget _hero(SensorSession s) {
    final p = context.palette;
    final latest = s.latest;
    final level = latest == null ? null : GlucoseLevel.of(latest.dy);
    const soft = Color(0xD9FFFFFF);
    final message = !s.paired
        ? context.tr('hero_connect')
        : s.warming
        ? context.tr('hero_warming', {'time': mmss(s.remaining)})
        : latest == null
        ? context.tr('hero_waiting')
        : null;
    return AppCard(
      gradient: p.hero,
      padding: const EdgeInsets.all(Gap.xl + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('latest_reading'),
                  style: const TextStyle(
                    color: soft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SensorStatusPill(onDark: true),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: latest == null ? '--' : '${latest.dy.round()}',
                  style: context.text.displaySmall!.copyWith(
                    color: Colors.white,
                    fontSize: 56,
                  ),
                ),
                const TextSpan(
                  text: '  mg/dL',
                  style: TextStyle(fontSize: 17, color: soft),
                ),
              ],
            ),
          ),
          if (level != null) ...[
            const SizedBox(height: Gap.sm),
            StatusPill(
              context.tr(level.labelKey),
              level.color(p),
              icon: level.icon,
              onDark: true,
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: Gap.sm),
            Text(
              message,
              style: const TextStyle(color: soft, fontSize: 15, height: 1.4),
            ),
          ],
          const SizedBox(height: Gap.lg + 2),
          FilledButton(
            onPressed: () => widget.onNavigate(0),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: p.heroEnd,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              context.tr(s.paired ? 'view_sensor' : 'connect_sensor'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- time in range + stats ----------
  Widget _overview(GlucoseStats st) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            context.tr('time_in_range'),
            subtitle: context.tr('target_note', {
              'low': kTargetLow,
              'high': kTargetHigh,
            }),
          ),
          const SizedBox(height: Gap.lg),
          TimeInRangeBar(low: st.low, inRange: st.inRange, high: st.high),
          const SizedBox(height: Gap.md + 2),
          Row(
            children: [
              _Legend(
                context.tr('low'),
                st.low,
                p.critical,
                Icons.south_rounded,
              ),
              _Legend(
                context.tr('in_range'),
                st.inRange,
                p.normal,
                Icons.check_circle_rounded,
              ),
              _Legend(
                context.tr('high'),
                st.high,
                p.caution,
                Icons.north_rounded,
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  context.tr('ehba1c'),
                  Icons.bloodtype_outlined,
                  value: GlucoseStats.fmt(st.ehba1c, digits: 1),
                  unit: '%',
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: StatTile(
                  context.tr('average'),
                  Icons.functions_rounded,
                  value: GlucoseStats.fmt(st.average),
                  unit: 'mg/dL',
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  context.tr('highest'),
                  Icons.arrow_upward_rounded,
                  value: GlucoseStats.fmt(st.highest),
                  unit: 'mg/dL',
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: StatTile(
                  context.tr('lowest'),
                  Icons.arrow_downward_rounded,
                  value: GlucoseStats.fmt(st.lowest),
                  unit: 'mg/dL',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- curve ----------
  Widget _curve(SensorSession s, GlucoseStats st) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          context.tr('glucose_curve'),
          action: context.tr('expand'),
          onAction: _expandChart,
        ),
        const SizedBox(height: Gap.md),
        StatRow([
          Stat(context.tr('readings'), value: '${st.count}', compact: true),
          Stat(
            context.tr('in_range'),
            value: GlucoseStats.fmt(st.inRange),
            unit: '%',
            compact: true,
          ),
          Stat(
            context.tr('lowest'),
            value: GlucoseStats.fmt(st.lowest),
            unit: 'mg/dL',
            compact: true,
          ),
        ]),
        const SizedBox(height: Gap.lg),
        SizedBox(height: 220, child: GlucoseChart(points: s.readings)),
      ],
    ),
  );

  // ---------- daily logs: Carbohydrate, Insulin, Medication ----------
  Widget _logs() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          context.tr('daily_logs'),
          action: context.tr('more'),
          onAction: _soon,
        ),
        const SizedBox(height: Gap.xs),
        _logRow(
          'carbs',
          Icons.restaurant_rounded,
          detail: _carbsToday(),
          onAdd: () => widget.onNavigate(2), // carbs come from meal analysis
        ),
        const Divider(),
        _logRow('insulin', Icons.vaccines_rounded),
        const Divider(),
        _logRow('medication', Icons.medication_rounded),
      ],
    ),
  );

  String? _carbsToday() {
    final today = context.meals.today;
    if (today.isEmpty) return null;
    final g = today.fold<double>(0, (s, e) => s + e.analysis.carbs);
    return context.tr('carbs_from_meals', {'g': g.round(), 'n': today.length});
  }

  Widget _logRow(
    String key,
    IconData icon, {
    String? detail,
    VoidCallback? onAdd,
  }) {
    final p = context.palette;
    final label = context.tr(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          IconCircle(icon, size: 42),
          const SizedBox(width: Gap.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail ?? context.tr('no_entries'),
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('add_entry', {'item': label}),
            onPressed: onAdd ?? _soon,
            style: IconButton.styleFrom(
              backgroundColor: p.primarySoft,
              foregroundColor: p.primary,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  // ---------- weight ----------
  Widget _weight() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.tr('weight')),
        const SizedBox(height: Gap.lg),
        StatRow([
          Stat(context.tr('current'), unit: 'kg'),
          Stat(context.tr('change'), unit: 'kg'),
        ]),
        const SizedBox(height: Gap.lg),
        StatRow([
          Stat(context.tr('body_fat'), unit: '%'),
          Stat(context.tr('bmi')),
        ]),
        const SizedBox(height: Gap.xl),
        SoftButton(
          context.tr('weight_plan'),
          icon: Icons.flag_rounded,
          onPressed: _soon,
        ),
      ],
    ),
  );
}

// ---------- time-in-range bar ----------
class TimeInRangeBar extends StatelessWidget {
  const TimeInRangeBar({super.key, this.low, this.inRange, this.high});

  /// Percentages (0–100). Leave null until you have data.
  final double? low, inRange, high;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = low, m = inRange, h = high;
    final segments = (l != null && m != null && h != null)
        ? [
            (l, p.critical),
            (m, p.normal),
            (h, p.caution),
          ].where((s) => s.$1 > 0).toList()
        : <(double, Color)>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: segments.isEmpty
            ? ColoredBox(color: p.border, child: const SizedBox.expand())
            : Row(
                children: [
                  for (final (v, c) in segments)
                    Expanded(
                      flex: (v * 10).round().clamp(1, 1000),
                      child: ColoredBox(color: c),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.percent, this.color, this.icon);
  final String label;
  final double? percent;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${GlucoseStats.fmt(percent)}%',
                style: context.text.titleMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------- glucose chart ----------
class GlucoseChart extends StatelessWidget {
  const GlucoseChart({super.key, required this.points});

  /// Offset(hourOfDay 0-24, glucose mg/dL)
  final List<Offset> points;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('chart_semantics', {'n': points.length}),
    child: CustomPaint(
      size: Size.infinite,
      painter: _ChartPainter(
        points: points,
        palette: context.palette,
        hourLabels: [
          for (final h in [0, 6, 12, 18, 0]) context.tr('h_$h'),
        ],
        emptyLabel: context.tr('chart_empty'),
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.palette,
    required this.hourLabels,
    required this.emptyLabel,
  });
  final List<Offset> points;
  final AppPalette palette;
  final List<String> hourLabels;
  final String emptyLabel;

  static const _yMax = 300.0;

  void _text(
    Canvas c,
    String s,
    Offset at, {
    bool centered = false,
    double size = 11.5,
    Color? color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color ?? palette.hint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centered ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 20.0, top = 8.0, bottom = 26.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double y(num v) =>
        top +
        h *
            (1 -
                v.clamp(0, _yMax) /
                    _yMax); // off-scale values stick to the edge
    double x(num hr) => left + w * hr.clamp(0, 24) / 24;

    // target range band
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        y(kTargetHigh),
        left + w,
        y(kTargetLow),
        const Radius.circular(6),
      ),
      Paint()..color = palette.primarySoft,
    );

    final grid = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    for (final v in [0, 100, 200, 300]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      _text(canvas, '$v', Offset(0, y(v) - 7));
    }

    for (var i = 0; i < hourLabels.length; i++) {
      _text(
        canvas,
        hourLabels[i],
        Offset(x(i * 6), size.height - 18),
        centered: true,
      );
    }

    if (points.isEmpty) {
      _text(
        canvas,
        emptyLabel,
        Offset(left + w / 2, y(150) - 8),
        centered: true,
        size: 14,
        color: palette.muted,
      );
      return;
    }
    final sorted = [...points]..sort((a, b) => a.dx.compareTo(b.dx));
    if (sorted.length > 1) {
      final line = Path()..moveTo(x(sorted.first.dx), y(sorted.first.dy));
      for (final p in sorted.skip(1)) {
        line.lineTo(x(p.dx), y(p.dy));
      }
      final area = Path.from(line)
        ..lineTo(x(sorted.last.dx), y(0))
        ..lineTo(x(sorted.first.dx), y(0))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.primaryBright.withAlpha(70),
              palette.primaryBright.withAlpha(0),
            ],
          ).createShader(Rect.fromLTRB(left, top, left + w, top + h)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = palette.primaryBright
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // latest point (also covers a single reading)
    final last = Offset(x(sorted.last.dx), y(sorted.last.dy));
    canvas.drawCircle(last, 7, Paint()..color = palette.surface);
    canvas.drawCircle(last, 4.5, Paint()..color = palette.primaryBright);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      !listEquals(old.points, points) ||
      old.palette != palette ||
      old.emptyLabel != emptyLabel ||
      !listEquals(old.hourLabels, hourLabels);
}
