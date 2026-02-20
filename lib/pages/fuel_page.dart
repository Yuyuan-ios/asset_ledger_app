// ==============================================================================
// 📁 文件说明：燃油页面 (fuel_page.dart)
//
// 目标改造：
// 1) 燃油页只负责“统计 + 效率 + 筛选 + 列表”整页展示（不承载表单）
// 2) 右上角提供「+ 新建」按钮，使用 AppBottomSheetShell 弹出底部弹窗
// 3) 新建/编辑表单下沉到 FuelDetailContent（与 Timing/Account 统一）
// ==============================================================================

// =====================================================================
// 一、导入依赖
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fuel_log.dart';

import '../presentation/utils/format_utils.dart';
import '../presentation/widgets/device_avatar.dart';
import '../presentation/widgets/record_list_tile.dart';
import '../presentation/widgets/auto_suggest_field.dart';

import '../presentation/sheets/app_bottom_sheet_shell.dart';
import '../presentation/content/fuel_detail_content.dart';

import '../store/device_store.dart';
import '../store/fuel_store.dart';
import '../store/timing_store.dart';

// =====================================================================
// 二、FuelPage
// =====================================================================

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

// =====================================================================
// 三、State：页面级交互（不承载表单）
// =====================================================================

class _FuelPageState extends State<FuelPage> {
  // -------------------------------------------------------------------
  // 3.1 筛选：供应人关键字（可空）
  // -------------------------------------------------------------------
  final _supplierFilterCtrl = TextEditingController();
  String _supplierFilter = '';

  // =====================================================================
  // 四、生命周期：兜底加载
  // =====================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 兜底加载（即使 MainPage 已 loadAll，也不影响功能）
      await context.read<DeviceStore>().loadAll();
      await context.read<TimingStore>().loadAll();
      await context.read<FuelStore>().loadAll();
    });
  }

  @override
  void dispose() {
    _supplierFilterCtrl.dispose();
    super.dispose();
  }

  // =====================================================================
  // 五、通用：toast
  // =====================================================================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // =====================================================================
  // 六、弹窗：新建/编辑
  // =====================================================================

  Future<void> _openFuelEditor({FuelLog? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AppBottomSheetShell(
          title: editing == null ? '新增燃油' : '编辑燃油',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              // ✅ 用 ctx 取 viewInsets，确保键盘弹起时 padding 跟随
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: FuelDetailContent(
              editing: editing,
              onCancel: () => Navigator.of(ctx).pop(),
              onToast: _toast,

              // ✅ 保存流程：Page 负责（与 Account / Timing 统一）
              onSubmit: (log) async {
                final store = context.read<FuelStore>();

                // FuelStore：insert/update 后会刷新 logs
                if (log.id == null) {
                  await store.insert(log);
                } else {
                  await store.update(log);
                }

                if (!mounted) return;

                if (store.error != null) {
                  _toast('保存失败：${store.error}');
                  return;
                }

                _toast('已保存');
                Navigator.of(ctx).pop(); // ✅ 保存成功后关闭弹窗
              },
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 七、删除：确认 + Store.deleteById
  // =====================================================================

  Future<void> _delete(FuelLog log) async {
    if (log.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('确认删除？'),
          content: const Text('删除后不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final store = context.read<FuelStore>();
    await store.deleteById(log.id!);

    if (!mounted) return;

    if (store.error != null) {
      _toast('删除失败：${store.error}');
    } else {
      _toast('已删除');
    }
  }

  // =====================================================================
  // 八、UI：本年度统计（随供应人筛选联动）
  // =====================================================================

  Widget _buildSupplierYearSummary() {
    final fuelStore = context.watch<FuelStore>();

    // ✅ nowYmd 由 Page 注入，方便测试
    final now = DateTime.now();
    final nowYmd = now.year * 10000 + now.month * 100 + now.day;

    final supplier = _supplierFilter.trim().isEmpty
        ? null
        : _supplierFilter.trim();

    final summary = fuelStore.currentYearSummary(
      nowYmd: nowYmd,
      supplier: supplier,
    );

    final title = (supplier == null) ? '本年度·总计' : '本年度·供应人：$supplier';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$title：${FormatUtils.liters(summary.liters)} L / ${FormatUtils.money(summary.cost)}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }

  // =====================================================================
  // 九、UI：效率汇总（All time）：按设备聚合
  // 口径（已确认）：
  // - 总工时仅统计 TimingType.hours
  // - rent 不参与效率
  // - 包油/包电通过 TimingRecord.excludeFromFuelEfficiency（你已加字段）
  //   ⚠️ 这里是否要排除，取决于 FuelStore.buildEfficiencyByDevice 是否已支持该字段
  // =====================================================================

  Widget _buildEfficiencySummary() {
    final fuelStore = context.watch<FuelStore>();
    final timingRecords = context.watch<TimingStore>().records;
    final deviceStore = context.watch<DeviceStore>();

    final byDev = fuelStore.efficiencyByDeviceAllTime(timingRecords);

    if (byDev.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('设备燃油效率：暂无数据（先录入燃油记录与工时记录）'),
      );
    }

    final ids = byDev.keys.toList()..sort();

    String fmtRate(double? v, {required String suffix}) {
      if (v == null) return '--';
      return '${FormatUtils.meter(v)} $suffix';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设备燃油效率',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...ids.map((id) {
            final agg = byDev[id]!;
            final device = deviceStore.findById(id);
            final name = device?.name ?? '设备$id（已停用/不存在）';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${fmtRate(agg.litersPerHour, suffix: 'L/h')}  '
                    '${fmtRate(agg.costPerHour, suffix: '¥/h')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =====================================================================
  // 十、列表：统计
  // =====================================================================

  ({double liters, double cost}) _sumOfLogs(List<FuelLog> logs) {
    double liters = 0.0;
    double cost = 0.0;
    for (final x in logs) {
      liters += x.liters;
      cost += x.cost;
    }
    return (liters: liters, cost: cost);
  }

  // =====================================================================
  // 十一、UI：列表区
  // =====================================================================

  Widget _buildListSection() {
    final store = context.watch<FuelStore>();
    final logs = store.logs;

    final filtered = _supplierFilter.isEmpty
        ? logs
        : logs.where((e) => e.supplier.contains(_supplierFilter)).toList();

    final sum = _sumOfLogs(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近记录（${filtered.length}）',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (filtered.isNotEmpty)
              Text(
                '总计：${FormatUtils.liters(sum.liters)} L / ${FormatUtils.money(sum.cost)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildListView(filtered),
      ],
    );
  }

  Widget _buildListView(List<FuelLog> filtered) {
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('暂无记录（点击右上角 + 新建）')),
      );
    }

    final deviceStore = context.read<DeviceStore>();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = filtered[index];
        final device = deviceStore.findById(log.deviceId);

        final title = '${log.supplier} · ${FormatUtils.date(log.date)}';
        final subtitle = device?.name ?? '设备${log.deviceId}（已停用/不存在）';

        return RecordListTile(
          dense: true,
          leading: device == null
              ? const CircleAvatar(radius: 18, child: Text('?'))
              : DeviceAvatar(device: device),
          title: title,
          subtitle: subtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${FormatUtils.liters(log.liters)} L',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    FormatUtils.money(log.cost),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: (log.id == null) ? null : () => _delete(log),
              ),
            ],
          ),
          onTap: () => _openFuelEditor(editing: log),
        );
      },
    );
  }

  // =====================================================================
  // 十二、build：整页（效率 + 本年度 + 筛选 + 列表）
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final fuelStore = context.watch<FuelStore>();
    final deviceStore = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();

    final loading =
        fuelStore.loading || deviceStore.loading || timingStore.loading;
    final err = fuelStore.error ?? deviceStore.error ?? timingStore.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('燃油'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: () => _openFuelEditor(),
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
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

              // ① 效率汇总
              _buildEfficiencySummary(),
              const SizedBox(height: 12),

              // ② 本年度汇总（随供应人筛选联动）
              _buildSupplierYearSummary(),
              const SizedBox(height: 12),

              const Divider(),
              const SizedBox(height: 12),

              // ③ 筛选：供应人
              Consumer<FuelStore>(
                builder: (context, store, _) {
                  return AutoSuggestField(
                    controller: _supplierFilterCtrl,
                    label: '筛选：供应人',
                    hint: '输入关键字即可过滤（可空）',
                    suggestionsBuilder: (q) => store.supplierSuggestions(q),
                    onChanged: (v) =>
                        setState(() => _supplierFilter = v.trim()),
                    onSelected: (v) {
                      _supplierFilterCtrl.text = v;
                      setState(() => _supplierFilter = v.trim());
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // ④ 列表
              _buildListSection(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
