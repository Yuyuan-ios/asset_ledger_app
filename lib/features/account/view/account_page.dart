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
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/interaction_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../patterns/account/account_overview_card_pattern.dart';
import '../../../patterns/account/account_project_detail_sheet_pattern.dart';
import '../../../patterns/account/account_project_section_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/feedback/store_error_banner.dart';

// ------------------------------ Stores ------------------------------
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_filter_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/timing/state/timing_store.dart';
import 'dialogs/account_payment_editor_dialog.dart';
import 'dialogs/account_project_filter_sheet.dart';
import 'dialogs/account_rate_dialogs.dart';

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
  @override
  void initState() {
    super.initState();
    // 账户页依赖 payment/rate 两个 store，应用启动阶段未预加载，
    // 在这里主动拉取，避免重启后短暂回落到默认单价。
    Future.microtask(() async {
      if (!mounted) return;
      final paymentStore = context.read<AccountPaymentStore>();
      final rateStore = context.read<ProjectRateStore>();
      await Future.wait([paymentStore.loadAll(), rateStore.loadAll()]);
    });
  }

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
      builder: (_) => AccountPaymentEditorDialog(
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
    List<ProjectDeviceRate> rates,
  ) async {
    final usedDevices = devices
        .where((d) => d.id != null && p.deviceIds.contains(d.id!))
        .toList();

    if (usedDevices.isEmpty) {
      _toast(noEditableDevicesMessage());
      return;
    }

    final first = usedDevices.first;
    final firstId = first.id!;
    double? initDiggingOverride;
    double? initBreakingOverride;
    for (final r in rates) {
      if (r.projectKey != p.projectKey || r.deviceId != firstId) continue;
      if (r.isBreaking) {
        initBreakingOverride = r.rate;
      } else {
        initDiggingOverride = r.rate;
      }
    }
    final initDigging = (initDiggingOverride ?? first.defaultUnitPrice).round();
    final initBreaking =
        (initBreakingOverride ??
                first.breakingUnitPrice ??
                first.defaultUnitPrice)
            .round();

    final newRate = await showDialog<AccountBatchRateUpdate>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateBatchDialog(
        title: '批量修改单价：${p.displayName}',
        deviceCount: usedDevices.length,
        initialDiggingRateInt: initDigging,
        initialBreakingRateInt: initBreaking,
      ),
    );

    if (!mounted || newRate == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final rateStore = context.read<ProjectRateStore>();

      for (final d in usedDevices) {
        final id = d.id!;
        const eps = 0.05;
        final defaultDigging = d.defaultUnitPrice;
        final defaultBreaking = d.breakingUnitPrice ?? d.defaultUnitPrice;

        if ((newRate.diggingRate - defaultDigging).abs() <= eps) {
          await rateStore.delete(p.projectKey, id, isBreaking: false);
        } else {
          await rateStore.upsert(
            ProjectDeviceRate(
              projectKey: p.projectKey,
              deviceId: id,
              isBreaking: false,
              rate: newRate.diggingRate,
            ),
          );
        }

        if ((newRate.breakingRate - defaultBreaking).abs() <= eps) {
          await rateStore.delete(p.projectKey, id, isBreaking: true);
        } else {
          await rateStore.upsert(
            ProjectDeviceRate(
              projectKey: p.projectKey,
              deviceId: id,
              isBreaking: true,
              rate: newRate.breakingRate,
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
    bool isBreaking,
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
      if (r.projectKey == p.projectKey &&
          r.deviceId == deviceId &&
          r.isBreaking == isBreaking) {
        currentOverride = r.rate;
        break;
      }
    }

    final modeDefaultRate = isBreaking
        ? (device.breakingUnitPrice ?? device.defaultUnitPrice)
        : device.defaultUnitPrice;
    final current = (currentOverride ?? modeDefaultRate).round();

    final newRate = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateSingleDialog(
        title: isBreaking ? '编辑破碎单价：${p.displayName}' : '编辑单价：${p.displayName}',
        deviceName: isBreaking ? '${device.name} · 破碎' : device.name,
        initialRateInt: current,
      ),
    );

    if (!mounted || newRate == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final rateStore = context.read<ProjectRateStore>();

      const eps = 0.05;
      if ((newRate - modeDefaultRate).abs() <= eps) {
        await rateStore.delete(p.projectKey, deviceId, isBreaking: isBreaking);
      } else {
        await rateStore.upsert(
          ProjectDeviceRate(
            projectKey: p.projectKey,
            deviceId: deviceId,
            isBreaking: isBreaking,
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

    final result = await showAccountProjectFilterSheet(
      context,
      initialKeyword: filterStore.projectFilterKeyword,
      suggestions: suggestions,
    );

    if (!mounted || result == null) return;

    // 同样用 microtask：避免 sheet 退场 + notifyListeners 的竞态
    Future.microtask(() {
      if (!mounted) return;
      _applyProjectFilterResult(result);
    });
  }

  void _applyProjectFilterResult(AccountProjectFilterResult result) {
    final filterStore = context.read<AccountFilterStore>();

    switch (result.type) {
      case AccountProjectFilterResultType.clear:
        filterStore.clearProjectFilter();
        _toast(filterStatusMessage(cleared: true, hasActiveFilter: false));
        break;
      case AccountProjectFilterResultType.ok:
        filterStore.setProjectFilterKeyword(result.keyword);
        _toast(
          filterStatusMessage(
            cleared: false,
            hasActiveFilter: filterStore.projectFilterKeyword.isNotEmpty,
          ),
        );
        break;
      case AccountProjectFilterResultType.cancel:
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
    openEditorSheet<void>(
      context: context,
      title: '项目详情',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailContentInset,
      ),
      childBuilder: (_) => AccountProjectDetailSheet(
        projectKey: p.projectKey,
        onBatchEditRate: _openBatchRateEditor,
        onEditDeviceRate: _openSingleRateEditor,
        onAddPayment: _openPaymentEditor,
        onEditPayment: _openPaymentEditor,
        onDeletePayment: _deletePayment,
      ),
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
                              AccountProjectSection(
                                projects: filteredProjects,
                                hasActiveFilter: hasActiveFilter,
                                onOpenFilter: () => _openProjectFilterSheet(
                                  suggestions: projectSuggestions,
                                ),
                                onClearFilter: () => _applyProjectFilterResult(
                                  const AccountProjectFilterResult.clear(),
                                ),
                                onTapProject: _openProjectDetail,
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
