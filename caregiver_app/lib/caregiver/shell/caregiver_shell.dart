import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/alerts/alerts_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/readings/readings_screen.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../widgets/sheets.dart';
import 'bottom_nav.dart';

/// The signed-in caregiver experience: four tabs, each with its own
/// navigator so the bottom navigation stays visible on every sub screen.
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  final List<GlobalKey<NavigatorState>> _keys = List<GlobalKey<NavigatorState>>.generate(
    4,
    (int _) => GlobalKey<NavigatorState>(),
  );

  int _seenReset = 0;
  bool _initialised = false;

  /// System back: close a sub screen, then go back to Home, then leave.
  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) return;
    final c = context.cgRead;
    final NavigatorState? nav = _keys[c.tabIndex].currentState;
    if (nav != null) {
      final bool popped = await nav.maybePop();
      if (popped) return;
    }
    if (!mounted) return;
    if (c.tabIndex != 0) {
      c.selectTab(0);
      return;
    }
    final VoidCallback? exit = c.onExit;
    if (exit != null) {
      exit();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;

    // When the access level changes or the caregiver disconnects, every tab
    // returns to its first screen.
    if (!_initialised) {
      _seenReset = c.resetTick;
      _initialised = true;
    }
    if (_seenReset != c.resetTick) {
      _seenReset = c.resetTick;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        for (final GlobalKey<NavigatorState> key in _keys) {
          key.currentState?.popUntil((Route<dynamic> route) => route.isFirst);
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: pal.bg,
        body: Stack(
          children: <Widget>[
            IndexedStack(
              index: c.tabIndex,
              children: <Widget>[
                _TabNavigator(navigatorKey: _keys[0], root: const HomeScreen()),
                _TabNavigator(navigatorKey: _keys[1], root: const ReadingsScreen()),
                _TabNavigator(navigatorKey: _keys[2], root: const AlertsScreen()),
                _TabNavigator(navigatorKey: _keys[3], root: const ProfileScreen()),
              ],
            ),
            const PositionedDirectional(
              end: 16,
              bottom: 16,
              child: DemoFab(),
            ),
          ],
        ),
        bottomNavigationBar: const CaregiverBottomNav(),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.root});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    // Nested navigators must not share the app's HeroController.
    return HeroControllerScope.none(
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext _) => root,
          );
        },
      ),
    );
  }
}
