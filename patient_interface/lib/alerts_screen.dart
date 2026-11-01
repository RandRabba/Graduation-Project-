import 'package:flutter/material.dart';
import 'app_state.dart';
import 'common.dart';
import 'l10n.dart';
import 'models.dart';
import 'repositories.dart';
import 'theme.dart';

/// Icon and colour for each alert type the backend produces.
(IconData, Color) alertLook(String type, AppPalette p) => switch (type) {
  'critical_low' => (GlucoseLevel.veryLow.icon, p.critical),
  'low' => (GlucoseLevel.low.icon, p.elevated),
  'high' => (GlucoseLevel.high.icon, p.caution),
  'critical_high' => (GlucoseLevel.veryHigh.icon, p.critical),
  'emergency' => (Icons.sos_rounded, p.critical),
  _ => (Icons.notifications_rounded, p.primary),
};

const _knownTypes = {
  'critical_low',
  'low',
  'high',
  'critical_high',
  'emergency',
};

/// Every glucose alert and SOS for the signed-in patient, newest first.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _items = <AlertItem>[];
  DateTime? _next;
  bool _loading = true, _more = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final alerts = context.repos.alerts;
      final page = await alerts.history(limit: 30);
      final unread = await alerts.unreadCount();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _next = page.nextBefore;
      });
      AppScope.read<AlertInbox>(context).unread = unread;
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_more || _next == null) return;
    setState(() => _more = true);
    try {
      final page = await context.repos.alerts.history(limit: 30, before: _next);
      if (!mounted) return;
      final seen = {for (final a in _items) a.id};
      setState(() {
        _items.addAll(page.items.where((a) => !seen.contains(a.id)));
        _next = page.nextBefore;
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _markRead(AlertItem a) async {
    if (a.read) return;
    final i = _items.indexOf(a);
    setState(() => _items[i] = a.copyWith(read: true));
    final inbox = AppScope.read<AlertInbox>(context);
    try {
      await context.repos.alerts.markRead(a.id);
      inbox.unread = (inbox.unread - 1).clamp(0, 1 << 30);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items[_items.indexWhere((x) => x.id == a.id)] = a);
      showSnack(context, errorText(context, e));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await context.repos.alerts.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(read: true);
        }
      });
      AppScope.read<AlertInbox>(context).unread = 0;
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((a) => !a.read).length;
    return SubPage(
      title: context.tr('alerts_title'),
      onRefresh: _load,
      actions: [
        if (unread > 0)
          IconButton(
            tooltip: context.tr('mark_all_read'),
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.lg),
          child: Text(
            context.tr('alerts_subtitle', {
              'low': kTargetLow,
              'high': kTargetHigh,
            }),
            style: context.text.bodyMedium,
          ),
        ),
        if (_loading)
          const LoadingState()
        else if (_error != null && _items.isEmpty)
          ErrorState(message: errorText(context, _error!), onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
            icon: Icons.notifications_none_rounded,
            title: context.tr('no_alerts'),
            message: context.tr('no_alerts_body'),
          )
        else ...[
          for (final a in _items) _AlertCard(a, onTap: () => _markRead(a)),
          if (_next != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: SoftButton(
                context.tr(_more ? 'loading' : 'load_older'),
                icon: Icons.history_rounded,
                onPressed: _more ? null : _loadMore,
              ),
            ),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(this.alert, {required this.onTap});
  final AlertItem alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = alert;
    final (icon, color) = alertLook(a.type, p);
    final known = _knownTypes.contains(a.type);
    final glucose = a.glucose?.round();
    // glucose alerts are worded in the app's language; SOS keeps the patient's own message
    final body = a.type == 'emergency' || !known || glucose == null
        ? a.message
        : context.tr('alert_body_${a.type}', {'v': glucose});
    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      onTap: a.read ? null : onTap,
      child: Semantics(
        label: a.read ? null : context.tr('unread'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconCircle(icon, color: color, size: 44),
            const SizedBox(width: Gap.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(known ? 'alert_${a.type}' : 'alert_other'),
                          style: context.text.titleMedium!.copyWith(
                            fontWeight: a.read
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!a.read) StatusPill(context.tr('new'), p.primary),
                    ],
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(body, style: context.text.bodyLarge),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.md,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        Icons.schedule_rounded,
                        dateTimeLabel(context, a.at),
                      ),
                      if (glucose != null)
                        _Meta(Icons.water_drop_outlined, '$glucose mg/dL'),
                      if (a.caregiverNotified == true)
                        _Meta(
                          Icons.family_restroom_rounded,
                          context.tr('caregiver_notified'),
                        ),
                      _Meta(
                        a.read
                            ? Icons.drafts_outlined
                            : Icons.mark_email_unread_outlined,
                        context.tr(a.read ? 'read' : 'unread'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: context.palette.muted),
      const SizedBox(width: Gap.xs),
      Flexible(child: Text(text, style: context.text.labelSmall)),
    ],
  );
}
