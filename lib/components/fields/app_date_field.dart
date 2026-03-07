import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../core/utils/format_utils.dart';

class SheetDateField extends StatelessWidget {
  const SheetDateField({
    super.key,
    required this.controller,
    required this.onPickDate,
    this.label,
    this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onPickDate;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final fieldStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    final hintStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.hint,
    );
    final labelStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldLabelSize,
      color: SheetColors.textPrimary,
    );

    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onPickDate,
      style: fieldStyle,
      decoration: InputDecoration(
        labelText: label ?? FormatUtils.ymdInputLabel,
        hintText: hint ?? FormatUtils.ymdInputHint,
        hintStyle: hintStyle,
        labelStyle: labelStyle,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: SheetColors.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SheetTokens.fieldContentHPadding,
          vertical: SheetTokens.fieldContentVPadding,
        ),
        suffixIcon: IconButton(
          onPressed: onPickDate,
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.calendar_month_outlined,
            color: SheetColors.muted,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: SheetColors.fieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: SheetColors.fieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: SheetColors.fieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        isDense: true,
      ),
    );
  }
}
