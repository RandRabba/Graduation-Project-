import 'package:flutter/material.dart';

import '../models/models.dart';

/// Colour tokens for the Caregiver module.
///
/// The VALUES are the Patient app's palette (`patient_interface/lib/theme.dart`,
/// `AppPalette.light` and `AppPalette.dark`), copied hex for hex, so both apps
/// look the same in light and dark mode. If the Patient palette changes, change
/// the matching lines here.
///
/// The short caregiver NAMES are kept so the screens did not have to change:
///
/// | caregiver     | patient          |
/// | ------------- | ---------------- |
/// | `bg`          | `bg`             |
/// | `card`        | `surface`        |
/// | `text`        | `ink`            |
/// | `sub`         | `muted`          |
/// | `hint`        | `hint`           |
/// | `line`        | `border`         |
/// | `input`       | `surfaceAlt`     |
/// | `pri`         | `primary`        |
/// | `acc`         | `primaryBright`  |
/// | `onPri`       | `onPrimary`      |
/// | `soft`        | `primarySoft`    |
/// | `ok`          | `normal`         |
/// | `ctl`         | `primary`        |
/// | `high`        | `caution`        |
/// | `low`         | `elevated`       |
/// | `crit`        | `critical`       |
///
/// Status backgrounds (`okBg`, `highBg`, ...) are the status colour at the
/// same alpha the Patient app uses for its status pills.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.text,
    required this.sub,
    required this.hint,
    required this.line,
    required this.input,
    required this.pri,
    required this.acc,
    required this.onPri,
    required this.soft,
    required this.ok,
    required this.ctl,
    required this.high,
    required this.low,
    required this.crit,
    required this.heroStart,
    required this.heroEnd,
    required this.ctaStart,
    required this.ctaEnd,
    required this.shadow,
  });

  /// Page background, cards, inset fills, hairlines.
  final Color bg, card, input, line;

  /// Text: main, secondary, placeholder.
  final Color text, sub, hint;

  /// [pri] is safe for text and button fills; [acc] is for charts and decoration.
  final Color pri, acc, onPri, soft;

  /// Status colours: stable, controlled, caution (high), elevated (low), critical.
  /// Always pair them with a label or glyph, never colour alone.
  final Color ok, ctl, high, low, crit;

  /// Gradient of the dark "hero" cards (white text on top).
  final Color heroStart, heroEnd;

  /// Gradient of the main call-to-action button ([onPri] text on top).
  final Color ctaStart, ctaEnd;

  /// Card shadow colour.
  final Color shadow;

  /// Fixed solid red for badges and solid emergency fills with white text.
  /// Same in both modes on purpose, so white text keeps its contrast.
  /// This is the Patient app's light-mode `critical`.
  static const Color alertRed = Color(0xFFD12F3A);

  static const AppPalette light = AppPalette(
    bg: Color(0xFFEFF8FC),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF0B2545),
    sub: Color(0xFF55708A),
    hint: Color(0xFF8BA3B8),
    line: Color(0xFFD2EAF3),
    input: Color(0xFFE7F5FA),
    pri: Color(0xFF087F9E),
    acc: Color(0xFF1BBDE0),
    onPri: Color(0xFFFFFFFF),
    soft: Color(0xFFDDF2F9),
    ok: Color(0xFF13824F),
    ctl: Color(0xFF087F9E),
    high: Color(0xFF9A7300),
    low: Color(0xFFC25E0E),
    crit: Color(0xFFD12F3A),
    heroStart: Color(0xFF0B8DB2),
    heroEnd: Color(0xFF0A4F86),
    ctaStart: Color(0xFF0E9DC3),
    ctaEnd: Color(0xFF0A7398),
    shadow: Color(0x1A0A6E9A),
  );

  // Low-glare dark: desaturated slate-navy, soft off-white text and a muted cyan accent.
  static const AppPalette dark = AppPalette(
    bg: Color(0xFF0F1A24),
    card: Color(0xFF16232F),
    text: Color(0xFFD9E3EA),
    sub: Color(0xFF94A6B4),
    hint: Color(0xFF64798A),
    line: Color(0xFF263746),
    input: Color(0xFF1C2B38),
    pri: Color(0xFF5CC8D8),
    acc: Color(0xFF5CC8D8),
    onPri: Color(0xFF0B1F27),
    soft: Color(0xFF1B3440),
    ok: Color(0xFF6FCF97),
    ctl: Color(0xFF5CC8D8),
    high: Color(0xFFE6C36A),
    low: Color(0xFFF0A070),
    crit: Color(0xFFEF7B7B),
    heroStart: Color(0xFF1D3B4B),
    heroEnd: Color(0xFF15283A),
    ctaStart: Color(0xFF68D0DE),
    ctaEnd: Color(0xFF4BB4C8),
    shadow: Color(0x33000000),
  );

  // ---- Derived tokens ------------------------------------------------------

  /// Same as `line`; the Patient app has no separate input border.
  Color get inputBorder => line;

  /// The Patient app has no secondary colour: links and accents use primary.
  Color get sec => pri;

  Color get okBg => ok.withAlpha(30);
  Color get ctlBg => ctl.withAlpha(30);
  Color get highBg => high.withAlpha(30);
  Color get lowBg => low.withAlpha(30);
  Color get critBg => crit.withAlpha(30);

  /// Card shadow, identical to the Patient app's `AppCard`.
  List<BoxShadow> get shadows => <BoxShadow>[
        BoxShadow(color: shadow, blurRadius: 20, offset: const Offset(0, 6)),
      ];

  LinearGradient get hero => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: <Color>[heroStart, heroEnd],
      );

  LinearGradient get cta => LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: <Color>[ctaStart, ctaEnd],
      );

  Color fg(Tone t) {
    switch (t) {
      case Tone.ok:
        return ok;
      case Tone.ctl:
        return ctl;
      case Tone.high:
        return high;
      case Tone.low:
        return low;
      case Tone.crit:
        return crit;
    }
  }

  Color bgOf(Tone t) {
    switch (t) {
      case Tone.ok:
        return okBg;
      case Tone.ctl:
        return ctlBg;
      case Tone.high:
        return highBg;
      case Tone.low:
        return lowBg;
      case Tone.crit:
        return critBg;
    }
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      text: l(text, other.text),
      sub: l(sub, other.sub),
      hint: l(hint, other.hint),
      line: l(line, other.line),
      input: l(input, other.input),
      pri: l(pri, other.pri),
      acc: l(acc, other.acc),
      onPri: l(onPri, other.onPri),
      soft: l(soft, other.soft),
      ok: l(ok, other.ok),
      ctl: l(ctl, other.ctl),
      high: l(high, other.high),
      low: l(low, other.low),
      crit: l(crit, other.crit),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
      ctaStart: l(ctaStart, other.ctaStart),
      ctaEnd: l(ctaEnd, other.ctaEnd),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
