import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/page_frame.dart';
import '../profile/privacy_screen.dart';
import '../routes.dart';

/// Shown instead of a section the patient has not shared (Basic monitoring).
class RestrictedScreen extends StatelessWidget {
  const RestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    return PageFrame(
      children: <Widget>[
        const BackRow(),
        const SizedBox(height: 40),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Column(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.soft, shape: BoxShape.circle),
                child: AppIcon(AppIcons.lock, size: 28, color: pal.sec),
              ),
              const SizedBox(height: 14),
              Text(s.t('restr_t'), textAlign: TextAlign.center, style: context.hStyle(18)),
              const SizedBox(height: 6),
              Text(s.t('restr_s'), textAlign: TextAlign.center, style: context.subStyle(13.5)),
              const SizedBox(height: 10),
              TextLinkButton(
                s.t('privTitle'),
                onPressed: () => pushScreen(context, const PrivacyScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
