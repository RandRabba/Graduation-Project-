import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_screen.dart';
import 'common.dart';
import 'sensor_screen.dart';
import 'summary_screen.dart';

void main() => runApp(const CgmApp());

class CgmApp extends StatelessWidget {
  const CgmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: kAppName,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.blue,
          scaffoldBackgroundColor: AppColors.page,
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        home: const AppShell(),
      );
}

// (outlined icon, selected icon, label)
const _tabs = [
  (Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Sensor'),
  (Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Summary'),
  (Icons.auto_awesome_outlined, Icons.auto_awesome, '$kAppName AI'),
  (Icons.groups_outlined, Icons.groups_rounded, 'Social'),
  (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

const _tourText = [
  ('Sensor data', 'See real-time glucose data from your Sensor and trend reports.'),
  ('Summary', 'Review your overview, glucose curve, daily logs and weight.'),
  ('$kAppName AI', 'Ask questions and get quick answers or deeper health insights.'),
  ('Social', 'Share your progress and stay connected with family and friends.'),
  ('Profile', 'Manage your account, devices and settings.'),
];

// Status-bar icon colors: white on the blue Summary header, dark everywhere else.
const _lightIcons = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);
const _darkIcons = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _step = 0;
  bool _touring = true; // set to false to skip the first-run tour

  void _go(int i) => setState(() => _index = i);

  void _next() => setState(() {
        if (_step == _tabs.length - 1) {
          _touring = false;
        } else {
          _step++;
          _index = _step; // the tour walks through the tabs
        }
      });

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _index == 1 ? _lightIcons : _darkIcons,
        child: Scaffold(
          body: Stack(fit: StackFit.expand, children: [
            IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                const SensorScreen(),
                const SummaryScreen(),
                AiScreen(onNavigate: _go),
                const _Placeholder('Social', Icons.groups_rounded),
                const _Placeholder('Profile', Icons.person_rounded),
              ],
            ),
            if (_touring)
              Positioned.fill(
                child: _Tour(step: _step, onNext: _next, onSkip: () => setState(() => _touring = false)),
              ),
          ]),
          bottomNavigationBar: _NavBar(index: _index, onTap: _go),
        ),
      );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 16,
        shadowColor: const Color(0x333B6EFF),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 58,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.rangeBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: i == index
                            ? ShaderMask(
                                shaderCallback: (r) => brandGradient.createShader(r),
                                child: Icon(_tabs[i].$2, size: 26, color: Colors.white),
                              )
                            : Icon(_tabs[i].$1, size: 26, color: AppColors.inactive),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabs[i].$3,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          color: i == index ? AppColors.blue : AppColors.inactive,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// First-run coach-mark overlay: dim background, bubble pointing at the active tab, Skip / Next.
class _Tour extends StatelessWidget {
  const _Tour({required this.step, required this.onNext, required this.onSkip});
  final int step;
  final VoidCallback onNext, onSkip;

  static const _bubble = Color(0xFFE4EBFF);

  @override
  Widget build(BuildContext context) {
    final (title, body) = _tourText[step];
    final last = step == _tabs.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // swallow taps while the tour is showing
      child: ColoredBox(
        color: const Color(0xAA0B1226),
        child: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                // swap for your mascot image
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7DB6FF), AppColors.blue],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.sentiment_very_satisfied_rounded, color: Colors.white, size: 38),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0x33FFFFFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                  ),
                  child: Text(last ? 'Done' : 'Next',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: BoxDecoration(color: _bubble, borderRadius: BorderRadius.circular(26)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 10),
                Text(body, style: const TextStyle(fontSize: 18, height: 1.35, color: AppColors.ink)),
                const SizedBox(height: 16),
                Row(children: [
                  for (var i = 0; i < _tabs.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == step ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == step ? AppColors.blue : const Color(0x333B6EFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
              ]),
            ),
            // pointer triangle aimed at the active tab
            Align(
              alignment: Alignment(-1 + (2 * step + 1) / _tabs.length, 0),
              child: const Icon(Icons.arrow_drop_down, size: 44, color: _bubble),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title, this.icon);
  final String title;
  final IconData icon;

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
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: brandGradient,
                  boxShadow: [BoxShadow(color: Color(0x553B6EFF), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Icon(icon, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppColors.rangeBlue, borderRadius: BorderRadius.circular(20)),
                child: const Text('Coming soon',
                    style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
}