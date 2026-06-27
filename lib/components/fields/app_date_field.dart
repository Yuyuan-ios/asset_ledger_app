import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../core/utils/format_utils.dart';
import 'sheet_input_decoration.dart';

const _sheetCalendarIconAsset = 'assets/icons/timing/calendar_icon.png';
const _sheetDateFieldIconSize = 30.0;

class SheetDateField extends StatelessWidget {
  const SheetDateField({
    super.key,
    required this.controller,
    required this.onPickDate,
    this.label,
    this.hint,
    this.helperText,
    this.enabled = true,
    this.tooltip = '选择日期',
  });

  final TextEditingController controller;
  final VoidCallback onPickDate;
  final String? label;
  final String? hint;
  final String? helperText;
  final bool enabled;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final fieldStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: enabled ? onPickDate : null,
      style: fieldStyle,
      decoration: buildSheetInputDecoration(
        context,
        labelText: label ?? FormatUtils.ymdInputLabel,
        hintText: hint ?? FormatUtils.ymdInputHint,
        helperText: helperText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: IconButton(
          tooltip: tooltip,
          onPressed: enabled ? onPickDate : null,
          padding: const EdgeInsets.all(1),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Image.asset(
            _sheetCalendarIconAsset,
            width: _sheetDateFieldIconSize,
            height: _sheetDateFieldIconSize,
            fit: BoxFit.contain,
          ),
        ),
        isDense: true,
      ),
    );
  }
}
