// ==============================================================================
// 📁 文件说明：计时弹窗内容 (timing_detail_content.dart)
//
// 设计目标：
// 1) 作为 BottomSheet 的内容区域（配合 AppBottomSheetShell 使用）
// 2) 负责“新建/编辑计时”的完整表单与校验（只做表单，不做保存流程）
// 3) 支持“包油/包电”：仅工时模式可切换；租金模式隐藏且不影响
// 4) 不直接落库/不 pop：由外部（TimingPage）接管 save + toast + pop
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/timing_record.dart';

import '../../store/device_store.dart';
import '../../store/timing_store.dart';

import '../widgets/auto_suggest_field.dart';
import '../widgets/device_picker.dart';

import '../utils/format_utils.dart';
import '../../services/timing_service.dart';

// =====================================================================
// ============================== 一、UI 辅助枚举 ==============================
// =====================================================================

/// 弹窗内的工作模式：
/// - hours：工时
/// - rent ：租金
enum WorkMode { hours, rent }

// =====================================================================
// ============================== 二、TimingDetailContent ==============================
// =====================================================================

class TimingDetailContent extends StatefulWidget {
  const TimingDetailContent({
    super.key,
    this.editing,
    required this.onCancel,
    required this.onSubmit,
    required this.onToast,
  });

  /// editing != null：编辑模式；否则新建模式
  final TimingRecord? editing;

  /// 外部负责 pop
  final VoidCallback onCancel;

  /// 外部负责：save + toast + pop（成功后外部 pop）
  final Future<void> Function(TimingRecord record) onSubmit;

  /// 外部统一 toast（也可以直接用 ScaffoldMessenger）
  final void Function(String msg) onToast;

  @override
  State<TimingDetailContent> createState() => _TimingDetailContentState();
}

class _TimingDetailContentState extends State<TimingDetailContent> {
  // -------------------------------------------------------------------
  // 2.1 表单控制器
  // -------------------------------------------------------------------
  final _startDateCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();

  final _startMeterCtrl = TextEditingController();
  final _endMeterCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '0.0');

  // 租金金额
  final _incomeCtrl = TextEditingController(text: '0.0');

  // -------------------------------------------------------------------
  // 2.2 业务状态
  // -------------------------------------------------------------------
  int? _selectedDeviceId;

  WorkMode _mode = WorkMode.hours;

  /// ✅ 包油/包电：true 表示该工时不计入燃油效率
  bool _excludeFromFuelEfficiency = false;

  bool _submitting = false;

  // -------------------------------------------------------------------
  // 2.3 联动防循环
  // -------------------------------------------------------------------
  bool _syncingFromEndMeter = false;
  bool _syncingFromHours = false;

  // =====================================================================
  // ============================== 三、生命周期 ==============================
  // =====================================================================

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;

    if (editing == null) {
      // 新建：默认今天
      _startDateCtrl.text = FormatUtils.todayYmd();
      _mode = WorkMode.hours;
      _excludeFromFuelEfficiency = false;
    } else {
      // 编辑：回填
      _selectedDeviceId = editing.deviceId;
      _startDateCtrl.text = editing.startDate.toString();
      _contactCtrl.text = editing.contact;
      _siteCtrl.text = editing.site;

      _mode = (editing.type == TimingType.hours)
          ? WorkMode.hours
          : WorkMode.rent;

      _startMeterCtrl.text = FormatUtils.meter(editing.startMeter);
      _endMeterCtrl.text = FormatUtils.meter(editing.endMeter);
      _hoursCtrl.text = FormatUtils.meter(editing.hours);
      _incomeCtrl.text = FormatUtils.meter(editing.income);

      _excludeFromFuelEfficiency = editing.excludeFromFuelEfficiency;
    }
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _contactCtrl.dispose();
    _siteCtrl.dispose();
    _startMeterCtrl.dispose();
    _endMeterCtrl.dispose();
    _hoursCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  // =====================================================================
  // ============================== 四、工具：解析 / 校验 ==============================
  // =====================================================================

  double _parseDoubleOrZero(String s) {
    final v = double.tryParse(s.trim());
    return v ?? 0.0;
  }

  int? _parseYmd(String s) {
    final t = s.trim();
    if (t.length != 8) return null;
    return int.tryParse(t);
  }

  bool _deviceIsActive(Device d) {
    try {
      // ignore: avoid_dynamic_calls
      return (d as dynamic).isActive == true;
    } catch (_) {
      return true;
    }
  }

  // =====================================================================
  // ============================== 五、联动逻辑（码表/工时） ==============================
  // =====================================================================

  void _recalcFromEndMeter() {
    if (_syncingFromHours) return;

    final start = _parseDoubleOrZero(_startMeterCtrl.text);
    final end = _parseDoubleOrZero(_endMeterCtrl.text);
    if (end < start) return;

    final hours = end - start;

    _syncingFromEndMeter = true;
    _hoursCtrl.text = FormatUtils.meter(hours);
    _syncingFromEndMeter = false;
  }

  void _recalcFromHours() {
    if (_syncingFromEndMeter) return;

    final start = _parseDoubleOrZero(_startMeterCtrl.text);
    final hours = _parseDoubleOrZero(_hoursCtrl.text);
    if (hours < 0) return;

    final end = start + hours;

    _syncingFromHours = true;
    _endMeterCtrl.text = FormatUtils.meter(end);
    _syncingFromHours = false;
  }

  // =====================================================================
  // ============================== 六、设备选择：默认 currentMeter 回填 ==============================
  // =====================================================================

  void _onDeviceChanged(int? deviceId) {
    setState(() => _selectedDeviceId = deviceId);

    if (deviceId == null) return;

    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();

    final device = deviceStore.findById(deviceId);
    if (device == null) {
      widget.onToast('设备不存在（id=$deviceId），请先去设备页检查');
      setState(() => _selectedDeviceId = null);
      return;
    }

    // ✅ 新建态拦截停用设备（编辑态允许历史记录引用）
    if (widget.editing == null && !_deviceIsActive(device)) {
      widget.onToast('该设备已停用，不能用于新建（历史记录仍可查看）');
      setState(() => _selectedDeviceId = null);
      return;
    }

    final base = device.baseMeterHours;
    final currentMeter = TimingService.currentMeter(
      timingStore.records,
      deviceId,
      baseMeterHours: base,
    );

    _startMeterCtrl.text = FormatUtils.meter(currentMeter);
    _endMeterCtrl.text = _startMeterCtrl.text;
    _hoursCtrl.text = '0.0';

    if (widget.editing == null) {
      _incomeCtrl.text = '0.0';
    }
  }

  // =====================================================================
  // ============================== 七、提交：只校验+组装record，交给外部保存 ==============================
  // =====================================================================

  Future<void> _submit() async {
    if (_submitting) return;

    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      widget.onToast('请选择设备');
      return;
    }

    final ymd = _parseYmd(_startDateCtrl.text);
    if (ymd == null) {
      widget.onToast('日期格式错误，请输入 YYYYMMDD');
      return;
    }

    final contact = _contactCtrl.text.trim();
    final site = _siteCtrl.text.trim();
    if (contact.isEmpty || site.isEmpty) {
      widget.onToast('联系人和工地不能为空');
      return;
    }

    final startMeter = _parseDoubleOrZero(_startMeterCtrl.text);
    final endMeter = _parseDoubleOrZero(_endMeterCtrl.text);
    final hours = _parseDoubleOrZero(_hoursCtrl.text);

    if (endMeter < startMeter) {
      widget.onToast('结束码表不能小于开始码表');
      return;
    }
    if (hours < 0) {
      widget.onToast('工时不能为负数');
      return;
    }

    final income = (_mode == WorkMode.rent)
        ? _parseDoubleOrZero(_incomeCtrl.text)
        : 0.0;

    if (_mode == WorkMode.rent && income <= 0) {
      widget.onToast('租金模式请填写金额（元）');
      return;
    }

    // ✅ 闭合记录才做悖论校验
    final isClosed = (endMeter > startMeter) || (hours > 0);
    if (isClosed) {
      final store = context.read<TimingStore>();
      final records = store.records;
      final excludeId = widget.editing?.id;

      final lower = TimingService.lowerBound(
        records: records,
        deviceId: deviceId,
        startDate: ymd,
        excludeId: excludeId,
      );

      final upper = TimingService.upperBound(
        records: records,
        deviceId: deviceId,
        startDate: ymd,
        excludeId: excludeId,
      );

      if (endMeter < lower) {
        widget.onToast('保存失败：结束码表($endMeter) < 下界($lower)');
        return;
      }
      if (upper != double.infinity && endMeter > upper) {
        widget.onToast('保存失败：结束码表($endMeter) > 上界($upper)');
        return;
      }
    }

    // ✅ 核心规则：包油/包电仅工时生效；租金强制 false（隐藏且不影响）
    final excludeFuel = (_mode == WorkMode.hours)
        ? _excludeFromFuelEfficiency
        : false;

    final type = (_mode == WorkMode.hours) ? TimingType.hours : TimingType.rent;

    final record = TimingRecord(
      id: widget.editing?.id,
      deviceId: deviceId,
      startDate: ymd,
      contact: contact,
      site: site,
      type: type,
      startMeter: startMeter,
      endMeter: endMeter,
      hours: hours,
      income: income,
      excludeFromFuelEfficiency: excludeFuel,
    );

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(record);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // =====================================================================
  // ============================== 八、UI 组件 ==============================
  // =====================================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<WorkMode>(
      segments: const [
        ButtonSegment(value: WorkMode.hours, label: Text('工时')),
        ButtonSegment(value: WorkMode.rent, label: Text('租金')),
      ],
      selected: {_mode},
      onSelectionChanged: (s) {
        setState(() {
          _mode = s.first;

          // 切到工时：租金金额归零
          if (_mode == WorkMode.hours) {
            _incomeCtrl.text = '0.0';
          }

          // 切到租金：包油强制关闭（隐藏且不影响）
          if (_mode == WorkMode.rent) {
            _excludeFromFuelEfficiency = false;
          }
        });
      },
    );
  }

  /// ✅ 包油/包电开关（仅工时模式显示，且放在“工时输入”下面）
  Widget _buildExcludeFuelSwitch() {
    if (_mode != WorkMode.hours) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '包油/包电（不计入油耗效率）',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  '开启后：本条工时不参与油耗效率统计',
                  style: TextStyle(fontSize: 12, height: 1.2),
                ),
              ],
            ),
          ),
          Switch(
            value: _excludeFromFuelEfficiency,
            onChanged: (v) => setState(() => _excludeFromFuelEfficiency = v),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // ============================== 九、build（按你要求重新排版） ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1) 设备选择
        DevicePicker(
          selectedDeviceId: _selectedDeviceId,
          onChanged: _onDeviceChanged,
        ),
        const SizedBox(height: 12),

        // ✅ 2) 模式选择移到最上面（设备下面）
        _buildModeSelector(),
        const SizedBox(height: 12),

        // 3) 日期
        _field(
          controller: _startDateCtrl,
          label: '开始日期（YYYYMMDD）',
          keyboardType: TextInputType.number,
          hint: '例如 20260208',
        ),
        const SizedBox(height: 12),

        // 4) 联系人联想
        AutoSuggestField(
          controller: _contactCtrl,
          label: '联系人',
          hint: '例如：王涛',
          suggestionsBuilder: (q) =>
              context.read<TimingStore>().contactSuggestions(q),
          onSelected: (v) => _contactCtrl.text = v,
        ),
        const SizedBox(height: 12),

        // 5) 工地联想
        AutoSuggestField(
          controller: _siteCtrl,
          label: '使用地址/工地',
          hint: '例如：修文',
          suggestionsBuilder: (q) =>
              context.read<TimingStore>().siteSuggestions(q),
          onSelected: (v) => _siteCtrl.text = v,
        ),
        const SizedBox(height: 12),

        // 6) 码表
        _field(
          controller: _startMeterCtrl,
          label: '开始码表（小时）',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: '选设备后自动带出，可修改',
          onChanged: (_) {
            if (_syncingFromEndMeter) return;
            if (_syncingFromHours) return;
            _recalcFromEndMeter();
          },
        ),
        const SizedBox(height: 12),

        _field(
          controller: _endMeterCtrl,
          label: '结束码表（小时）',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _recalcFromEndMeter(),
        ),
        const SizedBox(height: 12),

        // 7) 工时 / 租金金额
        if (_mode == WorkMode.hours) ...[
          _field(
            controller: _hoursCtrl,
            label: '工时（小时）',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalcFromHours(),
          ),
          const SizedBox(height: 12),

          // ✅ 包油开关放到工时输入下面
          _buildExcludeFuelSwitch(),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _hoursCtrl,
                  label: '工时（小时）',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _recalcFromHours(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _incomeCtrl,
                  label: '金额（元）',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hint: '租金收入',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),

        // 8) 操作按钮
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
