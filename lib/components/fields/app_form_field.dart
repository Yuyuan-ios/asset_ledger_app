import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

/// 纯展示表单输入框：不感知 store，仅通过 controller/回调驱动。
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.onTap,
    this.keyboardType,
    this.readOnly = false,
    this.enabled = true,
    this.textStyle,
    this.suffixIcon,
    this.decoration,
    this.decorationBuilder,
    this.floatingLabelBehavior = FloatingLabelBehavior.never,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool enabled;
  final TextStyle? textStyle;
  final Widget? suffixIcon;
  final InputDecoration? decoration;
  final InputDecoration Function(InputDecoration base)? decorationBuilder;
  final FloatingLabelBehavior floatingLabelBehavior;

  InputDecoration _baseDecoration() {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: SheetTokens.fieldTextSize,
        color: SheetColors.hint,
      ),
      labelStyle: const TextStyle(
        fontSize: SheetTokens.fieldLabelSize,
        color: SheetColors.textDim,
      ),
      floatingLabelBehavior: floatingLabelBehavior,
      filled: true,
      fillColor: SheetColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SheetTokens.fieldContentHPadding,
        vertical: SheetTokens.fieldContentVPadding,
      ),
      suffixIcon: suffixIcon,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = decoration ?? _baseDecoration();
    final resolved = decorationBuilder != null
        ? decorationBuilder!(base)
        : base;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      keyboardType: keyboardType,
      readOnly: readOnly,
      enabled: enabled,
      style:
          textStyle ??
          const TextStyle(
            fontSize: SheetTokens.fieldTextSize,
            color: SheetColors.textPrimary,
          ),
      decoration: resolved,
    );
  }
}
