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
import '../../../data/models/account_payment.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';

// ------------------------------ UI / Utils ------------------------------
import '../../../core/utils/form_feedback.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/interaction_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/account/project_account_detail_content_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../patterns/account/account_overview_card_pattern.dart';
import '../../../patterns/account/account_project_list_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../components/fields/app_auto_suggest_field.dart';
import '../../../data/services/account_service.dart';

// ------------------------------ Stores ------------------------------
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_filter_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/timing/state/timing_store.dart';

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
    AppToast.show(context, msg);
  }

  Future<void> _retryLoad() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
    ]);
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

      final feedback = storeActionFeedback(store, action: '保存');
      _toast(feedback.message);
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
      _toast(noEditableDevicesMessage());
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

        final error = storeErrorMessage(rateStore, action: '保存');
        if (error != null) {
          _toast(error);
          return;
        }
      }

      _toast(storeActionFeedback(rateStore, action: '更新').message);
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
      _toast(missingEntityMessage('设备'));
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

      final feedback = storeActionFeedback(
        rateStore,
        action: '保存',
        successMessage: '已更新',
      );
      _toast(feedback.message);
    });
  }

  // =====================================================================
  // ============================== D) 收款：删除（二次确认） ==============================
  // =====================================================================
  Future<void> _deletePayment(AccountPayment p) async {
    if (p.id == null) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: '确认删除？',
      content:
          '日期：${FormatUtils.date(p.ymd)}\n金额：${FormatUtils.money(p.amount)}',
      confirmText: '删除',
    );

    if (ok != true) return;
    if (!mounted) return;

    final store = context.read<AccountPaymentStore>();
    await store.deleteById(p.id!);

    final feedback = storeActionFeedback(store, action: '删除');
    _toast(feedback.message);
    if (!feedback.isSuccess) {
      return;
    }
  }

  // =====================================================================
  // ============================== E) 项目筛选 BottomSheet ==============================
  // =====================================================================
  Future<void> _openProjectFilterSheet({
    required List<String> suggestions,
  }) async {
    final filterStore = context.read<AccountFilterStore>();

    final result = await showModalBottomSheet<_ProjectFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectFilterSheet(
        initialKeyword: filterStore.projectFilterKeyword,
        suggestions: suggestions,
      ),
    );

    if (!mounted || result == null) return;

    // 同样用 microtask：避免 sheet 退场 + notifyListeners 的竞态
    Future.microtask(() {
      if (!mounted) return;
      _applyProjectFilterResult(result);
    });
  }

  void _applyProjectFilterResult(_ProjectFilterResult result) {
    final filterStore = context.read<AccountFilterStore>();

    switch (result.type) {
      case _ProjectFilterResultType.clear:
        filterStore.clearProjectFilter();
        _toast(filterStatusMessage(cleared: true, hasActiveFilter: false));
        break;
      case _ProjectFilterResultType.ok:
        filterStore.setProjectFilterKeyword(result.keyword);
        _toast(
          filterStatusMessage(
            cleared: false,
            hasActiveFilter: filterStore.projectFilterKeyword.isNotEmpty,
          ),
        );
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
        final accountStore = sheetCtx.read<AccountStore>();

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
              padding: EdgeInsets.all(SpaceTokens.pagePadding),
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
          contentPadding: EdgeInsets.zero,
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
  // ============================== H) 页面 build ==============================
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    final filterStore = context.watch<AccountFilterStore>();

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

    final filteredProjects = filterStore.filterProjects(computed.projects);
    final projectSuggestions =
        timing
            .map((t) => t.contact.trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final loading =
        timingStore.loading ||
        deviceStore.loading ||
        paymentStore.loading ||
        rateStore.loading;
    final hasActiveFilter =
        filterStore.projectFilterKeyword.isNotEmpty &&
        filteredProjects.length < computed.projects.length;

    final err = firstStoreErrorMessage([
      timingStore,
      deviceStore,
      paymentStore,
      rateStore,
    ], action: '读取');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth >
                    AccountTokens.homeMaxContainerWidthTrigger
                ? AccountTokens.homeFixedContentWidth
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AccountTokens.homePageHorizontalPadding,
                    0,
                    AccountTokens.homePageHorizontalPadding,
                    0,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AccountTokens.homeTopGap),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (loading) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: 10),
                              ],
                              if (err != null) ...[
                                StoreErrorBanner(
                                  message: err,
                                  onRetry: loading ? null : () => _retryLoad(),
                                ),
                                const SizedBox(height: 10),
                              ],
                              AccountOverviewCard(
                                vm: AccountOverviewVm(
                                  totalReceivable: computed.totalReceivable,
                                  totalReceived: computed.totalReceived,
                                  totalRemaining: computed.totalRemaining,
                                  totalRatio: computed.totalRatio,
                                  deviceReceivables: computed.deviceReceivables,
                                ),
                              ),
                              const SizedBox(
                                height: AccountTokens.projectTitleTopGap,
                              ),
                              Row(
                                children: [
                                  Text(
                                    '项目(${filteredProjects.length})',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize:
                                          AccountTokens.projectTitleFontSize,
                                      fontWeight:
                                          AccountTokens.projectTitleWeight,
                                      height:
                                          AccountTokens.projectTitleLineHeight,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (hasActiveFilter)
                                    TextButton(
                                      onPressed: () =>
                                          _applyProjectFilterResult(
                                            const _ProjectFilterResult.clear(),
                                          ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.only(
                                          right: AccountTokens
                                              .projectFilterRightInset,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: AppColors.brand
                                            .withValues(alpha: 0.8),
                                      ),
                                      child: const Text(
                                        '取消筛选',
                                        style: TextStyle(
                                          fontSize: AccountTokens
                                              .projectFilterFontSize,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  if (!hasActiveFilter)
                                    TextButton(
                                      onPressed: () => _openProjectFilterSheet(
                                        suggestions: projectSuggestions,
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.only(
                                          right: AccountTokens
                                              .projectFilterRightInset,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: AppColors.brand
                                            .withValues(alpha: 0.8),
                                      ),
                                      child: const Text(
                                        '筛选',
                                        style: TextStyle(
                                          fontSize: AccountTokens
                                              .projectFilterFontSize,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(
                                height: AccountTokens.projectListTopGap,
                              ),
                              AccountProjectList(
                                projects: filteredProjects,
                                onTap: _openProjectDetail,
                              ),
                              const SizedBox(
                                height: AccountTokens.homeBottomGap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
  const _ProjectFilterSheet({
    required this.initialKeyword,
    required this.suggestions,
  });

  final String initialKeyword;
  final List<String> suggestions;

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
    List<String> buildSuggestions(String q) {
      final query = q.trim();
      if (query.isEmpty) return widget.suggestions;
      return widget.suggestions
          .where((s) => s.contains(query))
          .toList(growable: false);
    }

    return AppBottomSheetShell(
      title: '筛选项目',
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      onCancel: () => _close(const _ProjectFilterResult.cancel()),
      onConfirm: () => _close(_ProjectFilterResult.ok(_ctrl.text)),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 0),
            child: Column(
              children: [
                AutoSuggestField(
                  controller: _ctrl,
                  label: '关键词（联系人 / 工地）',
                  hint: '例如：王涛 / 修文 / 地铁站',
                  suggestionsBuilder: buildSuggestions,
                  onSelected: (v) => _ctrl.text = v,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _close(const _ProjectFilterResult.clear()),
                    child: const Text('清空'),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
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
      text: editing == null
          ? FormatUtils.todayDisplayDate()
          : FormatUtils.date(editing.ymd),
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
    AppToast.show(context, msg);
  }

  /// 计算：当前项目应收
  double get _receivable => widget.project.receivable;

  /// 计算：当前项目已实收（可排除正在编辑的那条）
  double _received({int? excludePaymentId}) {
    return AccountService.sumReceivedByProject(
      projectKey: widget.project.projectKey,
      payments: widget.allPayments,
      excludePaymentId: excludePaymentId,
    );
  }

  void _close(AccountPayment? r) {
    // 关闭前收起键盘/输入法，减少 route 退场期间的状态抖动
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                style: textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _dateCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: FormatUtils.ymdInputLabel,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金额（整数）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
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
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            // 1) 约束：编辑态必须属于当前项目（防止误调用）
            if (editing != null && editing.projectKey != project.projectKey) {
              _toastInDialog(formValidationMessage('编辑记录不属于当前项目'));
              return;
            }

            // 2) 日期校验
            final ymd = FormatUtils.parseDate(_dateCtrl.text);
            if (ymd == null) {
              _toastInDialog(formValidationMessage(FormatUtils.ymdInvalidMsg));
              return;
            }

            // 3) 金额校验
            final amtInt = int.tryParse(_amountCtrl.text.trim());
            if (amtInt == null || amtInt <= 0) {
              _toastInDialog(formValidationMessage('金额必须是 > 0 的整数'));
              return;
            }
            final amt = amtInt.toDouble();

            // 4) 超额校验：累计实收 <= 应收
            final receivedExcluding = _received(excludePaymentId: editing?.id);
            final after = receivedExcluding + amt;

            const eps = 0.05;
            if (after > _receivable + eps) {
              final remain = _receivable - receivedExcluding;
              _toastInDialog(
                formValidationMessage(
                  '超出剩余应收（剩余约 ${FormatUtils.money(remain)}）',
                ),
              );
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
    final textTheme = Theme.of(context).textTheme;
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
            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: const Text('取消'),
        ),
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
    final textTheme = Theme.of(context).textTheme;
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
            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: const Text('取消'),
        ),
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
