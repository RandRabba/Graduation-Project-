import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Keeps the app phone-sized on a wide screen (for example Chrome on a laptop):
/// a centred column at most [maxWidth] wide, with a quiet backdrop on both
/// sides. On a phone, or any window narrower than [maxWidth], it does nothing.
///
/// It sits above the Navigator, so sheets, dialogs and toasts stay inside the
/// column too.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// Widest the app is drawn, in logical pixels.
  static const double maxWidth = 480;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final MediaQueryData media = MediaQuery.of(context);
    final bool wide = media.size.width > maxWidth;

    // The widget tree has the same shape on a phone and on a wide screen, so
    // resizing the window never rebuilds the screens inside.
    return ColoredBox(
      color: wide ? pal.input : Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: wide ? pal.bg : null,
              border: wide ? Border.symmetric(vertical: BorderSide(color: pal.line)) : null,
            ),
            child: MediaQuery(
              data: wide ? media.copyWith(size: Size(maxWidth, media.size.height)) : media,
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
