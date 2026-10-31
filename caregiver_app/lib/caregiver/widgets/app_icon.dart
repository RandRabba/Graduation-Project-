import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_palette.dart';

/// Stroke icon paths on a 24x24 grid. They are the same paths the design
/// prototype used, so icons match exactly.
class AppIcons {
  const AppIcons._();

  static const String home = 'M3 11.5 12 4l9 7.5M5.5 10v9.5h13V10';
  static const String chart = 'M4 19V5M4 19h16M8 15l3-4 3 3 5-7';
  static const String bell = 'M6 16v-5a6 6 0 1 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0';
  static const String user = 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20a7.5 7.5 0 0 1 15 0';
  static const String phone = 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a1 1 0 0 1-1 1A15 15 0 0 1 4 5a1 1 0 0 1 1-1z';
  static const String drop = 'M12 3.5c3.5 4 6 7 6 10a6 6 0 0 1-12 0c0-3 2.5-6 6-10z';
  static const String chev = 'M9 6l6 6-6 6';
  static const String back = 'M15 6l-6 6 6 6';
  static const String file = 'M7 3h7l4 4v14H7zM14 3v4h4M10 12h5M10 16h5';
  static const String pill = 'M10 20.5a4.5 4.5 0 0 1-3.2-7.7l6-6a4.5 4.5 0 0 1 6.4 6.4l-6 6a4.5 4.5 0 0 1-3.2 1.3zM8.5 10.5l5 5';
  static const String syringe = 'M15 4l5 5M17.5 6.5l-9 9-3 5 5-3 9-9M10 14l2 2';
  static const String clock = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2';
  static const String lock = 'M7 11V8a5 5 0 0 1 10 0v3M5 11h14v9H5z';
  static const String shield = 'M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6z';
  static const String check = 'M5 12.5l4.5 4.5L19 7.5';
  static const String alert = 'M12 4l9 16H3zM12 10v4M12 17.5v.01';
  static const String up = 'M12 19V5M6 11l6-6 6 6';
  static const String down = 'M12 5v14M6 13l6 6 6-6';
  static const String repeat = 'M4 12h4l2-6 4 12 2-6h4';
  static const String globe = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18';
  static const String moon = 'M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z';
  static const String help = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 1-1 1.7M12 17v.01';
  static const String logout = 'M10 4H5v16h5M15 8l4 4-4 4M19 12H9';
  static const String edit = 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4';
  static const String cal = 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4';
  static const String link = 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1';
  static const String cloud = 'M7 18a4.5 4.5 0 1 1 .8-8.9A6 6 0 0 1 19 11.5 3.3 3.3 0 0 1 18 18zM9 12l6 6M15 12l-6 6';
  static const String userx = 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20a7.5 7.5 0 0 1 11-6.6M17 17l4 4M21 17l-4 4';
  static const String mail = 'M4 6h16v12H4zM4 7l8 6 8-6';
  static const String x = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9 9l6 6M15 9l-6 6';
  static const String tune = 'M4 7h9M17 7h3M4 17h3M11 17h9M13 5v4M7 15v4';
}

/// A decorative stroke icon. Set [flip] for directional icons (chevrons,
/// back arrows) so they mirror in right-to-left layouts.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.path, {
    super.key,
    this.size = 20,
    this.color,
    this.flip = false,
    this.stroke = 1.8,
  });

  final String path;
  final double size;
  final Color? color;
  final bool flip;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? IconTheme.of(context).color ?? context.pal.text;
    final String svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="#000000" stroke-width="$stroke" '
        'stroke-linecap="round" stroke-linejoin="round"><path d="$path"/></svg>';
    Widget w = SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
    if (flip && Directionality.of(context) == TextDirection.rtl) {
      w = Transform.flip(flipX: true, child: w);
    }
    return ExcludeSemantics(child: w);
  }
}
