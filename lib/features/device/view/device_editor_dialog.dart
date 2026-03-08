import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../components/feedback/app_toast.dart';
import '../../../core/utils/device_label.dart';
import '../../../data/models/device.dart';
import '../../../data/services/avatar_storage_service.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/subscription_service.dart';
import '../../../features/device/state/device_store.dart';
import '../../../patterns/device/device_editor_actions_pattern.dart';
import '../../../patterns/device/device_editor_brand_row_pattern.dart';
import '../../../patterns/device/device_editor_fields_group_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_avatar_select_page.dart';
import 'upgrade_page.dart';

class DeviceEditorDialog extends StatefulWidget {
  const DeviceEditorDialog({
    super.key,
    this.device,
    this.initialBrand,
    this.initialEquipmentType,
  });

  final Device? device;
  final String? initialBrand;
  final EquipmentType? initialEquipmentType;

  @override
  State<DeviceEditorDialog> createState() => _DeviceEditorDialogState();
}

class _DeviceEditorDialogState extends State<DeviceEditorDialog> {
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
    final selected = await pushDeviceAvatarSelectPage(
      context,
      initialType: _equipmentType,
      initialBrandValue: _selectedBrand,
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
    AppToast.show(context, msg);
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
      contentPadding: const EdgeInsets.fromLTRB(
        DialogTokens.deviceEditorContentPadLeft,
        DialogTokens.deviceEditorContentPadTop,
        DialogTokens.deviceEditorContentPadRight,
        DialogTokens.deviceEditorContentPadBottom,
      ),
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
              DeviceEditorBrandRow(
                selectedBrand: _selectedBrand,
                equipmentType: _equipmentType,
                previewLabel: previewLabel,
                saving: _saving,
                canUseCustomAvatar: SubscriptionService.canUseCustomAvatar,
                customAvatarPath: _customAvatarPath,
                onSelectBrand: _openBrandSheet,
                onPickFromGallery: _pickCustomAvatarFromGallery,
                onResetAvatar: () => setState(() => _customAvatarPath = null),
              ),
              const SizedBox(height: SpaceTokens.sectionGap),
              DeviceEditorFieldsGroup(
                baseMeterController: _baseMeterCtrl,
                unitPriceController: _unitPriceCtrl,
                breakingUnitPriceController: _breakingUnitPriceCtrl,
                modelController: _modelCtrl,
                equipmentType: _equipmentType,
              ),
            ],
          ),
        ),
      ),
      actions: DeviceEditorActionsPattern.build(
        saving: _saving,
        onCancel: () => _close(null),
        onConfirm: () async {
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

            final name = editing
                ? widget.device!.name
                : (_previewName.trim().isEmpty ? '' : _previewName.trim());

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
      ),
    );
  }
}
