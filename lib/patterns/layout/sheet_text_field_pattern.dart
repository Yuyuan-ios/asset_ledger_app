import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

class SheetTextFieldPattern extends StatelessWidget {
  const SheetTextFieldPattern({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.keyboardType,
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final FloatingLabelBehavior floatingLabelBehavior;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    final labelStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldLabelSize,
      color: SheetColors.textPrimary,
    );
    final hintStyle = AppTypography.bodySecondary(
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

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: textStyle,
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: floatingLabelBehavior,
        labelStyle: labelStyle,
        hintText: hintText,
        hintStyle: hintStyle,
        isDense: true,
        filled: true,
        fillColor: SheetColors.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SheetTokens.fieldContentHPadding,
          vertical: SheetTokens.fieldContentVPadding,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        disabledBorder: border,
      ),
    );
  }
}
