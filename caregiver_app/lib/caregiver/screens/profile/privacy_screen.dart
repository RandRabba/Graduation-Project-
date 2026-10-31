import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lock_note.dart';
import '../../widgets/page_frame.dart';

/// Plain-language list of what this caregiver can and cannot see. The access
/// level is set by the patient and cannot be changed here.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final bool ext = c.isExtended;

    const List<String> always = <String>['pv_name', 'pv_latest', 'pv_status', 'pv_crit', 'pv_emerg'];
    const List<String> extendedOnly = <String>['pv_hist', 'pv_rep', 'pv_rem', 'pv_ins'];

    final List<String> can = <String>[...always, if (ext) ...extendedOnly];
    final List<String> cant = ext ? const <String>[] : extendedOnly;

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('privTitle')),
        const SizedBox(height: 14),
        AppCard(
          color: pal.soft,
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppChip(
                  ext ? s.t('lvExt') : s.t('lvBasic'),
                  fg: pal.pri,
                  bg: pal.card,
                  icon: AppIcons.shield,
                ),
              ),
              const SizedBox(height: 8),
              Text(s.t('privIntro'), style: context.bodyStyle(13.5)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(s.t('privCan'), style: context.subStyle(12.5, FontWeight.w700)),
              for (final String key in can)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: <Widget>[
                      AppIcon(AppIcons.check, color: pal.ok),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.t(key), style: context.bodyStyle())),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (cant.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(s.t('privCant'), style: context.subStyle(12.5, FontWeight.w700)),
                for (final String key in cant)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: <Widget>[
                        AppIcon(AppIcons.lock, color: pal.sub),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.t(key), style: context.subStyle(14))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        LockNote(s.t('pv_never')),
      ],
    );
  }
}
