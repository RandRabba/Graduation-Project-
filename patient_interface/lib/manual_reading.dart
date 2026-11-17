import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'common.dart';
import 'glucose_history_screen.dart';
import 'l10n.dart';
import 'models.dart';
import 'repositories.dart';
import 'theme.dart';

/// Optional context for a manual reading, saved as the reading's note.
const kReadingTypes = ['fasting', 'before_meal', 'after_meal', 'random'];

/// One-screen manual glucose entry: type the number, optionally pick a type, save.
class ManualReadingCard extends StatefulWidget {
  const ManualReadingCard({super.key});

  @override
  State<ManualReadingCard> createState() => _ManualReadingCardState();
}

class _ManualReadingCardState extends State<ManualReadingCard> {
  final _value = TextEditingController();
  final _focus = FocusNode();
  String? _type;
  bool _busy = false;
  bool _touched = false;
  String? _error;

  /// Set once saved; switches the card to its confirmation state.
  ({double value, String? type, DateTime at, bool alert})? _saved;

  double? get _number => double.tryParse(_value.text);
  bool get _valid {
    final n = _number;
    return n != null && n >= 20 && n <= 600;
  }

  @override
  void dispose() {
    _value.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    if (!_valid || _busy) return;
    final value = _number!;
    final at = DateTime.now();
    final typeLabel = _type == null ? null : context.tr('rt_$_type');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final GlucoseAddResult res = await context.repos.glucose.add([
        GlucoseReading(
          id: '',
          value: value,
          at: at,
          source: 'manual',
          note: typeLabel,
        ),
      ]);
      if (!mounted) return;
      if (res.created.isEmpty) {
        setState(() => _error = context.tr('reading_duplicate'));
        return;
      }
      AppScope.read<SensorSession>(context).addLocal(at, value);
      AppScope.read<AlertInbox>(context).refresh();
      _focus.unfocus();
      setState(
        () => _saved = (
          value: value,
          type: _type,
          at: at,
          alert: res.alerts.isNotEmpty,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _again() => setState(() {
    _saved = null;
    _value.clear();
    _type = null;
    _touched = false;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: saved == null
          ? KeyedSubtree(key: const ValueKey('form'), child: _form())
          : KeyedSubtree(
              key: const ValueKey('saved'),
              child: _confirmation(saved),
            ),
    );
  }

  Widget _form() {
    final p = context.palette;
    final n = _number;
    final level = _valid ? GlucoseLevel.of(n!) : null;
    final showError = _touched && _value.text.isNotEmpty && !_valid;
    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconCircle(Icons.edit_note_rounded, size: 44),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('manual_title'),
                      style: context.text.titleLarge,
                    ),
                    Text(
                      context.tr('manual_body'),
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          // the number is the whole task, so it gets the biggest field on the screen
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: showError
                    ? p.critical
                    : (_focus.hasFocus ? p.primary : p.border),
                width: 1.5,
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Semantics(
                      label: context.tr('glucose_value'),
                      child: TextField(
                        key: const ValueKey('manual-value'),
                        controller: _value,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        maxLength: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        onTap: () => setState(() {}),
                        onSubmitted: (_) => _save(),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                          height: 1.1,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000',
                          hintStyle: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: p.border,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'mg/dL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            height: 30,
            child: Center(
              child: showError
                  ? Text(
                      context.tr('v_glucose'),
                      style: context.text.bodyMedium!.copyWith(
                        color: p.critical,
                      ),
                    )
                  : level != null
                  ? StatusPill(
                      context.tr(level.labelKey),
                      level.color(p),
                      icon: level.icon,
                    )
                  : Text(
                      context.tr('manual_range_hint'),
                      style: context.text.labelSmall,
                    ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(context.tr('reading_type'), style: context.text.labelMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final t in kReadingTypes)
                ChoiceChip(
                  label: Text(context.tr('rt_$t')),
                  selected: _type == t,
                  showCheckmark: false,
                  selectedColor: p.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _type == t ? p.onPrimary : p.ink,
                  ),
                  // tap again to clear: the type is optional
                  onSelected: (on) => setState(() => _type = on ? t : null),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: p.muted),
              const SizedBox(width: Gap.xs),
              Text(
                context.tr('recorded_now', {
                  'time': timeLabel(context, DateTime.now()),
                }),
                style: context.text.labelSmall,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Gap.md),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: Gap.xl),
          PrimaryButton(
            context.tr(_busy ? 'saving' : 'save_reading'),
            icon: Icons.check_rounded,
            onPressed: _busy || !_valid ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _confirmation(
    ({double value, String? type, DateTime at, bool alert}) s,
  ) {
    final p = context.palette;
    final level = GlucoseLevel.of(s.value);
    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.normal.withAlpha(30),
            ),
            child: Icon(Icons.check_rounded, size: 40, color: p.normal),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            context.tr('reading_saved_title'),
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: Gap.md),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${s.value.round()}',
                  style: context.text.displaySmall,
                ),
                TextSpan(
                  text: '  mg/dL',
                  style: TextStyle(fontSize: 16, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              StatusPill(
                context.tr(level.labelKey),
                level.color(p),
                icon: level.icon,
              ),
              if (s.type != null)
                StatusPill(context.tr('rt_${s.type}'), p.primary),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(dateTimeLabel(context, s.at), style: context.text.bodyMedium),
          if (s.alert) ...[
            const SizedBox(height: Gap.md),
            Text(
              context.tr('manual_saved_alert'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!.copyWith(color: level.color(p)),
            ),
          ],
          const SizedBox(height: Gap.xl),
          PrimaryButton(
            context.tr('add_another'),
            icon: Icons.add_rounded,
            onPressed: _again,
          ),
          const SizedBox(height: Gap.sm),
          SoftButton(
            context.tr('all_readings'),
            icon: Icons.history_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlucoseHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
