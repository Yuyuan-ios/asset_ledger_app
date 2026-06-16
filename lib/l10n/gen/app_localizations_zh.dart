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
}
