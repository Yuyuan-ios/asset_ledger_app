// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleet Ledger';

  @override
  String get tabTiming => 'Timing';

  @override
  String get tabEnergy => 'Energy';

  @override
  String get tabAccount => 'Accounts';

  @override
  String get tabMaintenance => 'Service';

  @override
  String get tabDevice => 'Devices';

  @override
  String get timingCalculatorExpressionPlaceholder => 'Work hour expression';

  @override
  String get timingCalculatorNoResult => 'Not calculated';

  @override
  String timingCalculatorResult(String value) {
    return 'Result $value h';
  }

  @override
  String get timingCalculatorApplyButton => 'Apply';

  @override
  String get timingCalculationHistoryEmpty => 'No calculation records';

  @override
  String timingCalculationHistoryMeta(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tickets',
      one: '1 ticket',
    );
    return '$date | $_temp0';
  }

  @override
  String get timingCalculationAppliedBadge => 'Applied to hours';

  @override
  String get timingAttachmentDigging => 'Bucket';

  @override
  String get timingAttachmentBreaking => 'Breaker';

  @override
  String get timingRecentRecordsTitle => 'Recent records';

  @override
  String get timingExternalWorkProjectsTitle => 'External work';

  @override
  String get timingAllDevicesFilter => 'All devices';

  @override
  String get timingExternalWorkImportAction => 'Import';

  @override
  String get timingExternalWorkLinkAction => 'Link';

  @override
  String timingRecentRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String timingRecentAggregateSummary(String error, String total) {
    return 'Error $error, total $total';
  }

  @override
  String get timingRecentAggregateExpanded => 'expanded';

  @override
  String get timingRecentAggregateCollapsed => 'grouped';

  @override
  String get timingRecentBreakingBadge => 'Breaker';
}
