import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'toast.dart';

/// Round red button that calls [phone] straight away. 44px, so it is easy to
/// hit. Used next to the emergency contact.
class CallButton extends StatelessWidget {
  const CallButton({super.key, required this.phone});

  final String phone;

  Future<void> _call(BuildContext context) async {
    final controller = context.cgRead;
    final String failed = controller.strings.t('callFail');
    final bool ok = await controller.callPhone(phone);
    if (!ok && context.mounted) showToast(context, '$failed $phone', aboveNav: true);
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to call: a live backend may not have a number for this contact.
    if (phone.trim().isEmpty) return const SizedBox.shrink();
    final s = context.s;
    return Semantics(
      button: true,
      label: '${s.t('call')}: $phone',
      excludeSemantics: true,
      onTap: () => _call(context),
      child: Material(
        color: AppPalette.alertRed,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _call(context),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: AppIcon(AppIcons.phone, size: 20, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
