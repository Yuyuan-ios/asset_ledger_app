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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/controllers/account_action_controller.dart';
import '../domain/entities/account_entities.dart';
import '../domain/entities/project_settlement_result.dart';
import '../domain/services/external_work_receivable.dart';
import '../../../features/account/model/account_project_payment_display_vm.dart';
import '../../../features/account/model/account_view_model.dart';

// ------------------------------ UI / Utils ------------------------------
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/interaction_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../patterns/account/account_project_detail_sheet_pattern.dart';
import '../../../patterns/account/external_work_detail_sheet_pattern.dart';
import '../use_cases/project_share_export_use_case.dart';
import '../../../features/reports/use_cases/export_timing_worklog_excel_use_case.dart';
import 'dialogs/project_share_export_dialog.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';

// ------------------------------ Stores ------------------------------
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_filter_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/timing/state/timing_external_work_store.dart';
import '../../../features/timing/state/timing_store.dart';
import 'actions/account_rate_edit_actions.dart';
import 'account_page_view_data.dart';
import 'dialogs/account_payment_editor_dialog.dart';
import 'dialogs/account_dissolve_merge_confirm_dialog.dart';
import 'dialogs/account_project_merge_sheet.dart';
import 'dialogs/account_project_merge_sheet_data.dart';
import 'dialogs/account_project_filter_sheet.dart';
import 'dialogs/project_settlement_dialog.dart';
import 'widgets/account_page_content.dart';
import 'widgets/account_project_area_header.dart';

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

enum _AccountProjectAreaSection { projects, externalWork }

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  bool _isCompactProjectList = false;
  var _externalWorkLoadRequested = false;
  var _projectAreaSection = _AccountProjectAreaSection.projects;

  late final TabController _projectAreaTabController;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _projectAreaTabController = TabController(length: 2, vsync: this);
    _projectAreaTabController.addListener(_handleProjectAreaTabChanged);
  }

  @override
  void dispose() {
    _projectAreaTabController.removeListener(_handleProjectAreaTabChanged);
    _projectAreaTabController.dispose();
    super.dispose();
  }

  void _handleProjectAreaTabChanged() {
    final nextSection =
        _AccountProjectAreaSection.values[_projectAreaTabController.index];
    if (nextSection == _projectAreaSection) return;
    setState(() => _projectAreaSection = nextSection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_externalWorkLoadRequested) return;
    _externalWorkLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final externalWorkStore = context.read<TimingExternalWorkStore?>();
      if (externalWorkStore == null) return;
      unawaited(externalWorkStore.loadAll());
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
    final accountStore = context.read<AccountStore>();
    final externalWorkStore = context.read<TimingExternalWorkStore?>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
      if (externalWorkStore != null) externalWorkStore.loadAll(),
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
    final result = await showDialog<ProjectSettlementResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectSettlementDialog(
        project: project,
        onSave: (input) async {
          if (!mounted) throw StateError('页面已关闭');

          final latestProject = _latestProjectForSettlement(project);
          final controller = context.read<AccountActionController>();
          final timingStore = context.read<TimingStore>();
          final deviceStore = context.read<DeviceStore>();
          final paymentStore = context.read<AccountPaymentStore>();
          final rateStore = context.read<ProjectRateStore>();
          final accountStore = context.read<AccountStore>();
          final settlement = latestProject.kind == AccountProjectKind.merged
              ? await controller.settleMergedProject(
                  project: latestProject,
                  paymentAmount: input.paymentAmount,
                  writeOffAmount: input.writeOffAmount,
                  writeOffReason: input.writeOffReason,
                  ymd: input.ymd,
                  note: input.note,
                  timingStore: timingStore,
                  deviceStore: deviceStore,
                  paymentStore: paymentStore,
                  rateStore: rateStore,
                  accountStore: accountStore,
                )
              : await controller.settleProject(
                  project: latestProject,
                  paymentAmount: input.paymentAmount,
                  writeOffAmount: input.writeOffAmount,
                  writeOffReason: input.writeOffReason,
                  ymd: input.ymd,
                  note: input.note,
                  paymentStore: paymentStore,
                  accountStore: accountStore,
                );

          return settlement;
        },
      ),
    );

    if (!mounted || result == null) return;
    _toast(result.successMessage);
  }

  AccountProjectVM _latestProjectForSettlement(AccountProjectVM project) {
    if (project.kind == AccountProjectKind.merged) {
      return _latestProjectByProjectId(
        project.effectiveProjectId,
        includeMergeGroups: true,
      );
    }
    return _latestProjectByProjectId(project.effectiveProjectId);
  }

  AccountProjectVM _latestProjectByProjectId(
    String projectId, {
    bool includeMergeGroups = false,
  }) {
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
      activeMergeGroups: includeMergeGroups ? null : const [],
    );
    for (final item in computed.projects) {
      if (item.effectiveProjectId == normalizedProjectId) {
        return item;
      }
    }
    throw StateError(_l10n.accountProjectMissing);
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
        _toast(_l10n.accountMergedPaymentSaveSuccess);
      } catch (error) {
        if (!mounted) return;
        _toast(
          _l10n.accountSaveFailureWithReason(
            controller.friendlyMergedPaymentError(error),
          ),
        );
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
        _toast(_l10n.accountSaved);
      } catch (error) {
        if (!mounted) return;
        _toast(
          _l10n.accountSaveFailureWithReason(
            controller.friendlyMergedPaymentError(error),
          ),
        );
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
      title: _l10n.accountMergedPaymentDeleteTitle,
      content: _l10n.accountMergedPaymentDeleteContent(
        FormatUtils.date(paymentItem.ymd),
        FormatUtils.money(paymentItem.amount),
      ),
      cancelText: _l10n.accountCancelAction,
      confirmText: _l10n.accountDeleteAction,
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
      _toast(_l10n.accountDeleted);
    } catch (error) {
      if (!mounted) return;
      _toast(
        _l10n.accountDeleteFailureWithReason(
          controller.friendlyMergedPaymentError(error),
        ),
      );
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
    _toast(_l10n.accountDissolveMergeSuccess);
  }

  // =====================================================================
  // ============================== D) 收款：删除（二次确认） ==============================
  // =====================================================================
  Future<void> _deletePayment(AccountPayment p) async {
    if (p.id == null) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: _l10n.accountDeleteConfirmTitle,
      content: _l10n.accountPaymentDeleteConfirmContent(
        FormatUtils.date(p.ymd),
        FormatUtils.money(p.amount),
      ),
      cancelText: _l10n.accountCancelAction,
      confirmText: _l10n.accountDeleteAction,
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
      _toast(_l10n.accountWriteOffRevoked);
    } catch (error) {
      if (!mounted) return;
      _toast(
        _l10n.accountRevokeWriteOffFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
    }
  }

  Future<void> _revokeProjectWriteOff(AccountProjectVM project) async {
    if (project.kind == AccountProjectKind.merged) {
      await _revokeMergedProjectWriteOff(project);
      return;
    }

    final projectIds = {project.effectiveProjectId.trim()}
      ..removeWhere((id) => id.isEmpty);
    final accountStore = context.read<AccountStore>();
    final writeOffs = accountStore.writeOffs
        .where((item) {
          return projectIds.contains(item.projectId.trim());
        })
        .toList(growable: false);

    if (writeOffs.length > 1) {
      _toast(_l10n.accountWriteOffInvalid);
      return;
    }
    if (writeOffs.length == 1) {
      await _revokeWriteOff(writeOffs.single);
      return;
    }

    final isSettled = projectIds.any(accountStore.settledProjectIds.contains);
    if (!isSettled) {
      _toast(_l10n.accountWriteOffInvalid);
      return;
    }

    try {
      final latestProject = _latestProjectByProjectId(
        project.effectiveProjectId,
      );
      final controller = context.read<AccountActionController>();
      await controller.revokeSettlementStatus(
        project: latestProject,
        accountStore: accountStore,
      );

      if (!mounted) return;
      _toast(_l10n.accountSettlementRevoked);
    } catch (error) {
      if (!mounted) return;
      _toast(
        _l10n.accountRevokeSettlementFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
    }
  }

  Future<void> _revokeMergedProjectWriteOff(AccountProjectVM project) async {
    final latestProject = _latestProjectForSettlement(project);
    final projectIds =
        latestProject.memberProjectIds.map((id) => id.trim()).toSet()
          ..removeWhere((id) => id.isEmpty);
    if (projectIds.isEmpty) {
      _toast(_l10n.accountMergedMemberInvalid);
      return;
    }

    final accountStore = context.read<AccountStore>();
    final writeOffs = accountStore.writeOffs
        .where((item) => projectIds.contains(item.projectId.trim()))
        .toList(growable: false);
    final controller = context.read<AccountActionController>();

    try {
      if (writeOffs.isNotEmpty) {
        await controller.deleteMergedWriteOffs(
          project: latestProject,
          writeOffs: writeOffs,
          timingStore: context.read<TimingStore>(),
          deviceStore: context.read<DeviceStore>(),
          paymentStore: context.read<AccountPaymentStore>(),
          rateStore: context.read<ProjectRateStore>(),
          accountStore: accountStore,
        );
        if (!mounted) return;
        _toast(_l10n.accountWriteOffRevoked);
        return;
      }

      final isSettled = projectIds.any(accountStore.settledProjectIds.contains);
      if (!isSettled) {
        _toast(_l10n.accountWriteOffInvalid);
        return;
      }

      await controller.revokeMergedSettlementStatus(
        project: latestProject,
        timingStore: context.read<TimingStore>(),
        deviceStore: context.read<DeviceStore>(),
        paymentStore: context.read<AccountPaymentStore>(),
        rateStore: context.read<ProjectRateStore>(),
        accountStore: accountStore,
      );

      if (!mounted) return;
      _toast(_l10n.accountSettlementRevoked);
    } catch (error) {
      if (!mounted) return;
      _toast(
        _l10n.accountRevokeSettlementFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
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

  Future<void> _openMergeSheet() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    final externalWorkStore = context.read<TimingExternalWorkStore?>();
    final controller = context.read<AccountActionController>();

    final computed = accountStore.compute(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
    );

    // 当前仍有计时记录的项目（与卡片合并计数口径一致）。
    final timingProjectIds = <String>{
      for (final record in timingStore.records)
        record.effectiveProjectId.trim(),
    };
    // 账务/外协/结清痕迹集合：用于保留显示无计时但仍有痕迹的历史合并成员。
    final settledProjectIds = accountStore.settledProjectIds;
    final tracedProjectIds = <String>{
      for (final payment in paymentStore.records)
        payment.effectiveProjectId.trim(),
      for (final writeOff in accountStore.writeOffs) writeOff.projectId.trim(),
      ...settledProjectIds,
      if (externalWorkStore != null)
        for (final item in externalWorkStore.items)
          if (item.record.linkedProjectId?.trim().isNotEmpty ?? false)
            item.record.linkedProjectId!.trim(),
    };

    final groups = buildMergeSheetGroups(
      normalProjects: computed.projects,
      activeMergeGroups: accountStore.activeMergeGroups,
      excludedProjectIds: settledProjectIds,
      timingProjectIds: timingProjectIds,
      tracedProjectIds: tracedProjectIds,
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
    _toast(_l10n.accountMergeSuccess);
  }

  // =====================================================================
  // ============================== F) 项目详情 BottomSheet ==============================
  // =====================================================================
  //
  // 关键点：
  // - 这里用 sheetCtx.watch(...)：保证详情里“保存/删除/改单价”后自动刷新 UI
  // - “新增收款”由详情内容区触发，并限定在当前项目范围内
  //
  // =====================================================================
  // ============================== 外协详情弹窗 ==============================
  // =====================================================================
  void _openExternalWorkDetail(AccountExternalWorkProjectVM project) {
    openEditorSheet<void>(
      context: context,
      title: _l10n.accountExternalWorkDetailTitle,
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailContentInset,
      ),
      footerEnabled: false,
      onConfirm: () => Navigator.of(context).maybePop(),
      headerTrailingBuilder: (headerContext) => IconButton(
        tooltip: _l10n.accountCloseTooltip,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(headerContext).maybePop(),
      ),
      childBuilder: (sheetContext) => Consumer<TimingExternalWorkStore>(
        builder: (context, externalWorkStore, _) {
          // 用最新 store 重算 VM，使改价后弹窗即时刷新。
          final items = externalWorkStore.items;
          var vm = project;
          for (final candidate in buildAccountExternalWorkProjects(items)) {
            if (candidate.importBatchId == project.importBatchId) {
              vm = candidate;
              break;
            }
          }
          return ExternalWorkDetailSheet(
            project: vm,
            onEditCustomerRate: () => _openExternalCustomerRateEditor(vm),
          );
        },
      ),
    );
  }

  Future<void> _openExternalCustomerRateEditor(
    AccountExternalWorkProjectVM project,
  ) async {
    final externalWorkStore = context.read<TimingExternalWorkStore?>();
    if (externalWorkStore == null) return;
    final result = await showDialog<ExternalCustomerRateResult>(
      context: context,
      builder: (_) =>
          ExternalCustomerRateDialog(initialFen: project.customerUnitPriceFen),
    );
    if (result == null || !mounted) return;
    await externalWorkStore.setBatchCustomerUnitPriceFen(
      project.importBatchId,
      result.fen,
    );
    if (!mounted) return;
    final feedback = storeActionFeedback(externalWorkStore, action: '保存');
    if (!feedback.isSuccess) _toast(feedback.message);
  }

  void _openProjectDetail(AccountProjectVM project) {
    openEditorSheet<void>(
      context: context,
      title: _l10n.accountProjectDetailTitle,
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailContentInset,
      ),
      footerEnabled: false,
      onConfirm: () => Navigator.of(context).maybePop(),
      titleTrailingBuilder: (_) =>
          ProjectDetailShareButton(onPressed: () => _openProjectShare(project)),
      headerTrailingBuilder: (headerContext) => IconButton(
        tooltip: _l10n.accountCloseTooltip,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(headerContext).maybePop(),
      ),
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
                  final rawComputed = accountStore.compute(
                    timingRecords: timing,
                    devices: devices,
                    rates: rates,
                    payments: payments,
                  );
                  final externalWorkStore = context
                      .watch<TimingExternalWorkStore?>();
                  final externalRollup = rollupExternalWorkReceivable(
                    externalWorkStore?.items ?? const [],
                  );
                  final computed = augmentComputedWithExternalWork(
                    rawComputed,
                    externalRollup,
                  );

                  return AccountProjectDetailSheet(
                    projectId: project.effectiveProjectId,
                    projectKey: project.projectKey,
                    timingRecords: timing,
                    allDevices: devices,
                    allPayments: payments,
                    allWriteOffs: accountStore.writeOffs,
                    allRates: rates,
                    allExternalWorkItems: externalWorkStore?.items ?? const [],
                    computed: computed,
                    settledProjectIds: accountStore.settledProjectIds,
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

  Future<void> _exportProjectTimingWorklog(AccountProjectVM project) async {
    late final AccountProjectVM latestProject;
    try {
      latestProject = _latestProjectForSettlement(project);
    } catch (_) {
      _toast(_l10n.accountProjectMissing);
      return;
    }

    final scope = _timingWorklogExportScope(latestProject);
    final externalWorkItems =
        context.read<TimingExternalWorkStore?>()?.items ??
        const <TimingExternalWorkRecordItem>[];

    final outcome = await context
        .read<ExportTimingWorklogExcelUseCase>()
        .execute(
          scope: scope,
          records: context.read<TimingStore>().records,
          devices: context.read<DeviceStore>().allDevices,
          rates: context.read<ProjectRateStore>().rates,
          externalWorkItems: externalWorkItems,
        );
    if (!mounted) return;
    _toast(outcome.message);
  }

  TimingWorklogExportScope _timingWorklogExportScope(AccountProjectVM project) {
    return project.kind == AccountProjectKind.merged
        ? TimingWorklogExportScope.mergedProject(
            memberProjectIds: project.memberProjectIds,
            fileNamePart: project.displayName,
          )
        : TimingWorklogExportScope.singleProject(
            projectId: project.effectiveProjectId,
            fileNamePart: project.displayName,
          );
  }

  bool _hasProjectTimingWorklog(AccountProjectVM project) {
    final scope = _timingWorklogExportScope(project);
    final hasLocalRecords = context.read<TimingStore>().records.any(
      scope.includes,
    );
    if (hasLocalRecords) return true;

    final externalWorkItems =
        context.read<TimingExternalWorkStore?>()?.items ??
        const <TimingExternalWorkRecordItem>[];
    return externalWorkItems.any(scope.includesExternal);
  }

  // 项目详情右上角“分享项目”：输入分享人/包名 → 生成 .jzt 文件并调起系统分享面板。
  Future<void> _openProjectShare(AccountProjectVM project) async {
    final senderName = await showProjectShareNameDialog(context);
    if (senderName == null || !mounted) return;

    final outcome = await context.read<ProjectShareExportUseCase>().execute(
      projectId: project.effectiveProjectId,
      projectKey: project.projectKey,
      senderName: senderName,
      // 合并项目用合成 merge:groupId，匹配不到任何 TimingRecord；必须把成员
      // 项目真实 id 展开传入，导出端才能按成员集合聚合记录。普通项目为空。
      memberProjectIds: project.kind == AccountProjectKind.merged
          ? project.memberProjectIds
          : const [],
      allRecords: context.read<TimingStore>().records,
      allDevices: context.read<DeviceStore>().allDevices,
      allPayments: context.read<AccountPaymentStore>().records,
      // 项目对设备的覆盖单价（如设备默认 180、项目覆盖 200）需要带进去，
      // builder 才能把可信单价写入 rich record source_unit_price_fen。
      allRates: context.read<ProjectRateStore>().rates,
    );
    if (!mounted) return;
    _toast(outcome.message);
  }

  Widget _buildProjectAreaHeader(AccountPageViewData viewData) {
    final isExternalWork =
        _projectAreaSection == _AccountProjectAreaSection.externalWork;
    return AccountProjectAreaHeader(
      isExternalWork: isExternalWork,
      projectCount: isExternalWork
          ? viewData.filteredExternalWorkProjects.length
          : viewData.filteredProjects.length,
      externalWorkTitle: _l10n.accountExternalProjectsTitle,
      isCompactProjectList: _isCompactProjectList,
      hasActiveFilter: viewData.hasActiveFilter,
      onToggleCompactProjectList: () {
        setState(() {
          _isCompactProjectList = !_isCompactProjectList;
        });
      },
      onOpenMerge: _openMergeSheet,
      onOpenFilter: () =>
          _openProjectFilterSheet(suggestions: viewData.projectSuggestions),
      onClearFilter: () =>
          _applyProjectFilterResult(const AccountProjectFilterResult.clear()),
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
    final externalWorkStore = context.watch<TimingExternalWorkStore?>();
    final fuelStore = context.watch<FuelStore?>();
    final maintenanceStore = context.watch<MaintenanceStore?>();

    final viewData = buildAccountPageViewData(
      timingStore: timingStore,
      deviceStore: deviceStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
      filterStore: filterStore,
      externalWorkStore: externalWorkStore,
      fuelStore: fuelStore,
      maintenanceStore: maintenanceStore,
    );

    return AccountPageContent(
      viewData: viewData,
      isCompactProjectList: _isCompactProjectList,
      projectAreaTabController: _projectAreaTabController,
      onRetryLoad: _retryLoad,
      projectAreaHeaderBuilder: _buildProjectAreaHeader,
      onOpenProjectDetail: _openProjectDetail,
      onExportProjectTimingWorklog: _exportProjectTimingWorklog,
      canExportProjectTimingWorklog: _hasProjectTimingWorklog,
      onOpenExternalWorkDetail: _openExternalWorkDetail,
    );
  }
}
