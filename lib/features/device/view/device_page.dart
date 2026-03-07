// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/models/device.dart';
import '../../../data/services/avatar_storage_service.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/rate_app_service.dart';
import '../../../data/services/subscription_service.dart';
import '../../../features/device/state/device_store.dart';

import '../../../patterns/device/brand_picker_grouped_pattern.dart';
import '../../../components/avatars/app_device_avatar.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../core/utils/device_label.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../core/foundation/typography.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';
import 'privacy_page.dart';
import 'terms_page.dart';
import 'upgrade_page.dart';

// =====================================================================
// ============================== 二、DevicePage：设备页入口 ==============================
// =====================================================================

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

// =====================================================================
// ============================== 三、State：仅做 UI 状态与交互 ==============================
// =====================================================================

class _DevicePageState extends State<DevicePage> {
  // -------------------------------------------------------------------
  // 3.1 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  // -------------------------------------------------------------------
  // 3.3 停用确认弹窗（软删除：停用设备）
  // -------------------------------------------------------------------
  Future<bool> _confirmDeactivate(Device d) async {
    return showAppConfirmDialog(
      context: context,
      title: '确认停用设备？',
      content:
          '设备：${d.name}\n\n'
          '✅ 只会停用设备，不会删除任何计时/燃油/收入历史记录。\n'
          '停用后：\n'
          '• 设备页默认不再显示\n'
          '• 计时页下拉框不可再选\n'
          '• 历史记录仍可回显（通过 deviceId 区分新旧设备）',
      confirmText: '停用',
    );
  }

  // =====================================================================
  // ============================== 四、新增/编辑弹窗（同一套表单复用） ==============================
  // =====================================================================
  Future<void> _openDeviceDialog({
    Device? device,
    String? initialBrand,
    EquipmentType? initialEquipmentType,
  }) async {
    final store = context.read<DeviceStore>();

    final edited = await showDialog<Device>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeviceEditorDialog(
        device: device,
        initialBrand: initialBrand,
        initialEquipmentType: initialEquipmentType,
      ),
    );

    if (!mounted || edited == null) return;

    // ✅ 事件循环切换：避开 route 退场敏感窗口
    Future.microtask(() async {
      if (!mounted) return;

      if (device == null) {
        await store.insert(edited);
      } else {
        await store.update(edited);
      }

      final feedback = storeActionFeedback(
        store,
        action: '保存',
        successMessage: device == null ? '已新增设备' : '已更新设备',
      );
      _toast(feedback.message);
    });
  }

  Future<void> _openAddDeviceFlow() async {
    final selected = await Navigator.of(context).push<_AvatarSelectionResult>(
      PageRouteBuilder<_AvatarSelectionResult>(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _DeviceAvatarSelectPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(offset),
            child: child,
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    await _openDeviceDialog(
      initialBrand: selected.brandValue,
      initialEquipmentType: selected.equipmentType,
    );
  }

  Future<void> _retryLoad() async {
    final store = context.read<DeviceStore>();
    await store.loadAll();
  }

  void _onPlaceholderTap(String label) {
    _toast('$label 功能下步再接入');
  }

  Future<void> _openRateApp() async {
    final ok = await RateAppService.openSystemRateEntry();
    if (!mounted) return;
    _toast(ok ? '已打开评分入口' : '评分入口暂不可用');
  }

  Future<void> _openTermsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsPage()));
  }

  Future<void> _openPrivacyPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage()));
  }

  Future<void> _openUpgradePage() async {
    final upgraded = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const UpgradePage()));
    if (!mounted) return;
    if (upgraded == true) {
      setState(() {});
      _toast('升级成功，已解锁自定义头像功能');
    }
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.body(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w300,
        color: Colors.black.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _menuCard({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              title,
              style: AppTypography.body(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            if (trailingIcon != null)
              Icon(trailingIcon, size: 24, color: const Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  Widget _plainMenuCard({
    required String title,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Text(
              title,
              style: AppTypography.body(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            if (trailingIcon != null)
              Icon(trailingIcon, size: 24, color: const Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  IconData _forwardLikeIcon() {
    return Icons.chevron_right;
  }

  IconData _externalLikeIcon() {
    return Icons.north_east;
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeviceStore>();
    final devices = store.activeDevices;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 393,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                padding: const EdgeInsets.only(top: 0, bottom: 95),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TimingTokens.headerHorizontalPadding,
                      0,
                      TimingTokens.headerHorizontalPadding,
                      TimingTokens.headerBottomPadding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '设备',
                        style: AppTypography.pageTitle(
                          context,
                          fontSize: TimingTokens.headerTitleSize,
                          fontWeight: FontWeight.w700,
                          height: TimingTokens.headerTitleLineHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 24,
                          color: Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '搜索',
                          style: AppTypography.body(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (store.failure != null) ...[
                    const SizedBox(height: 8),
                    StoreErrorBanner(
                      message: storeErrorMessage(store, action: '读取')!,
                      onRetry: store.loading ? null : () => _retryLoad(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _sectionTitle(context, '个人资料'),
                  const SizedBox(height: 4),
                  _menuCard(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: '立即升级',
                    onTap: _openUpgradePage,
                    trailingIcon: _forwardLikeIcon(),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, '设备'),
                        const SizedBox(height: 4),
                        _menuCard(
                          leading: const Icon(
                            Icons.settings,
                            size: 28,
                            color: Colors.black87,
                          ),
                          title: '添加设备',
                          onTap: _openAddDeviceFlow,
                          trailingIcon: _forwardLikeIcon(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, '管理设备(长按图标删除)'),
                        const SizedBox(height: 4),
                        Container(
                          height: 164,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0x33000000)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const maxSlots = 8;
                              final visible = devices.take(maxSlots).toList();
                              return GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  8,
                                ),
                                itemCount: maxSlots,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.67,
                                    ),
                                itemBuilder: (context, index) {
                                  if (index >= visible.length) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final d = visible[index];
                                  final label = DeviceLabel.indexOnly(d.name);
                                  final displayIndex = label.trim().isEmpty
                                      ? '—'
                                      : label.trim();
                                  final categoryLabel =
                                      d.equipmentType == EquipmentType.loader
                                      ? '装载机'
                                      : '挖掘机';
                                  final displayText = displayIndex == '—'
                                      ? categoryLabel
                                      : '$displayIndex$categoryLabel';
                                  return Tooltip(
                                    message: label.trim().isEmpty
                                        ? d.name
                                        : label,
                                    child: GestureDetector(
                                      onTap: () => _openDeviceDialog(device: d),
                                      onLongPress: () async {
                                        if (d.id == null) return;
                                        final deviceStore = context
                                            .read<DeviceStore>();
                                        final ok = await _confirmDeactivate(d);
                                        if (!ok || !mounted) return;
                                        await deviceStore.deactivateById(d.id!);
                                        final feedback = storeActionFeedback(
                                          deviceStore,
                                          action: '停用',
                                          successMessage: '已停用（历史记录不受影响）',
                                        );
                                        _toast(feedback.message);
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 45,
                                            height: 45,
                                            child: DeviceAvatar(
                                              brand: d.brand,
                                              customAvatarPath:
                                                  d.customAvatarPath,
                                              radius: 22.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            displayText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption(
                                              context,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle(context, '给我们评分'),
                  const SizedBox(height: 4),
                  _plainMenuCard(
                    title: '给app评分',
                    onTap: _openRateApp,
                    trailingIcon: _externalLikeIcon(),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle(context, '条款'),
                  const SizedBox(height: 4),
                  _plainMenuCard(
                    title: '使用条款',
                    onTap: _openTermsPage,
                    trailingIcon: _externalLikeIcon(),
                  ),
                  const SizedBox(height: 4),
                  _plainMenuCard(
                    title: '隐私政策',
                    onTap: _openPrivacyPage,
                    trailingIcon: _externalLikeIcon(),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle(context, '联系'),
                  const SizedBox(height: 4),
                  _plainMenuCard(
                    title: '联系开发者',
                    onTap: () => _onPlaceholderTap('联系开发者'),
                    trailingIcon: _externalLikeIcon(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceAvatarSelectPage extends StatelessWidget {
  const _DeviceAvatarSelectPage({
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
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

class _AvatarSelectionResult {
  final String brandValue;
  final EquipmentType equipmentType;

  const _AvatarSelectionResult({
    required this.brandValue,
    required this.equipmentType,
  });
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : BrandPickerGrouped(
                  selectedBrandValue: widget.initialBrandValue,
                  equipmentTypeFilter: _selectedType,
                  onSelected: (brand) {
                    Navigator.of(context).pop(
                      _AvatarSelectionResult(
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
  final EquipmentType selectedType;
  final ValueChanged<EquipmentType> onChanged;

  const _DeviceTypeSegment({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(EquipmentType type) {
      final selected = selectedType == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(type),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              type.label,
              style: AppTypography.body(
                context,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33000000)),
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

// =====================================================================
// ============================== 七、设备编辑弹窗（在这里创建/释放） ==============================
// =====================================================================
// 【设计要点】TextEditingController 的创建与释放绑定在该组件生命周期内，
// 避免父组件提前 dispose 导致 “used after disposed”。
// 【返回值】直接返回一个“完整可落盘的 Device”，避免字段名/必填项错配。

class _DeviceEditorDialog extends StatefulWidget {
  const _DeviceEditorDialog({
    this.device,
    this.initialBrand,
    this.initialEquipmentType,
  });

  final Device? device;
  final String? initialBrand;
  final EquipmentType? initialEquipmentType;

  @override
  State<_DeviceEditorDialog> createState() => _DeviceEditorDialogState();
}

class _DeviceEditorDialogState extends State<_DeviceEditorDialog> {
  late String? _selectedBrand;
  late String _previewName;
  late EquipmentType _equipmentType;

  late final TextEditingController _modelCtrl;
  late final TextEditingController _unitPriceCtrl;
  late final TextEditingController _breakingUnitPriceCtrl;
  late final TextEditingController _baseMeterCtrl;
  String? _customAvatarPath;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final d = widget.device;
    _selectedBrand = d?.brand ?? widget.initialBrand;
    _equipmentType =
        d?.equipmentType ??
        widget.initialEquipmentType ??
        EquipmentType.excavator;

    _modelCtrl = TextEditingController(text: d?.model ?? '');
    _unitPriceCtrl = TextEditingController(
      text: (d?.defaultUnitPrice ?? 0.0).toStringAsFixed(0),
    );
    _breakingUnitPriceCtrl = TextEditingController(
      text: d?.breakingUnitPrice?.toStringAsFixed(0) ?? '',
    );
    _baseMeterCtrl = TextEditingController(
      text: (d?.baseMeterHours ?? 0.0).toStringAsFixed(0),
    );
    _customAvatarPath = d?.customAvatarPath;

    _previewName = d?.name ?? '';
    if (d == null) {
      _previewName = _calcPreviewName();
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _unitPriceCtrl.dispose();
    _breakingUnitPriceCtrl.dispose();
    _baseMeterCtrl.dispose();
    super.dispose();
  }

  String _calcPreviewName() {
    if (widget.device != null) return widget.device!.name;
    final brand = (_selectedBrand ?? '').trim();
    if (brand.isEmpty) return '';
    final store = context.read<DeviceStore>();
    return store.previewNextName(brand);
  }

  Future<void> _openBrandSheet() async {
    if (!mounted) return;
    final selected = await Navigator.of(context).push<_AvatarSelectionResult>(
      PageRouteBuilder<_AvatarSelectionResult>(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _DeviceAvatarSelectPage(
              initialType: _equipmentType,
              initialBrandValue: _selectedBrand,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(offset),
            child: child,
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedBrand = selected.brandValue;
      _equipmentType = selected.equipmentType;
      _previewName = _calcPreviewName();
    });
  }

  void _close(Device? d) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(d);
  }

  double? _parseDoubleOrNull(String s) => double.tryParse(s.trim());

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ensureProForCustomAvatar() async {
    if (SubscriptionService.canUseCustomAvatar) return true;
    final goUpgrade = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要升级'),
        content: const Text('自定义头像仅订阅用户可用，是否去升级？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('去升级'),
          ),
        ],
      ),
    );
    if (goUpgrade != true || !mounted) return false;
    final upgraded = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const UpgradePage()));
    if (upgraded == true) {
      return SubscriptionService.canUseCustomAvatar;
    }
    return false;
  }

  Future<void> _pickCustomAvatarFromGallery() async {
    if (_saving) return;
    final allowed = await _ensureProForCustomAvatar();
    if (!allowed || !mounted) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null || !mounted) return;
    try {
      final savedPath = await AvatarStorageService.saveXFile(file);
      if (!mounted) return;
      setState(() => _customAvatarPath = savedPath);
      _showMsg('已从相册更换头像');
    } catch (e) {
      _showMsg('头像保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.device != null;

    final previewLabel = _previewName.trim().isEmpty
        ? ''
        : DeviceLabel.indexOnly(_previewName);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DialogTokens.deviceEditorInsetHorizontal,
        vertical: DialogTokens.deviceEditorInsetVertical,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      title: Align(
        alignment: Alignment.center,
        child: Text(editing ? '编辑设备' : '新增设备'),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height *
              DialogTokens.deviceEditorMaxHeightRatio,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 品牌/头像选择
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBrand == null || _selectedBrand!.trim().isEmpty
                          ? '未选择品牌（头像）'
                          : '品牌：${_equipmentType.label}  ${_selectedBrand!}${previewLabel.isEmpty ? '' : '  $previewLabel'}',
                      style: AppTypography.body(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _openBrandSheet,
                    child: Text(
                      '选择',
                      style: AppTypography.body(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
              if (SubscriptionService.canUseCustomAvatar) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _customAvatarPath == null || _customAvatarPath!.isEmpty
                            ? '头像：品牌默认'
                            : '头像：已设置自定义',
                        style: AppTypography.bodySecondary(
                          context,
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _pickCustomAvatarFromGallery,
                      child: const Text('相册'),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _customAvatarPath = null),
                      child: const Text('默认'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: SpaceTokens.sectionGap),

              TextField(
                controller: _baseMeterCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '基准码表（>=0，必填）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: SpaceTokens.sectionGap),

              TextField(
                controller: _unitPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '默认单价（>0，必填）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),

              if (_equipmentType == EquipmentType.excavator) ...[
                const SizedBox(height: SpaceTokens.sectionGap),
                TextField(
                  controller: _breakingUnitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '破碎单价（选填）',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: SpaceTokens.sectionGap),

              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: '型号（选填）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => _close(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);

                  try {
                    final brand = (_selectedBrand ?? '').trim();
                    if (brand.isEmpty) {
                      setState(() => _saving = false);
                      return;
                    }

                    final unitPrice = _parseDoubleOrNull(_unitPriceCtrl.text);
                    if (unitPrice == null || unitPrice <= 0) {
                      setState(() => _saving = false);
                      return;
                    }

                    final base = _parseDoubleOrNull(_baseMeterCtrl.text);
                    if (base == null || base < 0) {
                      setState(() => _saving = false);
                      return;
                    }

                    double? breakingPrice;
                    if (_equipmentType == EquipmentType.excavator) {
                      final breakingRaw = _breakingUnitPriceCtrl.text.trim();
                      breakingPrice = breakingRaw.isEmpty
                          ? null
                          : _parseDoubleOrNull(breakingRaw);
                      if (breakingRaw.isNotEmpty &&
                          (breakingPrice == null || breakingPrice <= 0)) {
                        setState(() => _saving = false);
                        return;
                      }
                    } else {
                      breakingPrice = null;
                    }

                    // name：新增允许留空，让 store.insert 自动生成；但我们仍保留预览用于 UI
                    final name = editing
                        ? widget.device!.name
                        : (_previewName.trim().isEmpty
                              ? ''
                              : _previewName.trim());

                    final modelTrim = _modelCtrl.text.trim();

                    final d = Device(
                      id: widget.device?.id,
                      name: name,
                      brand: brand,
                      model: modelTrim.isEmpty ? null : modelTrim,
                      defaultUnitPrice: unitPrice,
                      breakingUnitPrice: breakingPrice,
                      baseMeterHours: base,
                      isActive: widget.device?.isActive ?? true,
                      customAvatarPath: _customAvatarPath,
                      equipmentType: _equipmentType,
                    );

                    final resolved = DeviceService.applyCustomAvatar(
                      device: d,
                      customAvatarPath: _customAvatarPath,
                    );
                    _close(resolved);
                  } catch (e) {
                    _showMsg(e.toString());
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
