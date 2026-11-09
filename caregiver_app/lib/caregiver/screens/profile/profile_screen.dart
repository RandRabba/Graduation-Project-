import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/segmented.dart';
import '../../widgets/sheets.dart';
import '../../widgets/toast.dart';
import '../auth/session_routes.dart';
import '../routes.dart';
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'notification_prefs_screen.dart';
import 'privacy_screen.dart';

/// Profile tab: personal information (editable), the connection to the
/// patient, and settings. Always available, also in loading, error, revoked
/// and no-patient states.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final s = c.strings;

    return PageFrame(
      padding: const EdgeInsets.fromLTRB(CgGap.page, CgGap.md, CgGap.page, CgGap.xl),
      children: <Widget>[
        PageHeader(s.t('profT')),
        const _PersonalCard(),
        const _ConnectionCard(),
        const _SettingsCard(),
      ],
    );
  }
}

class _PersonalCard extends StatefulWidget {
  const _PersonalCard();

  @override
  State<_PersonalCard> createState() => _PersonalCardState();
}

class _PersonalCardState extends State<_PersonalCard> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _startEdit() {
    final c = context.cgRead;
    _name.text = c.profileName(c.arabic);
    _phone.text = c.profilePhone;
    _email.text = c.repository.caregiver.email;
    setState(() => _editing = true);
  }

  void _save() {
    final c = context.cgRead;
    final String message = c.strings.t('pfSaved');
    c.saveProfile(name: _name.text, phone: _phone.text);
    setState(() => _editing = false);
    showToast(context, message, aboveNav: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final CaregiverProfile profile = c.repository.caregiver;

    return AppCard(
      margin: const EdgeInsets.only(bottom: CgGap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Avatar(profile.initials.of(ar), size: 60, fontSize: 19, label: s.t('profT')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(c.profileName(ar), style: context.hStyle(17)),
                    Text(profile.email, textDirection: TextDirection.ltr, style: context.subStyle()),
                    Text(c.profilePhone, textDirection: TextDirection.ltr, style: context.subStyle()),
                  ],
                ),
              ),
            ],
          ),
          if (!_editing) ...<Widget>[
            const SizedBox(height: 14),
            OutlineAppButton(
              label: s.t('pfEdit'),
              icon: AppIcons.edit,
              color: pal.sec,
              minHeight: 46,
              onPressed: _startEdit,
            ),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTextField(
                    label: s.t('pfName'),
                    controller: _name,
                    compact: true,
                    topSpacing: 0,
                    textInputAction: TextInputAction.next,
                  ),
                  AppTextField(
                    label: s.t('pfEmail'),
                    controller: _email,
                    compact: true,
                    enabled: false,
                    ltr: true,
                    topSpacing: 10,
                  ),
                  AppTextField(
                    label: s.t('pfPhone'),
                    controller: _phone,
                    compact: true,
                    ltr: true,
                    topSpacing: 10,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(child: PrimaryButton(label: s.t('pfSave'), minHeight: 48, onPressed: _save)),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => setState(() => _editing = false),
                        style: TextButton.styleFrom(
                          foregroundColor: pal.sub,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(
                          s.t('pfCancel'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final Patient p = c.repository.patient;

    if (c.dataState == DataState.noPatient) {
      return AppCard(
        margin: const EdgeInsets.only(bottom: CgGap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(s.t('pconn'), style: context.subStyle(12.5, FontWeight.w700)),
            const SizedBox(height: 8),
            Text(s.t('b_noPatient_t'), style: context.hStyle(14)),
            const SizedBox(height: 2),
            Text(s.t('b_noPatient_b'), style: context.subStyle(13)),
          ],
        ),
      );
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: CgGap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(s.t('pconn'), style: context.subStyle(12.5, FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Avatar(p.initials.of(ar), size: 44, fontSize: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(s.t('linked'), style: context.subStyle()),
                    Text(p.name.of(ar), style: context.hStyle(14)),
                  ],
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(s.t('connStatus'), style: context.subStyle())),
                StatusPill(s.t('active'), pal.ok, icon: AppIcons.check),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlineAppButton(
            label: s.t('disc'),
            icon: AppIcons.userx,
            color: pal.crit,
            minHeight: 46,
            onPressed: () => showDisconnectSheet(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;

    return SettingsGroup(s.t('settings'), <Widget>[
      SettingsTile(
        AppIcons.lock,
        s.t('chPwd'),
        onTap: () => pushScreen(context, const ChangePasswordScreen()),
      ),
      SettingsTile(
        AppIcons.bell,
        s.t('notifPref'),
        onTap: () => pushScreen(context, const NotificationPrefsScreen()),
      ),
      SettingsTile(
        AppIcons.globe,
        s.t('lang'),
        trailing: SegmentedBar<bool>(
          compact: true,
          semanticLabel: s.t('lang'),
          options: const <SegmentOption<bool>>[
            SegmentOption<bool>(false, 'English'),
            SegmentOption<bool>(true, 'العربية'),
          ],
          selected: c.arabic,
          onChanged: c.setArabic,
        ),
      ),
      SettingsTile(
        AppIcons.moon,
        s.t('appearance'),
        value: s.t(switch (c.themeMode) {
          ThemeMode.system => 'themeSys',
          ThemeMode.light => 'themeLight',
          ThemeMode.dark => 'themeDark',
        }),
        onTap: () => showThemeSheet(context),
      ),
      SettingsTile(
        AppIcons.shield,
        s.t('privTitle'),
        onTap: () => pushScreen(context, const PrivacyScreen()),
      ),
      SettingsTile(
        AppIcons.help,
        s.t('help'),
        onTap: () => pushScreen(context, const HelpScreen()),
      ),
      SettingsTile(
        AppIcons.logout,
        s.t('logout'),
        iconColor: pal.crit,
        onTap: () => goToLogin(context),
      ),
    ]);
  }
}
