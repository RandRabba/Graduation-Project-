import 'package:flutter/material.dart';
import 'app_state.dart';
import 'common.dart';
import 'l10n.dart';
import 'theme.dart';

/// Confirms, then sends an SOS notification to the caregiver.
Future<void> sendEmergency(BuildContext context) async {
  final p = context.palette;
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.sos_rounded, color: p.critical, size: 36),
      title: Text(ctx.tr('sos_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ctx.tr('sos_body'), style: ctx.text.bodyLarge),
          const SizedBox(height: Gap.md),
          TextField(
            controller: note,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(hintText: ctx.tr('sos_hint')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: p.critical,
            foregroundColor: Colors.white,
          ),
          child: Text(ctx.tr('sos_send')),
        ),
      ],
    ),
  );
  final text = note.text.trim();
  note.dispose();
  if (ok != true || !context.mounted) return;
  try {
    final notified = await AppScope.read<CaregiverAssignment>(context).sendSos(
      patientName: context.auth.user?.fullName ?? '',
      message: text.isEmpty ? null : text,
    );
    if (!context.mounted) return;
    showSnack(context, context.tr(notified ? 'sos_sent' : 'sos_no_caregiver'));
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(context, e));
  }
}

/// Shows the caregiver the patient added, or an "Add caregiver" button that adds one by email.
/// Adding writes the invitation `links/{email}`; the caregiver then registers in the Caregiver app.
class CaregiverScreen extends StatelessWidget {
  const CaregiverScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddCaregiverSheet(),
    );
    if (email == null || !context.mounted) return;
    try {
      await AppScope.read<CaregiverAssignment>(context).assign(email);
      if (context.mounted) showSnack(context, context.tr('caregiver_assigned'));
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(context, e));
    }
  }

  Future<void> _remove(BuildContext context) async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('remove_caregiver_title')),
        content: Text(
          ctx.tr('remove_caregiver_body'),
          style: ctx.text.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.critical),
            child: Text(ctx.tr('remove')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AppScope.read<CaregiverAssignment>(context).remove();
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = context.caregiver.email;
    final active = context.caregiver.active;
    return SubPage(
      title: context.tr('caregiver_title'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.lg),
          child: Text(
            context.tr('caregiver_subtitle'),
            style: context.text.bodyMedium,
          ),
        ),
        if (email == null) ...[
          EmptyState(
            icon: Icons.family_restroom_rounded,
            title: context.tr('no_caregiver'),
            message: context.tr('no_caregiver_body'),
          ),
          PrimaryButton(
            context.tr('add_caregiver'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _add(context),
          ),
        ] else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconCircle(
                      Icons.family_restroom_rounded,
                      size: 52,
                      color: p.normal,
                    ),
                    const SizedBox(width: Gap.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('your_caregiver'),
                            style: context.text.titleMedium,
                          ),
                          Text(email, style: context.text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                StatusPill(
                  context.tr(active ? 'status_active' : 'status_pending'),
                  active ? p.normal : p.caution,
                  icon: active
                      ? Icons.verified_rounded
                      : Icons.hourglass_top_rounded,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  context.tr(
                    active ? 'caregiver_active_body' : 'caregiver_pending_body',
                  ),
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Gap.xs),
                TextButton.icon(
                  onPressed: () => _remove(context),
                  style: TextButton.styleFrom(
                    foregroundColor: p.critical,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(context.tr('remove_caregiver')),
                ),
              ],
            ),
          ),
          SoftButton(
            context.tr('change_caregiver'),
            icon: Icons.swap_horiz_rounded,
            onPressed: () => _add(context),
          ),
        ],
      ],
    );
  }
}

/// Asks for the caregiver's email only. Pops with the email.
class _AddCaregiverSheet extends StatefulWidget {
  const _AddCaregiverSheet();

  @override
  State<_AddCaregiverSheet> createState() => _AddCaregiverSheetState();
}

class _AddCaregiverSheetState extends State<_AddCaregiverSheet> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _assign() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _email.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.xl + 4, 0, Gap.xl + 4, Gap.xl + 4),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('add_caregiver'),
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              context.tr('add_caregiver_body'),
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _assign(),
              validator: (v) =>
                  RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(v?.trim() ?? '')
                  ? null
                  : context.tr('v_email'),
              decoration: InputDecoration(
                labelText: context.tr('caregiver_email'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              context.tr('assign_caregiver'),
              icon: Icons.check_rounded,
              onPressed: _assign,
            ),
          ],
        ),
      ),
    ),
  );
}
