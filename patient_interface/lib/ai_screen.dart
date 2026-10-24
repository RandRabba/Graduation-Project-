import 'package:flutter/material.dart';
import 'common.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _Msg {
  const _Msg(this.mine, this.text);
  final bool mine;
  final String text;
}

class _AiScreenState extends State<AiScreen> {
  static const _prompts = [
    'Causes of insulin resistance in type 2',
    'What is time in range?',
    'What should I eat when my glucose is low?',
  ];

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  int _mode = 0; // 0 = Quick, 1 = Smart
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// TODO: call your backend here (e.g. your FastAPI service) and return the answer.
  /// `smart` is true when the user picked the Smart AI mode.
  Future<String> _reply(String question, {required bool smart}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'This is a demo reply. Connect your AI backend in _reply() to answer: “$question”';
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _ctrl.text).trim();
    if (q.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(true, q));
      _busy = true;
    });
    _toEnd();
    final answer = await _reply(q, smart: _mode == 1);
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, answer));
      _busy = false;
    });
    _toEnd();
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
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: _msgs.isEmpty ? _welcome() : _chat()),
          _inputBar(),
        ]),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('$kAppName AI', style: AppText.h1)),
            if (_msgs.isNotEmpty)
              IconButton(
                tooltip: 'New chat',
                onPressed: () => setState(() => _msgs.clear()),
                icon: const Icon(Icons.add_comment_outlined),
              ),
          ]),
          const SizedBox(height: 14),
          PillTabs(labels: const ['Quick', 'Smart'], index: _mode, onChanged: (i) => setState(() => _mode = i)),
          const SizedBox(height: 10),
          Text(_mode == 0 ? 'Fast answers & daily tasks' : 'Deep insights & health tips', style: AppText.label),
        ]),
      );

  // ---------- welcome ----------
  Widget _welcome() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), children: [
        const Text('How can I help today?', style: AppText.h2),
        const SizedBox(height: 14),
        for (final p in _prompts)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            onTap: () => _send(p),
            child: Row(children: [
              Expanded(child: Text(p, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.ink))),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 20),
            ]),
          ),
        const SizedBox(height: 14),
        const Text('Shortcuts', style: AppText.h2),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _shortcut("Today's glucose", Icons.water_drop_rounded, () => widget.onNavigate(1)),
          _shortcut('Health log', Icons.edit_note_rounded, () => widget.onNavigate(1)),
          _shortcut('Sensor usage', Icons.sensors_rounded, () => widget.onNavigate(0)),
          _shortcut('Customer support', Icons.headset_mic_rounded, () => _snack('TODO: support chat')),
          _shortcut('All functions', Icons.grid_view_rounded, () => _snack('TODO: all functions')),
        ]),
      ]);

  Widget _shortcut(String label, IconData icon, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.accent),
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        onPressed: onTap,
      );

  // ---------- chat ----------
  Widget _chat() => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        itemCount: _msgs.length + (_busy ? 1 : 0),
        itemBuilder: (context, i) =>
            i == _msgs.length ? const _Bubble(_Msg(false, 'Thinking…')) : _Bubble(_msgs[i]),
      );

  // ---------- input ----------
  Widget _inputBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask about your glucose…',
                hintStyle: const TextStyle(color: AppColors.hint),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                border: _border(AppColors.line),
                enabledBorder: _border(AppColors.line),
                focusedBorder: _border(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (context, v, _) {
              final empty = v.text.trim().isEmpty;
              return IconButton.filled(
                onPressed: () => empty ? _snack('TODO: voice input') : _send(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(52, 52),
                ),
                icon: Icon(empty ? Icons.mic_rounded : Icons.arrow_upward_rounded),
              );
            },
          ),
        ]),
      );

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: c));
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : Colors.white,
          border: mine ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
        ),
        child: Text(msg.text,
            style: TextStyle(fontSize: 16, height: 1.4, color: mine ? Colors.white : AppColors.ink)),
      ),
    );
  }
}
