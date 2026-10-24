import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  static const _ranges = [1, 7, 14, 30, 90];
  static const _rangeLabels = ['1D', '7D', '14D', '30D', '90D'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  int _range = 0;
  late DateTime _date;

  /// TODO: fill from your backend. Offset(hourOfDay 0-24, glucose in mg/dL).
  final List<Offset> _readings = [];

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

  String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String get _label {
    final n = _ranges[_range];
    final end = _isToday ? 'Today' : _fmt(_date);
    if (n == 1) return end;
    final start = DateTime(_date.year, _date.month, _date.day - (n - 1));
    return '${_fmt(start)} – $end';
  }

  void _shift(int dir) {
    final n = _ranges[_range];
    final next = DateTime(_date.year, _date.month, _date.day + dir * n);
    setState(() => _date = next.isAfter(_today) ? _today : next);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: _today);
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _expandChart() => Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Glucose curve')),
          body: Padding(padding: const EdgeInsets.all(16), child: GlucoseChart(points: _readings)),
        ),
      ));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          const Text('Summary', style: AppText.h1),
          const SizedBox(height: 16),
          PillTabs(labels: _rangeLabels, index: _range, onChanged: (i) => setState(() => _range = i)),
          _dateRow(),
          const SizedBox(height: 6),
          _hero(),
          _overview(),
          _curve(),
          _logs(),
          _weight(),
        ]),
      );

  Widget _dateRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          IconButton(
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          ),
          Expanded(
            child: Center(
              child: TextButton.icon(
                onPressed: _pickDate,
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(_label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () => _shift(1),
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
          ),
        ]),
      );

  // ---------- hero ----------
  Widget _hero() => AppCard(
        color: AppColors.ink,
        bordered: false,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Text('Latest reading', style: TextStyle(color: Colors.white70, fontSize: 15)),
            Spacer(),
            StatusPill('No sensor', Colors.white, onDark: true),
          ]),
          const SizedBox(height: 14),
          const Text.rich(TextSpan(children: [
            TextSpan(
              text: '--',
              style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1),
            ),
            TextSpan(text: '  mg/dL', style: TextStyle(fontSize: 18, color: Colors.white70)),
          ])),
          const SizedBox(height: 6),
          const Text('Connect your $kSensorName to see live glucose here.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => widget.onNavigate(0),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: const Text('Connect sensor'),
          ),
        ]),
      );

  // ---------- time in range + stats ----------
  Widget _overview() => const AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('Time in range'),
          SizedBox(height: 14),
          TimeInRangeBar(), // pass low / inRange / high (percent) when you have data
          SizedBox(height: 14),
          Row(children: [
            _Legend('Low', AppColors.low),
            _Legend('In range', AppColors.accent),
            _Legend('High', AppColors.high),
          ]),
          SizedBox(height: 18),
          Divider(height: 1, color: AppColors.line),
          SizedBox(height: 18),
          StatRow([Stat('eHbA1c', unit: '%'), Stat('Average', unit: 'mg/dL')]),
          SizedBox(height: 18),
          StatRow([Stat('Highest', unit: 'mg/dL'), Stat('Lowest', unit: 'mg/dL')]),
        ]),
      );

  // ---------- curve ----------
  Widget _curve() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('Glucose curve', action: 'Expand', onAction: _expandChart),
          const SizedBox(height: 14),
          const StatRow([
            Stat('0:00', unit: 'mg/dL', compact: true),
            Stat('6:00', unit: 'mg/dL', compact: true),
            Stat('Lowest', compact: true),
          ]),
          const SizedBox(height: 16),
          SizedBox(height: 230, child: GlucoseChart(points: _readings)),
        ]),
      );

  // ---------- daily logs: Carbohydrate, Insulin, Medication (BG removed) ----------
  Widget _logs() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('Daily logs', action: 'More', onAction: () => _snack('TODO: open full log history')),
          const SizedBox(height: 6),
          _logRow('Carbohydrate', Icons.restaurant_rounded, AppColors.high),
          const Divider(height: 1, color: AppColors.line),
          _logRow('Insulin', Icons.vaccines_rounded, const Color(0xFF6A5ACD)),
          const Divider(height: 1, color: AppColors.line),
          _logRow('Medication', Icons.medication_rounded, AppColors.accent),
        ]),
      );

  Widget _logRow(String label, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          IconCircle(icon, color: color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const Text('No entries yet', style: AppText.label),
            ]),
          ),
          IconButton(
            onPressed: () => _snack('TODO: add $label entry'),
            style: IconButton.styleFrom(backgroundColor: AppColors.accentSoft, foregroundColor: AppColors.accent),
            icon: const Icon(Icons.add_rounded),
          ),
        ]),
      );

  // ---------- weight ----------
  Widget _weight() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Weight'),
          const SizedBox(height: 16),
          const StatRow([Stat('Current', unit: 'kg'), Stat('Change', unit: 'kg')]),
          const SizedBox(height: 18),
          const StatRow([Stat('Body fat', unit: '%'), Stat('BMI')]),
          const SizedBox(height: 20),
          SoftButton('Set weight plan', icon: Icons.flag_rounded, onPressed: () => _snack('TODO: weight plan setup')),
        ]),
      );
}

// ---------- time-in-range bar ----------
class TimeInRangeBar extends StatelessWidget {
  const TimeInRangeBar({super.key, this.low, this.inRange, this.high});

  /// Percentages (0–100). Leave null until you have data.
  final double? low, inRange, high;

  Widget _seg(double v, Color c) =>
      Expanded(flex: math.max(1, (v * 10).round()), child: ColoredBox(color: c));

  @override
  Widget build(BuildContext context) {
    final l = low, m = inRange, h = high;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: (l != null && m != null && h != null)
            ? Row(children: [_seg(l, AppColors.low), _seg(m, AppColors.accent), _seg(h, AppColors.high)])
            : const ColoredBox(color: AppColors.line, child: SizedBox.expand()),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.label),
            const Text('--%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ]),
        ]),
      );
}

// ---------- glucose chart ----------
class GlucoseChart extends StatelessWidget {
  const GlucoseChart({super.key, required this.points});

  /// Offset(hourOfDay 0-24, glucose mg/dL)
  final List<Offset> points;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _ChartPainter(points));
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);
  final List<Offset> points;

  static const _yMax = 300.0;

  void _text(Canvas c, String s, Offset at, {bool centered = false, double size = 12, Color color = AppColors.hint}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centered ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 20.0, top = 8.0, bottom = 26.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double y(num v) => top + h * (1 - v / _yMax);
    double x(num hr) => left + w * hr / 24;

    // target range band (70–180 mg/dL)
    canvas.drawRRect(
      RRect.fromLTRBR(left, y(180), left + w, y(70), const Radius.circular(6)),
      Paint()..color = AppColors.accentSoft,
    );

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (final v in [0, 100, 200, 300]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      _text(canvas, '$v', Offset(0, y(v) - 7));
    }

    const labels = ['12 am', '6 am', '12 pm', '6 pm', '12 am'];
    for (var i = 0; i < labels.length; i++) {
      _text(canvas, labels[i], Offset(x(i * 6), size.height - 18), centered: true);
    }

    if (points.isEmpty) {
      _text(canvas, 'No readings yet', Offset(left + w / 2, y(150) - 8),
          centered: true, size: 14, color: AppColors.muted);
      return;
    }
    if (points.length > 1) {
      final sorted = [...points]..sort((a, b) => a.dx.compareTo(b.dx));
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
            colors: [AppColors.accent.withAlpha(60), AppColors.accent.withAlpha(0)],
          ).createShader(Rect.fromLTRB(left, top, left + w, top + h)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final last = Offset(x(sorted.last.dx), y(sorted.last.dy));
      canvas.drawCircle(last, 7, Paint()..color = Colors.white);
      canvas.drawCircle(last, 4.5, Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
