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
}
