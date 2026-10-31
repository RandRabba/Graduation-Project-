import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'segmented.dart';
import 'toast.dart';

Future<void> _showSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    // Cover the bottom navigation bar too, like the prototype.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C071525),
    elevation: 0,
    builder: builder,
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: label,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 22, 20, 26 + bottom),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _SheetTextButton extends StatelessWidget {
  const _SheetTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.subStyle(15, FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency contact
// ---------------------------------------------------------------------------

/// Bottom sheet with the patient's emergency contact and a "Call now" button.
Future<void> showEmergencySheet(BuildContext context) {
  return _showSheet(context, (BuildContext sheetContext) => _EmergencySheet(outerContext: context));
}

class _EmergencySheet extends StatelessWidget {
  const _EmergencySheet({required this.outerContext});

  final BuildContext outerContext;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final EmergencyContact ec = c.repository.patient.emergencyContact;
    final bool ar = c.arabic;

    return _SheetShell(
      label: s.t('emerg'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.t('emerg'), style: context.hStyle(18)),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Avatar(ec.initials.of(ar), size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(ec.name.of(ar), style: context.hStyle(14)),
                    Text(ec.relation.of(ar), style: context.subStyle(12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: pal.bg, borderRadius: BorderRadius.circular(14)),
            child: Text(
              ec.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: pal.text,
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: s.t('call'),
            icon: AppIcons.phone,
            onPressed: () {
              final controller = context.cgRead;
              final String message = controller.strings.t('calling');
              final ValueChanged<String>? callback = controller.onCall;
              Navigator.of(context).pop();
              if (callback != null) {
                callback(ec.phone);
              } else if (outerContext.mounted) {
                showToast(outerContext, message, aboveNav: true);
              }
            },
          ),
          const SizedBox(height: 6),
          _SheetTextButton(label: s.t('close'), onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disconnect confirmation
// ---------------------------------------------------------------------------

/// Confirmation sheet shown before the caregiver disconnects from the patient.
Future<void> showDisconnectSheet(BuildContext context) {
  return _showSheet(context, (BuildContext sheetContext) => _DisconnectSheet(outerContext: context));
}

class _DisconnectSheet extends StatelessWidget {
  const _DisconnectSheet({required this.outerContext});

  final BuildContext outerContext;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _SheetShell(
      label: s.t('discT'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.t('discT'), style: context.hStyle(18)),
          const SizedBox(height: 8),
          Text(s.t('discB'), style: context.subStyle(14)),
          const SizedBox(height: 18),
          PrimaryButton(
            label: s.t('discOk'),
            background: AppPalette.alertRed,
            foreground: Colors.white,
            minHeight: 50,
            onPressed: () {
              final controller = context.cgRead;
              final String message = controller.strings.t('discDone');
              Navigator.of(context).pop();
              controller.disconnect();
              if (outerContext.mounted) {
                showToast(outerContext, message, aboveNav: true);
              }
            },
          ),
          const SizedBox(height: 6),
          _SheetTextButton(label: s.t('pfCancel'), onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo controls (prototype only)
// ---------------------------------------------------------------------------

/// Opens the demo controls: access level, theme, language and data states.
/// Only reachable when `showDemoControls` is true. Text is English-only on
/// purpose: it is developer tooling and is removed in the integrated app.
Future<void> showDemoSheet(BuildContext context) {
  return _showSheet(context, (BuildContext sheetContext) => const _DemoSheet());
}

class _DemoSheet extends StatelessWidget {
  const _DemoSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(text, style: context.hStyle(13)),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: _SheetShell(
        label: 'Prototype controls',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Prototype controls', style: context.hStyle(18)),
            const SizedBox(height: 6),
            Text(
              'Mock data for demonstration only. In the real app the access level '
              'comes from the backend, and restricted data is never sent to the device.',
              style: context.subStyle(12.5),
            ),
            label('Access level (set by the patient)'),
            SegmentedBar<AccessLevel>(
              options: <SegmentOption<AccessLevel>>[
                SegmentOption<AccessLevel>(AccessLevel.basic, 'Basic'),
                SegmentOption<AccessLevel>(AccessLevel.extended, 'Extended'),
              ],
              selected: c.level,
              onChanged: c.setLevel,
            ),
            label('Theme'),
            SegmentedBar<bool>(
              options: <SegmentOption<bool>>[
                SegmentOption<bool>(false, 'Light'),
                SegmentOption<bool>(true, 'Dark'),
              ],
              selected: c.dark,
              onChanged: c.setDark,
            ),
            label('Language and direction'),
            SegmentedBar<bool>(
              options: <SegmentOption<bool>>[
                SegmentOption<bool>(false, 'English · LTR'),
                SegmentOption<bool>(true, 'العربية · RTL'),
              ],
              selected: c.arabic,
              onChanged: c.setArabic,
            ),
            label('Data state'),
            ChoicePills<DataState>(
              outlined: true,
              options: <SegmentOption<DataState>>[
                SegmentOption<DataState>(DataState.normal, 'Normal'),
                SegmentOption<DataState>(DataState.loading, 'Loading'),
                SegmentOption<DataState>(DataState.staleReading, 'Old reading'),
                SegmentOption<DataState>(DataState.noReading, 'No reading'),
                SegmentOption<DataState>(DataState.noAlerts, 'No alerts'),
                SegmentOption<DataState>(DataState.error, 'Error'),
                SegmentOption<DataState>(DataState.revoked, 'Access revoked'),
                SegmentOption<DataState>(DataState.noPatient, 'No linked patient'),
              ],
              selected: c.dataState,
              onChanged: c.setDataState,
            ),
            label('Invitation state (sign-in flow)'),
            ChoicePills<InvitationState>(
              outlined: true,
              options: <SegmentOption<InvitationState>>[
                SegmentOption<InvitationState>(InvitationState.pending, 'Pending'),
                SegmentOption<InvitationState>(InvitationState.expired, 'Expired'),
                SegmentOption<InvitationState>(InvitationState.declined, 'Declined'),
                SegmentOption<InvitationState>(InvitationState.revoked, 'Revoked'),
                SegmentOption<InvitationState>(InvitationState.accepted, 'Accepted'),
              ],
              selected: c.invitation,
              onChanged: c.setInvitation,
            ),
            label('Role returned after login'),
            SegmentedBar<bool>(
              options: <SegmentOption<bool>>[
                SegmentOption<bool>(false, 'CAREGIVER'),
                SegmentOption<bool>(true, 'PATIENT'),
              ],
              selected: c.roleIsPatient,
              onChanged: c.setRoleIsPatient,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: pal.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Everything in the caregiver app is read-only: there are no add, edit '
                'or delete controls for readings, reminders, medications or doctor instructions.',
                style: context.subStyle(12.5),
              ),
            ),
            const SizedBox(height: 6),
            _SheetTextButton(label: 'Close', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// Small round button that opens the demo controls. Renders nothing when
/// `showDemoControls` is false, so it is safe to leave in place.
class DemoFab extends StatelessWidget {
  const DemoFab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.cgRead.showDemoControls) return const SizedBox.shrink();
    final pal = context.pal;
    return Semantics(
      button: true,
      label: 'Prototype controls',
      excludeSemantics: true,
      onTap: () => showDemoSheet(context),
      child: Material(
        color: pal.pri,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showDemoSheet(context),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(child: AppIcon(AppIcons.tune, color: pal.onPri)),
          ),
        ),
      ),
    );
  }
}
