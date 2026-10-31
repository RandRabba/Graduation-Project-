import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/toast.dart';

/// Change password form. Mock: it validates locally and shows a message.
/// In the integrated app, call the backend here.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    if (_new.text.isEmpty || _new.text != _confirm.text) {
      setState(() => _error = true);
      return;
    }
    // Show the message first: the toast lives on the root overlay, so it
    // survives this screen closing.
    showToast(context, context.cgRead.strings.t('pwDone'), aboveNav: true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('chPwd')),
        const SizedBox(height: 14),
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
              if (_error)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.t('pwMismatch'),
                      style: TextStyle(color: pal.crit, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(label: s.t('pwUpd'), minHeight: 48, onPressed: _save),
            ],
          ),
        ),
      ],
    );
  }
}
