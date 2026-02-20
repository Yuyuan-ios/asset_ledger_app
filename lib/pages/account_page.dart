// ==============================================================================
// 📁 文件：account_page.dart
// 账户管理页（工程化版本 / 三联弹窗收口版）
//
// 核心职责：
// 1) 聚合 Timing / Device / Rate / Payment 数据 -> 计算项目应收/实收/剩余。
// 2) 展示财务总览 + 项目列表。
// 3) 提供：项目筛选、单价编辑（批量/单台）、项目详情、收款记录 CRUD。
// 4) 所有数据写入通过 Provider/Store；UI 层仅负责 open + apply。
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ------------------------------ Models ------------------------------
import '../models/account_payment.dart';
import '../models/device.dart';
import '../models/project_device_rate.dart';

// ------------------------------ UI / Utils ------------------------------
import '../presentation/utils/format_utils.dart';
import '../presentation/sheets/app_bottom_sheet_shell.dart';
import '../presentation/content/project_account_detail_content.dart';

// ------------------------------ Stores ------------------------------
import '../store/account_payment_store.dart';
import '../store/account_store.dart';
import '../store/device_store.dart';
import '../store/project_rate_store.dart';
import '../store/timing_store.dart';

// =====================================================================
// ============================== 常量定义 ==============================
// =====================================================================

/// 账户页统一间距：用于控件间垂直/水平间距
const double kAccountGap = 12.0;

/// 账户页整体内边距：页面根布局的左右上下内边距
const EdgeInsets kAccountPadding = EdgeInsets.all(16);

// =====================================================================
// 重要：BottomSheet/Dialog 返回值类型必须放文件顶层（不能放进 State）
// =====================================================================

/// 项目筛选结果的类型
enum _ProjectFilterResultType { ok, clear, cancel }

/// 项目筛选弹窗返回值
class _ProjectFilterResult {
  final _ProjectFilterResultType type;
  final String keyword;

  const _ProjectFilterResult._(this.type, this.keyword);

  const _ProjectFilterResult.clear()
    : this._(_ProjectFilterResultType.clear, '');

  const _ProjectFilterResult.cancel()
    : this._(_ProjectFilterResultType.cancel, '');

  _ProjectFilterResult.ok(String k)
    : this._(_ProjectFilterResultType.ok, k.trim());
}

// =====================================================================
// ============================== 页面入口 ==============================
// =====================================================================

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

// =====================================================================
// ============================== State：只做 UI 与交互 ==============================
// =====================================================================

class _AccountPageState extends State<AccountPage> {
  // -------------------------------------------------------------------
  // 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // -------------------------------------------------------------------
  // 工具：百分比显示
  // -------------------------------------------------------------------
  String _pct1(double? r) {
    if (r == null) return '-';
    final p = (r * 100);
    return '${p.toStringAsFixed(1)}%';
  }

  // -------------------------------------------------------------------
  // UI：通用 KV 行（左标签/右值）
  // -------------------------------------------------------------------
  Widget _kv(String k, String v, {bool bold = false}) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
        Text(
          v,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // UI：总览卡片
  // -------------------------------------------------------------------
  Widget _buildOverview(AccountComputed c) {
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
            '总览',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _kv('总应收', FormatUtils.money(c.totalReceivable)),
          const SizedBox(height: 6),
          _kv('已实收', FormatUtils.money(c.totalReceived)),
          const SizedBox(height: 6),
          _kv('剩余应收', FormatUtils.money(c.totalRemaining), bold: true),
          const SizedBox(height: 6),
          _kv('回款率', _pct1(c.totalRatio)),
        ],
      ),
    );
  }

  // =====================================================================
  // ============================== A) 三联弹窗：收款（项目内模式） ==============================
  // =====================================================================
  //
  // 【UI职责】只 open + 收集结果（AccountPayment）
  // 【写入职责】交给 Store.save
  //
  Future<void> _openPaymentEditor({
    required AccountProjectVM project,
    required List<AccountPayment> allPayments,
    AccountPayment? editing,
  }) async {
    final payment = await showDialog<AccountPayment>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentEditorDialog(
        project: project,
        allPayments: allPayments,
        editing: editing,
      ),
    );

    if (!mounted || payment == null) return;

    // ✅ 事件循环切换：避开 route 退场敏感窗口（你之前遇到的 controller disposed/依赖断言同源）
    Future.microtask(() async {
      if (!mounted) return;

      final store = context.read<AccountPaymentStore>();
      await store.save(payment);

      if (!mounted) return;

      if (store.error != null) {
        _toast('保存失败：${store.error}');
      } else {
        _toast('已保存');
      }
    });
  }

  // =====================================================================
  // ============================== B) 单价弹窗：批量修改 ==============================
  // =====================================================================
  Future<void> _openBatchRateEditor(
    AccountProjectVM p,
    List<Device> devices,
  ) async {
    final usedDevices = devices
        .where((d) => d.id != null && p.deviceIds.contains(d.id!))
        .toList();

    if (usedDevices.isEmpty) {
      _toast('该项目暂无设备可修改');
      return;
    }

    final init = (p.minRate ?? usedDevices.first.defaultUnitPrice).round();

    final newRate = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RateBatchDialog(
        title: '批量修改单价：${p.displayName}',
        deviceCount: usedDevices.length,
        initialRateInt: init,
      ),
    );

    if (!mounted || newRate == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final rateStore = context.read<ProjectRateStore>();

      for (final d in usedDevices) {
        final id = d.id!;
        const eps = 0.05;

        // 如果新值≈设备默认值 -> 清理覆盖记录，减少冗余
        if ((newRate - d.defaultUnitPrice).abs() <= eps) {
          await rateStore.delete(p.projectKey, id);
        } else {
          await rateStore.upsert(
            ProjectDeviceRate(
              projectKey: p.projectKey,
              deviceId: id,
              rate: newRate,
            ),
          );
        }

        if (rateStore.error != null) {
          _toast('保存失败：${rateStore.error}');
          return;
        }
      }

      _toast('已更新');
    });
  }

  // =====================================================================
  // ============================== C) 单价弹窗：单台修改 ==============================
  // =====================================================================
  Future<void> _openSingleRateEditor(
    AccountProjectVM p,
    int deviceId,
    List<Device> devices,
    List<ProjectDeviceRate> rates,
  ) async {
    final hit = devices.where((e) => e.id == deviceId).toList();
    if (hit.isEmpty) {
      _toast('设备不存在');
      return;
    }
    final device = hit.first;

    // 当前项目覆盖单价（如果有）
    double? currentOverride;
    for (final r in rates) {
      if (r.projectKey == p.projectKey && r.deviceId == deviceId) {
        currentOverride = r.rate;
        break;
      }
    }

    final current = (currentOverride ?? device.defaultUnitPrice).round();

    final newRate = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RateSingleDialog(
        title: '编辑单价：${p.displayName}',
        deviceName: device.name,
        initialRateInt: current,
      ),
    );

    if (!mounted || newRate == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final rateStore = context.read<ProjectRateStore>();

      const eps = 0.05;
      if ((newRate - device.defaultUnitPrice).abs() <= eps) {
        await rateStore.delete(p.projectKey, deviceId);
      } else {
        await rateStore.upsert(
          ProjectDeviceRate(
            projectKey: p.projectKey,
            deviceId: deviceId,
            rate: newRate,
          ),
        );
      }

      if (rateStore.error != null) {
        _toast('保存失败：${rateStore.error}');
      } else {
        _toast('已更新');
      }
    });
  }

  // =====================================================================
  // ============================== D) 收款：删除（二次确认） ==============================
  // =====================================================================
  Future<void> _deletePayment(AccountPayment p) async {
    if (p.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除？'),
          content: Text(
            '日期：${FormatUtils.date(p.ymd)}\n金额：${FormatUtils.money(p.amount)}',
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

    final store = context.read<AccountPaymentStore>();
    await store.deleteById(p.id!);

    if (store.error != null) {
      _toast('删除失败：${store.error}');
      return;
    }

    _toast('已删除');
  }

  // =====================================================================
  // ============================== E) 项目筛选 BottomSheet ==============================
  // =====================================================================
  Future<void> _openProjectFilterSheet() async {
    final store = context.read<AccountStore>();

    final result = await showModalBottomSheet<_ProjectFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ProjectFilterSheet(initialKeyword: store.projectFilterKeyword),
    );

    if (!mounted || result == null) return;

    // 同样用 microtask：避免 sheet 退场 + notifyListeners 的竞态
    Future.microtask(() {
      if (!mounted) return;
      _applyProjectFilterResult(result);
    });
  }

  void _applyProjectFilterResult(_ProjectFilterResult result) {
    final store = context.read<AccountStore>();

    switch (result.type) {
      case _ProjectFilterResultType.clear:
        store.clearProjectFilter();
        _toast('已清空筛选');
        break;
      case _ProjectFilterResultType.ok:
        store.setProjectFilterKeyword(result.keyword);
        _toast(store.projectFilterKeyword.isEmpty ? '未筛选' : '已筛选');
        break;
      case _ProjectFilterResultType.cancel:
        // 取消：不修改 store
        break;
    }
  }

  // =====================================================================
  // ============================== F) 项目详情 BottomSheet ==============================
  // =====================================================================
  //
  // 关键点：
  // - 这里用 sheetCtx.watch(...)：保证详情里“保存/删除/改单价”后自动刷新 UI
  // - 同时把“新增收款”限定为项目内模式：传 pNow 给 _openPaymentEditor
  //
  void _openProjectDetail(AccountProjectVM p) {
    final projectKey = p.projectKey;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final timingStore = sheetCtx.watch<TimingStore>();
        final deviceStore = sheetCtx.watch<DeviceStore>();
        final paymentStore = sheetCtx.watch<AccountPaymentStore>();
        final rateStore = sheetCtx.watch<ProjectRateStore>();
        final accountStore = sheetCtx.watch<AccountStore>();

        final timing = timingStore.records;
        final devicesAll = deviceStore.allDevices;
        final paymentsAll = paymentStore.records;
        final ratesAll = rateStore.rates;

        final computed = accountStore.compute(
          timingRecords: timing,
          devices: devicesAll,
          rates: ratesAll,
          payments: paymentsAll,
        );

        final hit = computed.projects
            .where((e) => e.projectKey == projectKey)
            .toList();

        if (hit.isEmpty) {
          return const AppBottomSheetShell(
            title: '项目详情',
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('项目不存在或已被清理'),
            ),
          );
        }

        final pNow = hit.first;

        // 设备：只取项目涉及的设备
        final usedDevices = devicesAll
            .where((d) => d.id != null && pNow.deviceIds.contains(d.id!))
            .toList();

        // 项目覆盖单价：只取该项目
        final deviceRates = <int, double>{};
        for (final r in ratesAll) {
          if (r.projectKey != pNow.projectKey) continue;
          deviceRates[r.deviceId] = r.rate;
        }

        return AppBottomSheetShell(
          title: '项目详情',
          child: ProjectAccountDetailContent(
            title: pNow.displayName,
            minYmd: pNow.minYmd,
            devices: usedDevices,
            deviceRates: deviceRates,
            receivable: pNow.receivable,
            remaining: pNow.remaining,
            payments: pNow.payments,

            // 单价
            onBatchEditRate: () => _openBatchRateEditor(pNow, devicesAll),
            onEditDeviceRate: (deviceId) =>
                _openSingleRateEditor(pNow, deviceId, devicesAll, ratesAll),

            // 收款（项目内模式：不再让用户选项目）
            onAddPayment: () =>
                _openPaymentEditor(project: pNow, allPayments: paymentsAll),
            onEditPayment: (pay) => _openPaymentEditor(
              project: pNow,
              allPayments: paymentsAll,
              editing: pay,
            ),
            onDeletePayment: (pay) => _deletePayment(pay),
          ),
        );
      },
    );
  }

  // =====================================================================
  // ============================== G) 项目列表 UI ==============================
  // =====================================================================
  Widget _buildProjectList(AccountComputed c) {
    if (c.projects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('暂无项目（计时页有记录后将自动出现）')),
      );
    }

    String priceText(AccountProjectVM p) {
      final rate = p.minRate;
      if (rate == null) return '单价：—';
      return p.isMultiDevice
          ? '单价：${FormatUtils.money(rate)}（多设备）'
          : '单价：${FormatUtils.money(rate)}';
    }

    return Column(
      children: [
        for (final p in c.projects) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openProjectDetail(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          FormatUtils.date(p.minYmd),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      priceText(p),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_pct1(p.ratio)} 实收',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '余:${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: (p.ratio ?? 0).clamp(0, 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =====================================================================
  // ============================== H) 页面 build ==============================
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();

    final timing = timingStore.records;
    final devices = deviceStore.allDevices;
    final payments = paymentStore.records;
    final rates = rateStore.rates;

    final computed = accountStore.compute(
      timingRecords: timing,
      devices: devices,
      rates: rates,
      payments: payments,
    );

    final filteredProjects = accountStore.filterProjects(computed.projects);

    final loading =
        timingStore.loading ||
        deviceStore.loading ||
        paymentStore.loading ||
        rateStore.loading;

    final err =
        timingStore.error ??
        deviceStore.error ??
        paymentStore.error ??
        rateStore.error;

    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: SingleChildScrollView(
        child: Padding(
          padding: kAccountPadding,
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
              _buildOverview(computed),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '项目（${filteredProjects.length}）',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openProjectFilterSheet,
                    child: Text(
                      accountStore.projectFilterKeyword.isEmpty ? '筛选' : '已筛选',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildProjectList(
                AccountComputed(
                  projects: filteredProjects,
                  totalReceivable: computed.totalReceivable,
                  totalReceived: computed.totalReceived,
                  totalRemaining: computed.totalRemaining,
                  totalRatio: computed.totalRatio,
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ============================== I) 项目筛选 Sheet（controller 归属组件） ==============================
// =====================================================================
//
// 关键：controller 在 State 内创建/释放，不要在 open 方法里 new+dispose
//
class _ProjectFilterSheet extends StatefulWidget {
  const _ProjectFilterSheet({required this.initialKeyword});

  final String initialKeyword;

  @override
  State<_ProjectFilterSheet> createState() => _ProjectFilterSheetState();
}

class _ProjectFilterSheetState extends State<_ProjectFilterSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close(_ProjectFilterResult r) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: '筛选项目',
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: '关键词（联系人 / 工地）',
                hintText: '例如：王涛 / 修文 / 地铁站',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => _close(const _ProjectFilterResult.clear()),
                  child: const Text('清空'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _close(const _ProjectFilterResult.cancel()),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _close(_ProjectFilterResult.ok(_ctrl.text)),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ============================== J) 收款弹窗（项目内模式：无项目选择） ==============================
// =====================================================================
//
// 本弹窗只用于【某个项目详情】里新增/编辑收款。
// - 项目固定：project.projectKey
// - UI 不展示项目输入框，避免误选/多项目歧义
// - 校验：不允许“累计实收 > 应收”
//
class _PaymentEditorDialog extends StatefulWidget {
  const _PaymentEditorDialog({
    required this.project,
    required this.allPayments,
    this.editing,
  });

  /// 当前项目（由项目详情页传入）
  final AccountProjectVM project;

  /// 全部收款记录（用于计算“已实收”并做超额校验）
  final List<AccountPayment> allPayments;

  /// 编辑态（null 表示新增）
  final AccountPayment? editing;

  @override
  State<_PaymentEditorDialog> createState() => _PaymentEditorDialogState();
}

class _PaymentEditorDialogState extends State<_PaymentEditorDialog> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;

    // 日期：新增默认今天；编辑回显原值
    _dateCtrl = TextEditingController(
      text: editing == null ? FormatUtils.todayYmd() : editing.ymd.toString(),
    );

    // 金额：编辑回显整数；新增空
    _amountCtrl = TextEditingController(
      text: editing == null ? '' : editing.amount.round().toString(),
    );

    // 备注：编辑回显；新增空
    _noteCtrl = TextEditingController(text: editing?.note ?? '');
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _toastInDialog(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 计算：当前项目应收
  double get _receivable => widget.project.receivable;

  /// 计算：当前项目已实收（可排除正在编辑的那条）
  double _received({int? excludePaymentId}) {
    double sum = 0.0;
    for (final p in widget.allPayments) {
      if (p.projectKey != widget.project.projectKey) continue;
      if (excludePaymentId != null && p.id == excludePaymentId) continue;
      sum += p.amount;
    }
    return sum;
  }

  void _close(AccountPayment? r) {
    // 关闭前收起键盘/输入法，减少 route 退场期间的状态抖动
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final editing = widget.editing;

    return AlertDialog(
      title: Text(editing == null ? '新增收款' : '编辑收款'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ 项目固定：只展示，不可编辑
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '项目：${project.displayName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _dateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '日期（YYYYMMDD）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金额（整数）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注（可填）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '应收：${FormatUtils.money(_receivable)}'
                '，已收：${FormatUtils.money(_received(excludePaymentId: editing?.id))}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            // 1) 约束：编辑态必须属于当前项目（防止误调用）
            if (editing != null && editing.projectKey != project.projectKey) {
              _toastInDialog('保存失败：编辑记录不属于当前项目');
              return;
            }

            // 2) 日期校验
            final ymd = FormatUtils.parseDate(_dateCtrl.text);
            if (ymd == null) {
              _toastInDialog('保存失败：日期格式应为 YYYYMMDD');
              return;
            }

            // 3) 金额校验
            final amtInt = int.tryParse(_amountCtrl.text.trim());
            if (amtInt == null || amtInt <= 0) {
              _toastInDialog('保存失败：金额必须是 > 0 的整数');
              return;
            }
            final amt = amtInt.toDouble();

            // 4) 超额校验：累计实收 <= 应收
            final receivedExcluding = _received(excludePaymentId: editing?.id);
            final after = receivedExcluding + amt;

            const eps = 0.05;
            if (after > _receivable + eps) {
              final remain = _receivable - receivedExcluding;
              _toastInDialog('保存失败：超出剩余应收（剩余约 ${FormatUtils.money(remain)}）');
              return;
            }

            // 5) 构建 Payment（项目固定，不可更改）
            final pay = AccountPayment(
              id: editing?.id,
              projectKey: project.projectKey,
              ymd: ymd,
              amount: amt,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            );

            _close(pay);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// =====================================================================
// ============================== K) 批量单价弹窗（controller 归属组件） ==============================
// =====================================================================

class _RateBatchDialog extends StatefulWidget {
  const _RateBatchDialog({
    required this.title,
    required this.deviceCount,
    required this.initialRateInt,
  });

  final String title;
  final int deviceCount;
  final int initialRateInt;

  @override
  State<_RateBatchDialog> createState() => _RateBatchDialogState();
}

class _RateBatchDialogState extends State<_RateBatchDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialRateInt.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close(double? r) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设备数：${widget.deviceCount} 台'),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '统一单价（整数）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '保存后：该项目下所有设备单价将统一为此值（仅影响本项目）。\n'
            '若等于设备默认单价，将自动清理覆盖记录（减少冗余）。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final vInt = int.tryParse(_ctrl.text.trim());
            if (vInt == null || vInt <= 0) return;
            _close(vInt.toDouble());
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// =====================================================================
// ============================== L) 单台单价弹窗（controller 归属组件） ==============================
// =====================================================================

class _RateSingleDialog extends StatefulWidget {
  const _RateSingleDialog({
    required this.title,
    required this.deviceName,
    required this.initialRateInt,
  });

  final String title;
  final String deviceName;
  final int initialRateInt;

  @override
  State<_RateSingleDialog> createState() => _RateSingleDialogState();
}

class _RateSingleDialogState extends State<_RateSingleDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialRateInt.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close(double? r) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '单价',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '提示：若把单价改回设备默认单价，将自动清理覆盖记录（减少冗余）。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final vInt = int.tryParse(_ctrl.text.trim());
            if (vInt == null || vInt <= 0) return;
            _close(vInt.toDouble());
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
