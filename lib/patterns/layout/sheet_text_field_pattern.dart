import 'package:flutter/material.dart';

import '../../components/fields/sheet_input_decoration.dart';
import '../../core/foundation/typography.dart';
import '../../core/utils/text_field_utils.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

class SheetTextFieldPattern extends StatelessWidget {
  const SheetTextFieldPattern({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.hintStyle,
    this.keyboardType,
    this.floatingLabelBehavior = FloatingLabelBehavior.always,
    this.selectAllOnTap = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.errorText,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final TextStyle? hintStyle;
  final TextInputType? keyboardType;
  final FloatingLabelBehavior floatingLabelBehavior;
  final bool selectAllOnTap;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final String? errorText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      onTap: selectAllOnTap
          ? () => selectAllText(controller)
          : (keyboardType == null
                ? null
                : () => selectAllIfZeroLike(controller)),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: textStyle,
      decoration: buildSheetInputDecoration(
        context,
        labelText: labelText,
        floatingLabelBehavior: floatingLabelBehavior,
        hintText: hintText,
        hintStyle: hintStyle,
        errorText: errorText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }
}
