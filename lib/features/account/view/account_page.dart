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

import '../application/controllers/account_action_controller.dart';
import '../domain/entities/account_entities.dart';
import '../domain/entities/project_settlement_result.dart';
import '../../../features/account/model/account_project_payment_display_vm.dart';
import '../../../features/account/model/account_view_model.dart';

// ------------------------------ UI / Utils ------------------------------
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/interaction_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../components/layout/pinned_header_delegate.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../patterns/account/account_overview_card_pattern.dart';
import '../../../patterns/account/account_project_detail_sheet_pattern.dart';
import '../../../patterns/account/account_project_list_pattern.dart';
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
import 'actions/account_rate_edit_actions.dart';
import 'account_page_view_data.dart';
import 'dialogs/account_payment_editor_dialog.dart';
import 'dialogs/account_dissolve_merge_confirm_dialog.dart';
import 'dialogs/account_project_merge_sheet.dart';
import 'dialogs/account_project_merge_sheet_data.dart';
import 'dialogs/account_project_filter_sheet.dart';
import 'dialogs/project_settlement_dialog.dart';

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
  bool _isCompactProjectList = false;

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
    final accountStore = context.read<AccountStore>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
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

  Future<void> _openProjectSettlement(AccountProjectVM project) async {
    if (project.kind != AccountProjectKind.normal) {
      _toast('合并项目暂不支持直接结清');
      return;
    }

    final result = await showDialog<ProjectSettlementResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectSettlementDialog(
        project: project,
        onSave: (input) async {
          if (!mounted) throw StateError('页面已关闭');

          final latestProject = _latestProjectForSettlement(project);
          final settlement = await context
              .read<AccountActionController>()
              .settleProject(
                project: latestProject,
                paymentAmount: input.paymentAmount,
                writeOffAmount: input.writeOffAmount,
                writeOffReason: input.writeOffReason,
                ymd: input.ymd,
                note: input.note,
                paymentStore: context.read<AccountPaymentStore>(),
                accountStore: context.read<AccountStore>(),
              );

          return settlement;
        },
      ),
    );

    if (!mounted || result == null) return;
    _toast(result.successMessage);
  }

  AccountProjectVM _latestProjectForSettlement(AccountProjectVM project) {
    return _latestProjectByProjectId(project.effectiveProjectId);
  }

  AccountProjectVM _latestProjectByProjectId(String projectId) {
    final normalizedProjectId = projectId.trim();
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    final computed = accountStore.compute(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
      activeMergeGroups: const [],
    );
    for (final item in computed.projects) {
      if (item.effectiveProjectId == normalizedProjectId) {
        return item;
      }
    }
    throw StateError('项目不存在或已被清理');
  }

  Future<void> _openMergedPaymentEditor(AccountProjectVM project) async {
    final payment = await showDialog<AccountPayment>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountPaymentEditorDialog(
        project: project,
        allPayments: project.payments,
        receivedOverride: project.received,
      ),
    );

    if (!mounted || payment == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final timingStore = context.read<TimingStore>();
      final deviceStore = context.read<DeviceStore>();
      final paymentStore = context.read<AccountPaymentStore>();
      final rateStore = context.read<ProjectRateStore>();
      final accountStore = context.read<AccountStore>();
      final controller = context.read<AccountActionController>();

      try {
        await controller.createMergedPayment(
          project: project,
          payment: payment,
          timingStore: timingStore,
          deviceStore: deviceStore,
          paymentStore: paymentStore,
          rateStore: rateStore,
          accountStore: accountStore,
        );
        if (!mounted) return;
        _toast('保存成功');
      } catch (error) {
        if (!mounted) return;
        _toast('保存失败：${controller.friendlyMergedPaymentError(error)}');
      }
    });
  }

  Future<void> _openMergedPaymentBatchEditor(
    AccountProjectVM project,
    AccountProjectPaymentDisplayVM paymentItem,
  ) async {
    final batchId = paymentItem.mergeBatchId;
    if (batchId == null || batchId.trim().isEmpty) return;

    final receivedExcludingBatch = project.received - paymentItem.amount;
    final payment = await showDialog<AccountPayment>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountPaymentEditorDialog(
        project: project,
        allPayments: project.payments,
        editing: AccountPayment(
          projectId: project.effectiveProjectId,
          projectKey: project.projectKey,
          ymd: paymentItem.ymd,
          amount: paymentItem.amount,
          note: paymentItem.note,
        ),
        receivedOverride: receivedExcludingBatch < 0
            ? 0.0
            : receivedExcludingBatch,
      ),
    );

    if (!mounted || payment == null) return;

    Future.microtask(() async {
      if (!mounted) return;

      final timingStore = context.read<TimingStore>();
      final deviceStore = context.read<DeviceStore>();
      final paymentStore = context.read<AccountPaymentStore>();
      final rateStore = context.read<ProjectRateStore>();
      final accountStore = context.read<AccountStore>();
      final controller = context.read<AccountActionController>();

      try {
        await controller.updateMergedPaymentBatch(
          project: project,
          paymentItem: paymentItem,
          payment: payment,
          timingStore: timingStore,
          deviceStore: deviceStore,
          paymentStore: paymentStore,
          rateStore: rateStore,
          accountStore: accountStore,
        );
        if (!mounted) return;
        _toast('已保存');
      } catch (error) {
        if (!mounted) return;
        _toast('保存失败：${controller.friendlyMergedPaymentError(error)}');
      }
    });
  }

  Future<void> _confirmDeleteMergedPaymentBatch(
    AccountProjectVM _,
    AccountProjectPaymentDisplayVM paymentItem,
  ) async {
    final batchId = paymentItem.mergeBatchId;
    if (batchId == null || batchId.trim().isEmpty) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: '删除收款？',
      content:
          '将删除这笔合并收款及其分摊记录：\n'
          '${FormatUtils.date(paymentItem.ymd)}  ${FormatUtils.money(paymentItem.amount)}\n\n'
          '此操作不会删除计时记录。',
      confirmText: '删除',
    );

    if (!mounted || ok != true) return;

    final paymentStore = context.read<AccountPaymentStore>();
    final accountStore = context.read<AccountStore>();
    final controller = context.read<AccountActionController>();

    try {
      await controller.deleteMergedPaymentBatch(
        mergeBatchId: batchId,
        paymentStore: paymentStore,
        accountStore: accountStore,
      );
      if (!mounted) return;
      _toast('已删除');
    } catch (error) {
      if (!mounted) return;
      _toast('删除失败：${controller.friendlyMergedPaymentError(error)}');
    }
  }

  // =====================================================================
  // ============================== B) 单价弹窗：批量修改 ==============================
  // =====================================================================
  Future<void> _openBatchRateEditor(
    AccountProjectVM p,
    List<Device> devices,
    List<ProjectDeviceRate> rates,
  ) async {
    await AccountRateEditActions(
      context: context,
      isMounted: () => mounted,
      toast: _toast,
    ).openBatchRateEditor(p, devices, rates);
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
    await AccountRateEditActions(
      context: context,
      isMounted: () => mounted,
      toast: _toast,
    ).openSingleRateEditor(p, deviceId, isBreaking, devices, rates);
  }

  Future<void> _confirmDissolveMergeGroup(
    AccountProjectVM project,
    BuildContext sheetContext,
  ) async {
    final groupId = project.mergeGroupId;
    if (groupId == null) return;

    final sheetNavigator = Navigator.of(sheetContext);
    final controller = context.read<AccountActionController>();
    final accountStore = context.read<AccountStore>();

    final dissolved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DissolveMergeConfirmDialog(
        project: project,
        onError: _toast,
        onConfirm: () async {
          await controller.dissolveMergeGroup(
            groupId: groupId,
            accountStore: accountStore,
          );
        },
      ),
    );

    if (!mounted || dissolved != true) return;
    sheetNavigator.maybePop();
    _toast('已解除合并');
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

  Future<void> _revokeWriteOff(ProjectWriteOff writeOff) async {
    try {
      final latestProject = _latestProjectByProjectId(writeOff.projectId);
      final controller = context.read<AccountActionController>();
      await controller.deleteWriteOff(
        project: latestProject,
        writeOff: writeOff,
        accountStore: context.read<AccountStore>(),
      );

      if (!mounted) return;
      _toast('已撤销核销，待收已恢复');
    } catch (error) {
      if (!mounted) return;
      _toast(
        '撤销核销失败：${context.read<AccountActionController>().friendlyWriteOffError(error)}',
      );
    }
  }

  Future<void> _revokeProjectWriteOff(AccountProjectVM project) async {
    final projectIds = {
      project.effectiveProjectId.trim(),
      if (project.kind == AccountProjectKind.merged)
        ...project.memberProjectIds.map((id) => id.trim()),
    }..removeWhere((id) => id.isEmpty);
    final writeOffs = context
        .read<AccountStore>()
        .writeOffs
        .where((item) {
          return projectIds.contains(item.projectId.trim());
        })
        .toList(growable: false);

    if (writeOffs.length != 1) {
      _toast('该项目核销记录异常，请先检查核销记录。');
      return;
    }
    await _revokeWriteOff(writeOffs.single);
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

  Future<void> _openMergeSheet() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    final controller = context.read<AccountActionController>();

    final computed = accountStore.compute(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
    );
    final groups = buildMergeSheetGroups(
      normalProjects: computed.projects,
      activeMergeGroups: accountStore.activeMergeGroups,
      excludedProjectIds: accountStore.settledProjectIds,
    );

    final result = await showAccountProjectMergeSheet(
      context,
      groups: groups,
      onError: _toast,
      onConfirmMerge: (result) async {
        await controller.createMergeGroup(
          contact: result.contact,
          projectIds: result.projectIds,
          projectKeys: result.projectKeys,
          accountStore: accountStore,
        );
      },
    );

    if (!mounted || result == null) return;
    _toast('已合并');
  }

  // =====================================================================
  // ============================== F) 项目详情 BottomSheet ==============================
  // =====================================================================
  //
  // 关键点：
  // - 这里用 sheetCtx.watch(...)：保证详情里“保存/删除/改单价”后自动刷新 UI
  // - “新增收款”由详情内容区触发，并限定在当前项目范围内
  //
  void _openProjectDetail(AccountProjectVM project) {
    openEditorSheet<void>(
      context: context,
      title: '项目详情',
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailContentInset,
      ),
      footerEnabled: false,
      onConfirm: () => Navigator.of(context).maybePop(),
      childBuilder: (sheetContext) =>
          Consumer5<
            TimingStore,
            DeviceStore,
            AccountPaymentStore,
            ProjectRateStore,
            AccountStore
          >(
            builder:
                (
                  context,
                  timingStore,
                  deviceStore,
                  paymentStore,
                  rateStore,
                  accountStore,
                  _,
                ) {
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

                  return AccountProjectDetailSheet(
                    projectId: project.effectiveProjectId,
                    projectKey: project.projectKey,
                    timingRecords: timing,
                    allDevices: devices,
                    allPayments: payments,
                    allWriteOffs: accountStore.writeOffs,
                    allRates: rates,
                    computed: computed,
                    onBatchEditRate: _openBatchRateEditor,
                    onEditDeviceRate: _openSingleRateEditor,
                    onAddPayment: _openPaymentEditor,
                    onEditPayment: _openPaymentEditor,
                    onDeletePayment: _deletePayment,
                    onDeleteWriteOff: _revokeWriteOff,
                    onRevokeProjectWriteOff: _revokeProjectWriteOff,
                    onSettleProject: _openProjectSettlement,
                    onDissolveMergeGroup: (project) =>
                        _confirmDissolveMergeGroup(project, sheetContext),
                    onAddMergedPayment: _openMergedPaymentEditor,
                    onEditMergedPaymentBatch: _openMergedPaymentBatchEditor,
                    onDeleteMergedPaymentBatch:
                        _confirmDeleteMergedPaymentBatch,
                  );
                },
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
    final accountStore = context.watch<AccountStore>();
    final filterStore = context.watch<AccountFilterStore>();

    final viewData = buildAccountPageViewData(
      timingStore: timingStore,
      deviceStore: deviceStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
      filterStore: filterStore,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: AccountTokens.homePageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  const SizedBox(height: AccountTokens.homeTopGap),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        if (viewData.loading)
                          const SliverToBoxAdapter(
                            child: Column(
                              children: [
                                LinearProgressIndicator(),
                                SizedBox(height: 10),
                              ],
                            ),
                          ),
                        if (viewData.error != null)
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                StoreErrorBanner(
                                  message: viewData.error!,
                                  onRetry: viewData.loading
                                      ? null
                                      : () => _retryLoad(),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: AccountOverviewCard(
                            vm: AccountOverviewVm(
                              totalReceivable:
                                  viewData.computed.totalReceivable,
                              totalReceived: viewData.computed.totalReceived,
                              totalRemaining: viewData.computed.totalRemaining,
                              totalRatio: viewData.computed.totalRatio,
                              deviceReceivables:
                                  viewData.computed.deviceReceivables,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: AccountTokens.projectTitleTopGap,
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: AccountTokens.projectPinnedHeaderHeight,
                            child: AccountProjectPinnedHeader(
                              projectCount: viewData.filteredProjects.length,
                              isCompactProjectList: _isCompactProjectList,
                              onToggleCompactProjectList: () {
                                setState(() {
                                  _isCompactProjectList =
                                      !_isCompactProjectList;
                                });
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AccountProjectMergeButton(
                                    onPressed: _openMergeSheet,
                                  ),
                                  AccountProjectFilterButton(
                                    hasActiveFilter: viewData.hasActiveFilter,
                                    onOpenFilter: () => _openProjectFilterSheet(
                                      suggestions: viewData.projectSuggestions,
                                    ),
                                    onClearFilter: () => _applyProjectFilterResult(
                                      const AccountProjectFilterResult.clear(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AccountProjectList(
                            projects: viewData.filteredProjects,
                            isCompact: _isCompactProjectList,
                            onTap: _openProjectDetail,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AccountTokens.homeBottomGap),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
