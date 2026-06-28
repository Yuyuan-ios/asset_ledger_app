import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

InputDecoration buildSheetInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  TextStyle? hintStyle,
  FloatingLabelBehavior floatingLabelBehavior = FloatingLabelBehavior.always,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? prefixText,
  String? helperText,
  String? errorText,
  bool? isDense,
  BoxConstraints? constraints = const BoxConstraints(
    minHeight: SheetTokens.fieldHeight,
  ),
  EdgeInsetsGeometry? contentPadding = const EdgeInsets.symmetric(
    horizontal: SheetTokens.fieldContentHPadding,
    vertical: SheetTokens.fieldContentVPadding,
  ),
}) {
  final labelStyle = AppTypography.bodySecondary(
    context,
    fontSize: SheetTokens.fieldLabelSize,
    color: SheetColors.fieldLabel,
  );
  final defaultHintStyle = AppTypography.bodySecondary(
    context,
    fontSize: SheetTokens.fieldTextSize,
    color: SheetColors.hint,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
    borderSide: const BorderSide(
      color: SheetColors.fieldBorder,
      width: SheetTokens.fieldBorderWidth,
    ),
  );

  return InputDecoration(
    labelText: labelText,
    floatingLabelBehavior: floatingLabelBehavior,
    labelStyle: labelStyle,
    hintText: hintText,
    hintStyle: hintStyle ?? defaultHintStyle,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    prefixText: prefixText,
    helperText: helperText,
    errorText: errorText,
    isDense: isDense,
    filled: true,
    fillColor: SheetColors.background,
    constraints: constraints,
    contentPadding: contentPadding,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    disabledBorder: border,
  );
}
