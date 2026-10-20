import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  static const _ranges = [1, 7, 14, 30, 90];
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
          appBar: AppBar(title: const Text('Curve')),
          body: Padding(padding: const EdgeInsets.all(16), child: GlucoseChart(points: _readings)),
        ),
      ));

  @override
  Widget build(BuildContext context) => Column(children: [
        _header(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [_overview(), _curve(), _logs(), _weight()],
          ),
        ),
      ]);

  // ---------- header ----------
  Widget _circle(double d) => Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x18FFFFFF)),
      );

  Widget _header() => Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF35C2D6), AppColors.blue],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: Stack(children: [
          Positioned(right: -40, top: -30, child: _circle(170)),
          Positioned(left: -30, bottom: -50, child: _circle(120)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Summary',
                    style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Your glucose at a glance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                _segments(),
                const SizedBox(height: 12),
                _dateBar(),
              ]),
            ),
          ),
        ]),
      );

  Widget _segments() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          for (var i = 0; i < _ranges.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _range = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _range ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: i == _range
                        ? const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))]
                        : null,
                  ),
                  child: Text(
                    i == 0 ? '1 Day' : '${_ranges[i]}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: i == _range ? AppColors.blue : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _dateBar() => Container(
        decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          IconButton(
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_label,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                  ]),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () => _shift(1),
            icon: Icon(Icons.chevron_right_rounded, color: _isToday ? Colors.white38 : Colors.white, size: 30),
          ),
        ]),
      );

  // ---------- cards ----------
  Widget _overview() => SectionCard(
        title: 'Overview',
        icon: Icons.dashboard_rounded,
        accent: AppColors.blue,
        child: Column(children: [
          // Pass high / inRange / low (percent) to RangeRing when you have data.
          const Row(children: [RangeRing(), SizedBox(width: 18), Expanded(child: _RangeLegend())]),
          const SizedBox(height: 16),
          tileRow([
            const StatTile('eHbA1c', unit: '%', info: true, icon: Icons.water_drop_rounded, color: AppColors.coral),
            const StatTile('Average', unit: 'mg/dL', icon: Icons.timeline_rounded, color: AppColors.blue),
          ]),
          tileRow([
            const StatTile('Highest', unit: 'mg/dL', icon: Icons.arrow_upward_rounded, color: AppColors.amber),
            const StatTile('Lowest', unit: 'mg/dL', icon: Icons.arrow_downward_rounded, color: AppColors.violet),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.rangeBlue, borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text('No data yet. Apply a sensor to see your stats.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
            ]),
          ),
        ]),
      );

  Widget _curve() => SectionCard(
        title: 'Curve',
        icon: Icons.show_chart_rounded,
        accent: AppColors.teal,
        trailing: IconButton.filledTonal(
          onPressed: _expandChart,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.open_in_full_rounded, size: 18),
        ),
        child: Column(children: [
          tileRow([
            const StatTile('0:00', unit: 'mg/dL'),
            const StatTile('6:00', unit: 'mg/dL'),
            const StatTile('Lowest', info: true),
          ]),
          const SizedBox(height: 6),
          SizedBox(height: 250, child: GlucoseChart(points: _readings)),
        ]),
      );

  // Daily logs: Carbohydrate, Insulin, Medication (BG removed).
  Widget _logs() => SectionCard(
        title: 'Daily logs',
        icon: Icons.edit_note_rounded,
        accent: AppColors.violet,
        trailing: TextButton(onPressed: () => _snack('TODO: open full log history'), child: const Text('More')),
        child: Column(children: [
          _logRow('Carbohydrate', Icons.restaurant_rounded, AppColors.amber),
          _logRow('Insulin', Icons.vaccines_rounded, AppColors.violet),
          _logRow('Medication', Icons.medication_rounded, AppColors.mint),
        ]),
      );

  Widget _logRow(String label, IconData icon, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(color: AppColors.tile, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          IconBubble(icon, color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const Text('No entries yet', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
          IconButton.filled(
            onPressed: () => _snack('TODO: add $label entry'),
            style: IconButton.styleFrom(backgroundColor: color),
            icon: const Icon(Icons.add_rounded),
          ),
        ]),
      );

  Widget _weight() => SectionCard(
        title: 'Daily weight',
        icon: Icons.monitor_weight_outlined,
        accent: AppColors.mint,
        child: Column(children: [
          _planBanner(),
          const SizedBox(height: 14),
          tileRow([
            const StatTile('Current weight', icon: Icons.monitor_weight_rounded, color: AppColors.mint),
            const StatTile('Weight change',
                icon: Icons.trending_down_rounded, color: AppColors.amber, info: true),
          ]),
          tileRow([
            const StatTile('Body fat', icon: Icons.percent_rounded, color: AppColors.coral),
            const StatTile('BMI', icon: Icons.speed_rounded, color: AppColors.sky),
          ]),
        ]),
      );

  Widget _planBanner() => Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE7F9F5), Color(0xFFE6F3FF)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFE8E0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _snack('TODO: weight plan setup'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const IconBubble(Icons.flag_rounded, AppColors.mint, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Text('Set your weight plan',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0E8F80))),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF0E8F80)),
                    ]),
                    const SizedBox(height: 4),
                    Text('$kAppName tracks your progress to help you reach your goals.',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---------- time-in-range ring ----------
class RangeRing extends StatelessWidget {
  const RangeRing({super.key, this.high, this.inRange, this.low});

  /// Percentages (0–100). Leave null until you have data.
  final double? high, inRange, low;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 118,
        height: 118,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: CustomPaint(painter: _RingPainter(high, inRange, low))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              inRange == null ? '--%' : '${inRange!.round()}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const Text('In range', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ]),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.high, this.inRange, this.low);
  final double? high, inRange, low;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFE9EEF7),
    );
    final parts = <(double?, Color)>[(low, AppColors.coral), (inRange, AppColors.mint), (high, AppColors.amber)];
    var start = -math.pi / 2;
    for (final (v, c) in parts) {
      if (v == null || v <= 0) continue;
      final sweep = math.pi * 2 * v / 100;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = c,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.high != high || old.inRange != inRange || old.low != low;
}

class _RangeLegend extends StatelessWidget {
  const _RangeLegend();

  @override
  Widget build(BuildContext context) => const Column(children: [
        _LegendRow('High', AppColors.amber),
        _LegendRow('In range', AppColors.mint),
        _LegendRow('Low', AppColors.coral),
      ]);
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.muted))),
          const Text('--%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
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

  void _text(Canvas c, String s, Offset at,
      {bool centered = false, double size = 12, Color color = AppColors.muted}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centered ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, right = 22.0, top = 24.0, bottom = 30.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double y(num v) => top + h * (1 - v / 200);
    double x(num hr) => left + w * hr / 24;

    _text(canvas, 'mg/dL', Offset.zero);

    // target range band (70–180 mg/dL)
    canvas.drawRRect(
      RRect.fromLTRBR(left, y(180), left + w, y(70), const Radius.circular(8)),
      Paint()..color = AppColors.rangeBlue,
    );
    _text(canvas, 'Target 70–180', Offset(left + 8, y(180) + 4), size: 11, color: AppColors.sky);

    final grid = Paint()
      ..color = const Color(0xFFDDE2EA)
      ..strokeWidth = 1;
    for (final v in [0, 50, 100, 150, 200]) {
      _text(canvas, '$v', Offset(0, y(v) - 8));
      if (v == 0) {
        canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      } else {
        for (var dx = left; dx < left + w; dx += 8) {
          canvas.drawLine(Offset(dx, y(v)), Offset(math.min(dx + 4, left + w), y(v)), grid);
        }
      }
    }

    const labels = ['12 am', '6 am', '12 pm', '6 pm', '12 am'];
    for (var i = 0; i < labels.length; i++) {
      _text(canvas, labels[i], Offset(x(i * 6), size.height - 20), centered: true);
    }

    if (points.isEmpty) {
      _text(canvas, 'No readings yet', Offset(left + w / 2, y(135) - 8), centered: true, size: 14);
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
            colors: [AppColors.blue.withAlpha(70), AppColors.blue.withAlpha(0)],
          ).createShader(Rect.fromLTRB(left, top, left + w, top + h)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final last = Offset(x(sorted.last.dx), y(sorted.last.dy));
      canvas.drawCircle(last, 7, Paint()..color = Colors.white);
      canvas.drawCircle(last, 4.5, Paint()..color = AppColors.blue);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}