import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../data/models/device.dart';
import '../../tokens/mapper/core_tokens.dart';

class DeviceEditorBrandRow extends StatelessWidget {
  const DeviceEditorBrandRow({
    super.key,
    required this.selectedBrand,
    required this.equipmentType,
    required this.previewLabel,
    required this.saving,
    required this.canUseCustomAvatar,
    required this.customAvatarPath,
    required this.onSelectBrand,
    required this.onPickFromGallery,
    required this.onResetAvatar,
  });

  final String? selectedBrand;
  final EquipmentType equipmentType;
  final String previewLabel;
  final bool saving;
  final bool canUseCustomAvatar;
  final String? customAvatarPath;
  final VoidCallback onSelectBrand;
  final VoidCallback onPickFromGallery;
  final VoidCallback onResetAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedBrand == null || selectedBrand!.trim().isEmpty
                    ? '未选择品牌（头像）'
                    : '品牌：${equipmentType.label}  ${selectedBrand!}${previewLabel.isEmpty ? '' : '  $previewLabel'}',
                style: AppTypography.body(
                  context,
                  fontSize: DeviceTokens.editorBrandTextFontSize,
                  fontWeight: DeviceTokens.editorBrandTextFontWeight,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: saving ? null : onSelectBrand,
              child: Text(
                '选择',
                style: AppTypography.body(
                  context,
                  fontSize: DeviceTokens.editorBrandSelectorTextFontSize,
                  fontWeight: DeviceTokens.editorBrandSelectorTextFontWeight,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
        if (canUseCustomAvatar) ...[
          const SizedBox(height: DeviceTokens.editorBrandCustomRowTopGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  customAvatarPath == null || customAvatarPath!.isEmpty
                      ? '头像：品牌默认'
                      : '头像：已设置自定义',
                  style: AppTypography.bodySecondary(
                    context,
                    fontSize: DeviceTokens.editorBrandCustomInfoFontSize,
                    color: Colors.black.withValues(
                      alpha: DeviceTokens.editorBrandCustomInfoAlpha,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: saving ? null : onPickFromGallery,
                child: const Text('相册'),
              ),
              TextButton(
                onPressed: saving ? null : onResetAvatar,
                child: const Text('默认'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
