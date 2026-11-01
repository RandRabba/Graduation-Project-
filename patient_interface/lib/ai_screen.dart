import 'package:flutter/material.dart';
import 'common.dart';
import 'l10n.dart';
import 'theme.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _Msg {
  const _Msg(this.mine, this.text, {this.failed = false});
  final bool mine;

  /// The message text — for a failed reply, the question to retry.
  final String text;
  final bool failed;
}

class _AiScreenState extends State<AiScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  int _mode = 0; // 0 = Quick, 1 = Smart
  bool _busy = false;
  int _chat =
      0; // bumped by "New chat" so late replies from the old chat are dropped

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// TODO: call your backend here (e.g. your FastAPI service) and return the answer.
  /// `smart` is true when the user picked the Smart AI mode.
  /// The backend must refuse insulin and medication dosing questions; the UI states this to the user.
  Future<String> _reply(String question, {required bool smart}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'This is a demo reply. Connect your AI backend in _reply() to answer: “$question”';
  }

  void _send([String? text]) {
    final q = (text ?? _ctrl.text).trim();
    if (q.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() => _msgs.add(_Msg(true, q)));
    _ask(q);
  }

  Future<void> _ask(String q) async {
    final chat = _chat;
    setState(() => _busy = true);
    _toEnd();
    _Msg answer;
    try {
      answer = _Msg(false, await _reply(q, smart: _mode == 1));
    } catch (_) {
      answer = _Msg(false, q, failed: true);
    }
    if (!mounted || chat != _chat) return;
    setState(() {
      _msgs.add(answer);
      _busy = false;
    });
    _toEnd();
  }

  void _retry(_Msg failed) {
    if (_busy) return;
    setState(() => _msgs.remove(failed));
    _ask(failed.text);
  }

  void _newChat() => setState(() {
    _chat++;
    _msgs.clear();
    _busy = false;
  });

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
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        _header(),
        // distinct keys so the welcome list doesn't inherit the chat's scroll offset
        Expanded(
          child: _msgs.isEmpty && !_busy
              ? KeyedSubtree(key: const ValueKey('welcome'), child: _welcome())
              : KeyedSubtree(key: const ValueKey('chat'), child: _chatList()),
        ),
        _composer(),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          context.tr('chatbot_title'),
          subtitle: context.tr(_mode == 0 ? 'ai_quick_desc' : 'ai_smart_desc'),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.palette.hero,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          trailing: _msgs.isEmpty
              ? null
              : IconButton(
                  tooltip: context.tr('ai_new_chat'),
                  onPressed: _newChat,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
        ),
        // hide the mode switch while typing so short screens keep room for the chat
        if (MediaQuery.viewInsetsOf(context).bottom == 0)
          PillTabs(
            labels: [context.tr('ai_quick'), context.tr('ai_smart')],
            index: _mode,
            onChanged: (i) => setState(() => _mode = i),
          ),
      ],
    ),
  );

  // ---------- welcome ----------
  Widget _welcome() {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.lg),
      children: [
        const _SafetyNote(),
        const SizedBox(height: Gap.lg),
        Text(context.tr('ai_greeting'), style: context.text.titleLarge),
        const SizedBox(height: Gap.xs),
        Text(context.tr('ai_greeting_sub'), style: context.text.bodyMedium),
        const SizedBox(height: Gap.lg),
        SectionTitle(context.tr('ai_try')),
        const SizedBox(height: Gap.sm),
        for (final key in ['prompt_1', 'prompt_2', 'prompt_3'])
          AppCard(
            margin: const EdgeInsets.only(bottom: Gap.sm + 2),
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md + 2,
            ),
            onTap: () => _send(context.tr(key)),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: p.primary,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    context.tr(key),
                    style: context.text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Icon(Icons.arrow_forward_rounded, color: p.primary, size: 20),
              ],
            ),
          ),
        const SizedBox(height: Gap.md),
        SectionTitle(context.tr('shortcuts')),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm + 2,
          runSpacing: Gap.sm + 2,
          children: [
            _shortcut(
              'sc_glucose',
              Icons.water_drop_rounded,
              () => widget.onNavigate(1),
            ),
            _shortcut(
              'sc_log',
              Icons.edit_note_rounded,
              () => widget.onNavigate(1),
            ),
            _shortcut(
              'sc_sensor',
              Icons.sensors_rounded,
              () => widget.onNavigate(0),
            ),
            _shortcut('sc_support', Icons.headset_mic_rounded, _soon),
            _shortcut('sc_all', Icons.grid_view_rounded, _soon),
          ],
        ),
      ],
    );
  }

  void _soon() => showSnack(context, context.tr('not_available'));

  Widget _shortcut(String key, IconData icon, VoidCallback onTap) {
    final p = context.palette;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: p.primary),
      label: Text(context.tr(key)),
      labelStyle: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      backgroundColor: p.surface,
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: Gap.sm + 2),
      onPressed: onTap,
    );
  }

  // ---------- chat ----------
  Widget _chatList() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
    itemCount: _msgs.length + 1 + (_busy ? 1 : 0),
    itemBuilder: (context, i) {
      if (i == 0) {
        return const Padding(
          padding: EdgeInsets.only(bottom: Gap.sm),
          child: _SafetyNote(),
        );
      }
      final j = i - 1;
      if (j == _msgs.length) return const _TypingBubble();
      final m = _msgs[j];
      return m.failed ? _FailedBubble(onRetry: () => _retry(m)) : _Bubble(m);
    },
  );

  // ---------- composer ----------
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
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: context.tr('ai_hint'),
                  filled: false,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (context, v, _) {
                final empty = v.text.trim().isEmpty;
                return IconButton.filled(
                  tooltip: context.tr(empty ? 'ai_voice' : 'ai_send'),
                  onPressed: empty ? _soon : (_busy ? null : _send),
                  style: IconButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    disabledBackgroundColor: p.border,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: Icon(
                    empty ? Icons.mic_none_rounded : Icons.arrow_upward_rounded,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible reminder that the assistant gives general information, not doses.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
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
              context.tr('ai_disclaimer'),
              style: context.text.bodyMedium!.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    required this.mine,
    required this.child,
    this.color,
    this.border,
  });
  final bool mine;
  final Widget child;
  final Color? color, border;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const r = Radius.circular(Radii.lg - 2);
    const tail = Radius.circular(6);
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .76,
      ),
      decoration: BoxDecoration(
        color: color ?? (mine ? p.primary : p.surface),
        border: mine && border == null
            ? null
            : Border.all(color: border ?? p.border),
        borderRadius: BorderRadiusDirectional.only(
          topStart: r,
          topEnd: r,
          bottomStart: mine ? r : tail,
          bottomEnd: mine ? tail : r,
        ),
      ),
      child: child,
    );
    if (mine) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: bubble);
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsetsDirectional.only(end: Gap.sm, bottom: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.hero),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _BubbleShell(
      mine: msg.mine,
      child: Text(
        msg.text,
        style: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: msg.mine ? p.onPrimary : p.ink,
        ),
      ),
    );
  }
}

class _FailedBubble extends StatelessWidget {
  const _FailedBubble({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _BubbleShell(
      mine: false,
      color: p.critical.withAlpha(20),
      border: p.critical.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: p.critical),
              const SizedBox(width: Gap.sm),
              Flexible(
                child: Text(
                  context.tr('ai_failed'),
                  style: context.text.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 40),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('retry')),
          ),
        ],
      ),
    );
  }
}

/// Three pulsing dots while the assistant is answering.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.value = 1;
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: context.tr('ai_thinking'),
      liveRegion: true,
      child: _BubbleShell(
        mine: false,
        child: SizedBox(
          height: 22,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.primary.withAlpha(
                        (90 + 165 * _pulse(i)).round(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _pulse(int i) {
    final t = (_anim.value - i * .2) % 1;
    return t < .5 ? t * 2 : (1 - t) * 2;
  }
}
