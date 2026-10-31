import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'services/caregiver_repository.dart';
import 'shell/caregiver_shell.dart';
import 'state/caregiver_controller.dart';
import 'state/caregiver_scope.dart';
import 'theme/app_theme.dart';

/// The whole Caregiver experience as one self-contained widget.
///
/// It has its own [MaterialApp] (theme, English/Arabic localization, RTL and
/// navigation), so it can run on its own (`lib/main.dart`) or be pushed as a
/// route from the Patient app:
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute<void>(
///   builder: (ctx) => CaregiverModule(
///     repository: ApiCaregiverRepository(session),
///     showDemoControls: false,
///     startAtDashboard: true,
///     onExit: () => Navigator.of(ctx).pop(),
///   ),
/// ));
/// ```
class CaregiverModule extends StatefulWidget {
  const CaregiverModule({
    super.key,
    this.controller,
    this.repository,
    this.startAtDashboard = false,
    this.showDemoControls = true,
    this.onExit,
    this.onCall,
  });

  /// Supply your own controller to share state with the host app. When null,
  /// the module creates and disposes its own.
  final CaregiverController? controller;

  /// Data source. Defaults to the mock repository. Ignored when a
  /// [controller] is supplied (the controller already holds its repository).
  final CaregiverRepository? repository;

  /// Skip login, registration and the invitation and open the dashboard.
  /// Use this when the host app already signed the caregiver in.
  final bool startAtDashboard;

  /// Shows the prototype controls (access level, theme, language, data
  /// states). Turn off in the integrated app. Ignored when a [controller] is
  /// supplied; set it on the controller instead.
  final bool showDemoControls;

  /// Called when the caregiver backs out of the module from its first screen.
  final VoidCallback? onExit;

  /// Called with the emergency contact's phone number when the caregiver taps
  /// "Call now". Wire it to `url_launcher` in the host app.
  final ValueChanged<String>? onCall;

  @override
  State<CaregiverModule> createState() => _CaregiverModuleState();
}

class _CaregiverModuleState extends State<CaregiverModule> {
  late CaregiverController _controller;
  late bool _ownsController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    final CaregiverController? provided = widget.controller;
    if (provided != null) {
      _controller = provided;
      _ownsController = false;
    } else {
      _controller = CaregiverController(
        repository: widget.repository,
        showDemoControls: widget.showDemoControls,
      );
      _ownsController = true;
    }
    _syncCallbacks();
  }

  void _syncCallbacks() {
    if (widget.onExit != null) _controller.onExit = widget.onExit;
    if (widget.onCall != null) _controller.onCall = widget.onCall;
  }

  @override
  void didUpdateWidget(CaregiverModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        (widget.controller == null && oldWidget.repository != widget.repository)) {
      if (_ownsController) _controller.dispose();
      _attachController();
    } else {
      _syncCallbacks();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// When the module is a route inside another app, the host's navigator
  /// receives the system back event first. Forward it to the module's own
  /// navigator, and leave the module only when nothing is left to close.
  Future<void> _onHostBack(bool didPop, Object? result) async {
    if (didPop) return;
    final NavigatorState? nav = _navigatorKey.currentState;
    final bool handled = nav != null && await nav.maybePop();
    if (!handled) {
      final VoidCallback? exit = widget.onExit;
      if (exit != null) exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CaregiverScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? _) {
          final CaregiverController c = _controller;
          final bool arabic = c.arabic;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: _onHostBack,
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: false,
              title: c.strings.t('sysName'),
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.build(dark: c.dark, arabic: arabic),
              builder: (BuildContext context, Widget? child) {
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: c.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: widget.startAtDashboard ? const CaregiverShell() : const LoginScreen(),
            ),
          );
        },
      ),
    );
  }
}
