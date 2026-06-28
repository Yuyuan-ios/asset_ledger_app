part of '../account_page.dart';

mixin _AccountPageProjectSheetActions
    on State<AccountPage>, _AccountPagePaymentDialogs {
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
    final feedback = storeActionFeedback(
      externalWorkStore,
      action: StoreActionKind.save,
    );
    if (!feedback.isSuccess) {
      _toast(localizeStoreActionFeedback(_l10n, feedback));
    }
  }

  void _openProjectDetail(AccountProjectVM project) {
    openEditorSheet<void>(
      context: context,
      title: _l10n.accountProjectDetailTitle,
      scrollable: true,
      footerEnabled: false,
      titleTrailingBuilder: (_) =>
          ProjectDetailShareButton(onPressed: () => _openProjectShare(project)),
      headerTrailingBuilder: (headerContext) => IconButton(
        tooltip: _l10n.accountCloseTooltip,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(headerContext).maybePop(),
      ),
      childBuilder: (sheetContext) {
        void showSheetToast(String message) {
          if (!sheetContext.mounted) return;
          AppToast.show(sheetContext, message);
        }

        return Consumer5<
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
                  onDeleteWriteOff: (writeOff) =>
                      _revokeWriteOff(writeOff, feedbackToast: showSheetToast),
                  onRevokeProjectWriteOff: (project) => _revokeProjectWriteOff(
                    project,
                    feedbackToast: showSheetToast,
                  ),
                  onSettleProject: _openProjectSettlement,
                  onDissolveMergeGroup: (project) =>
                      _confirmDissolveMergeGroup(project, sheetContext),
                  onAddMergedPayment: _openMergedPaymentEditor,
                  onEditMergedPaymentBatch: _openMergedPaymentBatchEditor,
                  onDeleteMergedPaymentBatch: _confirmDeleteMergedPaymentBatch,
                );
              },
        );
      },
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
}
