import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../data/models/device.dart';
import '../../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final equipmentLabel = equipmentType == EquipmentType.loader
        ? l10n.deviceEquipmentLoader
        : l10n.deviceEquipmentExcavator;
    final resolvedPreview = previewLabel.isEmpty ? '' : '  $previewLabel';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedBrand == null || selectedBrand!.trim().isEmpty
                    ? l10n.deviceBrandNotSelected
                    : l10n.deviceBrandSelectedLine(
                        equipmentLabel,
                        selectedBrand!,
                        resolvedPreview,
                      ),
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
                l10n.deviceSelectAction,
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
                      ? l10n.deviceAvatarBrandDefault
                      : l10n.deviceAvatarCustomSet,
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
                child: Text(l10n.deviceGalleryAction),
              ),
              TextButton(
                onPressed: saving ? null : onResetAvatar,
                child: Text(l10n.deviceDefaultAction),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
