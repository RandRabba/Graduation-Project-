import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Corner radii, the same scale as the Patient app's `Radii`.
abstract final class AppRadii {
  static const double sm = 12, md = 16, lg = 22, xl = 28;
}

/// Material theme for the Caregiver module.
///
/// This mirrors `buildTheme` in the Patient app (`patient_interface/lib/theme.dart`):
/// same colour scheme, same text sizes and weights, same component themes, and
/// no custom font (the system font is used, as in the Patient app). Light and
/// dark come from [AppPalette.light] and [AppPalette.dark].
class AppTheme {
  const AppTheme._();

  static final ThemeData light = build(Brightness.light);
  static final ThemeData dark = build(Brightness.dark);

  static ThemeData build(Brightness brightness) {
    final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.pri,
      brightness: brightness,
    ).copyWith(
      primary: p.pri,
      onPrimary: p.onPri,
      primaryContainer: p.soft,
      onPrimaryContainer: p.pri,
      surface: p.card,
      onSurface: p.text,
      onSurfaceVariant: p.sub,
      surfaceContainerHighest: p.input,
      outline: p.line,
      outlineVariant: p.line,
      error: p.crit,
    );
    final text = TextTheme(
      displaySmall: TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1,
        color: p.text,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: p.text,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: p.text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: p.text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: p.text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: p.sub),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.sub,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.text),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.pri,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.input,
        hintStyle: TextStyle(color: p.hint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: p.pri, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.pri,
        linearTrackColor: p.soft,
      ),
    );
  }
}
