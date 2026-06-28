import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../components/fields/sheet_field_popup_controls.dart';
import '../../components/fields/sheet_input_decoration.dart';
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
      return SizedBox(
        height: SheetTokens.fieldHeight,
        child: DropdownMenu<int>(
          enabled: false,
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          showTrailingIcon: false,
          textStyle: hintStyle,
          label: Text(emptyLabelText),
          hintText: emptyHintText,
          inputDecorationTheme: _inputDecorationTheme(
            context,
            labelText: emptyLabelText,
            hintStyle: hintStyle,
          ),
          dropdownMenuEntries: const [],
        ),
      );
    }

    return SizedBox(
      height: SheetTokens.fieldHeight,
      child: DropdownMenu<int>(
        initialSelection: vm.selectedId,
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        textStyle: valueStyle,
        label: Text(vm.decoration?.labelText ?? labelText),
        hintText: vm.decoration?.hintText ?? vm.hintText,
        trailingIcon:
            vm.icon ?? const SheetFieldPopupToggleIcon(expanded: false),
        selectedTrailingIcon: const SheetFieldPopupToggleIcon(expanded: true),
        menuStyle: sheetFieldPopupMenuStyle(),
        dropdownMenuEntries: vm.items.map((item) {
          return DropdownMenuEntry<int>(
            value: item.id,
            label: item.label,
            enabled: item.enabled,
          );
        }).toList(),
        onSelected: vm.onChanged,
        inputDecorationTheme: _inputDecorationTheme(
          context,
          decoration: vm.decoration,
          labelText: labelText,
          hintText: vm.hintText,
          hintStyle: hintStyle,
        ),
      ),
    );
  }

  InputDecorationThemeData _inputDecorationTheme(
    BuildContext context, {
    InputDecoration? decoration,
    String? labelText,
    String? hintText,
    TextStyle? hintStyle,
  }) {
    final inputDecoration =
        decoration ??
        buildSheetInputDecoration(
          context,
          labelText: labelText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: hintText,
          hintStyle: hintStyle,
        );
    return InputDecorationThemeData(
      labelStyle: inputDecoration.labelStyle,
      floatingLabelBehavior:
          inputDecoration.floatingLabelBehavior ?? FloatingLabelBehavior.always,
      hintStyle: inputDecoration.hintStyle,
      filled: inputDecoration.filled ?? false,
      fillColor: inputDecoration.fillColor,
      constraints: inputDecoration.constraints,
      contentPadding: inputDecoration.contentPadding,
      border: inputDecoration.border,
      enabledBorder: inputDecoration.enabledBorder,
      focusedBorder: inputDecoration.focusedBorder,
      disabledBorder: inputDecoration.disabledBorder,
    );
  }
}
