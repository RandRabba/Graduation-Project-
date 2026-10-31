import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../widgets/app_icon.dart';

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

/// Bottom navigation: Home / Readings / Alerts / Profile. The Alerts tab shows
/// the number of unread alerts.
class CaregiverBottomNav extends StatelessWidget {
  const CaregiverBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final double bottom = math.max(14.0, MediaQuery.of(context).padding.bottom);

    return Semantics(
      container: true,
      label: s.t('nav'),
      child: Material(
        color: pal.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(height: 1, color: pal.line),
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, bottom),
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
          ],
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
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? pal.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AppIcon(spec.icon, color: color),
                  ),
                  if (badge > 0)
                    PositionedDirectional(
                      top: -3,
                      end: 2,
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
              const SizedBox(height: 4),
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
