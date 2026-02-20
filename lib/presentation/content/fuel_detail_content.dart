// ==============================================================================
// 📁 文件说明：燃油弹窗内容 (fuel_detail_content.dart)
//
// 设计目标：
// 1) 作为 BottomSheet 的内容区域（配合 AppBottomSheetShell 使用）
// 2) 负责“新增/编辑燃油”的表单与校验
// 3) 不直接操作 Store / 不 pop：统一走回调（与 Account 统一）
// ==============================================================================

// =====================================================================
// 一、导入依赖
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fuel_log.dart';
import '../../models/device.dart';

import '../../store/fuel_store.dart';
import '../../store/device_store.dart';

import '../../presentation/widgets/auto_suggest_field.dart';
import '../../presentation/widgets/device_picker.dart';

import '../../presentation/utils/format_utils.dart';

// =====================================================================
// 二、FuelDetailContent
// =====================================================================

class FuelDetailContent extends StatefulWidget {
  const FuelDetailContent({
    super.key,
    this.editing,
    required this.onCancel,
    required this.onToast,
    required this.onSubmit,
  });

  /// editing != null：编辑；否则新建
  final FuelLog? editing;

  /// 取消（由 Page 负责 pop）
  final VoidCallback onCancel;

  /// toast（统一走 Page 的 toast 体系）
  final void Function(String msg) onToast;

  /// 提交（Content 只组装 FuelLog，Page 负责落库+toast+pop）
  final Future<void> Function(FuelLog log) onSubmit;

  @override
  State<FuelDetailContent> createState() => _FuelDetailContentState();
}

// =====================================================================
// 三、State：表单 + 校验 + 组装
// =====================================================================

class _FuelDetailContentState extends State<FuelDetailContent> {
  // -------------------------------------------------------------------
  // 3.1 表单控制器
  // -------------------------------------------------------------------

  final _dateCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  // -------------------------------------------------------------------
  // 3.2 业务状态
  // -------------------------------------------------------------------

  int? _selectedDeviceId;
  bool _submitting = false;

  // =====================================================================
  // 四、生命周期：回填/初始化
  // =====================================================================

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;
    if (editing == null) {
      _dateCtrl.text = FormatUtils.todayYmd();
      _selectedDeviceId = null;
      _supplierCtrl.clear();
      _litersCtrl.clear();
      _costCtrl.clear();
    } else {
      _selectedDeviceId = editing.deviceId;
      _dateCtrl.text = editing.date.toString();
      _supplierCtrl.text = editing.supplier;
      _litersCtrl.text = FormatUtils.liters(editing.liters);
      _costCtrl.text = FormatUtils.moneyNumber(editing.cost);
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _supplierCtrl.dispose();
    _litersCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  // =====================================================================
  // 五、工具：解析/校验
  // =====================================================================

  int? _parseYmd(String s) {
    final t = s.trim();
    if (t.length != 8) return null;
    return int.tryParse(t);
  }

  double? _parseDouble(String s) => double.tryParse(s.trim());

  /// 设备 active 判定（兼容旧模型没 isActive）
  bool _deviceIsActive(Device d) {
    try {
      // ignore: avoid_dynamic_calls
      return (d as dynamic).isActive == true;
    } catch (_) {
      return true;
    }
  }

  // =====================================================================
  // 六、提交：只组装 FuelLog + 调回调
  // =====================================================================

  Future<void> _submit() async {
    if (_submitting) return;

    // 6.1 device 必选
    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      widget.onToast('保存失败：请先选择设备');
      return;
    }

    // 6.2 新建态：不允许选停用设备（编辑态允许回显历史）
    final device = context.read<DeviceStore>().findById(deviceId);
    if (device == null) {
      widget.onToast('设备不存在（id=$deviceId），请先去设备页检查');
      return;
    }
    if (widget.editing == null && !_deviceIsActive(device)) {
      widget.onToast('该设备已停用，不能用于新建燃油记录');
      return;
    }

    // 6.3 日期
    final date = _parseYmd(_dateCtrl.text);
    if (date == null || date <= 0) {
      widget.onToast('保存失败：日期必须是 YYYYMMDD（例如 20260208）');
      return;
    }

    // 6.4 供应人必填
    final supplier = _supplierCtrl.text.trim();
    if (supplier.isEmpty) {
      widget.onToast('保存失败：供应人必填');
      return;
    }

    // 6.5 liters / cost
    final liters = _parseDouble(_litersCtrl.text);
    if (liters == null || liters <= 0) {
      widget.onToast('保存失败：加油量必须是 > 0 的数字');
      return;
    }

    final cost = _parseDouble(_costCtrl.text);
    if (cost == null || cost < 0) {
      widget.onToast('保存失败：金额必须是 >= 0 的数字');
      return;
    }

    // 6.6 组装 FuelLog（不落库、不 pop）
    final log = FuelLog(
      id: widget.editing?.id,
      deviceId: deviceId,
      date: date,
      supplier: supplier,
      liters: liters,
      cost: cost,
    );

    setState(() => _submitting = true);
    await widget.onSubmit(log);
    if (mounted) setState(() => _submitting = false);
  }

  // =====================================================================
  // 七、UI 小组件
  // =====================================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  // =====================================================================
  // 八、build：表单内容
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FuelStore>(); // 仅用于供应人联想候选

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1) 设备
        DevicePicker(
          selectedDeviceId: _selectedDeviceId,
          onChanged: (id) => setState(() => _selectedDeviceId = id),
        ),
        const SizedBox(height: 12),

        // 2) 日期
        _field(
          controller: _dateCtrl,
          label: '日期（YYYYMMDD）',
          hint: '例如：20260208',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        // 3) 供应人（必填，联想）
        AutoSuggestField(
          controller: _supplierCtrl,
          label: '供应人（必填）',
          hint: '例如：中石化 / 老王油品',
          suggestionsBuilder: (q) => store.supplierSuggestions(q),
          onSelected: (v) => _supplierCtrl.text = v,
        ),
        const SizedBox(height: 12),

        // 4) 加油量
        _field(
          controller: _litersCtrl,
          label: '加油量（升）',
          hint: '例如：120.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),

        // 5) 金额
        _field(
          controller: _costCtrl,
          label: '金额（元）',
          hint: '例如：980.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),

        // 6) 底部按钮（与 Timing/Account 统一）
        Row(
          children: [
            TextButton(
              onPressed: _submitting ? null : widget.onCancel,
              child: const Text('取消'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '保存中...' : '确定'),
            ),
          ],
        ),
      ],
    );
  }
}
