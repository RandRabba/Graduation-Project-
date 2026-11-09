import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/patient_style.dart';
import '../../widgets/state_view.dart';

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

/// Status pill with an icon, so the status never depends on colour alone.
Widget reminderStatusPill(BuildContext context, ReminderStatus status) {
  final s = context.s;
  final pal = context.pal;
  final Color color = switch (status) {
    ReminderStatus.done => pal.ok,
    ReminderStatus.upcoming => pal.pri,
    ReminderStatus.missed => pal.high,
  };
  final String icon = switch (status) {
    ReminderStatus.done => AppIcons.check,
    ReminderStatus.upcoming => AppIcons.clock,
    ReminderStatus.missed => AppIcons.alert,
  };
  return StatusPill(s.t('rs_${status.name}'), color, icon: icon);
}

/// The patient's reminders, read-only. The caregiver cannot add, edit or
/// delete a reminder.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    if (c.isBlocking) return const BlockedPage();

    final pal = context.pal;
    final s = c.strings;
    final bool ar = c.arabic;
    final TextTheme t = Theme.of(context).textTheme;
    final List<Reminder> reminders = c.repository.reminders(c.level);

    return SubPage(
      title: s.t('remT'),
      children: <Widget>[
        LockNote(s.t('remNote')),
        const SizedBox(height: CgGap.lg),
        if (reminders.isEmpty)
          AppCard(
            child: EmptyState(
              icon: AppIcons.clock,
              title: s.t('remT'),
              message: s.t('remNote'),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: CgGap.lg),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < reminders.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: pal.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CgGap.lg, vertical: CgGap.md),
                    child: Row(
                      children: <Widget>[
                        IconCircle(reminderIcon(reminders[i].type), size: 38),
                        const SizedBox(width: CgGap.md + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                reminders[i].name.of(ar),
                                style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${s.t('rt_${reminders[i].type.name}')} · '
                                '${s.t(reminderRepeatKey(reminders[i].repeat))}',
                                style: t.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: CgGap.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              reminders[i].time,
                              textDirection: TextDirection.ltr,
                              style: t.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 124),
                              child: reminderStatusPill(context, reminders[i].status),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
