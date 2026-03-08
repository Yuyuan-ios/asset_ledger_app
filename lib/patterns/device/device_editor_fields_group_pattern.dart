import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../tokens/mapper/core_tokens.dart';
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
    return Column(
      children: [
        _editorField(
          controller: baseMeterController,
          keyboardType: TextInputType.number,
          labelText: '基准码表（>=0，必填）',
        ),
        const SizedBox(height: SpaceTokens.sectionGap),
        _editorField(
          controller: unitPriceController,
          keyboardType: TextInputType.number,
          labelText: '默认单价（>0，必填）',
        ),
        if (equipmentType == EquipmentType.excavator) ...[
          const SizedBox(height: SpaceTokens.sectionGap),
          _editorField(
            controller: breakingUnitPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            labelText: '破碎单价（选填）',
            alwaysShowLabel: true,
          ),
        ],
        const SizedBox(height: SpaceTokens.sectionGap),
        _editorField(controller: modelController, labelText: '型号（选填）'),
      ],
    );
  }

  Widget _editorField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool alwaysShowLabel = false,
  }) {
    return SheetTextFieldPattern(
      controller: controller,
      labelText: labelText,
      hintText: null,
      keyboardType: keyboardType,
      floatingLabelBehavior: alwaysShowLabel
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.auto,
    );
  }
}
