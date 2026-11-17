import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'common.dart';
import 'glucose_history_screen.dart';
import 'l10n.dart';
import 'manual_reading.dart';
import 'summary_screen.dart' show GlucoseChart;
import 'theme.dart';

/// "mm:ss" for the warm-up countdown.
String mmss(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Label key, colour and icon for the current sensor state. Never claims data that hasn't arrived.
(String, Color, IconData) sensorStatus(SensorSession s, AppPalette p) {
  return !s.paired
      ? ('status_no_sensor', p.muted, Icons.sensors_off_rounded)
      : s.warming
      ? ('status_warming', p.caution, Icons.timer_rounded)
      : s.latest != null
      ? ('status_receiving', p.normal, Icons.wifi_tethering_rounded)
      : ('status_paired', p.primary, Icons.link_rounded);
}

class SensorStatusPill extends StatelessWidget {
  const SensorStatusPill({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final (key, color, icon) = sensorStatus(context.sensor, context.palette);
    return StatusPill(context.tr(key), color, icon: icon, onDark: onDark);
  }
}

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // respect the system "reduce motion" setting
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PairingSheet(),
    );
    if (code == null || !mounted) return;
    AppScope.read<SensorSession>(context).pair(code);
  }

  Future<void> _confirmRemove() async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.sensors_off_rounded, color: p.critical),
        title: Text(ctx.tr('remove_title')),
        content: Text(ctx.tr('remove_body'), style: ctx.text.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.critical),
            child: Text(ctx.tr('remove')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) AppScope.read<SensorSession>(context).remove();
  }

  /// 0 = read from the sensor, 1 = type it in
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.sensor;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
        children: [
          PageHeader(
            context.tr('sensor_title'),
            subtitle: context.tr('sensor_subtitle'),
            trailing: const SensorStatusPill(),
          ),
          _modeSwitch(),
          if (_mode == 1) ...[
            const ManualReadingCard(),
          ] else if (s.paired) ...[
            _live(s),
            _history(s),
            _details(s),
            SoftButton(
              context.tr('view_summary'),
              icon: Icons.insights_rounded,
              onPressed: () => widget.onNavigate(1),
            ),
            const SizedBox(height: Gap.sm),
            Center(
              child: TextButton.icon(
                onPressed: _confirmRemove,
                style: TextButton.styleFrom(
                  foregroundColor: context.palette.critical,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(context.tr('remove_sensor')),
              ),
            ),
          ] else ...[
            _hero(),
            _steps(),
          ],
        ],
      ),
    );
  }

  // ---------- Sensor / Manual switch ----------
  Widget _modeSwitch() {
    final p = context.palette;
    Widget option(int i, IconData icon, String title, String sub) {
      final on = _mode == i;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? p.primary : p.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            child: InkWell(
              key: ValueKey('record-mode-$i'),
              borderRadius: BorderRadius.circular(Radii.lg),
              onTap: () => setState(() => _mode = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(Gap.md + 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: on ? p.primary : p.border),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: on ? p.onPrimary : p.primary),
                    const SizedBox(width: Gap.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: on ? p.onPrimary : p.ink,
                            ),
                          ),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: on ? p.onPrimary.withAlpha(220) : p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('record_how'), style: context.text.labelMedium),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              option(
                0,
                Icons.sensors_rounded,
                context.tr('mode_sensor'),
                context.tr('mode_sensor_sub'),
              ),
              const SizedBox(width: Gap.sm + 2),
              option(
                1,
                Icons.edit_note_rounded,
                context.tr('mode_manual'),
                context.tr('mode_manual_sub'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- not paired ----------
  Widget _hero() => AppCard(
    padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xl + 4),
    child: Column(
      children: [
        SizedBox(
          height: 180,
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (_float.value - .5) * 12),
              child: child,
            ),
            child: const FittedBox(child: _DexcomArt()),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(kSensorName, style: context.text.headlineMedium),
        const SizedBox(height: Gap.xs),
        Text(
          context.tr('sensor_desc'),
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: Gap.xl),
        // main action stays above the fold
        PrimaryButton(
          context.tr('sensor_apply'),
          icon: Icons.add_rounded,
          onPressed: _apply,
        ),
      ],
    ),
  );

  Widget _steps() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.tr('how_it_works')),
        const SizedBox(height: Gap.lg),
        _StepRow(1, context.tr('step_apply'), context.tr('step_apply_body')),
        _StepRow(2, context.tr('step_pair'), context.tr('step_pair_body')),
        _StepRow(
          3,
          context.tr('step_warmup'),
          context.tr('step_warmup_body'),
          last: true,
        ),
      ],
    ),
  );

  // ---------- paired ----------
  Widget _live(SensorSession s) {
    final p = context.palette;
    final latest = s.latest;
    final level = latest == null ? null : GlucoseLevel.of(latest.dy);
    const soft = Color(0xD9FFFFFF);
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
                  context.tr('current_glucose'),
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
                  ),
                ),
                const TextSpan(
                  text: '  mg/dL',
                  style: TextStyle(fontSize: 16, color: soft),
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
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: _HeroFact(
                  Icons.trending_flat_rounded,
                  context.tr('trend'),
                  '--',
                ),
              ),
              Expanded(
                child: _HeroFact(
                  Icons.schedule_rounded,
                  context.tr('last_update'),
                  latest == null
                      ? context.tr('no_data_yet')
                      : _hourLabel(latest.dx),
                ),
              ),
            ],
          ),
          if (s.warming) ...[
            const SizedBox(height: Gap.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.warmupProgress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: Colors.white,
                semanticsLabel: context.tr('status_warming'),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              context.tr('warmup_left', {'time': mmss(s.remaining)}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.tr('warmup_tip'),
              style: const TextStyle(color: soft, fontSize: 14),
            ),
          ] else if (latest == null) ...[
            const SizedBox(height: Gap.lg),
            Text(
              context.tr('waiting_first'),
              style: const TextStyle(color: soft, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  String _hourLabel(double hour) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(
          hour: hour.floor() % 24,
          minute: ((hour % 1) * 60).round() % 60,
        ),
      );

  Widget _history(SensorSession s) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          context.tr('glucose_history'),
          action: context.tr('view_all'),
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GlucoseHistoryScreen()),
          ),
        ),
        const SizedBox(height: Gap.md),
        SizedBox(height: 200, child: GlucoseChart(points: s.readings)),
      ],
    ),
  );

  Widget _details(SensorSession s) {
    final loc = MaterialLocalizations.of(context);
    final at = s.startedAt!;
    return SettingsGroup(context.tr('sensor_details'), [
      SettingsTile(
        Icons.sensors_rounded,
        context.tr('tab_sensor'),
        value: kSensorName,
      ),
      SettingsTile(
        Icons.event_available_rounded,
        context.tr('paired_at'),
        value:
            '${loc.formatShortMonthDay(at)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
      ),
      SettingsTile(
        Icons.pin_outlined,
        context.tr('pairing_code'),
        value: s.code,
      ),
      SettingsTile(
        Icons.hourglass_bottom_rounded,
        context.tr('sensor_life'),
        value: context.tr('sensor_life_value'),
      ),
    ]);
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.white),
      const SizedBox(width: Gap.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Numbered step with a connecting line to the next one.
class _StepRow extends StatelessWidget {
  const _StepRow(this.n, this.title, this.sub, {this.last = false});
  final int n;
  final String title, sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.primarySoft,
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: Gap.xs),
                    color: p.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: Gap.md + 2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: last ? 0 : Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: context.text.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Dexcom G7 illustration (drawn in code; swap for Image.asset when you have artwork) ----------
class _DexcomArt extends StatelessWidget {
  const _DexcomArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 270,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 214,
            height: 214,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [p.primarySoft, p.primarySoft.withAlpha(0)],
                stops: const [.6, 1],
              ),
            ),
          ),
          const Positioned(left: 40, top: 12, child: _Applicator()),
          const Positioned(right: 8, bottom: 14, child: _SensorPod()),
        ],
      ),
    );
  }
}

class _Applicator extends StatelessWidget {
  const _Applicator();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 96,
      height: 206,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 22),
          Text(
            'Dexcom',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.ink,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: p.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'G7',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: p.onPrimary,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 58,
            width: double.infinity,
            color: p.surfaceAlt,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 44,
                    height: 3,
                    margin: const EdgeInsets.symmetric(vertical: 3.5),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small oval G7 sensor sitting on its adhesive overpatch.
class _SensorPod extends StatelessWidget {
  const _SensorPod();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 118,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(54),
              color: p.surfaceAlt,
              border: Border.all(color: p.border, width: 1.5),
            ),
          ),
          Container(
            width: 80,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.surface, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.surface, p.border],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.primaryBright, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- guided pairing sheet ----------
class _PairingSheet extends StatefulWidget {
  const _PairingSheet();

  @override
  State<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<_PairingSheet> {
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
    final p = context.palette;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final canNext = _step != 1 || _code.text.length == 4;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Gap.xl + 4,
          0,
          Gap.xl + 4,
          Gap.xl + 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('pair_step', {'n': _step + 1}),
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 3,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              context.tr('pair_title_$_step'),
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: Gap.lg),
            _body(p),
            const SizedBox(height: Gap.xl + 4),
            Row(
              children: [
                if (_step > 0) ...[
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    style: TextButton.styleFrom(
                      foregroundColor: p.muted,
                      minimumSize: const Size(64, 56),
                    ),
                    child: Text(context.tr('back')),
                  ),
                  const SizedBox(width: Gap.sm),
                ],
                Expanded(
                  child: PrimaryButton(
                    context.tr(
                      _step == 0
                          ? 'next'
                          : (_step == 1 ? 'pair_sensor' : 'done'),
                    ),
                    onPressed: canNext ? _next : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppPalette p) {
    switch (_step) {
      case 0:
        return Column(
          children: [
            _Tip(Icons.cleaning_services_rounded, context.tr('tip_clean')),
            _Tip(Icons.rotate_right_rounded, context.tr('tip_twist')),
            _Tip(Icons.touch_app_rounded, context.tr('tip_press')),
            _Tip(Icons.healing_rounded, context.tr('tip_patch')),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('code_help'), style: context.text.bodyMedium),
            const SizedBox(height: Gap.lg),
            Directionality(
              textDirection: TextDirection
                  .ltr, // digits read left-to-right in both languages
              child: Semantics(
                label: context.tr('code_label'),
                child: TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 32,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      borderSide: BorderSide(color: p.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconCircle(Icons.timer_rounded, size: 52),
            const SizedBox(width: Gap.md + 2),
            Expanded(
              child: Text(
                context.tr('pair_done_body'),
                style: context.text.bodyLarge,
              ),
            ),
          ],
        );
    }
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.md + 2),
    child: Row(
      children: [
        IconCircle(icon, size: 40),
        const SizedBox(width: Gap.md + 2),
        Expanded(child: Text(text, style: context.text.bodyLarge)),
      ],
    ),
  );
}
