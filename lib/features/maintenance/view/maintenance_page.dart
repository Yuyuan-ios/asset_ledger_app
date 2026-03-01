// ==============================================================================
// 📁 文件说明：维保页面 (maintenance_page.dart)
//
// 目标改造：
// 1) 维保页只负责“统计 + 列表”整页展示（不承载表单）
// 2) 右上角提供「+ 新建」按钮，使用 AppBottomSheetShell 弹出底部弹窗
// 3) 新建/编辑表单下沉到 MaintenanceDetailContent（与 Fuel/Timing/Account 统一）
// ==============================================================================

// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/foundation/spacing.dart';

import '../../../data/models/maintenance_record.dart';
import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/services/timing_service.dart';
import '../../../components/avatars/app_device_avatar.dart';
import '../../../components/list/app_record_list_tile.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../tokens/mapper/core_tokens.dart';

import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/maintenance/maintenance_detail_content_pattern.dart';

import '../../../features/device/state/device_controller.dart';
import '../../../features/maintenance/state/maintenance_controller.dart';
import '../../timing/state/timing_controller.dart';
import '../../../patterns/device/device_picker_pattern.dart';

// =====================================================================
// ============================== 二、页面入口 ==============================
// =====================================================================

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

// =====================================================================
// ============================== 四、State：仅做页面级交互 ==============================
// =====================================================================

class _MaintenancePageState extends State<MaintenancePage> {
  List<DevicePickerItemVm> _buildDevicePickerItems({
    required List<Device> activeDevices,
    required List<Device> allDevices,
    required List<TimingRecord> records,
    int? selectedId,
  }) {
    final items = <DevicePickerItemVm>[];
    final activeIds = <int>{};

    for (final d in activeDevices) {
      final id = d.id;
      if (id == null) continue;
      activeIds.add(id);
      final meter = TimingService.currentMeter(
        records,
        id,
        baseMeterHours: d.baseMeterHours,
      );
      final meterText = FormatUtils.meter(meter);
      items.add(
        DevicePickerItemVm(
          id: id,
          label: '${d.name}（码表 $meterText h）',
          enabled: true,
        ),
      );
    }

    if (selectedId != null && !activeIds.contains(selectedId)) {
      final selected = allDevices.firstWhere(
        (d) => d.id == selectedId,
        orElse: () => const Device(
          id: -1,
          name: '未知设备',
          brand: '',
          defaultUnitPrice: 0,
          baseMeterHours: 0,
          isActive: false,
        ),
      );
      final labelId = selected.id ?? selectedId;
      if (labelId >= 0) {
        final meter = TimingService.currentMeter(
          records,
          labelId,
          baseMeterHours: selected.baseMeterHours,
        );
        final meterText = FormatUtils.meter(meter);
        items.insert(
          0,
          DevicePickerItemVm(
            id: labelId,
            label: '${selected.name}（已停用 · 码表 $meterText h）',
            enabled: false,
          ),
        );
      } else {
        items.insert(
          0,
          DevicePickerItemVm(
            id: selectedId,
            label: '未知设备（已停用）',
            enabled: false,
          ),
        );
      }
    }

    return items;
  }
  // =====================================================================
  // ============================== 五、生命周期：兜底加载 ==============================
  // =====================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deviceStore = context.read<DeviceStore>();
      final maintenanceStore = context.read<MaintenanceStore>();

      // 兜底加载（即使 MainPage 已 loadAll，也不影响功能）
      await deviceStore.loadAll();
      await maintenanceStore.loadAll();
    });
  }

  // =====================================================================
  // ============================== 六、通用 toast ==============================
  // =====================================================================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: AppDurations.snackBar),
    );
  }

  // =====================================================================
  // ============================== 七、BottomSheet：新建/编辑 ==============================
  // =====================================================================

  Future<void> _openMaintenanceEditor({MaintenanceRecord? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final maintenanceStore = context.read<MaintenanceStore>();
    final deviceById = <int, Device>{};
    for (final d in deviceStore.allDevices) {
      final id = d.id;
      if (id == null) continue;
      deviceById[id] = d;
    }
    final deviceItems = _buildDevicePickerItems(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      records: timingStore.records,
      selectedId: editing?.deviceId,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AppBottomSheetShell(
          title: editing == null ? '新建维保' : '编辑维保',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: MaintenanceDetailContent(
              editing: editing,
              deviceById: deviceById,
              deviceItems: deviceItems,

              // 取消：Page 负责 pop
              onCancel: () => Navigator.of(ctx).pop(),

              // toast：统一走 Page
              onToast: _toast,

              // ✅ 保存：Page 负责落库 + toast + pop（与 Account/Fuel/Timing 统一）
              onSubmit: (record) async {
                await maintenanceStore.save(record);

                if (!mounted) return;

                if (maintenanceStore.error != null) {
                  _toast('保存失败：${maintenanceStore.error}');
                  return;
                }

                _toast('已保存');
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // ============================== 八、删除：确认 + Store.deleteById ==============================
  // =====================================================================

  Future<void> _delete(MaintenanceRecord r) async {
    if (r.id == null) return;
    final store = context.read<MaintenanceStore>();

    final ok = await showAppConfirmDialog(
      context: context,
      title: '确认删除？',
      content:
          '日期：${FormatUtils.date(r.ymd)}\n'
          '事项：${r.item}\n'
          '金额：${FormatUtils.money(r.amount)}\n\n'
          '⚠️ 删除后不可恢复',
      confirmText: '删除',
    );

    if (ok != true) return;

    await store.deleteById(r.id!);

    if (!mounted) return;

    if (store.error != null) {
      _toast('删除失败：${store.error}');
    } else {
      _toast('已删除');
    }
  }

  // =====================================================================
  // ============================== 九、UI：统计卡（按设备 + 公共 + 合计） ==============================
  // =====================================================================

  Widget _buildSummaryCard() {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();

    // 口径：当年（你 Store.currentYearSummary 的口径）
    final nowYmd = FormatUtils.ymdFromDate(DateTime.now());

    // 约定：map key = deviceId(int) 或 null(公共)
    final map = store.currentYearSummary(nowYmd: nowYmd);

    if (map.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Text('当年维保费：暂无数据'),
      );
    }

    final publicTotal = map[null] ?? 0.0;

    final deviceIds = map.keys.whereType<int>().toList()..sort();
    double allTotal = publicTotal;
    for (final id in deviceIds) {
      allTotal += (map[id] ?? 0.0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当年维保费用（按设备 & 公共）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // 设备分摊
          for (final id in deviceIds)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      deviceStore.findById(id)?.name ?? '设备$id（已停用/不存在）',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    FormatUtils.money(map[id] ?? 0.0),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // 公共支出
          if (publicTotal > 0) ...[
            const Divider(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('公共支出', style: TextStyle(fontSize: 13)),
                ),
                Text(
                  FormatUtils.money(publicTotal),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 16),

          // 合计
          Row(
            children: [
              const Expanded(
                child: Text(
                  '合计',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                FormatUtils.money(allTotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // ============================== 十、UI：列表（最近记录） ==============================
  // =====================================================================

  Widget _buildList() {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();

    final records = store.records;
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
        child: Center(child: Text('暂无记录（点击右上角 + 新建）')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = records[index];
        final isPublic = (r.deviceId == null);

        // leading：公共=“公”，设备=头像
        Widget leading;
        String deviceName;

        if (isPublic) {
          leading = const CircleAvatar(
            radius: 18,
            child: Text('公', style: TextStyle(fontWeight: FontWeight.w800)),
          );
          deviceName = '公共支出';
        } else {
          final device = deviceStore.findById(r.deviceId!);
          if (device == null) {
            leading = const CircleAvatar(radius: 18, child: Text('?'));
            deviceName = '设备#${r.deviceId}（已停用/不存在）';
          } else {
            leading = DeviceAvatar(
              brand: device.brand,
              customAvatarPath: device.customAvatarPath,
              radius: 18,
            );
            deviceName = device.name;
          }
        }

        final title = '$deviceName · ${FormatUtils.date(r.ymd)}';

        final subtitle = (r.note == null || r.note!.trim().isEmpty)
            ? r.item
            : '${r.item} · ${r.note!.trim()}';

        final trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FormatUtils.money(r.amount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: (r.id == null) ? null : () => _delete(r),
            ),
          ],
        );

        return RecordListTile(
          dense: true,
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: () => _openMaintenanceEditor(editing: r),
        );
      },
    );
  }

  // =====================================================================
  // ============================== 十一、build：统计 + 列表 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();

    final loading = store.loading || deviceStore.loading;
    final err = store.error ?? deviceStore.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('维保'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm + AppSpace.xxs),
            child: FilledButton.icon(
              onPressed: () => _openMaintenanceEditor(),
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
              ],
              if (err != null) ...[
                Text(err, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
              ],

              // ① 顶部统计卡
              _buildSummaryCard(),
              const SizedBox(height: AppSpacing.sectionGap),

              const Divider(),
              const SizedBox(height: AppSpacing.sectionGap),

              // ② 列表标题
              Text(
                '最近记录（${store.records.length}）',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),

              // ③ 列表
              _buildList(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
