// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/device.dart';
import '../../../features/device/state/device_store.dart';

import '../../../patterns/device/brand_picker_grouped_pattern.dart';
import '../../../components/avatars/app_device_avatar.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../core/utils/device_label.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../tokens/mapper/core_tokens.dart';

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
  Future<void> _openDeviceDialog({Device? device}) async {
    final store = context.read<DeviceStore>();

    final edited = await showDialog<Device>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeviceEditorDialog(device: device),
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

  Future<void> _retryLoad() async {
    final store = context.read<DeviceStore>();
    await store.loadAll();
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeviceStore>();
    final devices = store.activeDevices;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDeviceDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpaceTokens.pagePadding),
        children: [
          Text(
            '设备（${devices.length}）${store.loading ? " 读取中..." : ""}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (store.failure != null) ...[
            const SizedBox(height: 8),
            StoreErrorBanner(
              message: storeErrorMessage(store, action: '读取')!,
              onRetry: store.loading ? null : () => _retryLoad(),
            ),
          ],
          const SizedBox(height: SpaceTokens.sectionGap),
          const Divider(),
          if (devices.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(child: Text('暂无设备，点右下角 + 新增')),
          ] else ...[
            ...devices.map((d) {
              final label = DeviceLabel.indexOnly(d.name);

              final subtitle = [
                if (d.model != null && d.model!.trim().isNotEmpty)
                  '型号：${d.model}',
                '默认单价：${FormatUtils.money(d.defaultUnitPrice)}',
                '基准码表：${FormatUtils.hours(d.baseMeterHours)}',
              ].join(' · ');

              return ListTile(
                dense: true,
                leading: DeviceAvatar(
                  brand: d.brand,
                  customAvatarPath: d.customAvatarPath,
                ),
                title: Text(label.trim().isEmpty ? '编号未知' : label),
                subtitle: Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '编辑',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openDeviceDialog(device: d),
                    ),
                    IconButton(
                      tooltip: '停用',
                      icon: const Icon(Icons.pause_circle_outline),
                      onPressed: (d.id == null)
                          ? null
                          : () async {
                              final deviceStore = context.read<DeviceStore>();
                              final ok = await _confirmDeactivate(d);
                              if (!ok) return;
                              if (!mounted) return;

                              await deviceStore.deactivateById(d.id!);

                              final feedback = storeActionFeedback(
                                deviceStore,
                                action: '停用',
                                successMessage: '已停用（历史记录不受影响）',
                              );
                              _toast(feedback.message);
                              if (!feedback.isSuccess) {
                                return;
                              }
                            },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// ============================== 七、设备编辑弹窗（controller 在这里创建/释放） ==============================
// =====================================================================
// 【设计要点】TextEditingController 的创建与释放绑定在该组件生命周期内，
// 避免父组件提前 dispose 导致 “used after disposed”。
// 【返回值】直接返回一个“完整可落盘的 Device”，避免字段名/必填项错配。

class _DeviceEditorDialog extends StatefulWidget {
  const _DeviceEditorDialog({this.device});

  final Device? device;

  @override
  State<_DeviceEditorDialog> createState() => _DeviceEditorDialogState();
}

class _DeviceEditorDialogState extends State<_DeviceEditorDialog> {
  late String? _selectedBrand;
  late String _previewName;

  late final TextEditingController _modelCtrl;
  late final TextEditingController _unitPriceCtrl;
  late final TextEditingController _baseMeterCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final d = widget.device;
    _selectedBrand = d?.brand;

    _modelCtrl = TextEditingController(text: d?.model ?? '');
    _unitPriceCtrl = TextEditingController(
      text: (d?.defaultUnitPrice ?? 0.0).toStringAsFixed(0),
    );
    _baseMeterCtrl = TextEditingController(
      text: (d?.baseMeterHours ?? 0.0).toStringAsFixed(0),
    );

    _previewName = d?.name ?? '';
    if (d == null) {
      _previewName = _calcPreviewName();
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _unitPriceCtrl.dispose();
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.75,
            child: BrandPickerGrouped(
              selectedBrandValue: _selectedBrand,
              onSelected: (brand) {
                // 1) 更新值
                _selectedBrand = brand.value;

                // 2) 先关闭 sheet
                Navigator.of(sheetCtx).pop();

                // 3) 再刷新 dialog（避免路由切换期间 setState）
                Future.microtask(() {
                  if (!mounted) return;
                  setState(() {
                    _previewName = _calcPreviewName();
                  });
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _close(Device? d) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(d);
  }

  double? _parseDoubleOrNull(String s) => double.tryParse(s.trim());

  @override
  Widget build(BuildContext context) {
    final editing = widget.device != null;

    final previewLabel = _previewName.trim().isEmpty
        ? ''
        : DeviceLabel.indexOnly(_previewName);

    return AlertDialog(
      title: Text(editing ? '编辑设备' : '新增设备'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            // 品牌/头像选择
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedBrand == null || _selectedBrand!.trim().isEmpty
                        ? '未选择品牌（头像）'
                        : '品牌：${_selectedBrand!}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _openBrandSheet,
                  child: const Text('选择'),
                ),
              ],
            ),

            if (!editing) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('预览编号：', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      previewLabel.isEmpty ? '—' : previewLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
          ],
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
              : () {
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
                      baseMeterHours: base,
                      isActive: widget.device?.isActive ?? true,
                      customAvatarPath: widget.device?.customAvatarPath,
                    );

                    _close(d);
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
