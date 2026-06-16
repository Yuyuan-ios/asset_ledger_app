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

  @override
  String get timingExternalWorkLinkSheetTitle => 'Link to project';

  @override
  String get timingExternalWorkSelectPackage => 'Select external work package';

  @override
  String get timingExternalWorkPackageSummary => 'Package summary';

  @override
  String get timingExternalWorkCancelAction => 'Cancel';

  @override
  String get timingExternalWorkUnlinkAction => 'Unlink';

  @override
  String get timingExternalWorkConfirmLinkAction => 'Confirm link';

  @override
  String timingExternalWorkLinkedProject(String title) {
    return 'Linked: $title';
  }

  @override
  String get timingExternalWorkSelectProject => 'Select project to link';

  @override
  String get timingExternalWorkNoLinkableProjects =>
      'No local projects available';

  @override
  String timingExternalWorkSettledCandidateTitle(String title) {
    return '$title (settled)';
  }

  @override
  String get timingExternalWorkSettledHint =>
      'This project is settled. Linking the external work package will reopen it and recalculate the receivable from the updated project total.';

  @override
  String get timingExternalWorkSettledConfirmTitle => 'Link settled project';

  @override
  String get timingExternalWorkSettledConfirmContent =>
      'This project is settled. Linking the external work package will reopen it and recalculate the receivable from the updated project total. Continue?';

  @override
  String get timingExternalWorkContinueAction => 'Continue';

  @override
  String get timingExternalWorkDefaultLinkedProjectTitle => 'Linked project';

  @override
  String timingExternalWorkPackageRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String get timingExternalWorkSiteSummarySeparator => ', ';

  @override
  String get timingExternalWorkLinkSuccess => 'Linked to project';

  @override
  String get timingExternalWorkLinkSettledSuccess =>
      'Linked to project and settlement reopened';

  @override
  String get timingExternalWorkLinkFailure => 'Link failed. Try again';

  @override
  String get timingExternalWorkUnlinkConfirmTitle => 'Unlink';

  @override
  String get timingExternalWorkUnlinkConfirmContent =>
      'After unlinking, this external work package will remain as an independent external project. External work records will not be deleted. Continue?';

  @override
  String get timingExternalWorkUnlinkSuccess =>
      'Unlinked. External work records kept';

  @override
  String get timingExternalWorkUnlinkFailure => 'Unlink failed. Try again';

  @override
  String timingChartYearLabel(int year) {
    return '$year';
  }

  @override
  String get timingChartIncomeLegend => 'Income';

  @override
  String get timingChartNetIncomeValueLabel => 'Net';

  @override
  String get timingChartExpenseLabel => 'Expense';
}
