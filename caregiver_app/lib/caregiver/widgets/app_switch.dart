import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 50x30 toggle matching the prototype. The knob moves toward the end side,
/// so it mirrors automatically in right-to-left layouts.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Accessible name, for example "Dark mode".
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      container: true,
      label: label,
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: SizedBox(
            width: 50,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? pal.pri : pal.line,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: AlignmentDirectional(value ? 1 : -1, 0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
