import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/toast.dart';
import 'auth_frame.dart';
import 'invitation_screen.dart';
import 'register_screen.dart';

/// One shared login. The backend decides the role after sign in, so nobody
/// picks a role on this screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _error = false;

  @override
  void initState() {
    super.initState();
    // Demo convenience only: saves typing while reviewing the prototype.
    if (context.cgRead.showDemoControls) {
      _email.text = 'nour.haddad@example.com';
      _password.text = 'password123';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() => _error = false);
    final bool isPatient = context.cgRead.roleIsPatient;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            isPatient ? const PatientStubScreen() : const InvitationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;

    return AuthFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(header: true, child: Text(s.t('welcome'), style: context.hStyle(28))),
            const SizedBox(height: 4),
            Text(s.t('signSub'), style: context.subStyle(14)),
            AppTextField(
              label: s.t('fEmail'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              label: s.t('fPass'),
              controller: _password,
              obscure: true,
              autofillHints: const <String>[AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextLinkButton(
                s.t('forgot'),
                onPressed: () => showToast(context, s.t('resetSent')),
              ),
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    s.t('errLogin'),
                    style: TextStyle(color: pal.crit, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            PrimaryButton(label: s.t('login'), onPressed: _login),
            const SizedBox(height: 18),
            AppCard(
              color: pal.soft,
              shadow: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AppIcon(AppIcons.shield, color: pal.pri),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.t('roleNote'), style: context.bodyStyle(13))),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(s.t('invitedQ'), style: context.subStyle(13)),
                  TextLinkButton(
                    s.t('createAcc'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => const RegisterScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
