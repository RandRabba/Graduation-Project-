import 'package:flutter/material.dart';

import '../../services/caregiver_auth.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/toast.dart';

/// Change password form. It checks the new password locally, then asks
/// `auth.changePassword`, which verifies the current password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  /// String-table key of the current error, or null.
  String? _errorKey;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final c = context.cgRead;
    if (_new.text.isEmpty || _new.text != _confirm.text) {
      setState(() => _errorKey = 'pwMismatch');
      return;
    }
    if (_new.text.length < 8) {
      setState(() => _errorKey = 'errLen');
      return;
    }
    setState(() {
      _errorKey = null;
      _busy = true;
    });
    try {
      await c.auth.changePassword(current: _current.text, next: _new.text);
      if (!mounted) return;
      // Show the message first: the toast lives on the root overlay, so it
      // survives this screen closing.
      showToast(context, c.strings.t('pwDone'), aboveNav: true);
      Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKey = e.key;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;

    return SubPage(
      title: s.t('chPwd'),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: s.t('pwCur'),
                controller: _current,
                compact: true,
                topSpacing: 0,
                obscure: true,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                label: s.t('pwNew'),
                controller: _new,
                compact: true,
                topSpacing: 12,
                obscure: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                label: s.t('pwConf'),
                controller: _confirm,
                compact: true,
                topSpacing: 12,
                obscure: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              if (_errorKey != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.t(_errorKey!),
                      style: TextStyle(color: pal.crit, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(label: s.t('pwUpd'), minHeight: 48, onPressed: _busy ? null : _save),
            ],
          ),
        ),
      ],
    );
  }
}
