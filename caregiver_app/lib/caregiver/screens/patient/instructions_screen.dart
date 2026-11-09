import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/state_view.dart';

/// Instructions the doctor wrote and the patient chose to share. Read-only.
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;
    final List<DoctorInstruction> items = c.repository.instructions(c.level);

    return SubPage(
      title: s.t('insT'),
      children: <Widget>[
        LockNote(s.t('insNote')),
        const SizedBox(height: CgGap.lg),
        if (items.isEmpty)
          AppCard(
            child: EmptyState(
              icon: AppIcons.syringe,
              title: s.t('insT'),
              message: s.t('insNote'),
            ),
          ),
        for (final DoctorInstruction d in items)
          AppCard(
            margin: const EdgeInsets.only(bottom: CgGap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(d.title.of(ar), style: t.titleMedium),
                const SizedBox(height: 6),
                Text(d.body.of(ar), style: t.bodyLarge),
                const SizedBox(height: 10),
                Text(
                  '${s.t('sharedBy')} ${d.doctor.of(ar)} · ${monthDay(d.sharedOn, s)}',
                  style: t.labelSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
