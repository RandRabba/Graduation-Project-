import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'auth.dart';
import 'common.dart';
import 'l10n.dart';
import 'theme.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? _validateEmail(BuildContext context, String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return context.tr('v_required');
  if (!_email.hasMatch(s)) return context.tr('v_email');
  return null;
}

/// Same rule as the backend: 8+ characters with a letter and a number.
String? _validatePassword(BuildContext context, String? v) {
  final s = v ?? '';
  if (s.length < 8) return context.tr('v_password_len');
  if (!s.contains(RegExp('[A-Za-z]')) || !s.contains(RegExp('[0-9]'))) {
    return context.tr('v_password_mix');
  }
  return null;
}

/// Shared frame: brand mark, title, language switch.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    this.back = false,
  });
  final String title, subtitle;
  final List<Widget> children;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final arabic = settings.locale.languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: back,
        actions: [
          TextButton.icon(
            onPressed: () => settings.locale = Locale(arabic ? 'en' : 'ar'),
            icon: const Icon(Icons.translate_rounded, size: 20),
            label: Text(arabic ? 'English' : 'العربية'),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
          children: [
            PageHeader(
              title,
              subtitle: subtitle,
              leading: const BrandMark(size: 52),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.validator,
    this.newPassword = false,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool newPassword;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _hidden,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: widget.onSubmitted == null
        ? TextInputAction.next
        : TextInputAction.done,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: context.tr(_hidden ? 'show_password' : 'hide_password'),
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// UI only for now: opens the app without checking the fields or contacting the server.
  void _submit() => AppScope.read<AuthSession>(context).enter();

  @override
  Widget build(BuildContext context) {
    final expired = context.auth.expired;
    return _AuthFrame(
      title: context.tr('login_title'),
      subtitle: context.tr('login_subtitle'),
      children: [
        if (expired) ...[
          ErrorBanner(context.tr('session_expired')),
          const SizedBox(height: Gap.lg),
        ],
        AppCard(
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateEmail(context, v),
                    decoration: InputDecoration(
                      labelText: context.tr('email'),
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  _PasswordField(
                    controller: _password,
                    label: context.tr('password'),
                    validator: (v) =>
                        (v ?? '').isEmpty ? context.tr('v_required') : null,
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: Gap.xl),
                  PrimaryButton(
                    context.tr('sign_in'),
                    icon: Icons.login_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                context.tr('no_account'),
                style: context.text.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
              child: Text(context.tr('create_account')),
            ),
          ],
        ),
      ],
    );
  }
}

const _diabetesTypes = [
  'type1',
  'type2',
  'gestational',
  'prediabetes',
  'other',
];

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dob;
  String? _type;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _phone]) {
      c.dispose();
    }
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

  /// UI only for now: opens the app without checking the fields or creating an account.
  /// The app's auth listener removes this page from the stack.
  void _submit() => AppScope.read<AuthSession>(context).enter(newAccount: true);

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return _AuthFrame(
      back: true,
      title: context.tr('signup_title'),
      subtitle: context.tr('signup_subtitle'),
      children: [
        AppCard(
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? context.tr('v_name')
                        : null,
                    decoration: InputDecoration(
                      labelText: context.tr('full_name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateEmail(context, v),
                    decoration: InputDecoration(
                      labelText: context.tr('email'),
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  _PasswordField(
                    controller: _password,
                    label: context.tr('password'),
                    newPassword: true,
                    validator: (v) => _validatePassword(context, v),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: Gap.md,
                      top: Gap.xs,
                    ),
                    child: Text(
                      context.tr('password_rule'),
                      style: context.text.labelSmall,
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  _PasswordField(
                    controller: _confirm,
                    label: context.tr('confirm_password'),
                    newPassword: true,
                    validator: (v) => v != _password.text
                        ? context.tr('v_password_match')
                        : null,
                  ),
                  const SizedBox(height: Gap.xl),
                  Text(
                    context.tr('optional_details'),
                    style: context.text.labelMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: context.tr('diabetes_type'),
                      prefixIcon: const Icon(Icons.bloodtype_outlined),
                    ),
                    items: [
                      for (final t in _diabetesTypes)
                        DropdownMenuItem(
                          value: t,
                          child: Text(context.tr('dt_$t')),
                        ),
                    ],
                    onChanged: (v) => setState(() => _type = v),
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
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                    ],
                    maxLength: 20,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      return s.isNotEmpty &&
                              s.replaceAll(RegExp('[^0-9]'), '').length < 6
                          ? context.tr('v_phone')
                          : null;
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  PrimaryButton(
                    context.tr('create_account'),
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                context.tr('have_account'),
                style: context.text.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('sign_in')),
            ),
          ],
        ),
      ],
    );
  }
}
