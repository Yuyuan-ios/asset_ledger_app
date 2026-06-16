// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fleet Ledger';

  @override
  String get tabTiming => '计时';

  @override
  String get tabEnergy => '油电';

  @override
  String get tabAccount => '账户';

  @override
  String get tabMaintenance => '维保';

  @override
  String get tabDevice => '设备';

  @override
  String get timingCalculatorExpressionPlaceholder => '工时计算式';

  @override
  String get timingCalculatorNoResult => '未计算';

  @override
  String timingCalculatorResult(String value) {
    return '结果 $value h';
  }

  @override
  String get timingCalculatorApplyButton => '填入';

  @override
  String get timingCalculationHistoryEmpty => '暂无计算记录';

  @override
  String timingCalculationHistoryMeta(String date, int count) {
    return '$date | 票据 $count 张';
  }

  @override
  String get timingCalculationAppliedBadge => '已填入工时';

  @override
  String get timingAttachmentDigging => '挖斗';

  @override
  String get timingAttachmentBreaking => '破碎';

  @override
  String get timingRecentRecordsTitle => '最近记录';

  @override
  String get timingExternalWorkProjectsTitle => '外协项目';

  @override
  String get timingAllDevicesFilter => '全部设备';

  @override
  String get timingExternalWorkImportAction => '导入';

  @override
  String get timingExternalWorkLinkAction => '关联';

  @override
  String timingRecentRecordCount(int count) {
    return '$count条记录';
  }

  @override
  String timingRecentAggregateSummary(String error, String total) {
    return '误差 $error，累计 $total';
  }

  @override
  String get timingRecentAggregateExpanded => '已展开';

  @override
  String get timingRecentAggregateCollapsed => '已聚合';

  @override
  String get timingRecentBreakingBadge => '破碎';

  @override
  String get timingExternalWorkLinkSheetTitle => '关联到项目';

  @override
  String get timingExternalWorkSelectPackage => '选择外协包';

  @override
  String get timingExternalWorkPackageSummary => '外协包摘要';

  @override
  String get timingExternalWorkCancelAction => '取消';

  @override
  String get timingExternalWorkUnlinkAction => '解除关联';

  @override
  String get timingExternalWorkConfirmLinkAction => '确认关联';

  @override
  String timingExternalWorkLinkedProject(String title) {
    return '已关联：$title';
  }

  @override
  String get timingExternalWorkSelectProject => '选择要关联的项目';

  @override
  String get timingExternalWorkNoLinkableProjects => '暂无可关联的自有项目';

  @override
  String timingExternalWorkSettledCandidateTitle(String title) {
    return '$title（已结清）';
  }

  @override
  String get timingExternalWorkSettledHint =>
      '该项目已结清。关联外协包后将撤销结清状态，并按新的项目总应收重新计算待收。';

  @override
  String get timingExternalWorkSettledConfirmTitle => '关联到已结清项目';

  @override
  String get timingExternalWorkSettledConfirmContent =>
      '该项目已结清。关联外协包后将撤销结清状态，并按新的项目总应收重新计算待收。是否继续？';

  @override
  String get timingExternalWorkContinueAction => '继续';

  @override
  String get timingExternalWorkDefaultLinkedProjectTitle => '已关联项目';

  @override
  String timingExternalWorkPackageRecordCount(int count) {
    return '$count条记录';
  }

  @override
  String get timingExternalWorkSiteSummarySeparator => '、';

  @override
  String get timingExternalWorkLinkSuccess => '已关联到项目';

  @override
  String get timingExternalWorkLinkSettledSuccess => '已关联到项目，原结清已撤销';

  @override
  String get timingExternalWorkLinkFailure => '关联失败，请重试';

  @override
  String get timingExternalWorkUnlinkConfirmTitle => '解除关联';

  @override
  String get timingExternalWorkUnlinkConfirmContent =>
      '解除关联后，该外协包将作为独立的外协的项目保留，不会删除外协记录。是否继续？';

  @override
  String get timingExternalWorkUnlinkSuccess => '已解除关联，外协记录已保留';

  @override
  String get timingExternalWorkUnlinkFailure => '解除关联失败，请重试';

  @override
  String get timingEntryCreateSheetTitle => '新建计时';

  @override
  String get timingEntryEditSheetTitle => '编辑计时';

  @override
  String get timingEntryCancelAction => '取消';

  @override
  String get timingEntryDeleteRecordAction => '删除本记录';

  @override
  String get timingEntryHistoryLoadFailure => '工时计算历史加载失败，仍可继续编辑';

  @override
  String get timingEntrySaveFailure => '保存失败，请重试';

  @override
  String get timingEntryDeletePrecheckFailure => '删除前检查失败，请重试';

  @override
  String get timingEntryDeleteConfirmTitle => '删除计时记录';

  @override
  String get timingEntryDeleteConfirmAction => '删除';

  @override
  String get timingEntryDeleteFailure => '删除失败，请重试';

  @override
  String get timingEntryDeleteBlockedTitle => '无法删除';

  @override
  String get timingEntryDeleteBlockedConfirm => '知道了';

  @override
  String get timingEntryDeleteSettledConfirmContent =>
      '该项目已结清。删除计时记录后将撤销结清状态，并按新的项目金额重新计算待收。是否继续？';

  @override
  String get timingEntryDeleteLastRecordConfirmContent =>
      '删除后，该项目将不再有本地计时记录，并会同步解除相关合并/外协关联。是否继续？';

  @override
  String get timingEntryDeleteDefaultConfirmContent => '删除后不可恢复，确认删除这条记录吗？';

  @override
  String get timingEntryDeleted => '已删除';

  @override
  String get timingEntrySettlementRevoked => '已撤销结清';

  @override
  String get timingEntryMergeDissolved => '已解除合并';

  @override
  String get timingEntryMergeMemberRemoved => '已移出合并';

  @override
  String get timingEntryExternalWorkUnlinked => '已解除外协关联';

  @override
  String get timingEntryDeleteCascadeSeparator => '、';

  @override
  String timingEntryDeleteCascadeSuccess(String details) {
    return '已删除，$details';
  }

  @override
  String get timingEntryDeviceLabel => '设备编号';

  @override
  String get timingEntryDeviceHint => '请选择设备';

  @override
  String get timingEntryNoActiveDeviceHint => '暂无在用设备，请先去“设备”页新增';

  @override
  String get timingEntryContactLabel => '联系人';

  @override
  String get timingEntrySiteLabel => '使用地址/工地';

  @override
  String get timingEntryStartWorkTimeLabel => '开始工作时间';

  @override
  String get timingEntryEndWorkTimeLabel => '结束工作时间';

  @override
  String get timingEntryWorkHourBasisTooltip => '工时计算依据';

  @override
  String get timingEntryOptionalZeroHint => '0.0（可空）';

  @override
  String get timingEntryAmountYuanLabel => '金额（元）';

  @override
  String timingChartYearLabel(int year) {
    return '$year年';
  }

  @override
  String get timingChartIncomeLegend => '收入';

  @override
  String get timingChartNetIncomeValueLabel => '净入';

  @override
  String get timingChartExpenseLabel => '支出';

  @override
  String commonRecentRecordsCount(int count) {
    return '最近记录($count)';
  }

  @override
  String get commonNoRecordsTitle => '暂无记录';

  @override
  String get commonCreateFromTopRightHint => '点击右上角 + 新建';

  @override
  String get fuelPageTitle => '燃油';

  @override
  String get fuelCreateSheetTitle => '新增燃油';

  @override
  String get fuelEditSheetTitle => '编辑燃油';

  @override
  String get fuelCancelAction => '取消';

  @override
  String get fuelConfirmAction => '确定';

  @override
  String get fuelDeleteConfirmTitle => '确认删除？';

  @override
  String get fuelDeleteConfirmContent => '删除后不可恢复。';

  @override
  String get fuelDeleteConfirmAction => '删除';

  @override
  String fuelInactiveDeviceFallbackName(int id) {
    return '设备$id（已停用/不存在）';
  }

  @override
  String get fuelDeviceLabel => '设备编号';

  @override
  String get fuelDeviceHint => '请选择设备';

  @override
  String get fuelNoActiveDeviceHint => '暂无在用设备，请先去“设备”页新增';

  @override
  String get fuelSupplierRequiredLabel => '供应人（必填）';

  @override
  String get fuelSupplierHint => '例如：中石化 / 老王油品';

  @override
  String get fuelLitersLabel => '加油量（升）';

  @override
  String get fuelLitersHint => '例如：120.0';

  @override
  String get fuelAmountYuanLabel => '金额（元）';

  @override
  String get fuelAmountHint => '例如：980.0';

  @override
  String get fuelEfficiencyTitle => '设备燃油效率';

  @override
  String get fuelEfficiencyEmpty => '暂无数据（先录入燃油记录与工时记录）';

  @override
  String get fuelSupplierFilterLabel => '筛选：供应人';

  @override
  String get fuelSupplierFilterHint => '输入关键字即可过滤（可空）';

  @override
  String get maintenancePageTitle => '维保';

  @override
  String get maintenanceCreateSheetTitle => '新建维保';

  @override
  String get maintenanceEditSheetTitle => '编辑维保';

  @override
  String get maintenanceCancelAction => '取消';

  @override
  String get maintenanceConfirmAction => '确定';

  @override
  String get maintenanceDeleteConfirmTitle => '确认删除？';

  @override
  String maintenanceDeleteConfirmDateLine(String date) {
    return '日期：$date';
  }

  @override
  String maintenanceDeleteConfirmItemLine(String item) {
    return '事项：$item';
  }

  @override
  String maintenanceDeleteConfirmAmountLine(String amount) {
    return '金额：$amount';
  }

  @override
  String get maintenanceDeleteConfirmWarning => '⚠️ 删除后不可恢复';

  @override
  String get maintenanceDeleteConfirmAction => '删除';

  @override
  String get maintenanceSummaryEmpty => '当年维保费：暂无数据';

  @override
  String get maintenanceSummaryTitle => '当年维保费用（按设备 & 公共）';

  @override
  String get maintenancePublicExpenseLabel => '公共支出';

  @override
  String get maintenanceTotalLabel => '合计';

  @override
  String get maintenancePublicExpenseSwitchTitle => '公共支出（不属于任何设备）';

  @override
  String get maintenanceDeviceLabel => '设备编号';

  @override
  String get maintenanceDeviceHint => '请选择设备';

  @override
  String get maintenanceNoActiveDeviceHint => '暂无在用设备，请先去“设备”页新增';

  @override
  String get maintenanceItemRequiredLabel => '事项（必填）';

  @override
  String get maintenanceItemHint => '例如：更换机油/保养/维修';

  @override
  String get maintenanceAmountYuanLabel => '金额（元）';

  @override
  String get maintenanceAmountHint => '例如：980.0';

  @override
  String get maintenanceNoteOptionalLabel => '备注（可填）';

  @override
  String get maintenanceNoteHint => '例如：含工时/含配件';

  @override
  String get accountCancelAction => '取消';

  @override
  String get accountConfirmAction => '确定';

  @override
  String get accountDeleteAction => '删除';

  @override
  String get accountProjectTitleLabel => '项目';

  @override
  String get accountDensityNormalTooltip => '普通显示';

  @override
  String get accountDensityCompactTooltip => '紧凑显示';

  @override
  String get accountFilterAction => '筛选';

  @override
  String get accountClearFilterAction => '取消筛选';

  @override
  String get accountMergeAction => '合并';

  @override
  String get accountOverviewTitle => '总    览';

  @override
  String get accountNoDeviceData => '暂无设备数据';

  @override
  String get accountTotalReceivableLabel => '总应收';

  @override
  String get accountReceivedLabel => '已收';

  @override
  String get accountRemainingLabel => '剩余';

  @override
  String get accountReceiptRatioLabel => '回款';

  @override
  String get accountNetReceivedTooltip => '已收款扣除燃油、维保和已支付外协项目款后的金额。';

  @override
  String get accountNetReceivedLabel => '已收(净)';

  @override
  String get accountProjectMissing => '项目不存在或已被清理';

  @override
  String get accountOwnedProjectsEmpty => '暂无项目（计时页有记录后将自动出现）';

  @override
  String get accountSettledIconLabel => '结清图标';

  @override
  String get accountExportWorklogTooltip => '导出工时表';

  @override
  String get accountExternalPayableLabel => '外协应付';

  @override
  String get accountExternalReceivableLabel => '应收项目款';

  @override
  String get accountPendingSetup => '待设置';

  @override
  String get accountGrossProfitLabel => '毛利';

  @override
  String get accountPendingCalculation => '待计算';

  @override
  String get accountExternalWorkAvatarLabel => '协';

  @override
  String get accountExternalProjectsTitle => '外协项目';

  @override
  String get accountExternalProjectsEmpty => '暂无外协项目（未关联外协包导入后将自动出现）';

  @override
  String get accountProjectDetailTitle => '项目详情';

  @override
  String get accountCloseTooltip => '关闭';

  @override
  String get accountLocalDeviceLabel => '本地设备';

  @override
  String get accountExternalDeviceLabel => '外协设备';

  @override
  String get accountBatchEditAction => '批量修改';

  @override
  String get accountDissolveMergeAction => '解除合并';

  @override
  String get accountPaymentsTitle => '收款记录';

  @override
  String get accountNoPayments => '暂无收款记录';

  @override
  String get accountEditAction => '修改';

  @override
  String get accountEquipmentMissing => '设备未填写';

  @override
  String accountRecordCountLabel(String base, int count) {
    return '$base·$count条记录';
  }

  @override
  String get accountAddPaymentAction => '+ 新增收款';

  @override
  String accountProjectTotalSummary(String amount) {
    return '项目总额 $amount';
  }

  @override
  String get accountSettledStatus => '已结清';

  @override
  String get accountSettledRevokeAction => '已结清，点此撤销';

  @override
  String accountReceivedPercent(String percent) {
    return '已收 $percent%';
  }

  @override
  String accountPendingReceivable(String amount) {
    return '待收 $amount';
  }

  @override
  String get accountSettleAction => '结清';

  @override
  String get accountRateSectionLabel => '设备单价';

  @override
  String accountBreakingDeviceLabel(String name) {
    return '$name · 破碎';
  }

  @override
  String accountPaymentRemarkLine(String remark) {
    return '备注：$remark';
  }

  @override
  String get accountMergedPaymentSaveSuccess => '保存成功';

  @override
  String accountSaveFailureWithReason(String reason) {
    return '保存失败：$reason';
  }

  @override
  String get accountSaved => '已保存';

  @override
  String get accountMergedPaymentDeleteTitle => '删除收款？';

  @override
  String accountMergedPaymentDeleteContent(String date, String amount) {
    return '将删除这笔合并收款及其分摊记录：\n$date  $amount\n\n此操作不会删除计时记录。';
  }

  @override
  String get accountDeleted => '已删除';

  @override
  String accountDeleteFailureWithReason(String reason) {
    return '删除失败：$reason';
  }

  @override
  String get accountDissolveMergeSuccess => '已解除合并';

  @override
  String get accountDeleteConfirmTitle => '确认删除？';

  @override
  String accountPaymentDeleteConfirmContent(String date, String amount) {
    return '日期：$date\n金额：$amount';
  }

  @override
  String get accountWriteOffRevoked => '已撤销核销，待收已恢复';

  @override
  String accountRevokeWriteOffFailure(String reason) {
    return '撤销核销失败：$reason';
  }

  @override
  String get accountWriteOffInvalid => '该项目核销记录异常，请先检查核销记录。';

  @override
  String get accountSettlementRevoked => '已撤销结清状态';

  @override
  String accountRevokeSettlementFailure(String reason) {
    return '撤销结清状态失败：$reason';
  }

  @override
  String get accountMergedMemberInvalid => '合并项目成员异常，请刷新后重试。';

  @override
  String get accountMergeSuccess => '已合并';

  @override
  String get accountShareProjectTooltip => '分享项目';

  @override
  String get accountShareNameRequired => '请输入分享人姓名或包名';

  @override
  String get accountShareProjectTitle => '分享项目';

  @override
  String get accountShareNameLabel => '分享人姓名（自己）';

  @override
  String get accountShareNameHint => '例如：老王、张三等';

  @override
  String get accountShareNameHelp => '对方导入后，会在“外协项目”中看到这个名称。';

  @override
  String get accountGenerateSharePackageAction => '生成分享包';

  @override
  String get accountSettlementAlreadySettled => '项目已结清，不能重复结清';

  @override
  String get accountInputInvalid => '输入不合法';

  @override
  String get accountSaveFailureGeneric => '保存失败，请稍后重试';

  @override
  String get accountSettlementDialogTitle => '结清项目';

  @override
  String get accountWriteOffAmountLabel => '核销金额';

  @override
  String get accountWriteOffReasonLabel => '核销/减免原因（可填）';

  @override
  String get accountSettlementHelper => '确认后，这笔待收将作为核销处理，不再计入待收，也不会算作实收。';

  @override
  String get accountConfirmSettlementAction => '确认结清';

  @override
  String accountDeviceCountLine(int count) {
    return '设备数：$count 台';
  }

  @override
  String get accountDiggingBatchRateLabel => '挖斗统一单价（整数）';

  @override
  String get accountBreakingBatchRateLabel => '破碎统一单价（整数）';

  @override
  String get accountBatchRateHelper =>
      '保存后：该项目下所有设备会分别按“挖斗/破碎”模式更新单价（仅影响本项目）。\n若等于设备默认对应模式单价，将自动清理覆盖记录（减少冗余）。';

  @override
  String get accountSingleRateLabel => '单价';

  @override
  String get accountSingleRateHelper => '提示：若把单价改回设备默认单价，将自动清理覆盖记录（减少冗余）。';

  @override
  String accountBatchRateTitle(String project) {
    return '批量修改单价：$project';
  }

  @override
  String accountBreakingRateTitle(String project) {
    return '编辑破碎单价：$project';
  }

  @override
  String accountSingleRateTitle(String project) {
    return '编辑单价：$project';
  }

  @override
  String get accountUpdated => '已更新';

  @override
  String get accountFilterSheetTitle => '筛选项目';

  @override
  String get accountFilterKeywordLabel => '关键词（联系人 / 工地）';

  @override
  String get accountFilterKeywordHint => '例如：王涛 / 修文 / 地铁站';

  @override
  String get accountClearAction => '清空';

  @override
  String get accountPaymentCreateTitle => '新增收款';

  @override
  String get accountPaymentEditTitle => '编辑收款';

  @override
  String accountProjectLine(String project) {
    return '项目：$project';
  }

  @override
  String get accountPaymentAmountIntegerLabel => '金额（整数）';

  @override
  String get accountNoteOptionalLabel => '备注（可填）';

  @override
  String accountPaymentReceivableReceivedLine(
    String receivable,
    String received,
  ) {
    return '应收：$receivable，已收：$received';
  }

  @override
  String accountMergeFailureWithReason(String reason) {
    return '合并失败：$reason';
  }

  @override
  String get accountMergeSheetTitle => '合并项目';

  @override
  String get accountMergingAction => '合并中';

  @override
  String get accountNoMergeableProjects => '暂无可合并项目';

  @override
  String get accountUnmergedSection => '未合并';

  @override
  String get accountMergedSection => '已合并';

  @override
  String get accountDissolveConfirmTitle => '解除合并？';

  @override
  String get accountDissolveIntro => '解除后将恢复为普通项目：';

  @override
  String get accountDissolveHelp => '原始计时记录不会删除。\n设备、工时、单价不会改变。';

  @override
  String get accountDissolvingAction => '解除中';

  @override
  String accountDissolveFailureWithReason(String reason) {
    return '解除合并失败：$reason';
  }
}
