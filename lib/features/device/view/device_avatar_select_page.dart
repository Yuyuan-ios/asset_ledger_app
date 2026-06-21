import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/foundation/app_typography.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/device.dart';
import '../model/brand_catalog.dart';
import '../model/device_type_catalog.dart';
import '../../../patterns/device/brand_picker_grouped_pattern.dart';
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
  static const double chipRadius = 20;
  static const double ctaHeight = 52;
  static const double ctaRadius = 14;
  static const double sheetHeightFactor = 0.7;
  static const double sheetTopRadius = 20;
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
    final picked = await showModalBottomSheet<DeviceTypeDef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              0,
            ),
            child: _DeviceTypeCard(type: _selectedType, onTap: _openTypeSheet),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpaceTokens.pagePadding,
              SpaceTokens.md,
              SpaceTokens.pagePadding,
              SpaceTokens.sm,
            ),
            child: _QuickTypeChips(
              selectedId: _selectedType.id,
              onSelected: _onTypeSelected,
              onMore: _openTypeSheet,
            ),
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
      borderRadius: BorderRadius.circular(_Dim.typeCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_Dim.typeCardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SpaceTokens.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Dim.typeCardRadius),
            border: Border.all(color: AppColors.divider),
          ),
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

/// 常用类型快捷入口（前四个 + 更多）。
class _QuickTypeChips extends StatelessWidget {
  const _QuickTypeChips({
    required this.selectedId,
    required this.onSelected,
    required this.onMore,
  });

  final String selectedId;
  final ValueChanged<DeviceTypeDef> onSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: SpaceTokens.sm,
      runSpacing: SpaceTokens.sm,
      children: [
        for (final t in DeviceTypeCatalog.quickEntries)
          _TypeChip(
            label: t.name(l10n),
            selected: t.id == selectedId,
            onTap: () => onSelected(t),
          ),
        _TypeChip(
          label: l10n.deviceTypeMoreChip,
          selected: false,
          icon: Icons.more_horiz_rounded,
          onTap: onMore,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.brand : Colors.white,
      borderRadius: BorderRadius.circular(_Dim.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_Dim.chipRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceTokens.md,
            vertical: SpaceTokens.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Dim.chipRadius),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: SpaceTokens.inlineGap),
              ],
              Text(
                label,
                style: AppTypography.body(
                  context,
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceBrandSectionTitle,
            style: AppTypography.sectionTitle(
              context,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: SpaceTokens.sm),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: l10n.deviceBrandSearchHint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: SpaceTokens.sm,
              ),
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
        ],
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

/// 设备类型底部弹层：按大类分组 + 搜索 + 滚动。
class _DeviceTypeSheet extends StatefulWidget {
  const _DeviceTypeSheet({required this.selectedTypeId});

  final String selectedTypeId;

  @override
  State<_DeviceTypeSheet> createState() => _DeviceTypeSheetState();
}

class _DeviceTypeSheetState extends State<_DeviceTypeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final height = MediaQuery.of(context).size.height * _Dim.sheetHeightFactor;

    final categories = <DeviceTypeCategory>[];
    for (final c in DeviceTypeCatalog.categories) {
      final matched = c.types.where((t) {
        if (q.isEmpty) return true;
        return t.name(l10n).toLowerCase().contains(q) ||
            t.description(l10n).toLowerCase().contains(q) ||
            c.name(l10n).toLowerCase().contains(q);
      }).toList();
      if (matched.isNotEmpty) {
        categories.add(
          DeviceTypeCategory(id: c.id, name: c.name, types: matched),
        );
      }
    }

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_Dim.sheetTopRadius),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpaceTokens.pagePadding,
              SpaceTokens.md,
              SpaceTokens.sm,
              SpaceTokens.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.deviceTypeSheetTitle,
                    style: AppTypography.sectionTitle(
                      context,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpaceTokens.pagePadding,
            ),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: l10n.deviceTypeSearchHint,
                filled: true,
                fillColor: Colors.white,
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
          ),
          const SizedBox(height: SpaceTokens.sm),
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Text(
                      l10n.deviceTypeSheetEmpty,
                      style: AppTypography.bodySecondary(context),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      SpaceTokens.pagePadding,
                      0,
                      SpaceTokens.pagePadding,
                      SpaceTokens.xl,
                    ),
                    children: [
                      for (final c in categories) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: SpaceTokens.sm,
                          ),
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
                            selected: t.id == widget.selectedTypeId,
                            onTap: () => Navigator.of(context).pop(t),
                          ),
                      ],
                    ],
                  ),
          ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(RadiusTokens.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: SpaceTokens.sm),
          padding: const EdgeInsets.all(SpaceTokens.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: _Dim.sheetTypeIcon,
                height: _Dim.sheetTypeIcon,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(SpaceTokens.sm),
                ),
                child: _TypeGlyph(type: type, size: 22, color: AppColors.brand),
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
                const Icon(Icons.check_circle_rounded, color: AppColors.brand),
            ],
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
