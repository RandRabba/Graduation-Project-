import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Builds the Material theme from the palette. Latin text uses Plus Jakarta
/// Sans and Arabic uses IBM Plex Sans Arabic, as in the design prototype.
class AppTheme {
  const AppTheme._();

  static ThemeData build({required bool dark, required bool arabic}) {
    final pal = dark ? AppPalette.dark : AppPalette.light;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final TextTheme fontTheme = arabic
        ? GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        : GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final scheme = ColorScheme.fromSeed(
      seedColor: pal.pri,
      brightness: brightness,
    ).copyWith(
      primary: pal.pri,
      onPrimary: pal.onPri,
      secondary: pal.sec,
      surface: pal.card,
      onSurface: pal.text,
      error: pal.crit,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: pal.bg,
      canvasColor: pal.bg,
      textTheme: fontTheme.apply(bodyColor: pal.text, displayColor: pal.text),
      dividerColor: pal.line,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[pal],
    );
  }
}
