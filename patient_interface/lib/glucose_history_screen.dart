import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'common.dart';
import 'l10n.dart';
import 'models.dart';
import 'repositories.dart';
import 'theme.dart';

/// Every stored glucose reading for the patient, newest first, loaded page by page.
class GlucoseHistoryScreen extends StatefulWidget {
  const GlucoseHistoryScreen({super.key});

  @override
  State<GlucoseHistoryScreen> createState() => _GlucoseHistoryScreenState();
}

class _GlucoseHistoryScreenState extends State<GlucoseHistoryScreen> {
  static const _page = 50;

  /// Keyed by id so a refresh or overlapping page never shows a reading twice.
  final _byId = <String, GlucoseReading>{};
  final _scroll = ScrollController();
  DateTime? _next;
  bool _loading = true, _more = false;
  Object? _error;

  List<GlucoseReading> get _sorted =>
      _byId.values.toList()..sort((a, b) => b.at.compareTo(a.at));

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<Paged<GlucoseReading>> _fetch(DateTime? before) =>
      context.repos.glucose.history(limit: _page, before: before);

  Future<void> _load() async {
    setState(() {
      _loading = _byId.isEmpty;
      _error = null;
    });
    try {
      final page = await _fetch(null);
      if (!mounted) return;
      setState(() {
        _byId
          ..clear()
          ..addAll({for (final r in page.items) r.id: r});
        _next = page.nextBefore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_more || _loading || _next == null) return;
    setState(() => _more = true);
    try {
      final page = await _fetch(_next);
      if (!mounted) return;
      setState(() {
        for (final r in page.items) {
          _byId[r.id] = r;
        }
        _next = page.nextBefore;
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<GlucoseAddResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddReadingSheet(),
    );
    if (added == null || !mounted) return;
    final alerts = added.alerts;
    showSnack(
      context,
      alerts.isEmpty
          ? context.tr('reading_saved')
          : context.tr('reading_saved_alert', {
              'alert': context.tr('alert_${alerts.first.type}'),
            }),
    );
    final api = context.api;
    await _load();
    if (!mounted) return;
    // keep the dashboard chart and alert badge in step
    AppScope.read<SensorSession>(context).loadToday(api).catchError((_) {});
    AppScope.read<AlertInbox>(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final readings = _sorted;
    return SubPage(
      title: context.tr('all_readings'),
      controller: _scroll,
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: context.tr('add_reading'),
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      children: [
        if (_loading)
          const LoadingState()
        else if (_error != null && readings.isEmpty)
          ErrorState(message: errorText(context, _error!), onRetry: _load)
        else if (readings.isEmpty) ...[
          EmptyState(
            icon: Icons.water_drop_outlined,
            title: context.tr('no_readings'),
            message: context.tr('no_readings_body'),
          ),
          SoftButton(
            context.tr('add_reading'),
            icon: Icons.add_rounded,
            onPressed: _add,
          ),
        ] else ...[
          ..._grouped(readings),
          if (_next != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: _more
                  ? const Center(child: CircularProgressIndicator())
                  : SoftButton(
                      context.tr('load_older'),
                      icon: Icons.history_rounded,
                      onPressed: _loadMore,
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Center(
                child: Text(
                  context.tr('n_readings_total', {'n': readings.length}),
                  style: context.text.labelSmall,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// One card per calendar day.
  List<Widget> _grouped(List<GlucoseReading> readings) {
    final loc = MaterialLocalizations.of(context);
    final days = <DateTime, List<GlucoseReading>>{};
    for (final r in readings) {
      days
          .putIfAbsent(DateTime(r.at.year, r.at.month, r.at.day), () => [])
          .add(r);
    }
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return [
      for (final MapEntry(key: day, value: list) in days.entries)
        SettingsGroup(
          day == today ? context.tr('today') : loc.formatFullDate(day),
          [for (final r in list) _ReadingRow(r)],
        ),
    ];
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow(this.r);
  final GlucoseReading r;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final level = GlucoseLevel.of(r.value);
    final source = context.tr(
      'source_${['manual', 'dexcom', 'meter'].contains(r.source) ? r.source : 'other'}',
    );
    final detail = [
      source,
      if (r.sensor != null) r.sensor!,
      if (r.note != null && r.note!.isNotEmpty) r.note!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          IconCircle(level.icon, color: level.color(p), size: 38),
          const SizedBox(width: Gap.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${r.value.round()}',
                        style: context.text.titleLarge,
                      ),
                      TextSpan(text: ' mg/dL', style: context.text.labelSmall),
                    ],
                  ),
                ),
                Text(
                  detail,
                  style: context.text.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeLabel(context, r.at), style: context.text.labelMedium),
              const SizedBox(height: Gap.xs),
              Text(
                context.tr(level.labelKey),
                style: context.text.labelSmall!.copyWith(color: level.color(p)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Manual entry (e.g. a finger-stick meter). Pops with the saved result.
class _AddReadingSheet extends StatefulWidget {
  const _AddReadingSheet();

  @override
  State<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<_AddReadingSheet> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _note = TextEditingController();
  DateTime _at = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t == null) return;
    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(
      () => _at = picked.isAfter(DateTime.now()) ? DateTime.now() : picked,
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      final res = await context.repos.glucose.add([
        GlucoseReading(
          id: '',
          value: double.parse(_value.text),
          at: _at,
          source: 'manual',
          note: note.isEmpty ? null : note,
        ),
      ]);
      if (!mounted) return;
      if (res.created.isEmpty) {
        setState(() => _error = context.tr('reading_duplicate'));
        return;
      }
      Navigator.pop(context, res);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.xl + 4, 0, Gap.xl + 4, Gap.xl + 4),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('add_reading'), style: context.text.headlineMedium),
            const SizedBox(height: Gap.xs),
            Text(
              context.tr('add_reading_body'),
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 20 || n > 600
                    ? context.tr('v_glucose')
                    : null;
              },
              decoration: InputDecoration(
                labelText: context.tr('glucose_value'),
                suffixText: 'mg/dL',
                prefixIcon: const Icon(Icons.water_drop_outlined),
              ),
            ),
            const SizedBox(height: Gap.md),
            InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: _pickTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('measured_at'),
                  prefixIcon: const Icon(Icons.schedule_rounded),
                ),
                child: Text(dateTimeLabel(context, _at)),
              ),
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _note,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: context.tr('note_optional'),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.sm),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              context.tr(_busy ? 'saving' : 'save'),
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
