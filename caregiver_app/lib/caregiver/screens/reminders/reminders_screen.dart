import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/state_view.dart';
import '../patient/restricted_screen.dart';

/// Icon path for a reminder type.
String reminderIcon(ReminderType type) => switch (type) {
      ReminderType.medication => AppIcons.pill,
      ReminderType.glucose => AppIcons.drop,
      ReminderType.insulin => AppIcons.syringe,
    };

/// String-table key for "Every day" / "Every Sunday".
String reminderRepeatKey(ReminderRepeat repeat) => switch (repeat) {
      ReminderRepeat.daily => 'rpt_daily',
      ReminderRepeat.weekly => 'rpt_weekly',
    };

/// Status chip with a non-colour glyph: done, upcoming, missed.
Widget reminderStatusChip(BuildContext context, ReminderStatus status) {
  final s = context.s;
  final Tone tone = switch (status) {
    ReminderStatus.done => Tone.ok,
    ReminderStatus.upcoming => Tone.ctl,
    ReminderStatus.missed => Tone.high,
  };
  final String glyph = switch (status) {
    ReminderStatus.done => '✓ ',
    ReminderStatus.upcoming => '• ',
    ReminderStatus.missed => '! ',
  };
  return ToneChip('$glyph${s.t('rs_${status.name}')}', tone);
}

/// The patient's reminders, read-only. Extended access only.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();
    if (c.isBasic) return const RestrictedScreen();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final List<Reminder> reminders = c.repository.reminders(c.level);

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('remT')),
        const SizedBox(height: 6),
        LockNote(s.t('remNote')),
        for (final Reminder r in reminders)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  IconBox(icon: reminderIcon(r.type), fg: pal.sec, bg: pal.soft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(r.name.of(ar), style: context.hStyle(14)),
                        Text(s.t('rt_${r.type.name}'), style: context.subStyle()),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            AppChip(
                              '⁦${r.time}⁩',
                              fg: pal.text,
                              bg: pal.bg,
                              icon: AppIcons.clock,
                              fontSize: 12,
                            ),
                            Text(s.t(reminderRepeatKey(r.repeat)), style: context.subStyle()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  reminderStatusChip(context, r.status),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
