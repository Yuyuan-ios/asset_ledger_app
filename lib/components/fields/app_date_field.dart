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
        color: SheetColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label ?? FormatUtils.ymdInputLabel,
        hintText: hint ?? FormatUtils.ymdInputHint,
        hintStyle: const TextStyle(
          fontSize: SheetTokens.fieldTextSize,
          color: SheetColors.hint,
        ),
        labelStyle: const TextStyle(
          fontSize: SheetTokens.fieldLabelSize,
          color: SheetColors.textPrimary,
        ),
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
