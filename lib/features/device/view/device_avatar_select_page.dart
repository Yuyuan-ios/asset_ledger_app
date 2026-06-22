import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/foundation/app_typography.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/device.dart';
import '../model/brand_catalog.dart';
import '../model/device_type_catalog.dart';
import '../../../patterns/device/brand_picker_grouped_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_avatar_select_view_data.dart';

/// 选择页返回结果。
///
/// 为兼容现有调用方（device_editor_dialog / device_page_actions），保留
/// [brandValue] + [equipmentType] 两个字段；新增 [deviceTypeId] 供后续业务路由使用。
class AvatarSelectionResult {
  final String brandValue;
  final EquipmentType equipmentType;
  final String deviceTypeId;

  const AvatarSelectionResult({
    required this.brandValue,
    required this.equipmentType,
    required this.deviceTypeId,
  });
}

// 页面内尺寸常量。
// TODO(device-type-selector): 实验毕业后迁入 DeviceTokens。
class _Dim {
  static const double typeCardRadius = 14;
  static const double typeIconTile = 48;
  static const double typeIconTileRadius = 12;
  static const double ctaHeight = 52;
  static const double ctaRadius = 14;
  static const double sheetTypeIcon = 40;
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
            initialTypeId: DeviceTypeCatalog.fromEquipmentType(initialType).id,
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

class DeviceAvatarSelectPage extends StatefulWidget {
  const DeviceAvatarSelectPage({
    super.key,
    this.initialTypeId,
    this.initialBrandValue,
  });

  final String? initialTypeId;
  final String? initialBrandValue;

  @override
  State<DeviceAvatarSelectPage> createState() => _DeviceAvatarSelectPageState();
}

class _DeviceAvatarSelectPageState extends State<DeviceAvatarSelectPage> {
  late DeviceTypeDef _selectedType;
  String? _selectedBrandValue;
  String _brandQuery = '';
  bool _hasPickedBrand = false;
  final TextEditingController _brandSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType =
        DeviceTypeCatalog.byId(widget.initialTypeId) ??
        DeviceTypeCatalog.defaultType;
    _selectedBrandValue = widget.initialBrandValue;
    _hasPickedBrand = (_selectedBrandValue ?? '').trim().isNotEmpty;
  }

  @override
  void dispose() {
    _brandSearchCtrl.dispose();
    super.dispose();
  }

  bool _brandBelongsToType(String? brandValue, DeviceTypeDef type) {
    if (brandValue == null || brandValue.trim().isEmpty) return false;
    final v = brandValue.trim();
    return BrandCatalog.groupsByTypeId(
      type.id,
    ).values.any((items) => items.any((b) => b.value == v));
  }

  void _onTypeSelected(DeviceTypeDef def) {
    if (def.id == _selectedType.id) return;
    final l10n = AppLocalizations.of(context);
    final hadBrand = _hasPickedBrand;
    final keepBrand = _brandBelongsToType(_selectedBrandValue, def);
    setState(() {
      _selectedType = def;
      if (!keepBrand) {
        _selectedBrandValue = null;
        _hasPickedBrand = false;
      }
    });
    // 静默清空品牌会被当成 bug：仅当此前确实选过品牌时给一条明确提示。
    if (hadBrand && !keepBrand) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.deviceBrandResetNotice(def.name(l10n))),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _openTypeSheet() async {
    final picked = await showAppBottomSheet<DeviceTypeDef>(
      context: context,
      builder: (_) => _DeviceTypeSheet(selectedTypeId: _selectedType.id),
    );
    if (picked != null) _onTypeSelected(picked);
  }

  void _onBrandTap(BrandItem brand) {
    setState(() {
      _selectedBrandValue = brand.value;
      _hasPickedBrand = true;
    });
  }

  Future<void> _useCustomBrand() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: (_selectedBrandValue ?? '').trim(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.deviceBrandCustomDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.deviceBrandCustomDialogHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.deviceCancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(l10n.deviceBrandCustomConfirm),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      setState(() {
        _selectedBrandValue = value;
        _hasPickedBrand = true;
      });
    }
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context);
    if (!_selectedType.isAvailable) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.deviceTypeComingSoonCta(_selectedType.name(l10n)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    Navigator.of(context).pop(
      AvatarSelectionResult(
        brandValue: (_selectedBrandValue ?? '').trim(),
        equipmentType: _selectedType.equipmentType ?? EquipmentType.excavator,
        deviceTypeId: _selectedType.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewData = DeviceAvatarSelectViewData.forType(
      _selectedType,
      query: _brandQuery,
    );
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.deviceTypeSelectTitle,
          style: AppTypography.sectionTitle(
            context,
            fontSize: DeviceTokens.avatarPickerTitleFontSize,
            fontWeight: DeviceTokens.avatarPickerTitleFontWeight,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpaceTokens.pagePadding,
              SpaceTokens.sm,
              SpaceTokens.pagePadding,
              SpaceTokens.md,
            ),
            child: _DeviceTypeCard(type: _selectedType, onTap: _openTypeSheet),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _BrandSectionHeader(
            controller: _brandSearchCtrl,
            onChanged: (v) => setState(() => _brandQuery = v),
          ),
          Expanded(
            child: viewData.hasAnyBrand
                ? BrandPickerGrouped(
                    groups: viewData.groups,
                    selectedBrandValue: _selectedBrandValue,
                    onSelected: _onBrandTap,
                  )
                : _BrandEmptyState(
                    typeName: _selectedType.name(l10n),
                    isSearchMiss: viewData.typeHasBrandLibrary,
                    onUseCustom: _useCustomBrand,
                  ),
          ),
          _BottomCta(type: _selectedType, onPressed: _confirm),
        ],
      ),
    );
  }
}

/// 顶部设备类型卡片（替代原双段控件）。
class _DeviceTypeCard extends StatelessWidget {
  const _DeviceTypeCard({required this.type, required this.onTap});

  final DeviceTypeDef type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = DeviceTypeCatalog.categoryOf(type);
    final subtitle = '${category.name(l10n)} · ${type.description(l10n)}';
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Dim.typeCardRadius),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SpaceTokens.md),
          child: Row(
            children: [
              Container(
                width: _Dim.typeIconTile,
                height: _Dim.typeIconTile,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(_Dim.typeIconTileRadius),
                ),
                child: _TypeGlyph(type: type, size: 24, color: AppColors.brand),
              ),
              const SizedBox(width: SpaceTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            type.name(l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.sectionTitle(
                              context,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!type.isAvailable) ...[
                          const SizedBox(width: SpaceTokens.sm),
                          const _ComingSoonBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: SpaceTokens.inlineGap),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySecondary(context),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandSectionHeader extends StatelessWidget {
  const _BrandSectionHeader({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpaceTokens.pagePadding,
        SpaceTokens.md,
        SpaceTokens.pagePadding,
        SpaceTokens.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          hintText: l10n.deviceBrandSearchHint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
      ),
    );
  }
}

class _BrandEmptyState extends StatelessWidget {
  const _BrandEmptyState({
    required this.typeName,
    required this.isSearchMiss,
    required this.onUseCustom,
  });

  final String typeName;
  final bool isSearchMiss;
  final VoidCallback onUseCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = isSearchMiss
        ? l10n.deviceBrandSearchEmptyTitle
        : l10n.deviceBrandEmptyForType(typeName);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpaceTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary(context),
            ),
            const SizedBox(height: SpaceTokens.md),
            OutlinedButton.icon(
              onPressed: onUseCustom,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.deviceBrandUseCustom),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceTokens.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SpaceTokens.sm),
      ),
      child: Text(
        l10n.deviceTypeComingSoonBadge,
        style: AppTypography.caption(context, color: AppColors.brand),
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.type, required this.onPressed});

  final DeviceTypeDef type;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = type.isAvailable;
    final label = available
        ? l10n.deviceCreateNextCta(type.name(l10n))
        : l10n.deviceTypeComingSoonCta(type.name(l10n));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpaceTokens.pagePadding,
          SpaceTokens.sm,
          SpaceTokens.pagePadding,
          SpaceTokens.sm,
        ),
        child: SizedBox(
          width: double.infinity,
          height: _Dim.ctaHeight,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: available
                  ? AppColors.brand
                  : AppColors.brand.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_Dim.ctaRadius),
              ),
            ),
            child: Text(
              label,
              style: AppTypography.body(
                context,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 设备类型底部弹层：按大类分组（无搜索）。
class _DeviceTypeSheet extends StatelessWidget {
  const _DeviceTypeSheet({required this.selectedTypeId});

  final String selectedTypeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppBottomSheetShell(
      title: l10n.deviceTypeSheetTitle,
      scrollable: false,
      footerEnabled: false,
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpaceTokens.pagePadding,
          0,
          SpaceTokens.pagePadding,
          SpaceTokens.xl,
        ),
        children: [
          for (final c in DeviceTypeCatalog.categories) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
              child: Text(
                c.name(l10n),
                style: AppTypography.bodySecondary(
                  context,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final t in c.types)
              _TypeRow(
                type: t,
                selected: t.id == selectedTypeId,
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DeviceTypeDef type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = DeviceTypeCatalog.categoryOf(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpaceTokens.sm),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          side: BorderSide(
            color: selected ? AppColors.brand : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SpaceTokens.md),
            child: Row(
              children: [
                Container(
                  width: _Dim.sheetTypeIcon,
                  height: _Dim.sheetTypeIcon,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(SpaceTokens.sm),
                  ),
                  child: _TypeGlyph(
                    type: type,
                    size: 22,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: SpaceTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              type.name(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                context,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!type.isAvailable) ...[
                            const SizedBox(width: SpaceTokens.sm),
                            const _ComingSoonBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: SpaceTokens.inlineGap),
                      Text(
                        '${category.name(l10n)} · ${type.description(l10n)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.brand,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 设备类型图标：优先内联 SVG（如挖掘机挖斗），否则回退 Material 图标。
class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({
    required this.type,
    required this.size,
    required this.color,
  });

  final DeviceTypeDef type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final svg = type.svgGlyph;
    if (svg != null) {
      return SvgPicture.string(
        svg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(type.icon, size: size, color: color);
  }
}
