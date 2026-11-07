import 'package:flutter/material.dart';
import 'notifications_screen.dart';
import 'app_state.dart';
import 'auth.dart';
import 'caregiver_screen.dart';
import 'common.dart';
import 'doctor_chat_screen.dart';
import 'glucose_history_screen.dart';
import 'l10n.dart';
import 'models.dart';
import 'reminders_screen.dart';
import 'sensor_screen.dart' show sensorStatus;
import 'theme.dart';

const _languages = [(Locale('en'), 'English'), (Locale('ar'), 'العربية')];
const _themes = [
  (ThemeMode.system, 'theme_system'),
  (ThemeMode.light, 'theme_light'),
  (ThemeMode.dark, 'theme_dark'),
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (0 Sensor, 1 Summary, ...).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final sensor = context.sensor;
    final unread = context.inbox.unread;
    void soon() => showSnack(context, context.tr('not_available'));
    final language = _languages
        .firstWhere(
          (l) => l.$1 == settings.locale,
          orElse: () => _languages.first,
        )
        .$2;
    final theme = _themes.firstWhere((t) => t.$1 == settings.themeMode).$2;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
        children: [
          PageHeader(context.tr('tab_profile')),
          const _ProfileHeader(),
          SettingsGroup(context.tr('group_health'), [
            SettingsTile(
              Icons.badge_outlined,
              context.tr('personal_info'),
              onTap: () => _open(context, const _PersonalInfoPage()),
            ),
            SettingsTile(
              Icons.monitor_heart_outlined,
              context.tr('target_range'),
              value: '$kTargetLow–$kTargetHigh mg/dL',
            ),
            SettingsTile(
              Icons.water_drop_outlined,
              context.tr('all_readings'),
              onTap: () => _open(context, const GlucoseHistoryScreen()),
            ),
            SettingsTile(
              Icons.notifications_none_rounded,
              context.tr('alerts_title'),
              value: unread > 0 ? context.tr('n_new', {'n': unread}) : null,
              onTap: () => _open(context, const NotificationsScreen()),
            ),
            SettingsTile(
              Icons.alarm_rounded,
              context.tr('reminders_title'),
              onTap: () => _open(context, const RemindersScreen()),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          SettingsGroup(context.tr('group_care'), [
            SettingsTile(
              Icons.medical_services_outlined,
              context.tr('chat_doctor'),
              onTap: () => _open(context, const DoctorChatScreen()),
            ),
            SettingsTile(
              Icons.family_restroom_rounded,
              context.tr('caregiver_title'),
              onTap: () => _open(context, const CaregiverScreen()),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          SettingsGroup(context.tr('group_devices'), [
            SettingsTile(
              Icons.sensors_rounded,
              kSensorName,
              value: context.tr(sensorStatus(sensor, context.palette).$1),
              onTap: () => onNavigate(0),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          SettingsGroup(context.tr('group_prefs'), [
            SettingsTile(
              Icons.translate_rounded,
              context.tr('language'),
              value: language,
              onTap: () => _pick<Locale>(
                context,
                context.tr('language'),
                _languages,
                settings.locale,
                (l) => settings.locale = l,
              ),
            ),
            SettingsTile(
              Icons.dark_mode_outlined,
              context.tr('appearance'),
              value: context.tr(theme),
              onTap: () => _pick<ThemeMode>(
                context,
                context.tr('appearance'),
                [for (final (m, key) in _themes) (m, context.tr(key))],
                settings.themeMode,
                (m) => settings.themeMode = m,
              ),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          SettingsGroup(context.tr('group_about'), [
            SettingsTile(
              Icons.info_outline_rounded,
              context.tr('about_app'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const _AboutPage())),
            ),
            SettingsTile(
              Icons.help_outline_rounded,
              context.tr('help'),
              soon: true,
              onTap: soon,
            ),
          ]),
          Center(
            child: TextButton.icon(
              onPressed: () => _signOut(context),
              style: TextButton.styleFrom(
                foregroundColor: context.palette.critical,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(context.tr('sign_out')),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Center(
            child: Text(
              context.tr('version', {'v': kAppVersion}),
              style: context.text.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  static Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('sign_out_title')),
        content: Text(ctx.tr('sign_out_body'), style: ctx.text.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.palette.critical),
            child: Text(ctx.tr('sign_out')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await AppScope.read<AuthSession>(context).signOut();
    }
  }

  /// Bottom sheet with one tick-marked choice per option.
  static void _pick<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    T current,
    ValueChanged<T> onPick,
  ) => showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: Gap.sm,
                  bottom: Gap.sm,
                ),
                child: Text(title, style: ctx.text.titleLarge),
              ),
              for (final (value, label) in options)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  selected: value == current,
                  selectedTileColor: p.primarySoft,
                  selectedColor: p.primary,
                  title: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: value == current
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () {
                    onPick(value);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Account header for the signed-in patient.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final user = context.auth.user;
    return AppCard(
      gradient: context.palette.hero,
      margin: const EdgeInsets.only(bottom: Gap.xl),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(36),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?.fullName.isNotEmpty ?? false)
                      ? user!.fullName
                      : context.tr('guest'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (user?.email.isNotEmpty ?? false)
                      ? user!.email
                      : context.tr('not_signed_in'),
                  style: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable personal details. UI only for now: kept in memory until the backend is connected.
class _PersonalInfoPage extends StatefulWidget {
  const _PersonalInfoPage();

  @override
  State<_PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<_PersonalInfoPage> {
  static const _types = [
    'type1',
    'type2',
    'gestational',
    'prediabetes',
    'other',
  ];

  late final AppUser? _user = AppScope.read<AuthSession>(context).user;
  late final _name = TextEditingController(text: _user?.fullName);
  late final _email = TextEditingController(text: _user?.email);
  late final _phone = TextEditingController(text: _user?.phone);
  late DateTime? _dob = _user?.dateOfBirth;
  late String? _type = _user?.diabetesType;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) setState(() => _dob = d);
  }

  void _save() {
    final phone = _phone.text.trim();
    AppScope.read<AuthSession>(context).updateUser(
      AppUser(
        id: _user?.id ?? 'local',
        role: 'patient',
        email: _email.text.trim(),
        fullName: _name.text.trim(),
        dateOfBirth: _dob,
        diabetesType: _type,
        phone: phone.isEmpty ? null : phone,
        doctorId: _user?.doctorId,
      ),
    );
    showSnack(context, context.tr('info_saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return SubPage(
      title: context.tr('personal_info'),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.tr('full_name'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('email'),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: Gap.md),
              InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('date_of_birth'),
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _dob == null
                        ? context.tr('not_set')
                        : loc.formatMediumDate(_dob!),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: context.tr('diabetes_type'),
                  prefixIcon: const Icon(Icons.bloodtype_outlined),
                ),
                items: [
                  for (final t in _types)
                    DropdownMenuItem(
                      value: t,
                      child: Text(context.tr('dt_$t')),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
            ],
          ),
        ),
        PrimaryButton(
          context.tr('save'),
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('about_app'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          children: [
            AppCard(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: p.hero,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(kAppName, style: context.text.headlineMedium),
                  Text(
                    context.tr('version', {'v': kAppVersion}),
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    context.tr('about_body'),
                    style: context.text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconCircle(
                    Icons.health_and_safety_outlined,
                    color: p.caution,
                    size: 42,
                  ),
                  const SizedBox(width: Gap.md + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('medical_notice'),
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          context.tr('about_disclaimer'),
                          style: context.text.bodyMedium,
                        ),
                      ],
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
