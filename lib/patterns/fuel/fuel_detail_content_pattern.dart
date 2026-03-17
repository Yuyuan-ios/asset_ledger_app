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

import '../../data/models/device.dart';
import '../../data/models/fuel_log.dart';
import '../../tokens/mapper/bottom_sheet_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../core/utils/form_feedback.dart';
import '../../core/utils/interaction_feedback.dart';
import '../../core/utils/format_utils.dart';
import '../../components/fields/app_auto_suggest_field.dart';
import '../../patterns/device/device_picker_pattern.dart';
import '../../patterns/layout/sheet_text_field_pattern.dart';
import '../../components/fields/app_date_field.dart';
import '../../components/pickers/app_date_picker_dialog.dart';

// =====================================================================
// 二、FuelDetailContent
// =====================================================================

class FuelDetailContent extends StatefulWidget {
  const FuelDetailContent({
    super.key,
    this.editing,
    required this.logs,
    required this.activeDevices,
    required this.deviceById,
    required this.deviceItems,
    required this.supplierSuggestions,
    required this.onToast,
    required this.onSubmit,
  });

  /// editing != null：编辑；否则新建
  final FuelLog? editing;

  final List<FuelLog> logs;
  final List<Device> activeDevices;
  final Map<int, Device> deviceById;
  final List<DevicePickerItemVm> deviceItems;
  final List<String> Function(String) supplierSuggestions;

  /// toast（统一走 Page 的 toast 体系）
  final void Function(String msg) onToast;

  /// 提交（Content 只组装 FuelLog，Page 负责落库+toast+pop）
  final Future<void> Function(FuelLog log) onSubmit;

  @override
  State<FuelDetailContent> createState() => FuelDetailContentState();
}

// =====================================================================
// 三、State：表单 + 校验 + 组装
// =====================================================================

class FuelDetailContentState extends State<FuelDetailContent> {
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
      _dateCtrl.text = FormatUtils.todayDisplayDate();
      _applyDefaultDeviceForCreate();
      _supplierCtrl.text = _latestSupplier();
      _litersCtrl.clear();
      _costCtrl.clear();
    } else {
      _selectedDeviceId = editing.deviceId;
      _dateCtrl.text = FormatUtils.date(editing.date);
      _supplierCtrl.text = editing.supplier;
      _litersCtrl.text = FormatUtils.liters(editing.liters);
      _costCtrl.text = FormatUtils.moneyNumber(editing.cost);
    }
  }

  String _latestSupplier() {
    for (final r in widget.logs) {
      final s = r.supplier.trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  void _applyDefaultDeviceForCreate() {
    if (widget.editing != null || _selectedDeviceId != null) return;

    final activeDevices = widget.activeDevices.where((d) => d.id != null);
    if (activeDevices.isEmpty) return;

    int? defaultDeviceId;
    for (final r in widget.logs) {
      final d = widget.deviceById[r.deviceId];
      if (d != null && d.isActive) {
        defaultDeviceId = r.deviceId;
        break;
      }
    }

    defaultDeviceId ??= activeDevices.first.id;
    if (defaultDeviceId == null) return;

    final device = widget.deviceById[defaultDeviceId];
    if (device == null || !device.isActive) return;

    _selectedDeviceId = defaultDeviceId;
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

  double? _parseDouble(String s) => double.tryParse(s.trim());

  Future<void> _pickDate() async {
    final fallback = FormatUtils.parseDate(FormatUtils.todayDisplayDate())!;
    final currentYmd = FormatUtils.parseDate(_dateCtrl.text) ?? fallback;
    final initialDate = FormatUtils.dateFromYmd(currentYmd);

    final picked = await showSheetDatePickerDialog(
      context: context,
      initialDate: initialDate,
    );

    if (picked == null || !mounted) return;
    final ymd = FormatUtils.ymdFromDate(picked);
    setState(() => _dateCtrl.text = FormatUtils.date(ymd));
  }

  // =====================================================================
  // 六、提交：只组装 FuelLog + 调回调
  // =====================================================================

  Future<void> submit() async {
    if (_submitting) return;

    // 6.1 device 必选
    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      widget.onToast(formValidationMessage('请先选择设备'));
      return;
    }

    // 6.2 新建态：不允许选停用设备（编辑态允许回显历史）
    final device = widget.deviceById[deviceId];
    if (device == null) {
      widget.onToast(
        missingEntityMessage('设备', id: deviceId, suffix: '请先去设备页检查'),
      );
      return;
    }
    if (widget.editing == null && !device.isActive) {
      widget.onToast(inactiveEntityCreateMessage('该设备', recordLabel: '燃油记录'));
      return;
    }

    // 6.3 日期
    final date = FormatUtils.parseDate(_dateCtrl.text);
    if (date == null || date <= 0) {
      widget.onToast(formValidationMessage(FormatUtils.ymdInvalidMsg));
      return;
    }

    // 6.4 供应人必填
    final supplier = _supplierCtrl.text.trim();
    if (supplier.isEmpty) {
      widget.onToast(formValidationMessage('供应人必填'));
      return;
    }

    // 6.5 liters / cost
    final liters = _parseDouble(_litersCtrl.text);
    if (liters == null || liters <= 0) {
      widget.onToast(formValidationMessage('加油量必须是 > 0 的数字'));
      return;
    }

    final cost = _parseDouble(_costCtrl.text);
    if (cost == null || cost < 0) {
      widget.onToast(formValidationMessage('金额必须是 >= 0 的数字'));
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
  // 七、build：表单内容
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BottomSheetTokens.outerHPadding,
                  0,
                  BottomSheetTokens.outerHPadding,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1) 设备
                    DevicePickerPattern(
                      vm: DevicePickerVm(
                        selectedId: _selectedDeviceId,
                        items: widget.deviceItems,
                        onChanged: (id) =>
                            setState(() => _selectedDeviceId = id),
                      ),
                    ),
                    const SizedBox(height: SheetTokens.formFieldGap),

                    // 2) 日期
                    SheetDateField(
                      controller: _dateCtrl,
                      onPickDate: _pickDate,
                    ),
                    const SizedBox(height: SheetTokens.formFieldGap),

                    // 3) 供应人（必填，联想）
                    AutoSuggestField(
                      controller: _supplierCtrl,
                      label: '供应人（必填）',
                      hint: '例如：中石化 / 老王油品',
                      suggestionsBuilder: widget.supplierSuggestions,
                      onSelected: (v) => _supplierCtrl.text = v,
                    ),
                    const SizedBox(height: SheetTokens.formFieldGap),

                    // 4) 加油量
                    SheetTextFieldPattern(
                      controller: _litersCtrl,
                      labelText: '加油量（升）',
                      hintText: '例如：120.0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    const SizedBox(height: SheetTokens.formFieldGap),

                    // 5) 金额
                    SheetTextFieldPattern(
                      controller: _costCtrl,
                      labelText: '金额（元）',
                      hintText: '例如：980.0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
