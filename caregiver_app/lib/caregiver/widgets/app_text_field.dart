import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/text_styles.dart';

/// Labelled text field. [compact] is the 46px profile-form variant; the
/// default is the 52px sign-in variant.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.ltr = false,
    this.compact = false,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.badge,
    this.topSpacing = 16,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;

  /// Force left-to-right input (phone numbers).
  final bool ltr;
  final bool compact;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// Optional small widget next to the label (for example "Verified").
  final Widget? badge;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final double radius = compact ? 12 : 14;
    final double borderWidth = compact ? 1 : 1.5;
    final Color idle = compact ? pal.line : pal.inputBorder;

    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c, width: w),
        );

    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    style: context.subStyle(13, FontWeight.w600),
                  ),
                ),
                if (badge != null) ...<Widget>[
                  const SizedBox(width: 8),
                  badge!,
                ],
              ],
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Semantics(
            label: label,
            textField: true,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscure,
              enabled: enabled,
              textDirection: ltr ? TextDirection.ltr : null,
              autofillHints: autofillHints,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              cursorColor: pal.sec,
              style: TextStyle(
                fontSize: compact ? 14.5 : 15,
                height: 1.2,
                color: enabled ? pal.text : pal.sub,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: enabled ? pal.input : pal.bg,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 14 : 17,
                ),
                border: border(idle, borderWidth),
                enabledBorder: border(idle, borderWidth),
                disabledBorder: border(pal.line, borderWidth),
                focusedBorder: border(pal.acc, 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
