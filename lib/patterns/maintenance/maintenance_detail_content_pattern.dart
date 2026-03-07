// ==============================================================================
// 📁 文件说明：维保弹窗内容 (maintenance_detail_content.dart)
//
// 设计目标：
// 1) 作为 BottomSheet 的内容区域（配合 AppBottomSheetShell 使用）
// 2) 负责“新增/编辑维保”的表单与校验
// 3) 不直接操作 Store / 不 pop：统一走回调（与 Account 统一）
// ==============================================================================

// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../data/models/device.dart';
import '../../data/models/maintenance_record.dart';
import '../../core/utils/form_feedback.dart';
import '../../core/utils/interaction_feedback.dart';
import '../../core/utils/format_utils.dart';
import '../../patterns/device/device_picker_pattern.dart';
import '../../components/fields/app_auto_suggest_field.dart';
import '../../components/fields/app_date_field.dart';
import '../../components/pickers/app_date_picker_dialog.dart';

// =====================================================================
// ============================== 二、Content Widget ==============================
// =====================================================================

class MaintenanceDetailContent extends StatefulWidget {
  const MaintenanceDetailContent({
    super.key,
    this.editing,
    required this.deviceById,
    required this.deviceItems,
    required this.itemSuggestions,
    required this.onCancel,
    required this.onToast,
    required this.onSubmit,
  });

  /// editing != null：编辑；否则新建
  final MaintenanceRecord? editing;
  final Map<int, Device> deviceById;
  final List<DevicePickerItemVm> deviceItems;
  final List<String> Function(String query) itemSuggestions;

  /// 取消（由 Page 负责 pop）
  final VoidCallback onCancel;

  /// toast（统一走 Page 的 toast 体系）
  final void Function(String msg) onToast;

  /// 提交（Content 只组装 MaintenanceRecord）
  final Future<void> Function(MaintenanceRecord record) onSubmit;

  @override
  State<MaintenanceDetailContent> createState() =>
      MaintenanceDetailContentState();
}

class MaintenanceDetailContentState extends State<MaintenanceDetailContent> {
  // -------------------------------------------------------------------
  // 2.1 表单控制器
  // -------------------------------------------------------------------

  final _dateCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0.0');
  final _noteCtrl = TextEditingController();

  // -------------------------------------------------------------------
  // 2.2 表单状态
  // -------------------------------------------------------------------

  int? _selectedDeviceId;

  /// 公共支出：deviceId = null
  bool _isPublicExpense = false;

  bool _submitting = false;

  // =====================================================================
  // ============================== 三、生命周期 ==============================
  // =====================================================================

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;

    if (editing == null) {
      _dateCtrl.text = FormatUtils.todayDisplayDate();
      _isPublicExpense = false;
      _selectedDeviceId = null;
      _itemCtrl.clear();
      _amountCtrl.text = '0.0';
      _noteCtrl.clear();
    } else {
      _dateCtrl.text = FormatUtils.date(editing.ymd);
      _itemCtrl.text = editing.item;
      _amountCtrl.text = editing.amount.toStringAsFixed(1);
      _noteCtrl.text = editing.note ?? '';

      _isPublicExpense = (editing.deviceId == null);
      _selectedDeviceId = editing.deviceId;
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _itemCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // =====================================================================
  // ============================== 四、工具：解析/校验 ==============================
  // =====================================================================

  double? _parseAmount(String s) => double.tryParse(s.trim());

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

  Future<void> _submit() async {
    if (_submitting) return;

    // 1) 日期
    final ymd = FormatUtils.parseDate(_dateCtrl.text);
    if (ymd == null || ymd <= 0) {
      widget.onToast(formValidationMessage(FormatUtils.ymdInvalidMsg));
      return;
    }

    // 2) 事项
    final item = _itemCtrl.text.trim();
    if (item.isEmpty) {
      widget.onToast(formValidationMessage('事项必填'));
      return;
    }

    // 3) 金额
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null) {
      widget.onToast(formValidationMessage('金额格式不正确'));
      return;
    }
    if (amount <= 0) {
      widget.onToast(formValidationMessage('金额应大于 0'));
      return;
    }

    // 4) 设备 / 公共支出
    int? deviceId;
    if (_isPublicExpense) {
      deviceId = null;
    } else {
      deviceId = _selectedDeviceId;
      if (deviceId == null) {
        widget.onToast(formValidationMessage('请选择设备，或切换为“公共支出”'));
        return;
      }

      // 新建态：不允许选停用设备（编辑态允许回显历史）
      final device = widget.deviceById[deviceId];
      if (device == null) {
        widget.onToast(
          missingEntityMessage('设备', id: deviceId, suffix: '请先去设备页检查'),
        );
        return;
      }
      if (widget.editing == null && !device.isActive) {
        widget.onToast(inactiveEntityCreateMessage('该设备', recordLabel: '维保记录'));
        return;
      }
    }

    // 5) 备注（可空）
    final note = _noteCtrl.text.trim();

    final record = MaintenanceRecord(
      id: widget.editing?.id,
      deviceId: deviceId,
      ymd: ymd,
      item: item,
      amount: amount,
      note: note.isEmpty ? null : note,
    );

    setState(() => _submitting = true);
    await widget.onSubmit(record);
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> submit() => _submit();

  // =====================================================================
  // ============================== 五、UI 小组件 ==============================
  // =====================================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hint,
  }) {
    final fieldTextStyle = AppTypography.body(context, color: Colors.black);
    final labelStyle = AppTypography.bodySecondary(
      context,
      color: Colors.black,
    );
    final hintStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade600,
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: fieldTextStyle,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: labelStyle,
        hintText: hint,
        hintStyle: hintStyle,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  // =====================================================================
  // ============================== 六、build：表单内容 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final switchTitleStyle = AppTypography.body(
      context,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1) 公共支出开关（置顶）
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('公共支出（不属于任何设备）', style: switchTitleStyle),
                    value: _isPublicExpense,
                    onChanged: (v) {
                      setState(() {
                        _isPublicExpense = v;
                        if (v) _selectedDeviceId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2) 设备（公共支出时灰掉）
                  IgnorePointer(
                    ignoring: _isPublicExpense,
                    child: Opacity(
                      opacity: _isPublicExpense ? 0.5 : 1.0,
                      child: DevicePickerPattern(
                        vm: DevicePickerVm(
                          selectedId: _selectedDeviceId,
                          items: widget.deviceItems,
                          onChanged: (id) =>
                              setState(() => _selectedDeviceId = id),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3) 日期
                  SheetDateField(controller: _dateCtrl, onPickDate: _pickDate),
                  const SizedBox(height: 12),

                  // 4) 事项
                  AutoSuggestField(
                    controller: _itemCtrl,
                    label: '事项（必填）',
                    hint: '例如：更换机油/保养/维修',
                    suggestionsBuilder: widget.itemSuggestions,
                    onSelected: (v) => _itemCtrl.text = v,
                  ),
                  const SizedBox(height: 12),

                  // 5) 金额
                  _field(
                    controller: _amountCtrl,
                    label: '金额（元）',
                    hint: '例如：980.0',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6) 备注
                  _field(
                    controller: _noteCtrl,
                    label: '备注（可填）',
                    hint: '例如：含工时/含配件',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
