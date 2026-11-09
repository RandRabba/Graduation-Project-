import 'package:flutter/material.dart';

import '../../shell/caregiver_shell.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import 'auth_frame.dart';
import 'login_screen.dart';

/// Replaces the whole auth stack with the caregiver dashboard. Used after a
/// successful login or registration, so Back never returns to the form.
/// Called from the auth screens, which sit on the module's own navigator.
void openDashboard(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (BuildContext _) => const CaregiverShell()),
    (Route<dynamic> route) => false,
  );
}

/// Returns to the login screen and clears the navigation history. Used by
/// "Log out" in the profile.
void goToLogin(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (BuildContext _) => const LoginScreen()),
    (Route<dynamic> route) => false,
  );
}

/// Shown when the backend says the account belongs to a patient. In the real
/// app this hands over to the existing Patient dashboard.
class PatientStubScreen extends StatelessWidget {
  const PatientStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    return AuthFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StatusCircle(icon: AppIcons.user, fg: pal.sec, bg: pal.soft),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(s.t('stubT'), textAlign: TextAlign.center, style: context.hStyle(24)),
            ),
            const SizedBox(height: 8),
            Text(s.t('stubB'), textAlign: TextAlign.center, style: context.subStyle(14)),
            const SizedBox(height: 28),
            PrimaryButton(
              label: s.t('toLogin'),
              onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
