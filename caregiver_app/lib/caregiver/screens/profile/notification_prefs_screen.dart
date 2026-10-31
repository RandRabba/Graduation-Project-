import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/toast.dart';

class _PrefItem {
  const _PrefItem(this.key, this.labelKey, this.noteKey);

  final String key;
  final String labelKey;
  final String? noteKey;
}

/// Notification preferences. Critical alerts are always on. The other
/// switches exist for Extended monitoring only. This screen stores the
/// preferences; delivery is the backend's job.
class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;

    final List<_PrefItem> items = <_PrefItem>[
      const _PrefItem('crit', 'nCrit', 'nCritNote'),
      if (c.isExtended) ...const <_PrefItem>[
        _PrefItem('high', 'nHigh', null),
        _PrefItem('low', 'nLow', null),
        _PrefItem('rep', 'nRep', null),
        _PrefItem('rem', 'nRem', null),
      ],
    ];

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('notifPref')),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  decoration: i == items.length - 1
                      ? null
                      : BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                s.t(items[i].labelKey),
                                style: context.bodyStyle(14, FontWeight.w600),
                              ),
                              if (items[i].noteKey != null)
                                Text(s.t(items[i].noteKey!), style: context.subStyle()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppSwitch(
                        label: s.t(items[i].labelKey),
                        value: items[i].key == 'crit' ? true : c.notifEnabled(items[i].key),
                        onChanged: (bool v) {
                          if (items[i].key == 'crit') {
                            showToast(context, s.t('nCritNote'), aboveNav: true);
                          } else {
                            c.setNotif(items[i].key, v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(s.t('nNote'), style: context.subStyle()),
      ],
    );
  }
}
