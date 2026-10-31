import 'package:flutter/material.dart';

import '../models/models.dart';

/// Colour tokens, identical to the design prototype (light and dark).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.text,
    required this.sub,
    required this.line,
    required this.inputBorder,
    required this.pri,
    required this.onPri,
    required this.sec,
    required this.acc,
    required this.soft,
    required this.input,
    required this.shadows,
    required this.ok,
    required this.okBg,
    required this.ctl,
    required this.ctlBg,
    required this.high,
    required this.highBg,
    required this.low,
    required this.lowBg,
    required this.crit,
    required this.critBg,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color text;
  final Color sub;
  final Color line;
  final Color inputBorder;
  final Color pri;
  final Color onPri;
  final Color sec;
  final Color acc;
  final Color soft;
  final Color input;
  final List<BoxShadow> shadows;
  final Color ok;
  final Color okBg;
  final Color ctl;
  final Color ctlBg;
  final Color high;
  final Color highBg;
  final Color low;
  final Color lowBg;
  final Color crit;
  final Color critBg;

  /// Fixed solid red used for badges and the emergency call button.
  static const Color alertRed = Color(0xFFC62828);

  static const AppPalette light = AppPalette(
    isDark: false,
    bg: Color(0xFFF5FBFD),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF0A1A33),
    sub: Color(0xFF4F6275),
    line: Color(0xFFDCEBF1),
    inputBorder: Color(0xFFC9DDE5),
    pri: Color(0xFF08085F),
    onPri: Color(0xFFFFFFFF),
    sec: Color(0xFF045F88),
    acc: Color(0xFF00B5D1),
    soft: Color(0xFFC7EEF5),
    input: Color(0xFFFFFFFF),
    shadows: <BoxShadow>[
      BoxShadow(color: Color(0x1408085F), blurRadius: 12, offset: Offset(0, 2)),
    ],
    ok: Color(0xFF1B6B4B),
    okBg: Color(0xFFE2F4EA),
    ctl: Color(0xFF045F88),
    ctlBg: Color(0xFFDDF1F9),
    high: Color(0xFF8A4B00),
    highBg: Color(0xFFFFF0D2),
    low: Color(0xFF6B3FA0),
    lowBg: Color(0xFFEFE7FA),
    crit: Color(0xFFB3261E),
    critBg: Color(0xFFFDEBEA),
  );

  static const AppPalette dark = AppPalette(
    isDark: true,
    bg: Color(0xFF071525),
    card: Color(0xFF10243A),
    text: Color(0xFFF0F8FF),
    sub: Color(0xFFA8BDCF),
    line: Color(0xFF294158),
    inputBorder: Color(0xFF294158),
    pri: Color(0xFF22C1DC),
    onPri: Color(0xFF071525),
    sec: Color(0xFF66C7E8),
    acc: Color(0xFF22C1DC),
    soft: Color(0xFF0B1C2D),
    input: Color(0xFF0B1C2D),
    shadows: <BoxShadow>[],
    ok: Color(0xFF5FD6A0),
    okBg: Color(0xFF11332A),
    ctl: Color(0xFF7CCBEF),
    ctlBg: Color(0xFF0F2F45),
    high: Color(0xFFF5C26B),
    highBg: Color(0xFF3A2E12),
    low: Color(0xFFC9A8F5),
    lowBg: Color(0xFF2B2142),
    crit: Color(0xFFFF8A84),
    critBg: Color(0xFF3B1A1E),
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
    return t < 0.5 ? this : other;
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
