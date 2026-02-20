// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../utils/format_utils.dart';
import '../../services/timing_service.dart';
import '../../store/device_store.dart';
import '../../store/timing_store.dart';

// =====================================================================
// ============================== 二、DevicePicker（统一设备选择器） ==============================
// =====================================================================
//
// 设计目标：
// - 全 App 统一“设备编号下拉框”逻辑（active 可选；inactive 仅回显不可选）
// - 解决：编辑旧记录时 value 不在 items 中导致 Dropdown 报错
// - 解决：records 变化时，码表 meter 自动刷新（watch TimingStore）
//
// 层级：Presentation Widget（可复用组件）
// =====================================================================

class DevicePicker extends StatelessWidget {
  // -------------------------------------------------------------------
  // 2.1 当前选中的设备 id（可为 null）
  // -------------------------------------------------------------------
  final int? selectedDeviceId;

  // -------------------------------------------------------------------
  // 2.2 选择回调：把选中的 id 抛回页面（页面决定如何联动 startMeter 等）
  // -------------------------------------------------------------------
  final ValueChanged<int?> onChanged;

  const DevicePicker({
    super.key,
    required this.selectedDeviceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // -----------------------------------------------------------------
    // 8.3.1 数据源：只让用户“选 active 设备”
    // 但：编辑旧记录时，如果旧设备已停用，也要能显示出来（否则 Dropdown 会报错）
    // -----------------------------------------------------------------

    // ✅ DeviceStore：activeDevices（用于选择）+ findById（用于回显已停用）
    final deviceStore = context.watch<DeviceStore>();
    final activeDevices = deviceStore.activeDevices;

    // ✅ TimingStore：records 变化时，下拉框里的“码表xxh”要自动刷新
    final records = context.watch<TimingStore>().records;

    // -----------------------------------------------------------------
    // 8.3.2 兜底：把“当前选中的设备（可能已停用）”插回 items
    //
    // 触发场景：
    // - 用户在列表点了一条旧记录进入编辑
    // - 那条记录的 deviceId 对应设备已停用（isActive=false）
    //
    // 如果不做这个兜底，DropdownButtonFormField 会因为 value 不在 items 中而直接报错。
    // -----------------------------------------------------------------
    final List<Device> dropdownDevices = [...activeDevices];

    if (selectedDeviceId != null) {
      final selected = deviceStore.findById(selectedDeviceId!);

      final selectedExistsInActive = activeDevices.any(
        (d) => d.id == selectedDeviceId,
      );

      // ✅ 当前选中的设备存在，但不在 active 列表里（=已停用）
      // -> 插到最前面，确保 Dropdown 能显示当前 value
      if (selected != null && !selectedExistsInActive) {
        dropdownDevices.insert(0, selected);
      }
    }

    // -----------------------------------------------------------------
    // 8.3.3 空态：没有任何 active 设备
    // -----------------------------------------------------------------
    if (activeDevices.isEmpty) {
      return DropdownButtonFormField<int>(
        initialValue: null,
        items: const [],
        onChanged: null, // ✅ 禁用
        decoration: const InputDecoration(
          labelText: '设备编号',
          hintText: '暂无在用设备，请先去“设备”页新增',
          border: OutlineInputBorder(),
        ),
      );
    }

    // -----------------------------------------------------------------
    // 8.3.4 UI：构建 Dropdown
    // 关键点：
    // - active 设备：可选
    // - inactive 设备：仅展示（disabled），防止用户在新建时选到旧设备
    // -----------------------------------------------------------------
    return DropdownButtonFormField<int>(
      initialValue: selectedDeviceId,
      items: dropdownDevices.where((d) => d.id != null).map((d) {
        final id = d.id!;

        // ✅ currentMeter = max(baseMeterHours, maxEndMeter)
        final meter = TimingService.currentMeter(
          records,
          id,
          baseMeterHours: d.baseMeterHours,
        );

        // ✅ 展示格式化：统一由 FormatUtils 输出（例如 123.4）
        final meterText = FormatUtils.meter(meter);

        // ✅ 已停用设备：只用于“编辑旧记录回显”
        final isInactive = !d.isActive;

        return DropdownMenuItem<int>(
          value: id,
          enabled: !isInactive, // ✅ 停用设备不可选（灰掉）
          child: Text(
            isInactive
                ? '${d.name}（已停用 · 码表 $meterText h）'
                : '${d.name}（码表 $meterText h）',
          ),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: '设备编号',
        border: OutlineInputBorder(),
      ),
    );
  }
}
