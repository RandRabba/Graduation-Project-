import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

OverlayEntry? _currentToast;
Timer? _toastTimer;

void _dismissToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  final OverlayEntry? entry = _currentToast;
  _currentToast = null;
  if (entry != null) {
    try {
      entry.remove();
    } catch (_) {
      // Already removed (for example when the app tree was rebuilt).
    }
  }
}

/// Shows a short message pill near the bottom of the screen for 2.6 seconds.
///
/// Set [aboveNav] when the bottom navigation bar is visible so the message
/// sits above it.
void showToast(BuildContext context, String message, {bool aboveNav = false}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _dismissToast();

  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext ctx) => _ToastView(message: message, bottom: aboveNav ? 92 : 28),
  );
  _currentToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(milliseconds: 2600), _dismissToast);
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.message, required this.bottom});

  final String message;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom + (bottom < 60 ? safeBottom : 0),
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (BuildContext ctx, double v, Widget? child) => Opacity(opacity: v, child: child),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: pal.pri,
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pal.onPri,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.4,
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
