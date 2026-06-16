import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

class DevicePickerItemVm {
  final int id;
  final String label;
  final bool enabled;

  const DevicePickerItemVm({
    required this.id,
    required this.label,
    this.enabled = true,
  });
}

class DevicePickerVm {
  final int? selectedId;
  final List<DevicePickerItemVm> items;
  final ValueChanged<int?> onChanged;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Widget? icon;
  final String? labelText;
  final String? hintText;
  final String? emptyHintText;
  final String? emptyLabelText;

  const DevicePickerVm({
    required this.selectedId,
    required this.items,
    required this.onChanged,
    this.decoration,
    this.style,
    this.icon,
    this.labelText,
    this.hintText,
    this.emptyHintText,
    this.emptyLabelText,
  });
}

class DevicePickerPattern extends StatelessWidget {
  final DevicePickerVm vm;

  const DevicePickerPattern({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelText = vm.labelText ?? l10n.devicePickerLabel;
    final emptyHintText = vm.emptyHintText ?? l10n.devicePickerEmptyHint;
    final emptyLabelText = vm.emptyLabelText ?? l10n.devicePickerLabel;
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
    final valueStyle =
        vm.style ??
        AppTypography.body(
          context,
          fontSize: SheetTokens.fieldTextSize,
          color: SheetColors.textPrimary,
        );

    if (vm.items.isEmpty) {
      return DropdownButtonFormField<int>(
        initialValue: null,
        isExpanded: true,
        hint: Text(emptyHintText, overflow: TextOverflow.ellipsis),
        disabledHint: Text(emptyHintText, overflow: TextOverflow.ellipsis),
        items: const [],
        onChanged: null,
        style: hintStyle,
        decoration: InputDecoration(
          labelText: emptyLabelText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: labelStyle,
          hintStyle: hintStyle,
          filled: true,
          fillColor: SheetColors.fieldBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SheetTokens.fieldContentHPadding,
            vertical: SheetTokens.fieldContentVPadding,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
            borderSide: const BorderSide(
              color: SheetColors.fieldBorder,
              width: SheetTokens.fieldBorderWidth,
            ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: vm.selectedId,
      isExpanded: true,
      icon:
          vm.icon ??
          const Icon(Icons.arrow_drop_down, color: SheetColors.muted),
      style: valueStyle,
      items: vm.items.map((item) {
        return DropdownMenuItem<int>(
          value: item.id,
          enabled: item.enabled,
          child: Text(item.label, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: vm.onChanged,
      decoration:
          vm.decoration ??
          InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: labelStyle,
            hintText: vm.hintText,
            hintStyle: hintStyle,
            filled: true,
            fillColor: SheetColors.fieldBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SheetTokens.fieldContentHPadding,
              vertical: SheetTokens.fieldContentVPadding,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
              borderSide: const BorderSide(
                color: SheetColors.fieldBorder,
                width: SheetTokens.fieldBorderWidth,
              ),
            ),
          ),
    );
  }
}
