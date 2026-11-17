import 'dart:async';
import 'package:flutter/material.dart';
import 'common.dart';
import 'l10n.dart';
import 'models.dart';
import 'repositories.dart';
import 'theme.dart';

/// Messages with the clinic's doctor. A paid feature: shows the offer until it's unlocked.
class DoctorChatScreen extends StatefulWidget {
  const DoctorChatScreen({super.key});

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  Person? _doctor;
  bool _access = false, _loading = true, _buying = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final repos = context.repos;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctor = await repos.doctorChat.doctor();
      final access = await repos.entitlements.hasAccess(PaidFeature.doctorChat);
      if (mounted) {
        setState(() {
          _doctor = doctor;
          _access = access;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy({bool restore = false}) async {
    final entitlements = context.repos.entitlements;
    setState(() => _buying = true);
    try {
      final bool access;
      if (restore) {
        await entitlements.restore();
        access = await entitlements.hasAccess(PaidFeature.doctorChat);
      } else {
        access = await entitlements.purchase(PaidFeature.doctorChat);
      }
      if (!mounted) return;
      setState(() => _access = access);
      if (!access && restore) {
        showSnack(context, context.tr('nothing_to_restore'));
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _doctor;
    if (doctor != null && _access) {
      return _ChatView(
        doctor: doctor,
        onLocked: () => setState(() => _access = false),
      );
    }
    return SubPage(
      title: context.tr('chat_doctor'),
      children: [
        if (_loading)
          const LoadingState()
        else if (doctor == null)
          ErrorState(message: errorText(context, _error!), onRetry: _open)
        else ...[
          EmptyState(
            icon: Icons.workspace_premium_rounded,
            title: context.tr('chat_paid_title'),
            message: context.tr('chat_paid_body', {'name': doctor.fullName}),
          ),
          SettingsGroup(context.tr('your_doctor'), [
            SettingsTile(
              Icons.medical_services_rounded,
              doctor.fullName,
              value: doctor.specialty,
            ),
          ]),
          PrimaryButton(
            context.tr(_buying ? 'loading' : 'unlock_chat'),
            icon: Icons.lock_open_rounded,
            onPressed: _buying ? null : _buy,
          ),
          TextButton(
            onPressed: _buying ? null : () => _buy(restore: true),
            child: Text(context.tr('restore_purchase')),
          ),
        ],
      ],
    );
  }
}

class _Pending {
  _Pending(this.text);
  final String text;
  bool failed = false;
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.doctor, required this.onLocked});
  final Person doctor;

  /// Called when access to the paid chat is gone (e.g. the subscription ended).
  final VoidCallback onLocked;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  static const _poll = Duration(seconds: 5);

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _pending = <_Pending>[];
  Timer? _timer;
  bool _loading = true, _older = false, _hasMore = false, _polling = false;
  Object? _error;

  DoctorChatRepository get _chat => context.repos.doctorChat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLatest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // only poll while the app is in the foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _fetchNew();
    } else {
      _timer?.cancel();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_poll, (_) => _fetchNew());
  }

  Future<void> _loadLatest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _chat.history(limit: 50);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.items.reversed);
        _hasMore = page.nextBefore != null;
      });
      _markRead();
      _toEnd();
      _startPolling();
    } on PaymentRequired {
      if (mounted) widget.onLocked();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchNew() async {
    if (_polling || _loading || _error != null) return;
    _polling = true;
    try {
      final after = _messages.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : _messages.last.at;
      final incoming = await _chat.since(after);
      if (!mounted) return;
      final fresh = _merge(incoming);
      if (fresh > 0) {
        _markRead();
        _toEnd();
      }
    } catch (_) {
      // transient; the next poll retries
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadOlder() async {
    if (_older || _messages.isEmpty) return;
    setState(() => _older = true);
    try {
      final page = await _chat.history(limit: 50, before: _messages.first.at);
      if (!mounted) return;
      setState(() {
        final seen = {for (final m in _messages) m.id};
        _messages.insertAll(0, [
          for (final m in page.items.reversed)
            if (!seen.contains(m.id)) m,
        ]);
        _hasMore = page.nextBefore != null;
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _older = false);
    }
  }

  /// Adds messages not already shown; returns how many were new.
  int _merge(List<ChatMessage> incoming) {
    final seen = {for (final m in _messages) m.id};
    final fresh = incoming.where((m) => !seen.contains(m.id)).toList();
    if (fresh.isNotEmpty) {
      setState(
        () => _messages
          ..addAll(fresh)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );
    }
    return fresh.length;
  }

  void _markRead() => _chat.markRead().catchError((_) {});

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final p = _Pending(text);
    setState(() => _pending.add(p));
    _toEnd();
    _deliver(p);
  }

  Future<void> _deliver(_Pending p) async {
    setState(() => p.failed = false);
    try {
      final msg = await _chat.send(p.text);
      if (!mounted) return;
      setState(() => _pending.remove(p));
      _merge([msg]);
      _toEnd();
    } catch (_) {
      if (mounted) setState(() => p.failed = true);
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.hero,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctor.fullName,
                    style: context.text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.doctor.specialty ?? context.tr('your_doctor'),
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingState();
    if (_error != null) {
      return ListView(
        children: [
          ErrorState(
            message: errorText(context, _error!),
            onRetry: _loadLatest,
          ),
        ],
      );
    }
    if (_messages.isEmpty && _pending.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.forum_outlined,
            title: context.tr('chat_empty'),
            message: context.tr('chat_empty_body', {
              'name': widget.doctor.fullName,
            }),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.page),
            child: _UrgentNote(),
          ),
        ],
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
      children: [
        const _UrgentNote(),
        if (_hasMore)
          Center(
            child: TextButton.icon(
              onPressed: _older ? null : _loadOlder,
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text(context.tr(_older ? 'loading' : 'load_earlier')),
            ),
          ),
        for (final m in _messages)
          _MessageBubble(
            text: m.text,
            mine: m.fromPatient,
            time: dateTimeLabel(context, m.at),
          ),
        for (final m in _pending)
          _MessageBubble(
            text: m.text,
            mine: true,
            time: context.tr(m.failed ? 'not_sent' : 'sending'),
            failed: m.failed,
            onRetry: () => _deliver(m),
          ),
      ],
    );
  }

  Widget _composer() {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Gap.lg + 2,
          Gap.xs,
          Gap.xs + 2,
          Gap.xs,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: p.shadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                enabled: !_loading && _error == null,
                textCapitalization: TextCapitalization.sentences,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: context.tr('message_doctor_hint'),
                  filled: false,
                  counterText: '',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (context, v, _) => IconButton.filled(
                tooltip: context.tr('ai_send'),
                onPressed: v.text.trim().isEmpty ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  disabledBackgroundColor: p.border,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Messages aren't monitored around the clock, so emergencies need another route.
class _UrgentNote extends StatelessWidget {
  const _UrgentNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 20, color: p.primary),
          const SizedBox(width: Gap.sm + 2),
          Expanded(
            child: Text(
              context.tr('chat_urgent_note'),
              style: context.text.bodyMedium!.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.mine,
    required this.time,
    this.failed = false,
    this.onRetry,
  });
  final String text, time;
  final bool mine, failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const r = Radius.circular(Radii.lg - 2);
    const tail = Radius.circular(6);
    final fg = mine ? p.onPrimary : p.ink;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md - 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .76,
        ),
        decoration: BoxDecoration(
          color: failed
              ? p.critical.withAlpha(20)
              : (mine ? p.primary : p.surface),
          border: mine && !failed
              ? null
              : Border.all(color: failed ? p.critical.withAlpha(90) : p.border),
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: mine ? r : tail,
            bottomEnd: mine ? tail : r,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Text(
                context.tr('doctor'),
                style: context.text.labelSmall!.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: failed ? p.ink : fg,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failed) ...[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: p.critical,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: failed ? p.critical : fg.withAlpha(190),
                  ),
                ),
                if (failed)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 32),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                    ),
                    child: Text(context.tr('retry')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
