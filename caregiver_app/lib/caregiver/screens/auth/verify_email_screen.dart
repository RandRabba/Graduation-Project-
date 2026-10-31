import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/toast.dart';
import 'auth_frame.dart';
import 'invitation_screen.dart';

/// "Check your inbox" step after registration.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final String shown = email.isEmpty ? 'nour.haddad@example.com' : email;

    return AuthFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StatusCircle(icon: AppIcons.mail, fg: pal.sec, bg: pal.soft),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(s.t('verT'), textAlign: TextAlign.center, style: context.hStyle(24)),
            ),
            const SizedBox(height: 8),
            Text(s.t('verSub'), textAlign: TextAlign.center, style: context.subStyle(14)),
            const SizedBox(height: 4),
            Text(
              shown,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: context.hStyle(14),
            ),
            const SizedBox(height: 8),
            Text(s.t('verHint'), textAlign: TextAlign.center, style: context.subStyle(14)),
            const SizedBox(height: 26),
            PrimaryButton(
              label: s.t('verDone'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => const InvitationScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlineAppButton(
              label: s.t('resend'),
              onPressed: () => showToast(context, s.t('resent')),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextLinkButton(
                s.t('diffEmail'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
