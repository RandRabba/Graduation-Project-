import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buttons.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/toast.dart';

/// Help and support: three common questions and a contact button.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    Widget faq(String titleKey, String bodyKey, double top) => Padding(
          padding: EdgeInsets.only(top: top),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.t(titleKey), style: context.hStyle(14)),
                const SizedBox(height: 4),
                Text(s.t(bodyKey), style: context.subStyle(13.5)),
              ],
            ),
          ),
        );

    return PageFrame(
      children: <Widget>[
        const BackRow(),
        ScreenTitle(s.t('helpT')),
        faq('h1', 'h1b', 14),
        faq('h2', 'h2b', 10),
        faq('h3', 'h3b', 10),
        const SizedBox(height: 14),
        PrimaryButton(
          label: s.t('contact'),
          onPressed: () => showToast(context, s.t('contactDone'), aboveNav: true),
        ),
      ],
    );
  }
}
