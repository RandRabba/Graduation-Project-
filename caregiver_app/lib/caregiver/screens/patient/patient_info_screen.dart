import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/sheets.dart';
import '../../widgets/state_view.dart';
import '../routes.dart';
import 'instructions_screen.dart';

/// Patient information, read-only. Diabetes type and the assigned doctor are
/// shown only with Extended monitoring.
class PatientInfoScreen extends StatelessWidget {
  const PatientInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final bool ext = c.isExtended;
    final Patient p = c.repository.patient;
    final EmergencyContact ec = p.emergencyContact;
    final String level = ext ? s.t('lvExt') : s.t('lvBasic');

    Widget infoRow({required String label, required Widget value, bool last = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: context.subStyle()),
            value,
          ],
        ),
      );
    }

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        const SizedBox(height: 4),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Column(
            children: <Widget>[
              Avatar(p.initials.of(ar), size: 76, fontSize: 24, label: s.t('avatarAlt')),
              const SizedBox(height: 12),
              Semantics(header: true, child: Text(p.name.of(ar), style: context.hStyle(20))),
              const SizedBox(height: 8),
              AppChip(level, fg: pal.sec, bg: pal.soft),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              infoRow(
                label: s.t('dtype'),
                value: ext ? Text(p.diabetesType.of(ar), style: context.hStyle(14)) : const NotSharedLine(),
              ),
              infoRow(
                label: s.t('docL'),
                value: ext
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(p.doctorName.of(ar), style: context.hStyle(14)),
                          Text(p.clinic.of(ar), style: context.subStyle()),
                        ],
                      )
                    : const NotSharedLine(),
              ),
              infoRow(
                label: s.t('accessL'),
                last: true,
                value: Text(level, style: context.hStyle(14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('ecL'), style: context.subStyle(12.5, FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Avatar(ec.initials.of(ar), size: 44, fontSize: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(ec.name.of(ar), style: context.hStyle(14)),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: '${ec.relation.of(ar)} · '),
                              TextSpan(text: '⁦${ec.phone}⁩'),
                            ],
                          ),
                          style: context.subStyle(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EmergencyButton(
                label: s.t('emerg'),
                compact: true,
                onPressed: () => showEmergencySheet(context),
              ),
            ],
          ),
        ),
        if (ext) ...<Widget>[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => pushScreen(context, const InstructionsScreen()),
            child: Row(
              children: <Widget>[
                IconBox(icon: AppIcons.file, fg: pal.sec, bg: pal.soft),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t('insT'), style: context.hStyle(14))),
                AppIcon(AppIcons.chev, color: pal.sub, flip: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        LockNote(s.t('roPatient')),
      ],
    );
  }
}
