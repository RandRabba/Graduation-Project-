import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Text styles shared by all caregiver screens (sizes match the prototype).
extension CaregiverTextStyles on BuildContext {
  /// Bold heading text.
  TextStyle hStyle([double size = 15, FontWeight weight = FontWeight.w700]) =>
      TextStyle(fontSize: size, fontWeight: weight, color: pal.text, height: 1.3);

  /// Secondary (muted) text.
  TextStyle subStyle([double size = 12.5, FontWeight weight = FontWeight.w400]) =>
      TextStyle(fontSize: size, fontWeight: weight, color: pal.sub, height: 1.45);

  /// Regular body text.
  TextStyle bodyStyle([double size = 14, FontWeight weight = FontWeight.w400]) =>
      TextStyle(fontSize: size, fontWeight: weight, color: pal.text, height: 1.45);
}
