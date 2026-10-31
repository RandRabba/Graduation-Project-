import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/lock_note.dart';
import '../../shell/caregiver_shell.dart';
import 'auth_frame.dart';
import 'login_screen.dart';

/// Invitation from the patient. Shows the right view for each invitation
/// state: pending, accepted, declined, expired or revoked.
class InvitationScreen extends StatelessWidget {
  const InvitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    switch (c.invitation) {
      case InvitationState.pending:
        return const AuthFrame(child: _PendingView());
      case InvitationState.accepted:
        return const AuthFrame(child: _AcceptedView());
      case InvitationState.declined:
      case InvitationState.expired:
      case InvitationState.revoked:
        return AuthFrame(child: _EndedView(state: c.invitation));
    }
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final Patient patient = c.repository.patient;
    final bool ar = c.arabic;

    final List<String> seeList = <String>[s.t('i1'), s.t('i2'), s.t('i3'), s.t('i4')];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppChip('• ${s.t('invT')}', fg: pal.ctl, bg: pal.ctlBg),
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              s.t('invHead'),
              style: context.hStyle(24).copyWith(height: 1.25),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Avatar(patient.initials.of(ar), size: 56, fontSize: 18, label: patient.name.of(ar)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.t('invFrom'), style: context.subStyle(12)),
                          Text(patient.name.of(ar), style: context.hStyle(17)),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.t('invLevel'), style: context.subStyle(12)),
                      Text(s.t('lvExt'), style: context.hStyle(14)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(s.t('invSee'), style: context.subStyle(12, FontWeight.w700)),
                for (final String item in seeList)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: AppIcon(AppIcons.check, color: pal.ok),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item, style: context.bodyStyle(13.5))),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                LockNote(s.t('invNever')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              AppIcon(AppIcons.clock, size: 15, color: pal.sub),
              const SizedBox(width: 6),
              Expanded(child: Text(s.t('invExp'), style: context.subStyle(12.5))),
            ],
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: s.t('accept'),
            onPressed: () => c.setInvitation(InvitationState.accepted),
          ),
          const SizedBox(height: 10),
          OutlineAppButton(
            label: s.t('decline'),
            onPressed: () => c.setInvitation(InvitationState.declined),
          ),
        ],
      ),
    );
  }
}

class _AcceptedView extends StatelessWidget {
  const _AcceptedView();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StatusCircle(icon: AppIcons.check, fg: pal.ok, bg: pal.okBg, iconSize: 40),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(s.t('okT'), textAlign: TextAlign.center, style: context.hStyle(24)),
          ),
          const SizedBox(height: 8),
          Text(s.t('okB'), textAlign: TextAlign.center, style: context.subStyle(14)),
          const SizedBox(height: 28),
          PrimaryButton(
            label: s.t('openDash'),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (BuildContext _) => const CaregiverShell()),
              (Route<dynamic> route) => false,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedView extends StatelessWidget {
  const _EndedView({required this.state});

  final InvitationState state;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;

    final String icon;
    final String titleKey;
    final String bodyKey;
    switch (state) {
      case InvitationState.expired:
        icon = AppIcons.clock;
        titleKey = 'exp_t';
        bodyKey = 'exp_b';
        break;
      case InvitationState.revoked:
        icon = AppIcons.lock;
        titleKey = 'rev_t';
        bodyKey = 'rev_b';
        break;
      default:
        icon = AppIcons.x;
        titleKey = 'dec_t';
        bodyKey = 'dec_b';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StatusCircle(icon: icon, fg: pal.high, bg: pal.highBg),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(s.t(titleKey), textAlign: TextAlign.center, style: context.hStyle(24)),
          ),
          const SizedBox(height: 8),
          Text(s.t(bodyKey), textAlign: TextAlign.center, style: context.subStyle(14)),
          const SizedBox(height: 28),
          PrimaryButton(
            label: s.t('toLogin'),
            onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
          ),
        ],
      ),
    );
  }
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

/// Returns to the login screen and clears the navigation history. Used by
/// "Log out" in the profile.
void goToLogin(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (BuildContext _) => const LoginScreen()),
    (Route<dynamic> route) => false,
  );
}
