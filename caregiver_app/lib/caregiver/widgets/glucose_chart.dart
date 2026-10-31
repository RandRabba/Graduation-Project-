import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/text_styles.dart';

/// Line chart of glucose values (mg/dL) with the 70-180 target band.
///
/// Charts are always drawn left-to-right, also in Arabic, because time runs
/// left-to-right on a chart. Abnormal points use the critical colour so they
/// do not depend on the line colour alone.
class GlucoseChart extends StatelessWidget {
  const GlucoseChart({
    super.key,
    required this.values,
    required this.height,
    this.dotDiameter = 8,
    this.semanticLabel,
  });

  final List<int> values;
  final double height;
  final double dotDiameter;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        image: true,
        label: semanticLabel,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              values: values,
              band: pal.okBg,
              line: pal.sec,
              normalDot: pal.sec,
              abnormalDot: pal.crit,
              dotDiameter: dotDiameter,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.band,
    required this.line,
    required this.normalDot,
    required this.abnormalDot,
    required this.dotDiameter,
  });

  final List<int> values;
  final Color band;
  final Color line;
  final Color normalDot;
  final Color abnormalDot;
  final double dotDiameter;

  static const double _padLeft = 8;
  static const double _padRight = 8;
  static const double _padTop = 10;
  static const double _padBottom = 10;
  static const double _lo = 40;
  static const double _hi = 360;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    double xAt(int i) {
      if (values.length < 2) return size.width / 2;
      return _padLeft + i * (size.width - _padLeft - _padRight) / (values.length - 1);
    }

    double yAt(int v) {
      final double c = v.toDouble().clamp(_lo, _hi).toDouble();
      return _padTop + (_hi - c) / (_hi - _lo) * (size.height - _padTop - _padBottom);
    }

    // Target range band (70-180 mg/dL).
    final double yTop = yAt(180);
    final double yBottom = yAt(70);
    canvas.drawRRect(
      RRect.fromLTRBR(0, yTop, size.width, yBottom, const Radius.circular(4)),
      Paint()..color = band,
    );

    // Line.
    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
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

    // Points. Abnormal values get the critical colour.
    final Paint normalPaint = Paint()..color = normalDot;
    final Paint abnormalPaint = Paint()..color = abnormalDot;
    for (int i = 0; i < values.length; i++) {
      final int v = values[i];
      final bool abnormal = v < 70 || v > 180;
      canvas.drawCircle(
        Offset(xAt(i), yAt(v)),
        dotDiameter / 2,
        abnormal ? abnormalPaint : normalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    return old.values != values ||
        old.band != band ||
        old.line != line ||
        old.normalDot != normalDot ||
        old.abnormalDot != abnormalDot ||
        old.dotDiameter != dotDiameter;
  }
}

/// X-axis labels under a [GlucoseChart].
class ChartLabels extends StatelessWidget {
  const ChartLabels(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (final String l in labels) Text(l, style: context.subStyle(11)),
          ],
        ),
      ),
    );
  }
}
