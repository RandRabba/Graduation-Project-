import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> with SingleTickerProviderStateMixin {
  static const _suggestions = [
    'Causes of insulin resistance in type 2',
    'What is time in range?',
    'Snacks for low glucose',
    'How does a CGM work?',
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final _ctrl = TextEditingController();
  bool _smart = false;
  bool _menuOpen = false;

  @override
  void dispose() {
    _c.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String get _name => _smart ? '$kAppName Smart AI' : '$kAppName Quick AI';

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _ask(String q) {
    // TODO: send `q` to your AI backend and show the answer.
    _snack('TODO: send "$q" to the AI backend');
    _ctrl.clear();
  }

  void _fill(String s) => _ctrl.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDDE8FF), AppColors.page],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              _topBar(),
              const SizedBox(height: 20),
              Center(child: _orb()),
              _hero(),
              const SizedBox(height: 24),
              _input(),
              const SizedBox(height: 14),
              _chips(),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('Quick actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              _shortcuts(),
            ]),
            if (_menuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _menuOpen = false),
                ),
              ),
              Positioned(top: 68, left: 32, right: 32, child: _menu()),
            ],
          ]),
        ),
      );

  // ---------- top bar ----------
  Widget _roundBtn(IconData icon, VoidCallback onTap) => Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: softShadow),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 46, height: 46, child: Icon(icon, color: AppColors.ink)),
          ),
        ),
      );

  Widget _topBar() => Row(children: [
        _roundBtn(Icons.menu_rounded, () => _snack('TODO: chat history drawer')),
        Expanded(
          child: Center(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: softShadow),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => setState(() => _menuOpen = !_menuOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_smart ? Icons.psychology_rounded : Icons.bolt_rounded, size: 20, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Text(_name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(width: 4),
                      Icon(_menuOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        _roundBtn(Icons.add_comment_outlined, () => _snack('TODO: start a new chat')),
      ]);

  Widget _menu() => Material(
        elevation: 8,
        shadowColor: const Color(0x443B6EFF),
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _menuItem(false, Icons.bolt_rounded, '$kAppName Quick AI', 'Fast answers & daily tasks'),
          _menuItem(true, Icons.psychology_rounded, '$kAppName Smart AI', 'Deep insights & health tips'),
        ]),
      );

  Widget _menuItem(bool smart, IconData icon, String title, String sub) {
    final selected = _smart == smart;
    return ListTile(
      tileColor: selected ? AppColors.rangeBlue : null,
      leading: IconBubble(icon, AppColors.blue, size: 38),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
      onTap: () => setState(() {
        _smart = smart;
        _menuOpen = false;
      }),
    );
  }

  // ---------- hero ----------
  Widget _orb() => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final s = 1 + 0.06 * math.sin(_c.value * 2 * math.pi);
          return Transform.scale(
            scale: s,
            child: SizedBox(
              width: 130,
              height: 130,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0x553B6EFF), Color(0x003B6EFF)]),
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8FB8FF), Color(0xFF6C63FF)],
                    ),
                    boxShadow: [BoxShadow(color: Color(0x663B6EFF), blurRadius: 26, offset: Offset(0, 8))],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
                ),
              ]),
            ),
          );
        },
      );

  Widget _hero() => Column(children: [
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (r) => brandGradient.createShader(r),
          child: Text(_name,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(
          _smart ? 'Deep insights & health tips.' : 'We are here for your everyday needs.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.muted),
        ),
      ]);

  // ---------- input ----------
  Widget _input() => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xFFF2E85C), Color(0xFF7FD3E6), AppColors.blue]),
          boxShadow: const [BoxShadow(color: Color(0x223B6EFF), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.auto_awesome_rounded, color: AppColors.sky),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 17),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Ask anything about your glucose…',
                      hintStyle: TextStyle(color: AppColors.inactive, fontSize: 17),
                    ),
                  ),
                ),
              ]),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (context, v, _) {
                  final empty = v.text.trim().isEmpty;
                  return Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: brandGradient),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => empty ? _snack('TODO: voice input') : _ask(v.text.trim()),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(empty ? Icons.graphic_eq_rounded : Icons.arrow_upward_rounded,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      );

  Widget _chips() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _suggestions.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) => ActionChip(
            label: Text(_suggestions[i]),
            labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink),
            backgroundColor: Colors.white,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onPressed: () => _fill(_suggestions[i]),
          ),
        ),
      );

  // ---------- shortcuts ----------
  Widget _shortcuts() {
    final items = <(String, IconData, Color, VoidCallback)>[
      ("Today's glucose", Icons.water_drop_rounded, AppColors.coral, () => widget.onNavigate(1)),
      ('Health log', Icons.bar_chart_rounded, AppColors.mint, () => widget.onNavigate(1)),
      ('Sensor usage', Icons.sensors_rounded, AppColors.sky, () => widget.onNavigate(0)),
      ('Customer support', Icons.headset_mic_rounded, AppColors.violet, () => _snack('TODO: support chat')),
      ('All functions', Icons.grid_view_rounded, AppColors.blue, () => _snack('TODO: all functions')),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        for (final (label, icon, color, onTap) in items)
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: softShadow),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconBubble(icon, color, size: 44),
                      Text(label,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}