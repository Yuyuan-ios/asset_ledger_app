import 'package:flutter/material.dart';

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
  final String labelText;
  final String? hintText;
  final String emptyHintText;
  final String emptyLabelText;

  const DevicePickerVm({
    required this.selectedId,
    required this.items,
    required this.onChanged,
    this.decoration,
    this.style,
    this.icon,
    this.labelText = '设备编号',
    this.hintText,
    this.emptyHintText = '暂无在用设备，请先去“设备”页新增',
    this.emptyLabelText = '设备编号',
  });
}

class DevicePickerPattern extends StatelessWidget {
  final DevicePickerVm vm;

  const DevicePickerPattern({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.items.isEmpty) {
      return DropdownButtonFormField<int>(
        initialValue: null,
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          labelText: vm.emptyLabelText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            fontSize: SheetTokens.fieldLabelSize,
            color: SheetColors.textPrimary,
          ),
          hintText: vm.emptyHintText,
          hintStyle: const TextStyle(
            fontSize: SheetTokens.fieldTextSize,
            color: SheetColors.hint,
          ),
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
      icon: vm.icon ?? const Icon(Icons.arrow_drop_down, color: SheetColors.muted),
      style:
          vm.style ??
          const TextStyle(
            fontSize: SheetTokens.fieldTextSize,
            color: SheetColors.textPrimary,
          ),
      items: vm.items.map((item) {
        return DropdownMenuItem<int>(
          value: item.id,
          enabled: item.enabled,
          child: Text(item.label),
        );
      }).toList(),
      onChanged: vm.onChanged,
      decoration:
          vm.decoration ??
          InputDecoration(
            labelText: vm.labelText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: const TextStyle(
              fontSize: SheetTokens.fieldLabelSize,
              color: SheetColors.textPrimary,
            ),
            hintText: vm.hintText,
            hintStyle: const TextStyle(
              fontSize: SheetTokens.fieldTextSize,
              color: SheetColors.hint,
            ),
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
