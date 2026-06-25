part of '../account_page.dart';

typedef _AccountFeedbackToast = void Function(String message);

mixin _AccountPagePaymentDialogs on State<AccountPage> {
  AppLocalizations get _l10n;
  void _toast(String msg);

  void _toastTo(_AccountFeedbackToast? feedbackToast, String msg) {
    if (!mounted) return;
    final targetToast = feedbackToast ?? _toast;
    targetToast(msg);
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

      final feedback = storeActionFeedback(store, action: StoreActionKind.save);
      _toast(localizeStoreActionFeedback(_l10n, feedback));
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

    final feedback = storeActionFeedback(store, action: StoreActionKind.delete);
    _toast(localizeStoreActionFeedback(_l10n, feedback));
    if (!feedback.isSuccess) {
      return;
    }
  }

  Future<void> _revokeWriteOff(
    ProjectWriteOff writeOff, {
    _AccountFeedbackToast? feedbackToast,
  }) async {
    try {
      final latestProject = _latestProjectByProjectId(writeOff.projectId);
      final controller = context.read<AccountActionController>();
      await controller.deleteWriteOff(
        project: latestProject,
        writeOff: writeOff,
        accountStore: context.read<AccountStore>(),
      );

      if (!mounted) return;
      _toastTo(feedbackToast, _l10n.accountWriteOffRevoked);
    } catch (error) {
      if (!mounted) return;
      _toastTo(
        feedbackToast,
        _l10n.accountRevokeWriteOffFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
    }
  }

  Future<void> _revokeProjectWriteOff(
    AccountProjectVM project, {
    _AccountFeedbackToast? feedbackToast,
  }) async {
    if (project.kind == AccountProjectKind.merged) {
      await _revokeMergedProjectWriteOff(project, feedbackToast: feedbackToast);
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
      _toastTo(feedbackToast, _l10n.accountWriteOffInvalid);
      return;
    }
    if (writeOffs.length == 1) {
      await _revokeWriteOff(writeOffs.single, feedbackToast: feedbackToast);
      return;
    }

    final isSettled = projectIds.any(accountStore.settledProjectIds.contains);
    if (!isSettled) {
      _toastTo(feedbackToast, _l10n.accountWriteOffInvalid);
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
      _toastTo(feedbackToast, _l10n.accountSettlementRevoked);
    } catch (error) {
      if (!mounted) return;
      _toastTo(
        feedbackToast,
        _l10n.accountRevokeSettlementFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
    }
  }

  Future<void> _revokeMergedProjectWriteOff(
    AccountProjectVM project, {
    _AccountFeedbackToast? feedbackToast,
  }) async {
    final latestProject = _latestProjectForSettlement(project);
    final projectIds =
        latestProject.memberProjectIds.map((id) => id.trim()).toSet()
          ..removeWhere((id) => id.isEmpty);
    if (projectIds.isEmpty) {
      _toastTo(feedbackToast, _l10n.accountMergedMemberInvalid);
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
        _toastTo(feedbackToast, _l10n.accountWriteOffRevoked);
        return;
      }

      final isSettled = projectIds.any(accountStore.settledProjectIds.contains);
      if (!isSettled) {
        _toastTo(feedbackToast, _l10n.accountWriteOffInvalid);
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
      _toastTo(feedbackToast, _l10n.accountSettlementRevoked);
    } catch (error) {
      if (!mounted) return;
      _toastTo(
        feedbackToast,
        _l10n.accountRevokeSettlementFailure(
          context.read<AccountActionController>().friendlyWriteOffError(error),
        ),
      );
    }
  }
}
