import 'package:flutter/material.dart';
import 'app_state.dart';
import 'common.dart';
import 'l10n.dart';
import 'models.dart';
import 'theme.dart';

const _categories = [
  ('glucose', Icons.water_drop_rounded),
  ('meal', Icons.restaurant_rounded),
  ('appointment', Icons.medical_services_rounded),
  ('general', Icons.favorite_rounded),
];

IconData _categoryIcon(String c) =>
    _categories.firstWhere((x) => x.$1 == c, orElse: () => _categories.last).$2;

/// Next time, or "Ended" for a one-off in the past, plus how it repeats.
String _schedule(BuildContext context, Reminder r) {
  final next = r.nextAfter(DateTime.now());
  final when = next == null
      ? context.tr('reminder_past')
      : dateTimeLabel(context, next);
  return '$when · ${context.tr('repeat_${r.repeat.name}')}';
}

/// Shows a snack if notifications are blocked, so the patient knows saved reminders won't ring.
Future<void> _ensurePermission(BuildContext context) async {
  final scheduler = AppScope.read<ReminderList>(context).scheduler;
  bool granted;
  try {
    granted = await scheduler.requestPermission();
  } catch (_) {
    granted = false;
  }
  if (!granted && context.mounted) {
    showSnack(context, context.tr('notifications_off'));
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = AppScope.read<ReminderList>(context);
    setState(() {
      _loading = !list.loaded;
      _error = null;
    });
    try {
      await list.load();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edit([Reminder? r]) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ReminderEditor(reminder: r)));

  Future<void> _toggle(Reminder r, bool on) async {
    try {
      await AppScope.read<ReminderList>(context).toggle(r, on);
      if (on && mounted) await _ensurePermission(context);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = context.reminders;
    final now = DateTime.now();
    final upcoming = [
      for (final r in list.items)
        if (r.enabled && r.nextAfter(now) != null) r,
    ]..sort((a, b) => a.nextAfter(now)!.compareTo(b.nextAfter(now)!));
    final rest = [
      for (final r in list.items)
        if (!upcoming.contains(r)) r,
    ];
    return SubPage(
      title: context.tr('reminders_title'),
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: context.tr('add_reminder'),
          onPressed: _edit,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.lg),
          child: Text(
            context.tr('reminders_subtitle'),
            style: context.text.bodyMedium,
          ),
        ),
        if (_loading)
          const LoadingState()
        else if (_error != null && list.items.isEmpty)
          ErrorState(message: errorText(context, _error!), onRetry: _load)
        else if (list.items.isEmpty) ...[
          EmptyState(
            icon: Icons.notifications_active_outlined,
            title: context.tr('no_reminders'),
            message: context.tr('no_reminders_body'),
          ),
          PrimaryButton(
            context.tr('add_reminder'),
            icon: Icons.add_rounded,
            onPressed: _edit,
          ),
        ] else ...[
          if (upcoming.isNotEmpty) ...[
            SettingsGroup(context.tr('upcoming'), [
              for (final r in upcoming)
                _ReminderTile(
                  r,
                  onTap: () => _edit(r),
                  onToggle: (v) => _toggle(r, v),
                ),
            ]),
            const SizedBox(height: Gap.sm),
          ],
          if (rest.isNotEmpty)
            SettingsGroup(context.tr('reminders_inactive'), [
              for (final r in rest)
                _ReminderTile(
                  r,
                  onTap: () => _edit(r),
                  onToggle: (v) => _toggle(r, v),
                ),
            ]),
        ],
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile(this.r, {required this.onTap, required this.onToggle});
  final Reminder r;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Gap.lg,
        Gap.md,
        Gap.sm,
        Gap.md,
      ),
      child: Row(
        children: [
          IconCircle(
            _categoryIcon(r.category),
            size: 38,
            color: r.enabled ? null : context.palette.muted,
          ),
          const SizedBox(width: Gap.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: context.text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(_schedule(context, r), style: context.text.bodyMedium),
                if (r.description.isNotEmpty)
                  Text(
                    r.description,
                    style: context.text.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Switch(value: r.enabled, onChanged: onToggle),
        ],
      ),
    ),
  );
}

/// Create (no [reminder]) or edit a reminder.
class ReminderEditor extends StatefulWidget {
  const ReminderEditor({super.key, this.reminder});
  final Reminder? reminder;

  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.reminder?.title);
  late final _description = TextEditingController(
    text: widget.reminder?.description,
  );
  late String _category = widget.reminder?.category ?? 'glucose';
  late DateTime _at = widget.reminder?.dueAt ?? _defaultTime();
  late ReminderRepeat _repeat = widget.reminder?.repeat ?? ReminderRepeat.none;
  late bool _enabled = widget.reminder?.enabled ?? true;
  bool _busy = false;
  String? _error;

  static DateTime _defaultTime() {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(now) ? now : _at,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(
        () => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute),
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t != null) {
      setState(
        () => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute),
      );
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_repeat == ReminderRepeat.none &&
        _enabled &&
        !_at.isAfter(DateTime.now())) {
      setState(() => _error = context.tr('v_reminder_future'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final reminder = Reminder(
      id: widget.reminder?.id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category,
      dueAt: _at,
      repeat: _repeat,
      enabled: _enabled,
    );
    try {
      await AppScope.read<ReminderList>(context).save(reminder);
      if (!mounted) return;
      if (_enabled) await _ensurePermission(context);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: p.critical),
        title: Text(ctx.tr('delete_reminder_title')),
        content: Text(
          ctx.tr('delete_reminder_body'),
          style: ctx.text.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.critical),
            child: Text(ctx.tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.read<ReminderList>(context).remove(widget.reminder!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final p = context.palette;
    return SubPage(
      title: context.tr(
        widget.reminder == null ? 'add_reminder' : 'edit_reminder',
      ),
      children: [
        Form(
          key: _form,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? context.tr('v_required')
                      : null,
                  decoration: InputDecoration(
                    labelText: context.tr('reminder_title'),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _description,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr('reminder_description'),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(context.tr('category'), style: context.text.labelMedium),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final (key, icon) in _categories)
                      ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 18,
                          color: _category == key ? p.onPrimary : p.primary,
                        ),
                        label: Text(context.tr('cat_$key')),
                        selected: _category == key,
                        showCheckmark: false,
                        selectedColor: p.primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _category == key ? p.onPrimary : p.ink,
                        ),
                        onSelected: (_) => setState(() => _category = key),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                Text(context.tr('repeat'), style: context.text.labelMedium),
                const SizedBox(height: Gap.sm),
                PillTabs(
                  labels: [
                    for (final r in ReminderRepeat.values)
                      context.tr('repeat_${r.name}'),
                  ],
                  index: _repeat.index,
                  onChanged: (i) =>
                      setState(() => _repeat = ReminderRepeat.values[i]),
                ),
              ],
            ),
          ),
        ),
        SettingsGroup(context.tr('when'), [
          SettingsTile(
            Icons.event_rounded,
            context.tr(_repeat == ReminderRepeat.none ? 'date' : 'starts_on'),
            value: loc.formatMediumDate(_at),
            onTap: _pickDate,
          ),
          SettingsTile(
            Icons.schedule_rounded,
            context.tr('time'),
            value: timeLabel(context, _at),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(
              Gap.lg,
              Gap.xs,
              Gap.md,
              Gap.xs,
            ),
            secondary: const IconCircle(
              Icons.notifications_active_rounded,
              size: 38,
            ),
            title: Text(
              context.tr('reminder_on'),
              style: context.text.bodyLarge!.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ]),
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: Gap.lg),
        ],
        PrimaryButton(
          context.tr(_busy ? 'saving' : 'save'),
          icon: Icons.check_rounded,
          onPressed: _busy ? null : _save,
        ),
        if (widget.reminder != null) ...[
          const SizedBox(height: Gap.sm),
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: p.critical),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.tr('delete_reminder')),
            ),
          ),
        ],
      ],
    );
  }
}
