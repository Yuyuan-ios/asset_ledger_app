import 'package:flutter/material.dart';

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
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onPickDate,
      style: const TextStyle(
        fontSize: SheetTokens.fieldTextSize,
        color: AppColors.sheetTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label ?? FormatUtils.ymdInputLabel,
        hintText: hint ?? FormatUtils.ymdInputHint,
        hintStyle: const TextStyle(
          fontSize: SheetTokens.fieldTextSize,
          color: AppColors.sheetHint,
        ),
        labelStyle: const TextStyle(
          fontSize: SheetTokens.fieldLabelSize,
          color: AppColors.sheetTextPrimary,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.sheetFieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SheetTokens.fieldContentHPadding,
          vertical: SheetTokens.fieldContentVPadding,
        ),
        suffixIcon: IconButton(
          onPressed: onPickDate,
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.sheetMuted,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: AppColors.sheetFieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: AppColors.sheetFieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
          borderSide: const BorderSide(
            color: AppColors.sheetFieldBorder,
            width: SheetTokens.fieldBorderWidth,
          ),
        ),
        isDense: true,
      ),
    );
  }
}
