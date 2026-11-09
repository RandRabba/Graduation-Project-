import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import 'auth_frame.dart';
import 'session_routes.dart';

/// Caregiver registration.
///
/// The patient adds the caregiver by email only (from the Patient app). The
/// caregiver then registers here with that same email, chooses a password,
/// confirms it and goes straight into the app: no email verification and no
/// invitation step.
///
/// The "is this email invited?" check is done against the repository in the
/// prototype. In production the backend must make it (a pending caregiver
/// link has to exist for the email) and answer with an error otherwise.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  /// String-table key of the current error, or null.
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    // Demo convenience only: the invited address is filled in for the review.
    final c = context.cgRead;
    if (c.showDemoControls) _email.text = c.repository.invitedEmail;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _register() {
    final String email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _errorKey = 'errFill');
      return;
    }
    if (email.toLowerCase() != context.cgRead.repository.invitedEmail.toLowerCase()) {
      setState(() => _errorKey = 'errNoInvite');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _errorKey = 'errLen');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _errorKey = 'errMatch');
      return;
    }
    setState(() => _errorKey = null);
    openDashboard(context);
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
            Semantics(header: true, child: Text(s.t('regT'), style: context.hStyle(26))),
            const SizedBox(height: 4),
            Text(s.t('regSub'), style: context.subStyle(14)),
            const SizedBox(height: 16),
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
                  Expanded(child: Text(s.t('regNote'), style: context.bodyStyle(13))),
                ],
              ),
            ),
            AppTextField(
              label: s.t('fEmail'),
              controller: _email,
              topSpacing: 16,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              label: s.t('fPass'),
              controller: _password,
              topSpacing: 12,
              obscure: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 4),
            Text(s.t('passHint'), style: context.subStyle(12)),
            AppTextField(
              label: s.t('fConf'),
              controller: _confirm,
              topSpacing: 12,
              obscure: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
            ),
            if (_errorKey != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    s.t(_errorKey!),
                    style: TextStyle(color: pal.crit, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(label: s.t('createAcc'), onPressed: _register),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(s.t('haveAcc'), style: context.subStyle(13)),
                  TextLinkButton(
                    s.t('login'),
                    onPressed: () => Navigator.of(context).maybePop(),
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
