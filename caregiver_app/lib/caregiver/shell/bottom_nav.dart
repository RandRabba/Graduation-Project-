import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/patient_style.dart';

class _NavSpec {
  const _NavSpec(this.icon, this.labelKey);

  final String icon;
  final String labelKey;
}

const List<_NavSpec> _tabs = <_NavSpec>[
  _NavSpec(AppIcons.home, 'tHome'),
  _NavSpec(AppIcons.chart, 'tRead'),
  _NavSpec(AppIcons.bell, 'tAlerts'),
  _NavSpec(AppIcons.user, 'tProfile'),
];

/// Bottom navigation: Home / Readings / Alerts / Profile.
///
/// Same floating rounded bar as the Patient app. The Alerts tab shows the
/// number of unread alerts.
class CaregiverBottomNav extends StatelessWidget {
  const CaregiverBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;

    return Semantics(
      container: true,
      label: s.t('nav'),
      child: Material(
        color: pal.bg,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: CgGap.sm),
          child: Container(
            margin: const EdgeInsets.fromLTRB(CgGap.md, CgGap.xs, CgGap.md, CgGap.xs),
            padding: const EdgeInsets.symmetric(horizontal: CgGap.xs, vertical: CgGap.xs + 2),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: pal.line),
              boxShadow: <BoxShadow>[
                BoxShadow(color: pal.shadow, blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      spec: _tabs[i],
                      label: s.t(_tabs[i].labelKey),
                      selected: c.tabIndex == i,
                      badge: i == 2 ? c.unreadCount : 0,
                      onTap: () => c.selectTab(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _NavSpec spec;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final Color color = selected ? pal.pri : pal.sub;
    final String badgeText = badge > 9 ? '9+' : '$badge';
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badgeText' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CgGap.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 52,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? pal.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: AppIcon(spec.icon, size: 24, color: color),
                  ),
                  if (badge > 0)
                    PositionedDirectional(
                      top: -3,
                      end: 0,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.alertRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CgGap.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
