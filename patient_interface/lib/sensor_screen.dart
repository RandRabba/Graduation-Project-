import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> with SingleTickerProviderStateMixin {
  static const _warmup = Duration(minutes: 30);

  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  Timer? _timer;
  DateTime? _startedAt; // set when the sensor has been paired

  @override
  void dispose() {
    _float.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _paired => _startedAt != null;

  Duration get _remaining {
    final s = _startedAt;
    if (s == null) return _warmup;
    final left = _warmup - DateTime.now().difference(s);
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _apply() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _PairingSheet(),
    );
    if (code == null || !mounted) return;
    // TODO: hand `code` to your real Dexcom pairing logic (BLE / API).
    setState(() => _startedAt = DateTime.now());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == Duration.zero) t.cancel();
    });
  }

  void _remove() {
    _timer?.cancel();
    setState(() => _startedAt = null);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Row(children: [
            const Text(kAppName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: .4)),
            const Spacer(),
            _statusPill(),
          ]),
          const SizedBox(height: 18),
          _hero(),
          const SizedBox(height: 6),
          if (_paired)
            _statusCard()
          else ...[
            _steps(),
            const SizedBox(height: 10),
            PrimaryButton('Apply sensor', icon: Icons.add_rounded, onPressed: _apply),
          ],
        ]),
      );

  Widget _statusPill() {
    if (!_paired) return const StatusPill('No sensor', AppColors.muted);
    return _remaining > Duration.zero
        ? const StatusPill('Warming up', AppColors.high)
        : const StatusPill('Connected', AppColors.accent);
  }

  Widget _hero() => AppCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(children: [
          SizedBox(
            height: 230,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(0, (_float.value - .5) * 12), child: child),
              child: const _DexcomArt(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(kSensorName, style: AppText.h1),
          const SizedBox(height: 6),
          const Text('Continuous glucose sensor · up to 10 days', textAlign: TextAlign.center, style: AppText.label),
        ]),
      );

  Widget _steps() => const AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('How it works'),
          SizedBox(height: 16),
          _StepRow(1, 'Apply', 'Attach the sensor to the back of your upper arm.'),
          SizedBox(height: 16),
          _StepRow(2, 'Pair', 'Enter the 4-digit code printed on the applicator.'),
          SizedBox(height: 16),
          _StepRow(3, 'Warm-up', 'Wait about 30 minutes for your first reading.'),
        ]),
      );

  Widget _statusCard() {
    final left = _remaining;
    final warming = left > Duration.zero;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final progress = 1 - left.inSeconds / _warmup.inSeconds;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconCircle(warming ? Icons.timer_rounded : Icons.check_circle_rounded,
              color: warming ? AppColors.high : AppColors.accent, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(warming ? 'Warming up' : 'Sensor active', style: AppText.h2),
              const SizedBox(height: 2),
              Text(warming ? 'First reading in about $mm:$ss' : 'Your readings now appear in Summary.',
                  style: AppText.label),
            ]),
          ),
        ]),
        if (warming) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.accentSoft,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Avoid heavy exercise during warm-up.', style: AppText.label),
        ],
        const SizedBox(height: 20),
        SoftButton('View summary', icon: Icons.insights_rounded, onPressed: () => widget.onNavigate(1)),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _remove,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Remove sensor'),
          ),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.n, this.title, this.sub);
  final int n;
  final String title, sub;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentSoft),
          child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(sub, style: AppText.label),
          ]),
        ),
      ]);
}

// ---------- Dexcom G7 illustration (drawn in code; swap for Image.asset when you have artwork) ----------
class _DexcomArt extends StatelessWidget {
  const _DexcomArt();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        height: 230,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 210,
            height: 210,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentSoft),
          ),
          const Positioned(left: 40, top: 12, child: _Applicator()),
          const Positioned(right: 8, bottom: 14, child: _SensorPod()),
        ]),
      );
}

class _Applicator extends StatelessWidget {
  const _Applicator();

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 206,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.line, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x1A15221C), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: Column(children: [
          const SizedBox(height: 22),
          const Text('Dexcom',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: .3)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
            child: const Text('G7', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.accent),
          ),
          const SizedBox(height: 14),
          Container(
            height: 58,
            width: double.infinity,
            color: const Color(0xFFE3E8E5),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 44,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 3.5),
                  decoration: BoxDecoration(color: const Color(0x2215221C), borderRadius: BorderRadius.circular(2)),
                ),
            ]),
          ),
        ]),
      );
}

/// The small oval G7 sensor sitting on its adhesive overpatch.
class _SensorPod extends StatelessWidget {
  const _SensorPod();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 118,
        height: 108,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(54),
              color: const Color(0xFFF1F4F2),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
          ),
          Container(
            width: 80,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFD9DFDC)],
              ),
              boxShadow: const [BoxShadow(color: Color(0x2615221C), blurRadius: 14, offset: Offset(0, 8))],
            ),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x2215221C), width: 1.5),
              ),
            ),
          ),
        ]),
      );
}

// ---------- guided pairing sheet ----------
class _PairingSheet extends StatefulWidget {
  const _PairingSheet();

  @override
  State<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<_PairingSheet> {
  static const _titles = ['Apply your sensor', 'Enter the sensor code', 'You’re all set'];
  int _step = 0;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 2) {
      Navigator.pop(context, _code.text);
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final canNext = _step != 1 || _code.text.length == 4;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + inset),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Step ${_step + 1} of 3', style: AppText.label),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            minHeight: 6,
            backgroundColor: AppColors.accentSoft,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text(_titles[_step], style: AppText.h1),
        const SizedBox(height: 16),
        _body(),
        const SizedBox(height: 24),
        Row(children: [
          if (_step > 0) ...[
            TextButton(
              onPressed: () => setState(() => _step--),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted, minimumSize: const Size(64, 56)),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: PrimaryButton(
              _step == 0 ? 'Next' : (_step == 1 ? 'Pair sensor' : 'Done'),
              onPressed: canNext ? _next : null,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return const Column(children: [
          _Tip(Icons.cleaning_services_rounded, 'Clean and dry the back of your upper arm.'),
          _Tip(Icons.rotate_right_rounded, 'Twist off the applicator cap.'),
          _Tip(Icons.touch_app_rounded, 'Press it against your skin and push the button.'),
          _Tip(Icons.healing_rounded, 'Press the adhesive patch down around the sensor.'),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('You’ll find the 4-digit code on the applicator. Keep the applicator in case you need it again.',
              style: AppText.label),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: const TextStyle(color: AppColors.hint),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
        ]);
      default:
        return const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(Icons.timer_rounded, size: 52),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Warm-up takes about 30 minutes. You can leave this screen — your first reading will appear in Summary.',
              style: AppText.body,
            ),
          ),
        ]);
    }
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          IconCircle(icon, size: 40),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppText.body)),
        ]),
      );
}
