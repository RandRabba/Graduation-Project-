import 'package:flutter/material.dart';

/// Spacing scale (logical pixels).
abstract final class Gap {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 28.0;

  /// Side padding of every page.
  static const page = 20.0;
}

/// Corner radii.
abstract final class Radii {
  static const sm = 12.0, md = 16.0, lg = 22.0, xl = 28.0;
}

/// Colour tokens for one brightness. Read them with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.primaryBright,
    required this.onPrimary,
    required this.primarySoft,
    required this.ink,
    required this.muted,
    required this.hint,
    required this.normal,
    required this.caution,
    required this.elevated,
    required this.critical,
    required this.heroStart,
    required this.heroEnd,
    required this.ctaStart,
    required this.ctaEnd,
    required this.shadow,
  });

  /// Page background, cards, inset fills, hairlines.
  final Color bg, surface, surfaceAlt, border;

  /// [primary] is safe for text and button fills; [primaryBright] is for charts and decoration.
  final Color primary, primaryBright, onPrimary, primarySoft;

  /// Text: main, secondary, placeholder.
  final Color ink, muted, hint;

  /// Medical status: stable, caution, elevated concern, critical. Always pair with a label or icon.
  final Color normal, caution, elevated, critical;

  /// Gradient of the dark "hero" cards (white text on top).
  final Color heroStart, heroEnd;

  /// Gradient of the main call-to-action buttons ([onPrimary] text on top).
  final Color ctaStart, ctaEnd;
  final Color shadow;

  static const light = AppPalette(
    bg: Color(0xFFEFF8FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE7F5FA),
    border: Color(0xFFD2EAF3),
    primary: Color(0xFF087F9E),
    primaryBright: Color(0xFF1BBDE0),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFDDF2F9),
    ink: Color(0xFF0B2545),
    muted: Color(0xFF55708A),
    hint: Color(0xFF8BA3B8),
    normal: Color(0xFF13824F),
    caution: Color(0xFF9A7300),
    elevated: Color(0xFFC25E0E),
    critical: Color(0xFFD12F3A),
    heroStart: Color(0xFF0B8DB2),
    heroEnd: Color(0xFF0A4F86),
    ctaStart: Color(0xFF0E9DC3),
    ctaEnd: Color(0xFF0A7398),
    shadow: Color(0x1A0A6E9A),
  );

  // Low-glare dark: desaturated slate-navy, soft off-white text and a muted cyan accent.
  static const dark = AppPalette(
    bg: Color(0xFF0F1A24),
    surface: Color(0xFF16232F),
    surfaceAlt: Color(0xFF1C2B38),
    border: Color(0xFF263746),
    primary: Color(0xFF5CC8D8),
    primaryBright: Color(0xFF5CC8D8),
    onPrimary: Color(0xFF0B1F27),
    primarySoft: Color(0xFF1B3440),
    ink: Color(0xFFD9E3EA),
    muted: Color(0xFF94A6B4),
    hint: Color(0xFF64798A),
    normal: Color(0xFF6FCF97),
    caution: Color(0xFFE6C36A),
    elevated: Color(0xFFF0A070),
    critical: Color(0xFFEF7B7B),
    heroStart: Color(0xFF1D3B4B),
    heroEnd: Color(0xFF15283A),
    ctaStart: Color(0xFF68D0DE),
    ctaEnd: Color(0xFF4BB4C8),
    shadow: Color(0x33000000),
  );

  LinearGradient get hero => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [heroStart, heroEnd],
  );

  LinearGradient get cta => LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [ctaStart, ctaEnd],
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      primaryBright: l(primaryBright, other.primaryBright),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      hint: l(hint, other.hint),
      normal: l(normal, other.normal),
      caution: l(caution, other.caution),
      elevated: l(elevated, other.elevated),
      critical: l(critical, other.critical),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
      ctaStart: l(ctaStart, other.ctaStart),
      ctaEnd: l(ctaEnd, other.ctaEnd),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Text roles used across the app:
/// displaySmall = big glucose value, headlineMedium = page title, titleMedium = card title,
/// bodyLarge = body, bodyMedium = secondary text, labelSmall = captions.
ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primarySoft,
        onPrimaryContainer: p.primary,
        surface: p.surface,
        onSurface: p.ink,
        onSurfaceVariant: p.muted,
        surfaceContainerHighest: p.surfaceAlt,
        outline: p.border,
        outlineVariant: p.border,
        error: p.critical,
      );
  final text = TextTheme(
    displaySmall: TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -1,
      color: p.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: p.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: p.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: p.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: p.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: p.muted),
    labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: p.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: p.muted,
    ),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    textTheme: text,
    extensions: [p],
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontSize: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      hintStyle: TextStyle(color: p.hint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.primarySoft,
    ),
  );
}

extension ThemeX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
