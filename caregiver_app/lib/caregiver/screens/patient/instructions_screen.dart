import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/state_view.dart';
import 'restricted_screen.dart';

/// Instructions the doctor wrote and the patient chose to share. Read-only,
/// Extended access only.
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();
    if (c.isBasic) return const RestrictedScreen();

    final s = c.strings;
    final bool ar = c.arabic;
    final List<DoctorInstruction> items = c.repository.instructions(c.level);

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('insT')),
        const SizedBox(height: 6),
        LockNote(s.t('insNote')),
        for (final DoctorInstruction d in items)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(d.title.of(ar), style: context.hStyle(14)),
                  const SizedBox(height: 6),
                  Text(d.body.of(ar), style: context.bodyStyle()),
                  const SizedBox(height: 10),
                  Text(
                    '${s.t('sharedBy')} ${d.doctor.of(ar)} · ${monthDay(d.sharedOn, s)}',
                    style: context.subStyle(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
