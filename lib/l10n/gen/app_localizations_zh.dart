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
  String timingChartYearLabel(int year) {
    return '$year年';
  }

  @override
  String get timingChartIncomeLegend => '收入';

  @override
  String get timingChartNetIncomeValueLabel => '净入';

  @override
  String get timingChartExpenseLabel => '支出';
}
