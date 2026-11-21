import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/text_styles.dart';

/// Where the points of a chart sit, shared by the painter, the tap handling and
/// the x-axis labels so all three line up.
class _Geom {
  const _Geom._();

  /// Width reserved on the left for the mg/dL scale.
  static const double axisWidth = 34;
  static const double padRight = 10;
  static const double padTop = 12;
  static const double padBottom = 10;
  static const double inset = 8;

  /// Value range drawn by the chart; readings outside are clamped.
  static const double lo = 40;
  static const double hi = 360;

  /// Target range band and the scale ticks (mg/dL).
  static const int targetLow = 70;
  static const int targetHigh = 180;
  static const List<int> ticks = <int>[70, 120, 180, 240, 300];

  static double xAt(int i, int n, double width) {
    final double left = axisWidth + inset;
    final double right = width - padRight;
    if (n < 2) return (left + right) / 2;
    return left + i * (right - left) / (n - 1);
  }

  static double yAt(num v, double height) {
    final double c = v.toDouble().clamp(lo, hi).toDouble();
    return padTop + (hi - c) / (hi - lo) * (height - padTop - padBottom);
  }
}

/// Line chart of glucose values (mg/dL) with a mg/dL scale, light grid lines and
/// the 70-180 target band.
///
/// Tap a point to see its value (and its label, such as the day or the time).
/// Tap it again, or tap anywhere else, to close it.
///
/// Charts are always drawn left-to-right, also in Arabic, because time runs
/// left-to-right on a chart. Abnormal points use the critical colour so they do
/// not depend on the line colour alone.
class GlucoseChart extends StatefulWidget {
  const GlucoseChart({
    super.key,
    required this.values,
    required this.height,
    this.labels,
    this.unit = 'mg/dL',
    this.dotDiameter = 8,
    this.semanticLabel,
  });

  final List<int> values;
  final double height;

  /// One label per value (for the tapped-point bubble). Ignored when its length
  /// differs from [values].
  final List<String>? labels;
  final String unit;
  final double dotDiameter;
  final String? semanticLabel;

  @override
  State<GlucoseChart> createState() => _GlucoseChartState();
}

class _GlucoseChartState extends State<GlucoseChart> {
  int? _selected;

  @override
  void didUpdateWidget(GlucoseChart old) {
    super.didUpdateWidget(old);
    final int? i = _selected;
    if (i != null && (i >= widget.values.length || old.values != widget.values)) {
      _selected = null;
    }
  }

  void _onTap(Offset p, double width) {
    final int n = widget.values.length;
    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < n; i++) {
      final double dx = (p.dx - _Geom.xAt(i, n, width)).abs();
      if (dx < bestDist) {
        bestDist = dx;
        best = i;
      }
    }
    // Reach: half the gap between points, but never less than a finger.
    final double gap = n < 2 ? width : (width - _Geom.axisWidth - _Geom.padRight) / (n - 1);
    final double reach = gap / 2 < 22.0 ? 22.0 : gap / 2;
    setState(() {
      if (best == null || bestDist > reach || best == _selected) {
        _selected = null;
      } else {
        _selected = best;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final List<String>? labels =
        widget.labels != null && widget.labels!.length == widget.values.length ? widget.labels : null;
    final int? sel = _selected;
    final String? bubbleTitle = sel == null ? null : '${widget.values[sel]} ${widget.unit}';
    final String? bubbleSub = sel == null || labels == null ? null : labels[sel];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        image: true,
        label: widget.semanticLabel,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails d) => _onTap(d.localPosition, width),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ChartPainter(
                    values: widget.values,
                    band: pal.okBg,
                    grid: pal.line,
                    axisText: pal.sub,
                    line: pal.sec,
                    normalDot: pal.sec,
                    abnormalDot: pal.crit,
                    ring: pal.card,
                    bubbleBg: pal.text,
                    bubbleFg: pal.bg,
                    dotDiameter: widget.dotDiameter,
                    selected: sel,
                    bubbleTitle: bubbleTitle,
                    bubbleSub: bubbleSub,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.band,
    required this.grid,
    required this.axisText,
    required this.line,
    required this.normalDot,
    required this.abnormalDot,
    required this.ring,
    required this.bubbleBg,
    required this.bubbleFg,
    required this.dotDiameter,
    required this.selected,
    required this.bubbleTitle,
    required this.bubbleSub,
  });

  final List<int> values;
  final Color band;
  final Color grid;
  final Color axisText;
  final Color line;
  final Color normalDot;
  final Color abnormalDot;
  final Color ring;
  final Color bubbleBg;
  final Color bubbleFg;
  final double dotDiameter;
  final int? selected;
  final String? bubbleTitle;
  final String? bubbleSub;

  TextPainter _text(String s, double size, Color color, FontWeight weight) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final int n = values.length;
    final double h = size.height;
    final double w = size.width;
    double xAt(int i) => _Geom.xAt(i, n, w);
    double yAt(num v) => _Geom.yAt(v, h);

    // Target range band (70-180 mg/dL).
    canvas.drawRRect(
      RRect.fromLTRBR(
        _Geom.axisWidth,
        yAt(_Geom.targetHigh),
        w,
        yAt(_Geom.targetLow),
        const Radius.circular(4),
      ),
      Paint()..color = band,
    );

    // Grid lines and the mg/dL scale.
    final Paint gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final int tick in _Geom.ticks) {
      final double y = yAt(tick);
      canvas.drawLine(Offset(_Geom.axisWidth, y), Offset(w, y), gridPaint);
      final TextPainter tp = _text('$tick', 10.5, axisText, FontWeight.w500);
      tp.paint(canvas, Offset(_Geom.axisWidth - 6 - tp.width, y - tp.height / 2));
    }

    // Line.
    final Path path = Path();
    for (int i = 0; i < n; i++) {
      final double x = xAt(i);
      final double y = yAt(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Guide line under the tapped point.
    final int? sel = selected;
    if (sel != null && sel < n) {
      canvas.drawLine(
        Offset(xAt(sel), _Geom.padTop / 2),
        Offset(xAt(sel), h - _Geom.padBottom / 2),
        Paint()
          ..color = line.withAlpha(90)
          ..strokeWidth = 1.5,
      );
    }

    // Points. Abnormal values get the critical colour.
    final Paint normalPaint = Paint()..color = normalDot;
    final Paint abnormalPaint = Paint()..color = abnormalDot;
    for (int i = 0; i < n; i++) {
      final int v = values[i];
      final bool abnormal = v < _Geom.targetLow || v > _Geom.targetHigh;
      final Offset c = Offset(xAt(i), yAt(v));
      if (i == sel) {
        canvas.drawCircle(c, dotDiameter / 2 + 4, Paint()..color = ring);
        canvas.drawCircle(c, dotDiameter / 2 + 2.5, abnormal ? abnormalPaint : normalPaint);
        canvas.drawCircle(c, dotDiameter / 2 - 1, Paint()..color = ring);
      } else {
        canvas.drawCircle(c, dotDiameter / 2, abnormal ? abnormalPaint : normalPaint);
      }
    }

    // Bubble with the tapped value.
    if (sel != null && sel < n && bubbleTitle != null) {
      final TextPainter title = _text(bubbleTitle!, 13, bubbleFg, FontWeight.w700);
      final TextPainter? sub =
          bubbleSub == null ? null : _text(bubbleSub!, 11, bubbleFg.withAlpha(210), FontWeight.w500);
      final double bw = (sub != null && sub.width > title.width ? sub.width : title.width) + 20;
      final double bh = 12 + title.height + (sub == null ? 0 : sub.height + 1);
      final Offset c = Offset(xAt(sel), yAt(values[sel]));
      double left = c.dx - bw / 2;
      if (left < _Geom.axisWidth) left = _Geom.axisWidth;
      if (left + bw > w) left = w - bw;
      double top = c.dy - bh - 12;
      if (top < 0) top = c.dy + 12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, bw, bh), const Radius.circular(10)),
        Paint()..color = bubbleBg,
      );
      title.paint(canvas, Offset(left + (bw - title.width) / 2, top + 6));
      if (sub != null) {
        sub.paint(canvas, Offset(left + (bw - sub.width) / 2, top + 6 + title.height + 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    return old.values != values ||
        old.band != band ||
        old.grid != grid ||
        old.axisText != axisText ||
        old.line != line ||
        old.normalDot != normalDot ||
        old.abnormalDot != abnormalDot ||
        old.ring != ring ||
        old.bubbleBg != bubbleBg ||
        old.bubbleFg != bubbleFg ||
        old.dotDiameter != dotDiameter ||
        old.selected != selected ||
        old.bubbleTitle != bubbleTitle ||
        old.bubbleSub != bubbleSub;
  }
}

/// X-axis labels under a [GlucoseChart], one per point, drawn at the same x
/// positions as the points.
class ChartLabels extends StatelessWidget {
  const ChartLabels(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.subStyle(11);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth;
            const double slot = 40;
            return SizedBox(
              height: 16,
              width: width,
              child: Stack(
                children: <Widget>[
                  for (int i = 0; i < labels.length; i++)
                    Positioned(
                      left: _Geom.xAt(i, labels.length, width) - slot / 2,
                      width: slot,
                      top: 0,
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: style,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
