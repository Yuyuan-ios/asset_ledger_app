import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../core/utils/format_utils.dart';

const _sheetCalendarIconAsset = 'assets/icons/timing/calendar_icon.png';
const _sheetDateFieldIconSize = 30.0;

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
          tooltip: '选择日期',
          onPressed: onPickDate,
          padding: const EdgeInsets.all(1),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Image.asset(
            _sheetCalendarIconAsset,
            width: _sheetDateFieldIconSize,
            height: _sheetDateFieldIconSize,
            fit: BoxFit.contain,
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
