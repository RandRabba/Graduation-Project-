import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9E9FF), AppColors.page],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Row(children: [
                ShaderMask(
                  shaderCallback: (r) => brandGradient.createShader(r),
                  child: const Text(kAppName,
                      style: TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1)),
                ),
                const Spacer(),
                _statusChip(),
              ]),
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _art()))),
              _steps(),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Apply Sensor',
                icon: Icons.sensors_rounded,
                // TODO: start sensor pairing (BLE / NFC) here.
                onTap: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('TODO: start sensor pairing'))),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      );

  Widget _statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: softShadow),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 9, color: AppColors.amber),
          SizedBox(width: 6),
          Text('No sensor',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ]),
      );

  Widget _steps() => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: softShadow),
        child: const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Step(Icons.qr_code_scanner_rounded, 'Scan', AppColors.blue),
          _Step(Icons.touch_app_rounded, 'Attach', AppColors.teal),
          _Step(Icons.bluetooth_searching_rounded, 'Pair', AppColors.violet),
        ]),
      );

  /// Placeholder illustration drawn in code. Swap the `_device()` call for Image.asset(...) with real artwork.
  Widget _art() => SizedBox(
        width: 320,
        height: 340,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final dy = math.sin(t * 2 * math.pi) * 8;
            return Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: CustomPaint(painter: _BackdropPainter(t))),
              Transform.translate(offset: Offset(0, dy), child: _device()),
            ]);
          },
        ),
      );

  Widget _device() => SizedBox(
        width: 280,
        height: 310,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 170,
            height: 270,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(85),
              border: Border.all(color: Colors.white, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFE1E5EC)],
              ),
              boxShadow: const [BoxShadow(color: Color(0x2A3B6EFF), blurRadius: 40, offset: Offset(0, 24))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.teal),
              ),
              const SizedBox(height: 22),
              Container(
                width: 56,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0x12000000), borderRadius: BorderRadius.circular(28)),
                child: const RotatedBox(
                  quarterTurns: 3,
                  child: Text(kAppName,
                      style: TextStyle(
                          fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.w600, color: Color(0xFF9097A6))),
                ),
              ),
            ]),
          ),
          Positioned(
            right: 0,
            bottom: 14,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                gradient: const RadialGradient(colors: [Colors.white, Color(0xFFE3E7EF)]),
                boxShadow: const [BoxShadow(color: Color(0x333B6EFF), blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: const Icon(Icons.sensors_rounded, color: AppColors.sky, size: 34),
            ),
          ),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        IconBubble(icon, color, size: 44),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ]);
}

/// Pulsing rings + a gradient ribbon behind the device.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        100 + phase * 60,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.blue.withAlpha(((1 - phase) * 60).round()),
      );
    }
    final ribbon = Path()
      ..moveTo(0, s.height * .78)
      ..cubicTo(s.width * .25, s.height * .42, s.width * .4, s.height * .95, s.width * .62, s.height * .62)
      ..cubicTo(s.width * .8, s.height * .35, s.width * .92, s.height * .3, s.width * 1.05, s.height * .08);
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..shader = brandGradient.createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}