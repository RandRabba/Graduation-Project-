import 'package:flutter/widgets.dart';

import '../l10n/app_strings.dart';
import 'caregiver_controller.dart';

/// Makes the [CaregiverController] available to the whole module.
///
/// Widgets that call [CaregiverScope.of] rebuild whenever the controller
/// notifies. Use [CaregiverScope.read] inside callbacks.
class CaregiverScope extends InheritedNotifier<CaregiverController> {
  const CaregiverScope({
    super.key,
    required CaregiverController controller,
    required super.child,
  }) : super(notifier: controller);

  static CaregiverController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CaregiverScope>();
    assert(scope != null, 'CaregiverScope not found. Wrap the widget tree in CaregiverModule.');
    return scope!.notifier!;
  }

  static CaregiverController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<CaregiverScope>();
    assert(element != null, 'CaregiverScope not found. Wrap the widget tree in CaregiverModule.');
    return (element!.widget as CaregiverScope).notifier!;
  }
}

extension CaregiverContext on BuildContext {
  /// The controller, rebuilding the caller when it changes.
  CaregiverController get cg => CaregiverScope.of(this);

  /// The controller without subscribing to changes (use in callbacks).
  CaregiverController get cgRead => CaregiverScope.read(this);

  /// Strings for the current language.
  AppStrings get s => CaregiverScope.of(this).strings;
}
