import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../data/models/device.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../layout/sheet_text_field_pattern.dart';

class DeviceEditorFieldsGroup extends StatelessWidget {
  const DeviceEditorFieldsGroup({
    super.key,
    required this.baseMeterController,
    required this.unitPriceController,
    required this.breakingUnitPriceController,
    required this.modelController,
    required this.equipmentType,
  });

  final TextEditingController baseMeterController;
  final TextEditingController unitPriceController;
  final TextEditingController breakingUnitPriceController;
  final TextEditingController modelController;
  final EquipmentType equipmentType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _editorField(
          controller: baseMeterController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          labelText: l10n.deviceBaseMeterLabel,
        ),
        const SizedBox(height: SpaceTokens.sectionGap),
        _editorField(
          controller: unitPriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          labelText: l10n.deviceDefaultRateLabel,
        ),
        if (equipmentType == EquipmentType.excavator) ...[
          const SizedBox(height: SpaceTokens.sectionGap),
          _editorField(
            controller: breakingUnitPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            labelText: l10n.deviceBreakingRateOptionalLabel,
            hintText: l10n.deviceBreakingRateHint,
            hintStyle: AppTypography.bodySecondary(
              context,
              fontSize: SheetTokens.fieldLabelSize,
              color: SheetColors.hint,
            ),
            alwaysShowLabel: true,
          ),
        ],
        const SizedBox(height: SpaceTokens.sectionGap),
        _editorField(
          controller: modelController,
          labelText: l10n.deviceModelOptionalLabel,
        ),
      ],
    );
  }

  Widget _editorField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextStyle? hintStyle,
    TextInputType? keyboardType,
    bool alwaysShowLabel = false,
  }) {
    return SheetTextFieldPattern(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      hintStyle: hintStyle,
      keyboardType: keyboardType,
      floatingLabelBehavior: alwaysShowLabel
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.auto,
    );
  }
}
