import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ai_screen.dart';
import 'api.dart';
import 'app_state.dart';
import 'auth.dart';
import 'auth_screen.dart';
import 'common.dart';
import 'demo_data.dart';
import 'l10n.dart';
import 'meals_screen.dart';
import 'notifications.dart';
import 'profile_screen.dart';
import 'repositories.dart';
import 'sensor_screen.dart';
import 'summary_screen.dart';
import 'theme.dart';

void main() => runApp(const CgmApp());

class CgmApp extends StatefulWidget {
  const CgmApp({super.key, this.api, this.tokens, this.scheduler, this.repos});

  /// Injected by tests. By default: the DMS backend, secure storage and device notifications.
  final Api? api;
  final TokenStore? tokens;
  final ReminderScheduler? scheduler;

  /// Reminders, glucose, alerts and doctor chat. By default: the example records in demo_data.dart.
  final Repositories? repos;

  @override
  State<CgmApp> createState() => _CgmAppState();
}

class _CgmAppState extends State<CgmApp> {
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  final _settings = AppSettings();
  final _sensor = SensorSession();
  final _meals = MealLog();
  final _caregiver = CaregiverAssignment();
  final _nav = GlobalKey<NavigatorState>();
  late final _auth = AuthSession(
    widget.api ?? Api(),
    widget.tokens ?? SecureTokenStore(),
  );
  late final _repos = widget.repos ?? demoRepositories();
  late final _inbox = AlertInbox(_repos.alerts);
  late final _reminders = ReminderList(
    _repos.reminders,
    widget.scheduler ??
        (LocalReminderScheduler.supported
            ? LocalReminderScheduler()
            : NoopReminderScheduler()),
  );
  AuthStatus? _status;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    _auth.restore();
  }

  /// Loads the patient's data on sign-in and wipes it on sign-out.
  void _onAuth() {
    if (_auth.status == _status) return;
    _status = _auth.status;
    // drop pushed pages (sign-up, or screens left open when a session expired)
    _nav.currentState?.popUntil((r) => r.isFirst);
    switch (_status!) {
      case AuthStatus.signedIn:
        _sensor.loadToday(_auth.api).catchError((_) {});
        _inbox.refresh();
        _reminders.load().catchError((_) {});
      case AuthStatus.signedOut:
        _sensor.remove();
        _meals.clear();
        _caregiver.remove();
        _inbox.unread = 0;
        _reminders.clear();
      case AuthStatus.unknown:
        break;
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    for (final n in [
      _settings,
      _sensor,
      _meals,
      _caregiver,
      _auth,
      _inbox,
      _reminders,
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepositoryScope(
    repos: _repos,
    child: AppScope<AppSettings>(
      notifier: _settings,
      child: AppScope<SensorSession>(
        notifier: _sensor,
        child: AppScope<MealLog>(
          notifier: _meals,
          child: AppScope<AuthSession>(
            notifier: _auth,
            child: AppScope<AlertInbox>(
              notifier: _inbox,
              child: AppScope<ReminderList>(
                notifier: _reminders,
                child: AppScope<CaregiverAssignment>(
                  notifier: _caregiver,
                  child: ListenableBuilder(
                    listenable: _settings,
                    builder: (context, _) => MaterialApp(
                      navigatorKey: _nav,
                      debugShowCheckedModeBanner: false,
                      title: kAppName,
                      theme: _light,
                      darkTheme: _dark,
                      themeMode: _settings.themeMode,
                      locale: _settings.locale,
                      supportedLocales: L10n.supported,
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      home: ListenableBuilder(
                        listenable: _auth,
                        builder: (context, _) => switch (_auth.status) {
                          AuthStatus.signedIn => const AppShell(),
                          AuthStatus.signedOut => const LoginScreen(),
                          AuthStatus.unknown => const _Splash(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shown while the saved session is checked, or when that check couldn't reach the server.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final auth = context.auth;
    final error = auth.restoreError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: Gap.xl),
                if (error == null)
                  const CircularProgressIndicator()
                else ...[
                  ErrorState(
                    message: errorText(context, error),
                    onRetry: auth.restore,
                  ),
                  TextButton(
                    onPressed: auth.signOut,
                    child: Text(context.tr('sign_out')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// (outlined icon, selected icon, label key, tour text key)
const _tabs = [
  (Icons.sensors_outlined, Icons.sensors_rounded, 'tab_sensor', 'tour_sensor'),
  (
    Icons.insights_outlined,
    Icons.insights_rounded,
    'tab_summary',
    'tour_summary',
  ),
  (
    Icons.restaurant_outlined,
    Icons.restaurant_rounded,
    'tab_meals',
    'tour_meals',
  ),
  (Icons.smart_toy_outlined, Icons.smart_toy_rounded, 'tab_ai', 'tour_ai'),
  (
    Icons.person_outline_rounded,
    Icons.person_rounded,
    'tab_profile',
    'tour_profile',
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _step = 0;

  /// The guided tour shows once, right after sign-up — not on every login.
  late bool _touring = AppScope.read<AuthSession>(context).showTour;

  void _endTour() => setState(() {
    _touring = false;
    AppScope.read<AuthSession>(context).showTour = false;
  });

  void _go(int i) => setState(() {
    _index = i;
    if (_touring) _step = i; // keep the tour in step with the tab bar
  });

  void _next() => setState(() {
    if (_step == _tabs.length - 1) {
      _endTour();
    } else {
      _step++;
      _index = _step; // the tour walks through the tabs
    }
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      SensorScreen(onNavigate: _go),
      SummaryScreen(onNavigate: _go),
      const MealsScreen(),
      AiScreen(onNavigate: _go),
      ProfileScreen(onNavigate: _go),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                // pause animations on hidden tabs
                for (var i = 0; i < pages.length; i++)
                  TickerMode(enabled: i == _index, child: pages[i]),
              ],
            ),
            if (_touring)
              Positioned.fill(
                child: _Tour(step: _step, onNext: _next, onSkip: _endTour),
              ),
          ],
        ),
        bottomNavigationBar: _NavBar(index: _index, onTap: _go),
      ),
    );
  }
}

/// Floating rounded tab bar.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        margin: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xs,
          vertical: Gap.xs + 2,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: p.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavItem(
                  key: ValueKey('nav-$i'),
                  tab: _tabs[i],
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final (IconData, IconData, String, String) tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.primary : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 52,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? p.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(selected ? tab.$2 : tab.$1, size: 24, color: color),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                context.tr(tab.$3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run tour: dimmed screen, one clear card with Skip / Next, and a pointer to the active tab.
class _Tour extends StatelessWidget {
  const _Tour({required this.step, required this.onNext, required this.onSkip});
  final int step;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tab = _tabs[step];
    final last = step == _tabs.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // swallow taps while the tour is showing
      child: ColoredBox(
        color: const Color(0xB3061019),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: Gap.lg),
                padding: const EdgeInsets.all(Gap.xl + 4),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconCircle(tab.$2, size: 44),
                        const SizedBox(width: Gap.md),
                        Text(
                          context.tr('tour_step', {
                            'n': step + 1,
                            'total': _tabs.length,
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      context.tr(tab.$3),
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(context.tr(tab.$4), style: context.text.bodyLarge),
                    const SizedBox(height: Gap.xl),
                    Row(
                      children: [
                        TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: p.muted,
                            minimumSize: const Size(64, 52),
                          ),
                          child: Text(
                            context.tr('skip'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.primary,
                            foregroundColor: p.onPrimary,
                            minimumSize: const Size(120, 52),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            context.tr(last ? 'done' : 'next'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // pointer aimed at the active tab (mirrors in RTL)
              Align(
                alignment: AlignmentDirectional(
                  -1 + (2 * step + 1) / _tabs.length,
                  0,
                ),
                child: const Icon(
                  Icons.arrow_drop_down,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
