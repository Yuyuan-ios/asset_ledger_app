import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../../../data/models/device.dart';
import '../../../patterns/device/brand_picker_grouped_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';

class AvatarSelectionResult {
  final String brandValue;
  final EquipmentType equipmentType;

  const AvatarSelectionResult({
    required this.brandValue,
    required this.equipmentType,
  });
}

Future<AvatarSelectionResult?> pushDeviceAvatarSelectPage(
  BuildContext context, {
  EquipmentType initialType = EquipmentType.excavator,
  String? initialBrandValue,
}) {
  return Navigator.of(context).push<AvatarSelectionResult>(
    PageRouteBuilder<AvatarSelectionResult>(
      transitionDuration: const Duration(
        milliseconds: DeviceTokens.avatarPickerForwardDurationMs,
      ),
      reverseTransitionDuration: const Duration(
        milliseconds: DeviceTokens.avatarPickerReverseDurationMs,
      ),
      pageBuilder: (context, animation, secondaryAnimation) =>
          DeviceAvatarSelectPage(
            initialType: initialType,
            initialBrandValue: initialBrandValue,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(offset), child: child);
      },
    ),
  );
}

class DeviceAvatarSelectPage extends StatelessWidget {
  const DeviceAvatarSelectPage({
    super.key,
    this.initialType = EquipmentType.excavator,
    this.initialBrandValue,
  });

  final EquipmentType initialType;
  final String? initialBrandValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '选择设备头像',
          style: AppTypography.sectionTitle(
            context,
            fontSize: DeviceTokens.avatarPickerTitleFontSize,
            fontWeight: DeviceTokens.avatarPickerTitleFontWeight,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _EquipmentTypeBrandPicker(
        initialType: initialType,
        initialBrandValue: initialBrandValue,
      ),
    );
  }
}

class _EquipmentTypeBrandPicker extends StatefulWidget {
  const _EquipmentTypeBrandPicker({
    required this.initialType,
    this.initialBrandValue,
  });

  final EquipmentType initialType;
  final String? initialBrandValue;

  @override
  State<_EquipmentTypeBrandPicker> createState() =>
      _EquipmentTypeBrandPickerState();
}

class _EquipmentTypeBrandPickerState extends State<_EquipmentTypeBrandPicker> {
  late EquipmentType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final empty = BrandCatalog.groups(
      equipmentType: _selectedType,
    ).values.every((items) => items.isEmpty);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DeviceTokens.avatarPickerPadLeft,
            DeviceTokens.avatarPickerPadTop,
            DeviceTokens.avatarPickerPadRight,
            DeviceTokens.avatarPickerPadBottom,
          ),
          child: _DeviceTypeSegment(
            selectedType: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v),
          ),
        ),
        Expanded(
          child: empty
              ? Center(
                  child: Text(
                    '该类别暂无品牌，先选另一类或新增自定义头像',
                    style: AppTypography.bodySecondary(
                      context,
                      fontSize: DeviceTokens.avatarPickerEmptyTextFontSize,
                      color: Colors.black.withValues(
                        alpha: DeviceTokens.avatarPickerEmptyTextAlpha,
                      ),
                    ),
                  ),
                )
              : BrandPickerGrouped(
                  selectedBrandValue: widget.initialBrandValue,
                  equipmentTypeFilter: _selectedType,
                  onSelected: (brand) {
                    Navigator.of(context).pop(
                      AvatarSelectionResult(
                        brandValue: brand.value,
                        equipmentType: _selectedType,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DeviceTypeSegment extends StatelessWidget {
  const _DeviceTypeSegment({
    required this.selectedType,
    required this.onChanged,
  });

  final EquipmentType selectedType;
  final ValueChanged<EquipmentType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget buildItem(EquipmentType type) {
      final selected = selectedType == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(
            DeviceTokens.avatarTypeSegmentRadius,
          ),
          onTap: () => onChanged(type),
          child: Container(
            height: DeviceTokens.avatarTypeSegmentItemHeight,
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(
                DeviceTokens.avatarTypeSegmentRadius,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              type.label,
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.avatarTypeSegmentItemFontSize,
                fontWeight: selected
                    ? DeviceTokens.avatarTypeSegmentItemSelectedWeight
                    : DeviceTokens.avatarTypeSegmentItemUnselectedWeight,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: DeviceTokens.avatarTypeSegmentHeight,
      padding: const EdgeInsets.all(DeviceTokens.avatarTypeSegmentPadding),
      decoration: BoxDecoration(
        color: DeviceTokens.avatarTypeSegmentBackgroundColor,
        borderRadius: BorderRadius.circular(
          DeviceTokens.avatarTypeSegmentRadius,
        ),
        border: Border.all(color: DeviceTokens.avatarTypeSegmentBorderColor),
      ),
      child: Row(
        children: [
          buildItem(EquipmentType.excavator),
          buildItem(EquipmentType.loader),
        ],
      ),
    );
  }
}
