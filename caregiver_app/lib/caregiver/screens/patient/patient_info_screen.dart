import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/sheets.dart';
import '../../widgets/state_view.dart';
import '../routes.dart';
import 'instructions_screen.dart';

/// Patient information, read-only. Only the patient can change any of it.
class PatientInfoScreen extends StatelessWidget {
  const PatientInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;
    final Patient p = c.repository.patient;
    final EmergencyContact ec = p.emergencyContact;
    final (String statusKey, Tone statusTone) = patientStatusStyle(p.status);

    return SubPage(
      title: s.t('ptTitle'),
      children: <Widget>[
        AppCard(
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.xxl - 4),
          child: Column(
            children: <Widget>[
              Avatar(p.initials.of(ar), size: 76, fontSize: 24, label: s.t('avatarAlt')),
              const SizedBox(height: CgGap.md),
              Semantics(header: true, child: Text(p.name.of(ar), style: t.titleLarge)),
              const SizedBox(height: CgGap.sm),
              Semantics(
                label: '${s.t('ptStatus')}: ${s.t(statusKey)}',
                excludeSemantics: true,
                child: StatusPill(s.t(statusKey), pal.fg(statusTone)),
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _InfoRow(label: s.t('dtype'), value: p.diabetesType.of(ar)),
              Divider(height: 1, thickness: 1, color: pal.line),
              _InfoRow(label: s.t('docL'), value: p.doctorName.of(ar), caption: p.clinic.of(ar)),
            ],
          ),
        ),
        AppCard(
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('ecL'), style: t.labelMedium!.copyWith(color: pal.sub)),
              const SizedBox(height: CgGap.md),
              Row(
                children: <Widget>[
                  Avatar(ec.initials.of(ar), size: 44, fontSize: 14),
                  const SizedBox(width: CgGap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(ec.name.of(ar), style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w600)),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: '${ec.relation.of(ar)} · '),
                              TextSpan(text: '⁦${ec.phone}⁩'),
                            ],
                          ),
                          style: t.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CgGap.md),
              EmergencyButton(
                label: s.t('emerg'),
                compact: true,
                onPressed: () => showEmergencySheet(context),
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: CgGap.lg),
          child: SettingsTile(
            AppIcons.syringe,
            s.t('insT'),
            onTap: () => pushScreen(context, const InstructionsScreen()),
          ),
        ),
        LockNote(s.t('roPatient')),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: t.labelSmall),
          Text(value, style: context.bodyStyle(16, FontWeight.w500)),
          if (caption != null) Text(caption!, style: t.bodyMedium),
        ],
      ),
    );
  }
}
