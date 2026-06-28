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
  String get commonCreateAction => '+ 新建';

  @override
  String get timingSectionHeaderTitle => '计时';

  @override
  String get appUpdateActionUpdateNow => '立即更新';

  @override
  String get appUpdateActionLater => '稍后再说';

  @override
  String get appUpdateFallbackTitle => '发现新版本';

  @override
  String get appUpdateFallbackContent => '更新以获得更稳定的体验。';

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
  String get externalWorkPickInvalidType => '请选择 FleetLedger .jzt 分享包';

  @override
  String get externalWorkPickReadFailure => '读取分享包失败，请重新选择文件';

  @override
  String get externalWorkPickFileTooLarge => '分享包文件过大，无法导入';

  @override
  String get externalWorkImportPreviewTitle => '外协项目记录';

  @override
  String get externalWorkImportPreviewImportingAction => '导入中';

  @override
  String get externalWorkImportPreviewSectionTitle => '预览';

  @override
  String get externalWorkImportPreviewSenderLabel => '来自';

  @override
  String get externalWorkImportPreviewRecordLabel => '记录';

  @override
  String externalWorkImportPreviewRecordCount(int count) {
    return '$count 条';
  }

  @override
  String get externalWorkImportPreviewSiteLabel => '地点';

  @override
  String get externalWorkImportPreviewTotalHoursLabel => '总工时';

  @override
  String get externalWorkImportPreviewTotalAmountLabel => '总金额';

  @override
  String get externalWorkImportPreviewLinesTitle => '记录明细';

  @override
  String externalWorkImportPreviewHoursValue(String hours) {
    return '$hours小时';
  }

  @override
  String get externalWorkImportPreviewStatusImportable => '可导入';

  @override
  String get externalWorkImportPreviewStatusImported => '已导入过';

  @override
  String get externalWorkImportPreviewStatusSameSource => '存在相同来源记录';

  @override
  String get externalWorkImportPreviewStatusSuspiciousDuplicate => '存在可疑重复记录';

  @override
  String externalWorkImportPreviewSameSourceCount(int count) {
    return '存在相同来源记录 $count 条';
  }

  @override
  String externalWorkImportPreviewSuspiciousCount(int count) {
    return '存在可疑重复记录 $count 条';
  }

  @override
  String externalWorkImportPreviewImportedSuccess(int count) {
    return '已导入 $count 条外协项目记录';
  }

  @override
  String externalWorkImportPreviewSuccessBanner(String message) {
    return '$message，可在外协项目记录中查看';
  }

  @override
  String get externalWorkImportPreviewGenericPrepareFailure => '导入预览生成失败，请稍后重试';

  @override
  String get externalWorkImportPreviewGenericImportFailure => '导入失败，请稍后重试';

  @override
  String get externalWorkImportPreviewEmptyContent => '请先选择或粘贴 .jzt 内容';

  @override
  String get externalWorkImportPreviewInvalidJson => '分享包不是有效的 JSON 内容';

  @override
  String get externalWorkImportPreviewInvalidPackage =>
      '这不是有效的 FleetLedger 分享包';

  @override
  String get externalWorkImportPreviewUnsupportedVersion => '分享包版本暂不支持';

  @override
  String get externalWorkImportPreviewUnsupportedPackage => '暂不支持这种分享包';

  @override
  String get externalWorkImportPreviewIncompleteIntegrity => '分享包完整性信息不完整';

  @override
  String get externalWorkImportPreviewHashMismatch => '分享包内容校验失败，请重新获取分享包';

  @override
  String get externalWorkImportPreviewInvalidRecords => '分享包记录内容不完整或格式异常';

  @override
  String get externalWorkImportPreviewInvalidBaseInfo => '分享包基础信息不完整或格式异常';

  @override
  String get externalWorkImportPreviewParseFailure => '分享包无法解析';

  @override
  String get externalWorkImportPreviewDuplicateRejected =>
      '这份分享包已导入过，或包含相同来源记录';

  @override
  String get externalWorkRecordsEmptyTitle => '暂无外协项目记录';

  @override
  String get externalWorkRecordsEmptySubtitle => '从他人分享的 .jzt 文件导入后，会显示在这里';

  @override
  String get externalWorkRecordsSourceImported => '从分享包导入';

  @override
  String externalWorkRecordsBulletCount(int count) {
    return '•$count条记录';
  }

  @override
  String externalWorkRecordsMoreDevices(int count) {
    return '等$count台';
  }

  @override
  String get externalWorkRecordsMissingDevice => '设备未填写';

  @override
  String get externalWorkRecordsUnknown => '未知';

  @override
  String get externalWorkRecordsStatusLinked => '已关联';

  @override
  String get externalWorkRecordsStatusPending => '待处理';

  @override
  String get externalWorkRecordsStatusIgnored => '已忽略';

  @override
  String get externalWorkRecordsStatusArchived => '已归档';

  @override
  String get externalWorkRecordsStatusVoided => '已作废';

  @override
  String externalWorkRecordsYearLabel(int year) {
    return '$year年';
  }

  @override
  String get externalWorkRecordsSourceLabel => '来源';

  @override
  String get externalWorkRecordsSourceNameLabel => '分享人';

  @override
  String get externalWorkRecordsSiteLabel => '地址';

  @override
  String get externalWorkRecordsDeviceLabel => '设备';

  @override
  String get externalWorkRecordsDateLabel => '日期';

  @override
  String get externalWorkRecordsHoursQuantityLabel => '工时 / 数量';

  @override
  String get externalWorkRecordsUnitPriceLabel => '单价';

  @override
  String get externalWorkRecordsAmountLabel => '金额';

  @override
  String get externalWorkRecordsProjectReceivedLabel => '已收项目款';

  @override
  String get externalWorkRecordsImportedAtLabel => '导入时间';

  @override
  String get externalWorkRecordsCurrentStatusLabel => '当前状态';

  @override
  String get externalWorkRecordsReadOnlyNotice => '这条记录来自他人分享，当前不可编辑。';

  @override
  String get externalWorkRecordsLinkAction => '关联到本地项目';

  @override
  String get externalWorkRecordsAvatarLabel => '协';

  @override
  String get externalWorkDetailSheetTitle => '外协项目详情';

  @override
  String get externalWorkDeleteSharePackageAction => '删除分享包';

  @override
  String get externalWorkDeleteSharePackageTitle => '删除分享包';

  @override
  String externalWorkDeleteSharePackageContent(int count) {
    return '这将删除该分享包导入的全部 $count 条外协记录，删除后不可恢复。';
  }

  @override
  String get externalWorkDeleteAction => '删除';

  @override
  String get externalWorkReadAction => '读取';

  @override
  String get externalWorkConfirmAction => '确定';

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
  String get timingEntryLimitProTitle => '需要升级 Pro';

  @override
  String get timingEntryLimitProMessage =>
      '免费版最多支持 30 条计时记录。升级 Pro 后可继续新增和维护更多计时记录。';

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
  String get timingEntryOptionalZeroHint => '0.0（选填）';

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
  String get fuelPageTitle => '油电';

  @override
  String get fuelCreateSheetTitle => '新增油电';

  @override
  String get fuelEditSheetTitle => '编辑油电';

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
  String get fuelSupplierHint => '例如：中石化 / 充电站';

  @override
  String get fuelLitersLabel => '油电用量（升/度）';

  @override
  String get fuelLitersHint => '例如：120.0';

  @override
  String get fuelAmountYuanLabel => '金额（元）';

  @override
  String get fuelAmountHint => '例如：980.0';

  @override
  String get fuelEfficiencyTitle => '设备油电效率';

  @override
  String get fuelEfficiencyEmpty => '暂无数据（先录入油电记录与工时记录）';

  @override
  String get fuelSupplierFilterLabel => '筛选：供应人';

  @override
  String get fuelSupplierFilterHint => '输入关键字即可过滤（选填）';

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
  String get maintenanceNoteOptionalLabel => '备注（选填）';

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
  String get accountRemainingLabel => '待收';

  @override
  String get accountReceiptRatioLabel => '回款';

  @override
  String get accountNetReceivedTooltip => '已收款扣除油电、维保和已支付外协项目款后的金额。';

  @override
  String get accountNetReceivedLabel => '已收-开支';

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
  String accountExternalReceivableWithCustomerRate(String rate) {
    return '应收项目款(应收单价$rate)';
  }

  @override
  String accountExternalPayableWithSourceRate(String rate) {
    return '应付项目款(应付单价$rate)';
  }

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
  String get accountExternalWorkDetailTitle => '外协详情';

  @override
  String accountExternalHoursSummary(String hours) {
    return '工时 $hours h';
  }

  @override
  String get accountExternalCustomerRateLabel => '应收单价';

  @override
  String accountExternalPayableTotalSummary(String amount) {
    return '应付总额 $amount';
  }

  @override
  String accountExternalPaidPercent(int percent) {
    return '已付 $percent%';
  }

  @override
  String accountExternalUnpaidAmount(String amount) {
    return '待付 $amount';
  }

  @override
  String get accountExternalPaymentRecordsTitle => '支付记录';

  @override
  String get accountExternalAddPayableAction => '+ 新增应付';

  @override
  String get accountExternalPaymentsEmpty => '支付记录即将上线';

  @override
  String get accountExternalCustomerRateEditTitle => '设置应收单价';

  @override
  String get accountExternalCustomerRateInputHint => '应收单价（元）';

  @override
  String get accountExternalCustomerRateInvalid => '请输入有效金额';

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
  String get accountSettledPaymentSaveConfirmTitle => '撤销结清并保存收款？';

  @override
  String get accountSettledPaymentSaveConfirmContent =>
      '该项目已结清。保存收款前将先撤销结清状态，并撤销结清产生的核销结果。是否继续？';

  @override
  String accountSettledPaymentDeleteConfirmContent(String date, String amount) {
    return '该项目已结清。删除这笔收款前将先撤销结清状态，并撤销结清产生的核销结果。\n\n日期：$date\n金额：$amount\n\n是否继续？';
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
  String get accountWriteOffReasonLabel => '核销/减免原因（选填）';

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
      '保存后：该项目下所有设备会分别按“挖斗/破碎”模式更新项目单价（仅影响本项目）。';

  @override
  String get accountSingleRateLabel => '单价';

  @override
  String get accountSingleRateHelper => '提示：该单价会保存为本项目的项目单价，仅影响本项目。';

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
  String get accountNoteOptionalLabel => '备注（选填）';

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

  @override
  String get deviceCancelAction => '取消';

  @override
  String get deviceConfirmAction => '确定';

  @override
  String get deviceDoneAction => '我知道了';

  @override
  String get devicePageTitle => '设备';

  @override
  String get deviceSearchHint => '搜索';

  @override
  String get deviceAccountSyncSectionTitle => '账号与同步';

  @override
  String get deviceAccountCenterTitle => '账户中心';

  @override
  String get deviceProfileSectionTitle => '个人资料';

  @override
  String get deviceUpgradeNowTitle => '立即升级';

  @override
  String get deviceEquipmentSectionTitle => '设备';

  @override
  String get deviceAddDeviceAction => '添加设备';

  @override
  String get deviceRateUsSectionTitle => '给我们评分';

  @override
  String get deviceRateAppAction => '给app评分';

  @override
  String get deviceTermsSectionTitle => '条款';

  @override
  String get deviceTermsTitle => '使用条款';

  @override
  String get devicePrivacyTitle => '隐私政策';

  @override
  String get deviceSupportSectionTitle => '支持与反馈';

  @override
  String get deviceContactDeveloperAction => '联系开发者';

  @override
  String get deviceManagementTitle => '管理设备(长按图标删除)';

  @override
  String get deviceEquipmentExcavator => '挖掘机';

  @override
  String get deviceEquipmentLoader => '装载机';

  @override
  String get deviceEditorCreateTitle => '新增设备';

  @override
  String get deviceEditorEditTitle => '编辑设备';

  @override
  String get deviceBrandNotSelected => '未选择品牌（头像）';

  @override
  String deviceBrandSelectedLine(
    String equipmentType,
    String brand,
    String preview,
  ) {
    return '品牌：$equipmentType  $brand$preview';
  }

  @override
  String get deviceSelectAction => '选择';

  @override
  String get deviceAvatarBrandDefault => '头像：品牌默认';

  @override
  String get deviceAvatarCustomSet => '头像：已设置自定义';

  @override
  String get deviceGalleryAction => '相册';

  @override
  String get deviceDefaultAction => '默认';

  @override
  String get deviceBaseMeterLabel => '基准码表（>=0，必填）';

  @override
  String get deviceDefaultRateLabel => '默认单价（>0，必填）';

  @override
  String get deviceBreakingRateOptionalLabel => '破碎单价（选填）';

  @override
  String get deviceBreakingRateHint => '不填写默认该设备没有破碎';

  @override
  String get deviceModelOptionalLabel => '型号（选填）';

  @override
  String get deviceCustomAvatarProTitle => '需要升级';

  @override
  String get deviceCustomAvatarProMessage => '自定义设备头像是 Pro 功能，升级后可为设备设置专属头像。';

  @override
  String get deviceAvatarGalleryChanged => '已从相册更换头像';

  @override
  String deviceAvatarSaveFailure(String error) {
    return '头像保存失败：$error';
  }

  @override
  String get deviceAvatarSelectTitle => '选择设备头像';

  @override
  String get deviceAvatarEmpty => '该类别暂无品牌，先选另一类或新增自定义头像';

  @override
  String get deviceBrandCountryChina => '中国';

  @override
  String get deviceBrandCountryJapan => '日本';

  @override
  String get deviceBrandCountryUs => '美国';

  @override
  String get deviceBrandCountryKorea => '韩国';

  @override
  String get deviceTypeSelectTitle => '选择设备类型与品牌';

  @override
  String get deviceTypeMoreChip => '更多';

  @override
  String get deviceTypeSheetTitle => '选择设备类型';

  @override
  String get deviceTypeSearchHint => '搜索设备类型';

  @override
  String get deviceTypeSheetEmpty => '未找到相关设备类型';

  @override
  String get deviceTypeComingSoonBadge => '敬请期待';

  @override
  String deviceTypeComingSoonCta(String type) {
    return '$type 创建流程即将上线';
  }

  @override
  String deviceCreateNextCta(String type) {
    return '下一步：创建$type设备';
  }

  @override
  String get deviceBrandSectionTitle => '选择品牌头像';

  @override
  String get deviceBrandSearchHint => '搜索品牌 / 输入自定义品牌';

  @override
  String get deviceBrandSearchEmptyTitle => '未找到相关品牌';

  @override
  String deviceBrandSearchEmptyCreateHint(String ctaLabel) {
    return '未找到相关品牌，可直接点击下方‘$ctaLabel’按钮，直接创建自定义品牌';
  }

  @override
  String deviceBrandEmptyForType(String type) {
    return '暂未收录$type品牌，可使用自定义品牌';
  }

  @override
  String get deviceBrandUseCustom => '使用自定义品牌';

  @override
  String deviceBrandResetNotice(String type) {
    return '已切换为$type，品牌已重置';
  }

  @override
  String get deviceBrandCustomDialogTitle => '自定义品牌';

  @override
  String get deviceBrandCustomDialogHint => '输入品牌名称';

  @override
  String get deviceBrandCustomConfirm => '确定';

  @override
  String get deviceCategoryConstruction => '工程机械';

  @override
  String get deviceCategoryAgriculture => '农业设备';

  @override
  String get deviceCategoryUnmanned => '无人设备';

  @override
  String get deviceCategorySmart => '智能设备';

  @override
  String get deviceCategoryOther => '其他';

  @override
  String get deviceTypeExcavatorDesc => '土方 / 矿山 / 施工';

  @override
  String get deviceTypeLoaderDesc => '装载 / 转运 / 施工';

  @override
  String get deviceTypeRollerName => '压路机';

  @override
  String get deviceTypeRollerDesc => '道路 / 压实 / 施工';

  @override
  String get deviceTypeHandlingVehicleName => '装卸车';

  @override
  String get deviceTypeHandlingVehicleDesc => '装卸 / 转运 / 搬运';

  @override
  String get deviceTypeCraneName => '吊车';

  @override
  String get deviceTypeCraneDesc => '吊装 / 起重 / 吊运';

  @override
  String get deviceTypeForkliftName => '叉车';

  @override
  String get deviceTypeForkliftDesc => '叉取 / 仓储 / 堆垛';

  @override
  String get deviceTypeAgriMachineName => '农机';

  @override
  String get deviceTypeAgriMachineDesc => '农田 / 作业 / 农业生产';

  @override
  String get deviceTypeDroneName => '无人机';

  @override
  String get deviceTypeDroneDesc => '巡检 / 植保 / 测绘';

  @override
  String get deviceTypeRobotName => '机器人';

  @override
  String get deviceTypeRobotDesc => '巡检 / 作业 / 交互';

  @override
  String get deviceTypeCustomName => '自定义设备';

  @override
  String get deviceTypeCustomDesc => '其他类型 / 自定义';

  @override
  String get devicePickerLabel => '设备编号';

  @override
  String get devicePickerEmptyHint => '暂无在用设备，请先去“设备”页新增';

  @override
  String devicePickerItemWithMeter(String name, String meter) {
    return '$name（码表 $meter h）';
  }

  @override
  String get devicePickerUnknownDevice => '未知设备';

  @override
  String devicePickerInactiveItemWithMeter(String name, String meter) {
    return '$name（已停用 · 码表 $meter h）';
  }

  @override
  String get devicePickerUnknownInactive => '未知设备（已停用）';

  @override
  String get deviceDeactivateTitle => '确认停用设备？';

  @override
  String deviceDeactivateContent(String name) {
    return '设备：$name\n\n只会停用设备，不会删除任何计时/油电/收入历史记录。\n停用后：\n• 设备页默认不再显示\n• 计时页下拉框不可再选\n• 历史记录仍可回显（通过 deviceId 区分新旧设备）';
  }

  @override
  String get deviceDeactivateAction => '停用';

  @override
  String get deviceSaveAction => '保存';

  @override
  String get deviceReadAction => '读取';

  @override
  String get deviceSaveCreated => '已新增设备';

  @override
  String get deviceSaveUpdated => '已更新设备';

  @override
  String get deviceDeactivateSuccess => '已停用（历史记录不受影响）';

  @override
  String get deviceSaveFailureDataNotSaved => '保存失败：数据未保存，请稍后重试';

  @override
  String get deviceLifecycleSetCostAction => '点击设置成本与残值';

  @override
  String get deviceLifecycleNetProfitFormula => '生命周期净收益 = 已实收 + 预计残值 - 初始成本';

  @override
  String get deviceLifecyclePaybackNoCostStatus => '未设置成本';

  @override
  String get deviceLifecyclePaybackNoCostResult => '设置后可查看回本进度与预计盈余';

  @override
  String deviceLifecyclePaybackPaidBackMultiplier(String multiplier) {
    return '已回本 ${multiplier}x';
  }

  @override
  String get deviceLifecyclePaybackPaidBackFull => '已回本 100%';

  @override
  String deviceLifecyclePaybackPaidBackPercent(String percent) {
    return '已回本 $percent%';
  }

  @override
  String deviceLifecyclePaybackPercentInProgress(String percent) {
    return '回本 $percent%';
  }

  @override
  String deviceLifecyclePaybackProfit(String amount) {
    return '预计盈余 $amount';
  }

  @override
  String get deviceLifecyclePaybackBreakeven => '已回本，暂无盈余';

  @override
  String deviceLifecyclePaybackShortfall(String amount) {
    return '还差 $amount 回本';
  }

  @override
  String deviceLifecycleInitialInvestmentSemantics(String amount) {
    return '初始投入$amount';
  }

  @override
  String get deviceLifecycleInitialInvestmentUnsetValue => '未设置';

  @override
  String deviceLifecycleNetReceivedSemantics(String amount) {
    return '已实收净额$amount';
  }

  @override
  String deviceLifecycleEstimatedResidualSemantics(String amount) {
    return '预计售出残值$amount';
  }

  @override
  String deviceLifecyclePendingReceivableSemantics(String amount) {
    return '待收$amount';
  }

  @override
  String deviceLifecycleOperationSummary(String hours, int count) {
    return '已运营：$hours小时 / $count项';
  }

  @override
  String get deviceLifecycleInitialInvestmentUnset => '未设置初始投入';

  @override
  String deviceLifecycleInitialInvestmentAmount(String amount) {
    return '初始投入 $amount';
  }

  @override
  String get deviceLifecycleSurplusLabel => '盈余';

  @override
  String get deviceLifecyclePaybackGapLabel => '未回本缺口';

  @override
  String get deviceLifecycleReceivedPrincipalLabel => '实收补本额';

  @override
  String get deviceLifecycleNetReceivedLabel => '已实收净额';

  @override
  String get deviceLifecycleEstimatedResidualLabel => '预计售出残值';

  @override
  String deviceLifecyclePendingReceivableLabel(String amount) {
    return '待收 $amount';
  }

  @override
  String get deviceLifecycleAmountSheetTitle => '设置设备生命周期金额';

  @override
  String get deviceLifecycleAmountUpdateAction => '更新';

  @override
  String get deviceLifecycleInitialCostLabel => '初始投入成本';

  @override
  String get deviceLifecycleEstimatedResidualInputLabel => '预计售出残值';

  @override
  String get deviceLifecycleProjectedSurplusTitle => '预计盈余';

  @override
  String get deviceLifecyclePaybackRemainingTitle => '还差回本';

  @override
  String get deviceLifecycleEstimatedResidualFormulaLabel => '+ 预计售出残值';

  @override
  String get deviceLifecycleInitialCostFormulaLabel => '- 初始投入成本';

  @override
  String get deviceLifecycleNetProfitFormulaLabel => '= 生命周期净收益';

  @override
  String get deviceAccountStatusSectionTitle => '账号状态';

  @override
  String get deviceAccountCenterLoggedOutSubtitle => '未登录 · 登录后可备份与同步';

  @override
  String deviceAccountCenterLoggedInSubtitle(String entitlement) {
    return '已登录 · $entitlement';
  }

  @override
  String deviceAccountCenterLoggedInTailSubtitle(
    String tail,
    String entitlement,
  ) {
    return '已登录 · 尾号 $tail · $entitlement';
  }

  @override
  String get deviceAccountLoggedInTitle => '已登录';

  @override
  String get deviceAccountLoggedOutTitle => '未登录';

  @override
  String get deviceAccountAuthLoggedOutSubtitle => '登录后可使用云端备份与恢复';

  @override
  String deviceAccountAuthTailSubtitle(String tail, String entitlement) {
    return '尾号 $tail · $entitlement';
  }

  @override
  String get deviceEntitlementPro => 'Pro 已开通';

  @override
  String get deviceEntitlementMax => 'Max 已开通';

  @override
  String get deviceEntitlementFree => '免费版';

  @override
  String deviceEntitlementExpires(String entitlement, String date) {
    return '$entitlement · 有效至 $date';
  }

  @override
  String get devicePhoneLoginAction => '手机号登录';

  @override
  String get devicePhoneLoginSubtitle => '登录后可使用云端备份与购买权益同步';

  @override
  String get devicePurchaseSectionTitle => '购买权益';

  @override
  String get deviceUpgradeProTitle => '升级 Pro，支持持续维护';

  @override
  String get deviceUpgradeProSubtitle => '解除计时记录 30 条限制';

  @override
  String get deviceUpgradeProPrice => '6 元/年';

  @override
  String get deviceUpgradeProAction => '升级 Pro';

  @override
  String get deviceUpgradeMaxTitle => '升级 Max，开启云端备份';

  @override
  String get deviceUpgradeMaxSubtitle => '包含 Pro 权益，支持云端备份与恢复';

  @override
  String get deviceUpgradeMaxPrice => '24 元/年';

  @override
  String get deviceUpgradeMaxAction => '升级 Max';

  @override
  String get deviceRestorePurchasesAction => '恢复购买';

  @override
  String get deviceRestorePurchasesSubtitle => '从 App Store 恢复已购买权益';

  @override
  String get deviceRestoreResultRestoredPro => '已恢复 Pro 订阅';

  @override
  String get deviceRestoreResultRestoredMax => '已恢复 Max 订阅';

  @override
  String get deviceRestoreResultNoPurchase => '未发现可恢复的购买';

  @override
  String deviceRestoreResultFailed(String reason) {
    return '恢复失败：$reason';
  }

  @override
  String deviceRestoreResultUnavailable(String reason) {
    return '订阅服务暂不可用：$reason';
  }

  @override
  String get deviceDataSecuritySectionTitle => '数据安全';

  @override
  String get deviceCloudBackupTitle => '云端备份';

  @override
  String get deviceCloudBackupAuthedSubtitle => 'Max 功能，可上传当前数据并在需要时恢复';

  @override
  String get deviceCloudBackupLoginSubtitle => '登录后可使用云端备份与恢复';

  @override
  String get deviceCloudBackupMaxSubtitle => 'Max 功能，可上传当前数据并在需要时恢复';

  @override
  String get deviceCloudBackupMaxTitle => '需要升级 Max';

  @override
  String get deviceCloudBackupMaxMessage =>
      '云端备份与恢复是 Max 功能。升级 Max 后可上传当前数据，并可在需要时从云端恢复。';

  @override
  String get deviceCloudBackupRequiresMax => '云端备份与恢复需要 Max。若已购买，请登录并恢复购买后再试。';

  @override
  String get deviceCloudBackupNotConfigured => '云端备份服务暂未配置';

  @override
  String get deviceManualBackupTitle => '导出当前数据';

  @override
  String get deviceManualBackupSubtitle => '导出本机数据，便于保存与迁移';

  @override
  String get deviceLocalRestoreTitle => '本地恢复';

  @override
  String get deviceLocalRestoreSubtitle => '从备份文件恢复本机数据';

  @override
  String get deviceCloudRestoreTitle => '云端恢复';

  @override
  String get deviceCloudRestoreSubtitle => 'Max 功能，可从云端备份恢复数据';

  @override
  String get deviceSyncInfoTitle => '多端同步说明';

  @override
  String get deviceSyncInfoSubtitle => '当前版本暂不支持自动多端同步';

  @override
  String get deviceSyncInfoMessage =>
      '云端备份用于保存数据与换机恢复。多端同步是多台设备之间的实时数据同步，当前版本暂不支持自动多端同步。';

  @override
  String get deviceCloudBackupUnavailableTitle => '云端备份服务暂未配置';

  @override
  String get deviceLoginRequiredTitle => '需要登录';

  @override
  String get deviceCloudBackupLoginRequiredMessage => '请先完成手机号登录，再使用云端备份。';

  @override
  String get deviceCloudBackupChooseMessage =>
      '你可以上传当前本机数据，也可以从云端备份恢复到本机。云端恢复会完整替换当前本机业务数据。';

  @override
  String get deviceCloudRestoreAction => '从云端恢复';

  @override
  String get deviceCloudUploadAction => '上传当前数据';

  @override
  String get deviceCloudBackupFailureTitle => '云端备份失败';

  @override
  String get deviceCloudBackupUploadFailureMessage => '云端备份上传失败，请稍后重试。';

  @override
  String get deviceCloudBackupUploadedTitle => '云端备份已上传';

  @override
  String deviceCloudBackupUploadedMessage(String backupId, String size) {
    return '当前数据已保存到云端。\n备份 ID：$backupId\n大小：$size';
  }

  @override
  String get deviceCloudBackupReadFailureTitle => '无法读取云端备份';

  @override
  String get deviceCloudBackupReadFailureMessage => '云端备份列表读取失败，请稍后重试。';

  @override
  String get deviceCloudBackupEmptyTitle => '暂无云端备份';

  @override
  String get deviceCloudBackupEmptyMessage => '当前账号下还没有可恢复的云端备份。';

  @override
  String get deviceCloudBackupSelectTitle => '选择云端备份';

  @override
  String get deviceCloudRestoreConfirmTitle => '确认从云端恢复？';

  @override
  String deviceCloudRestoreConfirmMessage(String backupTime) {
    return '将恢复 $backupTime 的云端备份。恢复后，当前本机业务数据会被这份云端备份替换；恢复前 App 会先自动导出当前数据备份。';
  }

  @override
  String get deviceRestoreConfirmAction => '确认恢复';

  @override
  String get deviceLocalBackupFailureTitle => '本地备份失败';

  @override
  String get deviceLocalBackupFailureMessage => '备份失败，请稍后重试。';

  @override
  String get deviceLocalBackupGeneratedTitle => '本地备份已生成';

  @override
  String get deviceLocalBackupPathInvalidMessage =>
      '备份文件已生成，但文件路径异常。你仍可稍后从本地备份列表中选择该文件。';

  @override
  String get deviceLocalBackupOnlySuccessMessage => '备份已生成，可在本地恢复时选择这份备份。';

  @override
  String get deviceLocalBackupSharedSuccessMessage => '备份文件已生成，请确认已保存到安全位置。';

  @override
  String get deviceLocalBackupShareUnavailableMessage =>
      '备份文件已生成，但无法打开分享面板。你仍可在本地备份列表中找到它。';

  @override
  String get deviceManualBackupDialogMessage =>
      '导出一份当前数据备份文件。你可以仅保存在本机，也可以立即分享或保存到其他位置。';

  @override
  String get deviceBackupOnlyAction => '仅备份';

  @override
  String get deviceBackupAndShareAction => '备份并分享';

  @override
  String get deviceBackupSelectionCancelled => '已取消选择';

  @override
  String get deviceBackupPreviewUnavailableTitle => '无法预览备份文件';

  @override
  String get deviceInvalidBackupFileMessage => '这不是有效的 FleetLedger 备份文件';

  @override
  String get deviceBackupIncompleteMessage => '备份文件格式不完整';

  @override
  String get deviceBackupSelectFileTitle => '选择备份文件';

  @override
  String get deviceBackupSelectFileMessage =>
      '请选择由 FleetLedger 导出的备份文件。通常建议选择最近一次手动备份；恢复前备份用于撤回最近几次恢复操作前的数据。';

  @override
  String get deviceBackupNoRecognizedFiles =>
      '暂无可识别的本地备份文件，可点击“从文件选择”选择其他位置的 JSON 备份。';

  @override
  String get deviceBackupManualSection => '手动备份';

  @override
  String get deviceBackupPreRestoreSection => '恢复前备份（防误操）';

  @override
  String get deviceBackupLegacySection => '旧版备份';

  @override
  String get deviceBackupFromFileAction => '从文件选择';

  @override
  String get deviceUnknownValue => '未知';

  @override
  String get deviceBackupPreviewTitle => '备份文件预览';

  @override
  String get deviceBackupPreviewIntro => '这是一个 FleetLedger 本地备份文件。';

  @override
  String get deviceBackupTimeLabel => '备份时间';

  @override
  String get deviceBackupSchemaVersionLabel => '数据库版本';

  @override
  String get deviceBackupIncludedDataLabel => '包含数据：';

  @override
  String get deviceBackupDeviceCountLabel => '设备';

  @override
  String get deviceBackupTimingRecordCountLabel => '计时记录';

  @override
  String get deviceBackupFuelRecordCountLabel => '油电记录';

  @override
  String get deviceBackupMaintenanceRecordCountLabel => '维修记录';

  @override
  String get deviceBackupIncomeRecordCountLabel => '收款记录';

  @override
  String get deviceBackupProjectSettingsCountLabel => '项目相关设置';

  @override
  String deviceCountWithUnit(int count) {
    return '$count 条';
  }

  @override
  String deviceMachineCountWithUnit(int count) {
    return '$count 台';
  }

  @override
  String get deviceBackupRestoreWarning => '恢复后，当前本机的业务数据会被这份备份替换。';

  @override
  String get deviceRestoringMessage => '正在恢复，请勿关闭 App...';

  @override
  String get deviceLocalRestoreConfirmTitle => '确认恢复备份？';

  @override
  String get deviceLocalRestoreConfirmMessage =>
      '恢复后，当前本机的设备、计时、油电、维修、收款和项目相关设置等业务数据将被所选备份替换。恢复前，App 会先自动导出一份当前数据备份，便于必要时找回。当前版本仅支持完整覆盖恢复，不支持合并恢复。';

  @override
  String get deviceRestoreSuccessTitle => '恢复完成';

  @override
  String deviceRestoreSuccessMessage(
    int devices,
    int timingRecords,
    int fuelRecords,
    int maintenanceRecords,
    int accountPayments,
    int projectSettings,
  ) {
    return '已恢复以下业务数据：\n设备：$devices\n计时记录：$timingRecords\n油电记录：$fuelRecords\n维修记录：$maintenanceRecords\n收款记录：$accountPayments\n项目相关设置：$projectSettings\n\n恢复前已自动备份当前数据。';
  }

  @override
  String get deviceRestoreFailureTitle => '恢复失败';

  @override
  String get deviceRestoreAutoBackupNote => '\n\n恢复前已成功自动备份当前数据。';

  @override
  String get deviceBackupManualKindTitle => 'FleetLedger 手动备份';

  @override
  String get deviceBackupPreRestoreKindTitle => '恢复前备份';

  @override
  String get deviceBackupLegacyKindTitle => '旧版备份';

  @override
  String get deviceBackupUnknownKindTitle => 'FleetLedger 备份';

  @override
  String get deviceLedgerSectionTitle => '设备经营';

  @override
  String get deviceInactiveIndexLabel => '已停用';

  @override
  String get deviceUnitHour => '小时';

  @override
  String get deviceUnitShift => '台班';

  @override
  String get deviceUnitDay => '天';

  @override
  String get deviceUnitRent => '租期';

  @override
  String get deviceUnitMu => '亩';

  @override
  String get deviceUnitAcre => '英亩';

  @override
  String get deviceUnitHectare => '公顷';

  @override
  String get deviceUnitTon => '吨';

  @override
  String get deviceUnitCubicMeter => '方';

  @override
  String get deviceUnitTrip => '趟';

  @override
  String get deviceUnitSortie => '架次';

  @override
  String get deviceUnitTask => '任务';

  @override
  String get deviceUpgradeProFallbackTitle => '机账通 Pro 年订阅';

  @override
  String get deviceUpgradeMaxFallbackTitle => '机账通 Max 年订阅';

  @override
  String get deviceUpgradePeriodYear => '1 年 / 1 year';

  @override
  String get deviceUpgradeUnitYear => '年';

  @override
  String get deviceUpgradeProBody => '解除计时记录 30 条限制，适合长期持续记账和计时。';

  @override
  String get deviceUpgradeMaxBody => '包含 Pro 权益，支持云端备份与恢复。';

  @override
  String get deviceUpgradeLoadingProduct =>
      '等待 App Store 商品信息 / Loading from App Store';

  @override
  String get deviceUpgradeUnitPricePending =>
      '商品信息加载后显示 / Available after product details load';

  @override
  String get deviceUpgradePurchaseUnavailable => '订阅购买服务暂不可用，请稍后重试';

  @override
  String get deviceUpgradeLoadingProducts => '正在加载 App Store 订阅商品...';

  @override
  String get deviceUpgradeProductsUnavailable => '订阅商品暂不可用，请稍后重试';

  @override
  String get deviceUpgradeTransactionPending => '正在等待 App Store 交易结果...';

  @override
  String get deviceUpgradeMaxUnlocked => '订阅已生效，Max 权益已解锁';

  @override
  String get deviceUpgradeProUnlocked => '订阅已生效，Pro 权益已解锁';

  @override
  String get deviceUpgradeButtonLoading => '加载中...';

  @override
  String get deviceUpgradeButtonUnavailable => '暂不可购买';

  @override
  String get deviceUpgradeButtonProcessing => '处理中...';

  @override
  String get deviceUpgradeButtonSubscribed => '已订阅';

  @override
  String get deviceUpgradeButtonUpgradeMax => '升级到 Max';

  @override
  String get deviceUpgradeButtonContinue => '继续';

  @override
  String get deviceUpgradeBenefitClearLedger => '多留一份清楚的电子账';

  @override
  String get deviceUpgradeBenefitAutoRenewal => 'Pro 与 Max 均为年度自动续期订阅';

  @override
  String get deviceUpgradeBadgeIncludesPro => '包含 Pro';

  @override
  String get deviceUpgradeSubscriptionDetailsTitle =>
      '订阅信息 / Subscription details';

  @override
  String get deviceUpgradeSubscriptionNameLabel => '订阅名称';

  @override
  String get deviceUpgradeSubscriptionPeriodLabel => '订阅周期';

  @override
  String get deviceUpgradeSubscriptionPriceLabel => '订阅价格';

  @override
  String get deviceUpgradeUnitPriceLabel => '单位价格';

  @override
  String get deviceUpgradeProductNotLoadedMessage =>
      '商品信息未完整加载前无法购买，请等待 App Store 返回订阅信息。';

  @override
  String get deviceUpgradeUnlocksPremiumMessage =>
      '订阅后可解锁 Pro 功能，并在订阅有效期内持续使用已开放的高级功能。\nSubscription unlocks premium features while your subscription is active.';

  @override
  String get deviceUpgradeAutoRenewMessage =>
      '订阅会自动续期，除非你在当前周期结束前至少 24 小时关闭自动续期。你可以在 Apple ID 的订阅设置中管理或取消订阅。\nSubscriptions renew automatically unless auto-renewal is turned off at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple ID subscription settings.';

  @override
  String get deviceUpgradeReviewLegalMessage =>
      '购买前请阅读《隐私政策》和《使用条款》。\nPlease review the Privacy Policy and Terms of Use before purchasing.';

  @override
  String get deviceUpgradePrivacyLinkLabel => '隐私政策 Privacy Policy';

  @override
  String get deviceUpgradeTermsLinkLabel => '使用条款 Terms of Use';

  @override
  String get devicePrivacyEffectiveDate => '生效日期：2026 年 6 月 9 日';

  @override
  String get devicePrivacySection1Title => '1. 适用范围';

  @override
  String get devicePrivacySection1Body =>
      '欢迎使用 FleetLedger。\nFleetLedger 是一款面向工程机械经营场景的记录与管理工具，帮助用户管理设备工时、油电消耗、项目收支、维保明细及设备信息。\n\n本隐私政策用于说明：在当前版本下，FleetLedger 如何处理与你使用本应用相关的信息。\n\n本政策适用于 FleetLedger 当前提供的应用版本及相关支持页面。';

  @override
  String get devicePrivacySection2Title => '2. 当前版本涉及的本地数据类型';

  @override
  String get devicePrivacySection2Body =>
      '在当前版本中，应用涉及的数据主要包括：\n• 你主动录入的设备信息、工时记录、油电记录、项目收支、维保明细等业务数据；\n• 你在手机号登录页主动输入的手机号，以及你对隐私政策和使用条款的确认状态；\n• 你主动选择并设置的头像或图片文件；\n• 应用在本机运行过程中，为实现本地存储、页面展示、筛选查询、统计展示与功能判断所需的必要本地信息。\n\n上述业务数据在当前版本中主要存储在你的设备本地。为实现手机号验证码登录，你输入的手机号、验证码校验请求、登录状态及必要的服务端响应信息会发送至开发者配置的账号接口，并由阿里云号码认证服务提供短信验证码发送与校验能力。如你主动使用云端备份，应用会将当前账本备份上传至开发者配置的云端备份服务，用于后续备份列表展示和换机恢复。当前版本未接入广告 SDK、行为分析 SDK、第三方追踪服务或自动多端同步服务。';

  @override
  String get devicePrivacySection3Title => '3. 数据来源与用途说明';

  @override
  String get devicePrivacySection3Body =>
      '当前版本中的相关数据主要来源于：\n• 你的主动输入；\n• 你的主动上传或主动选择；\n• 你在使用相关功能时在设备本地形成的数据。\n\n这些数据主要用于在你的设备上实现 FleetLedger 的核心功能，包括但不限于：\n• 保存和展示设备经营记录；\n• 生成统计结果与页面展示内容；\n• 支持筛选、查询、汇总、头像显示等功能；\n• 在必要情况下协助进行本地问题排查与功能判断。\n\n除手机号验证码登录、你主动使用云端备份或恢复、你主动通过系统能力发起评分、邮件联系或打开外部链接等行为外，开发者当前不会通过本应用主动接收你在应用内录入的业务数据。';

  @override
  String get devicePrivacySection4Title => '4. 权限使用说明';

  @override
  String get devicePrivacySection4Body =>
      '为实现相关功能，FleetLedger 可能在你主动操作时请求系统权限。';

  @override
  String get devicePrivacySection5Title => '4.1 图片或相册相关权限';

  @override
  String get devicePrivacySection5Body =>
      '当你主动为设备设置头像、选择图片或更新相关展示内容时，应用可能请求访问图片或相册的权限。该权限仅用于完成你主动发起的操作，不会在未经你同意的情况下自动读取你的图片内容。';

  @override
  String get devicePrivacySection6Title => '4.2 外部链接与系统能力';

  @override
  String get devicePrivacySection6Body =>
      '当你主动点击“给 app 评分”“联系开发者”“隐私政策”“使用条款”“升级/订阅”或“恢复购买”等入口时，应用可能调用系统提供的浏览器、邮件、应用商店或其他系统能力，以完成对应操作。此类行为属于你主动发起的系统跳转。';

  @override
  String get devicePrivacySection7Title => '5. 信息共享、上传与第三方服务';

  @override
  String get devicePrivacySection7Body =>
      '当前版本下，你输入的业务记录主要存储在本地设备中；手机号验证码登录所需的手机号、验证码校验请求、登录状态及必要的服务端响应信息会发送至开发者配置的账号接口，并由阿里云号码认证服务处理短信验证码发送与校验。你主动使用云端备份时，应用会将当前账本备份上传至开发者配置的云端备份服务；你主动从云端恢复时，应用会下载你账号下选择的备份。\n\n开发者不会将这些记录出售、出租或主动共享给广告网络、数据经纪商或其他无关第三方。\n\n当前版本未接入以下类型的第三方服务：\n• 广告投放服务；\n• 行为分析服务；\n• 第三方追踪服务；\n• 自动多端同步服务。\n\n当前版本已接入的短信验证码服务仅用于手机号登录验证，不用于广告投放、行为分析或第三方追踪。\n\n如你主动使用应用商店评分、系统邮件联系、升级、订阅或恢复购买等系统能力，相关流程将由 Apple App Store、设备系统或对应平台按照其自身规则处理。若生产版本启用订阅服务端校验，应用可能向开发者配置的校验服务发送确认订阅状态所需的交易校验信息。开发者当前不直接收集你的银行卡号、支付账号密码等支付凭证信息。';

  @override
  String get devicePrivacySection8Title => '6. 数据存储与安全';

  @override
  String get devicePrivacySection8Body =>
      '当前版本中的主要业务数据保存在你的设备本地。你主动上传的云端备份会保存在账号对应的云端备份空间，用于备份列表展示和恢复。手机号验证码登录所需的登录凭证会保存在本机，用于维持登录状态。我们会在应用能力范围内采取合理措施，尽量降低数据被意外丢失、误操作或未经授权访问的风险。\n\n但请你理解，任何本地设备、操作系统环境或存储介质都无法保证绝对安全。建议你妥善保管自己的设备，并谨慎处理重要业务数据。';

  @override
  String get devicePrivacySection9Title => '7. 数据保留与删除';

  @override
  String get devicePrivacySection9Body =>
      '在当前版本中，相关业务数据通常会保留在你的本地设备中，直至出现以下情况之一：\n• 你主动删除相关记录；\n• 你主动清除应用数据；\n• 你卸载应用；\n• 因设备系统、存储环境或其他异常导致本地数据变化或丢失。\n\n如果你没有主动上传云端备份，开发者通常无法为你恢复仅保存在本地设备中的账本数据。';

  @override
  String get devicePrivacySection10Title => '8. 儿童与未成年人保护';

  @override
  String get devicePrivacySection10Body =>
      'FleetLedger 主要面向工程机械经营记录与管理场景，不以儿童为目标用户。如你是未成年人，建议在监护人指导下阅读并使用本应用。';

  @override
  String get devicePrivacySection11Title => '9. 未来功能更新说明';

  @override
  String get devicePrivacySection11Body =>
      '当前版本中，手机号验证码登录和用户主动发起的云端备份/恢复会按本政策说明处理相关信息。\n\n如未来版本引入以下能力，包括但不限于：\n• 自动多端同步；\n• 行为分析工具；\n• 第三方服务接入；\n• 错误日志收集；\n• 其他涉及数据上传、处理或共享的新功能，\n\n我们会根据届时的实际功能与数据流程，及时更新本隐私政策，并同步更新 App Store 隐私披露信息。';

  @override
  String get devicePrivacySection12Title => '10. 隐私政策的更新';

  @override
  String get devicePrivacySection12Body =>
      '我们可能会根据产品功能迭代、法律法规要求或服务变化，对本政策进行更新。更新后的版本会通过应用内相关页面、支持页面或其他合理方式进行发布。\n\n如无特别说明，更新后的政策自发布之日起生效。';

  @override
  String get devicePrivacySection13Title => '11. 联系我们';

  @override
  String get devicePrivacySection13Body =>
      '如果你对本隐私政策有疑问，或希望就隐私相关问题与我们联系，可以通过以下方式联系开发者：\n\n电子邮箱：582748196@qq.com';

  @override
  String get deviceTermsEffectiveDate => '生效日期：2026-03-17';

  @override
  String get deviceTermsSection1Title => '1. 适用范围与接受';

  @override
  String get deviceTermsSection1Body =>
      '本使用条款适用于“FleetLedger”在 iOS 与 Android 平台提供的产品与服务。你在下载、安装、访问或继续使用本应用时，即表示你已阅读并同意受本条款约束。';

  @override
  String get deviceTermsSection2Title => '2. 产品功能说明';

  @override
  String get deviceTermsSection2Body =>
      '本应用面向工程机械经营场景，主要用于设备信息、工时、油电、项目收支、维保明细等内容的记录与管理。应用展示结果仅作为经营辅助工具，不构成财务、税务、法律或其他专业意见。';

  @override
  String get deviceTermsSection3Title => '3. 用户责任';

  @override
  String get deviceTermsSection3Body =>
      '你应确保录入、保存、导出或分享的信息真实、准确、完整，并保证你对相关数据拥有合法使用权。你不得利用本应用制作、存储或传播违法、侵权、欺诈、恶意或其他违反适用法律法规的内容。';

  @override
  String get deviceTermsSection4Title => '4. 本地数据与备份';

  @override
  String get deviceTermsSection4Body =>
      '当前版本的设备信息、工时、油电、项目收支、维保明细等主要业务数据主要采用本地存储方式。手机号验证码登录会通过开发者配置的账号接口和短信验证码服务完成校验，用于识别登录状态。\n\n你理解并同意：因设备损坏、系统异常、误删除、权限变更、卸载应用或其他非开发者可控原因导致的本地业务数据丢失风险，应由你自行承担。建议你根据业务重要程度自行做好备份。';

  @override
  String get deviceTermsSection5Title => '5. 权限、平台能力与付费功能';

  @override
  String get deviceTermsSection5Body =>
      '当你主动使用图片选择、评分入口、升级/订阅或恢复购买能力时，应用可能调用系统权限或 Apple App Store、Google Play 提供的平台能力。自动续期订阅的名称、周期、价格与权益以购买页和对应应用商店确认页展示为准；订阅会自动续期，除非你在当前周期结束前至少 24 小时关闭自动续期。你可以在 Apple ID 的订阅设置中管理或取消订阅，退款、取消与续费规则以对应应用商店规则为准，相关支付结算由对应平台处理。';

  @override
  String get deviceTermsSection6Title => '6. 知识产权';

  @override
  String get deviceTermsSection6Body =>
      '本应用的软件代码、界面设计、文案结构与相关标识等内容，除法律另有规定或另有声明外，相关权利归开发者所有。未经许可，你不得对应用进行非法复制、反向工程、传播或商业化利用。';

  @override
  String get deviceTermsSection7Title => '7. 免责声明与责任限制';

  @override
  String get deviceTermsSection7Body =>
      '本应用按“现状”和“现有可用”状态提供。我们会持续改进产品体验，但不保证应用始终无中断、无错误或完全满足你的特定业务需求。对于因你录入错误、未及时备份、设备故障、系统限制、第三方平台异常或不可抗力导致的损失，在适用法律允许范围内，开发者承担的责任以法律强制要求为限。';

  @override
  String get deviceTermsSection8Title => '8. 条款更新与联系';

  @override
  String get deviceTermsSection8Body =>
      '我们可能根据产品迭代、平台政策或法律法规变化对本条款进行更新。更新版本发布后，如你继续使用本应用，视为接受更新后的条款。如有问题，可联系：582748196@qq.com。';

  @override
  String get syncConflictReviewTitle => '同步冲突复核';

  @override
  String get syncConflictReviewEmpty => '暂无待复核冲突';

  @override
  String get syncConflictReviewLoadFailure => '冲突列表加载失败，请稍后重试';

  @override
  String get syncConflictResolveFailure => '裁决失败，请稍后重试';

  @override
  String get syncConflictReviewManualHint => '需要手动合并时，先保留本地，再到常规编辑页调整。';

  @override
  String syncConflictReviewEntityTitle(String entityId) {
    return '计时记录 $entityId';
  }

  @override
  String syncConflictReviewReason(String reason) {
    return '原因：$reason';
  }

  @override
  String get syncConflictReviewLocalLabel => '本地当前';

  @override
  String get syncConflictReviewRemoteLabel => '远端来袭';

  @override
  String get syncConflictReviewUseRemote => '用远端';

  @override
  String get syncConflictReviewUseLocal => '用本地';

  @override
  String get syncConflictReviewMissingLocal => '本地记录已不存在';

  @override
  String get syncConflictReviewMissingRemote => '远端记录无法解析';

  @override
  String get syncConflictReviewDeletedSummary => '已删除记录';

  @override
  String syncConflictReviewTimingSummary(
    int deviceId,
    String date,
    String hours,
    String amount,
  ) {
    return '设备 $deviceId · $date · $hours h · ¥$amount';
  }

  @override
  String get deviceRateEntryOpened => '已打开评分入口';

  @override
  String get deviceRateEntryUnavailable => '评分入口暂不可用';

  @override
  String get deviceSupportSiteOpened => '已打开技术支持网页';

  @override
  String get deviceSupportEmailFallback => '暂时无法打开支持页，已切换到邮件联系';

  @override
  String deviceSupportUnavailable(String email) {
    return '暂时无法打开支持页，请稍后重试或发送邮件到 $email';
  }

  @override
  String get deviceRestoreBlockIncompleteFormat => '备份文件格式不完整，暂不能恢复。';

  @override
  String get deviceRestoreBlockOlderUnsupported =>
      '当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。';

  @override
  String get deviceRestoreBlockNewerVersion => '备份文件版本较新，请升级 App 后再试。';

  @override
  String get deviceCustomAvatarNotAllowed => '当前方案不支持自定义头像';

  @override
  String get storeActionSaveSuccess => '已保存';

  @override
  String get storeActionDeleteSuccess => '已删除';

  @override
  String get storeActionUpdateSuccess => '已更新';

  @override
  String get storeActionCreateSuccess => '已新增';

  @override
  String get storeActionDeactivateSuccess => '已停用';

  @override
  String get storeActionReadSuccess => '已读取';

  @override
  String get storeActionSaveLabel => '保存';

  @override
  String get storeActionDeleteLabel => '删除';

  @override
  String get storeActionUpdateLabel => '更新';

  @override
  String get storeActionCreateLabel => '新增';

  @override
  String get storeActionDeactivateLabel => '停用';

  @override
  String get storeActionReadLabel => '读取';

  @override
  String storeActionFailureWithDetail(String action, String detail) {
    return '$action失败：$detail';
  }

  @override
  String storeActionFailureDatabase(String action) {
    return '$action失败：数据未保存，请稍后重试';
  }

  @override
  String storeActionFailureFileSystem(String action) {
    return '$action失败：请检查文件状态和访问权限';
  }
}
