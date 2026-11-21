import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Labelled text field. [compact] is the 46px profile-form variant; the
/// default is the 52px sign-in variant. A field with [obscure] set gets a
/// show/hide button so the caregiver can check what was typed.
class AppTextField extends StatefulWidget {
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
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final AppTextField w = widget;
    final pal = context.pal;
    final s = context.s;
    // Same field style as the Patient app: filled, no idle outline, primary focus ring.
    OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: side,
        );

    return Padding(
      padding: EdgeInsets.only(top: w.topSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    w.label,
                    style: context.subStyle(13, FontWeight.w600),
                  ),
                ),
                if (w.badge != null) ...<Widget>[
                  const SizedBox(width: 8),
                  w.badge!,
                ],
              ],
            ),
          ),
          SizedBox(height: w.compact ? 4 : 6),
          Semantics(
            label: w.label,
            textField: true,
            child: TextField(
              controller: w.controller,
              keyboardType: w.keyboardType,
              obscureText: _hidden,
              enabled: w.enabled,
              textDirection: w.ltr ? TextDirection.ltr : null,
              autofillHints: w.autofillHints,
              textInputAction: w.textInputAction,
              onSubmitted: w.onSubmitted,
              onChanged: w.onChanged,
              cursorColor: pal.sec,
              style: TextStyle(
                fontSize: w.compact ? 14.5 : 15,
                height: 1.2,
                color: w.enabled ? pal.text : pal.sub,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: w.enabled ? pal.input : pal.bg,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: w.compact ? 12 : 14,
                  vertical: w.compact ? 14 : 17,
                ),
                hintStyle: TextStyle(color: pal.hint),
                border: border(BorderSide.none),
                enabledBorder: border(BorderSide.none),
                disabledBorder: border(BorderSide.none),
                focusedBorder: border(BorderSide(color: pal.pri, width: 1.5)),
                suffixIcon: w.obscure
                    ? IconButton(
                        tooltip: s.t(_hidden ? 'pwShow' : 'pwHide'),
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(
                          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 22,
                          color: pal.sub,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
