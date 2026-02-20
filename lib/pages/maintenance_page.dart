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

import '../models/maintenance_record.dart';

import '../presentation/utils/format_utils.dart';
import '../presentation/widgets/device_avatar.dart';
import '../presentation/widgets/record_list_tile.dart';

import '../presentation/sheets/app_bottom_sheet_shell.dart';
import '../presentation/content/maintenance_detail_content.dart';

import '../store/device_store.dart';
import '../store/maintenance_store.dart';

// =====================================================================
// ============================== 二、UI 常量 ==============================
// =====================================================================

const EdgeInsets kPagePadding = EdgeInsets.all(16);
const double kSectionGap = 12.0;
const double kCardRadius = 12.0;

// =====================================================================
// ============================== 三、页面入口 ==============================
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
  // =====================================================================
  // ============================== 五、生命周期：兜底加载 ==============================
  // =====================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 兜底加载（即使 MainPage 已 loadAll，也不影响功能）
      await context.read<DeviceStore>().loadAll();
      await context.read<MaintenanceStore>().loadAll();
    });
  }

  // =====================================================================
  // ============================== 六、通用 toast ==============================
  // =====================================================================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // =====================================================================
  // ============================== 七、BottomSheet：新建/编辑 ==============================
  // =====================================================================

  Future<void> _openMaintenanceEditor({MaintenanceRecord? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AppBottomSheetShell(
          title: editing == null ? '新建维保' : '编辑维保',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: MaintenanceDetailContent(
              editing: editing,

              // 取消：Page 负责 pop
              onCancel: () => Navigator.of(context).pop(),

              // toast：统一走 Page
              onToast: _toast,

              // ✅ 保存：Page 负责落库 + toast + pop（与 Account/Fuel/Timing 统一）
              onSubmit: (record) async {
                final store = context.read<MaintenanceStore>();
                await store.save(record);

                if (!mounted) return;

                if (store.error != null) {
                  _toast('保存失败：${store.error}');
                  return;
                }

                _toast('已保存');
                Navigator.of(context).pop();
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

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除？'),
          content: Text(
            '日期：${FormatUtils.date(r.ymd)}\n'
            '事项：${r.item}\n'
            '金额：${FormatUtils.money(r.amount)}\n\n'
            '⚠️ 删除后不可恢复',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final store = context.read<MaintenanceStore>();
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
    final now = DateTime.now();
    final nowYmd = now.year * 10000 + now.month * 100 + now.day;

    // 约定：map key = deviceId(int) 或 null(公共)
    final map = store.currentYearSummary(nowYmd: nowYmd);

    if (map.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(kCardRadius),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(kCardRadius),
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
              padding: const EdgeInsets.only(bottom: 8),
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
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('暂无记录（点击右上角 + 新建）')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
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
            leading = DeviceAvatar(device: device, radius: 18);
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
            padding: const EdgeInsets.only(right: 10),
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
          padding: kPagePadding,
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
              const SizedBox(height: kSectionGap),

              const Divider(),
              const SizedBox(height: kSectionGap),

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
