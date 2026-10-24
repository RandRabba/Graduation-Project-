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
          colorSchemeSeed: AppColors.accent,
          scaffoldBackgroundColor: AppColors.bg,
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
  (Icons.sensors_outlined, Icons.sensors_rounded, 'Sensor'),
  (Icons.insights_outlined, Icons.insights_rounded, 'Summary'),
  (Icons.auto_awesome_outlined, Icons.auto_awesome, '$kAppName AI'),
  (Icons.people_outline_rounded, Icons.people_rounded, 'Social'),
  (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

const _tourText = [
  ('Sensor', 'Apply your $kSensorName and follow the simple pairing steps.'),
  ('Summary', 'See your glucose, time in range, daily logs and weight in one place.'),
  ('$kAppName AI', 'Ask questions and get quick answers or deeper health insights.'),
  ('Social', 'Share your progress and stay connected with family and friends.'),
  ('Profile', 'Manage your account, devices and settings.'),
];

const _statusBarStyle = SystemUiOverlayStyle(
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
        value: _statusBarStyle,
        child: Scaffold(
          body: Stack(fit: StackFit.expand, children: [
            IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                SensorScreen(onNavigate: _go),
                SummaryScreen(onNavigate: _go),
                AiScreen(onNavigate: _go),
                const _Placeholder('Social', Icons.people_rounded),
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
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
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
                        duration: const Duration(milliseconds: 220),
                        width: 56,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.accentSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          i == index ? _tabs[i].$2 : _tabs[i].$1,
                          size: 24,
                          color: i == index ? AppColors.accent : AppColors.hint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabs[i].$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          color: i == index ? AppColors.accent : AppColors.hint,
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

/// First-run tour: dimmed screen, one clear card with Skip / Next, and a pointer to the active tab.
class _Tour extends StatelessWidget {
  const _Tour({required this.step, required this.onNext, required this.onSkip});
  final int step;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) {
    final (title, body) = _tourText[step];
    final last = step == _tabs.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // swallow taps while the tour is showing
      child: ColoredBox(
        color: const Color(0xB315221C),
        child: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${step + 1} of ${_tabs.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                const SizedBox(height: 8),
                Text(title, style: AppText.h1.copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(body, style: AppText.body),
                const SizedBox(height: 22),
                Row(children: [
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted, minimumSize: const Size(64, 52)),
                    child: const Text('Skip', style: TextStyle(fontSize: 16)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(120, 52),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(last ? 'Done' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
            // pointer aimed at the active tab
            Align(
              alignment: Alignment(-1 + (2 * step + 1) / _tabs.length, 0),
              child: const Icon(Icons.arrow_drop_down, size: 44, color: Colors.white),
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
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconCircle(icon, size: 88),
            const SizedBox(height: 18),
            Text(title, style: AppText.h2),
            const SizedBox(height: 4),
            const Text('Coming soon', style: AppText.label),
          ]),
        ),
      );
}
