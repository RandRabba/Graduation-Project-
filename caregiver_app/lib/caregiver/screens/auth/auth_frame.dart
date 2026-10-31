import 'package:flutter/material.dart';

import '../../state/caregiver_scope.dart';
import '../../theme/app_palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheets.dart';

/// Shared layout for the sign-in flow: brand header, language switch and a
/// scrollable body. No bottom navigation is shown before the dashboard.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: pal.bg,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.pri,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: AppIcon(AppIcons.drop, color: pal.onPri),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(s.t('sysName'), style: context.hStyle(13.5)),
                              Text(s.t('sysSub'), style: context.subStyle(12)),
                            ],
                          ),
                        ),
                        TextLinkButton(
                          s.t('otherLang'),
                          fontSize: 13,
                          onPressed: () => c.setArabic(!c.arabic),
                        ),
                      ],
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
          PositionedDirectional(
            end: 16,
            bottom: 16 + safeBottom,
            child: const DemoFab(),
          ),
        ],
      ),
    );
  }
}

/// Large round icon used on the verify, accepted, ended and stub screens.
class StatusCircle extends StatelessWidget {
  const StatusCircle({
    super.key,
    required this.icon,
    required this.fg,
    required this.bg,
    this.iconSize = 38,
  });

  final String icon;
  final Color fg;
  final Color bg;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: AppIcon(icon, size: iconSize, color: fg),
      ),
    );
  }
}
