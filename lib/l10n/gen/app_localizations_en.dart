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
  String get timingEntryCreateSheetTitle => 'New timing';

  @override
  String get timingEntryEditSheetTitle => 'Edit timing';

  @override
  String get timingEntryCancelAction => 'Cancel';

  @override
  String get timingEntryDeleteRecordAction => 'Delete this record';

  @override
  String get timingEntryHistoryLoadFailure =>
      'Calculation history failed to load. You can keep editing';

  @override
  String get timingEntrySaveFailure => 'Save failed. Try again';

  @override
  String get timingEntryDeletePrecheckFailure =>
      'Delete check failed. Try again';

  @override
  String get timingEntryDeleteConfirmTitle => 'Delete timing record';

  @override
  String get timingEntryDeleteConfirmAction => 'Delete';

  @override
  String get timingEntryDeleteFailure => 'Delete failed. Try again';

  @override
  String get timingEntryDeleteBlockedTitle => 'Cannot delete';

  @override
  String get timingEntryDeleteBlockedConfirm => 'OK';

  @override
  String get timingEntryDeleteSettledConfirmContent =>
      'This project is settled. Deleting the timing record will reopen the settlement and recalculate the receivable from the updated project amount. Continue?';

  @override
  String get timingEntryDeleteLastRecordConfirmContent =>
      'After deleting, this project will no longer have local timing records, and related merge/external work links will be removed. Continue?';

  @override
  String get timingEntryDeleteDefaultConfirmContent =>
      'This cannot be undone. Delete this timing record?';

  @override
  String get timingEntryDeleted => 'Deleted';

  @override
  String get timingEntrySettlementRevoked => 'Settlement reopened';

  @override
  String get timingEntryMergeDissolved => 'Merge dissolved';

  @override
  String get timingEntryMergeMemberRemoved => 'Removed from merge';

  @override
  String get timingEntryExternalWorkUnlinked => 'External work unlinked';

  @override
  String get timingEntryDeleteCascadeSeparator => ', ';

  @override
  String timingEntryDeleteCascadeSuccess(String details) {
    return 'Deleted, $details';
  }

  @override
  String get timingEntryDeviceLabel => 'Device';

  @override
  String get timingEntryDeviceHint => 'Select device';

  @override
  String get timingEntryNoActiveDeviceHint =>
      'No active devices. Add one on the Devices tab first';

  @override
  String get timingEntryContactLabel => 'Contact';

  @override
  String get timingEntrySiteLabel => 'Work site/address';

  @override
  String get timingEntryStartWorkTimeLabel => 'Start work time';

  @override
  String get timingEntryEndWorkTimeLabel => 'End work time';

  @override
  String get timingEntryWorkHourBasisTooltip => 'Work hour calculation basis';

  @override
  String get timingEntryOptionalZeroHint => '0.0 (optional)';

  @override
  String get timingEntryAmountYuanLabel => 'Amount (CNY)';

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

  @override
  String commonRecentRecordsCount(int count) {
    return 'Recent records ($count)';
  }

  @override
  String get commonNoRecordsTitle => 'No records';

  @override
  String get commonCreateFromTopRightHint => 'Tap + at the top right to create';

  @override
  String get fuelPageTitle => 'Fuel';

  @override
  String get fuelCreateSheetTitle => 'Add fuel';

  @override
  String get fuelEditSheetTitle => 'Edit fuel';

  @override
  String get fuelCancelAction => 'Cancel';

  @override
  String get fuelConfirmAction => 'Done';

  @override
  String get fuelDeleteConfirmTitle => 'Delete fuel record?';

  @override
  String get fuelDeleteConfirmContent => 'This cannot be undone.';

  @override
  String get fuelDeleteConfirmAction => 'Delete';

  @override
  String fuelInactiveDeviceFallbackName(int id) {
    return 'Device $id (inactive/missing)';
  }

  @override
  String get fuelDeviceLabel => 'Device';

  @override
  String get fuelDeviceHint => 'Select device';

  @override
  String get fuelNoActiveDeviceHint =>
      'No active devices. Add one on the Devices tab first';

  @override
  String get fuelSupplierRequiredLabel => 'Supplier (required)';

  @override
  String get fuelSupplierHint => 'Example: Sinopec / Wang fuel';

  @override
  String get fuelLitersLabel => 'Fuel volume (L)';

  @override
  String get fuelLitersHint => 'Example: 120.0';

  @override
  String get fuelAmountYuanLabel => 'Amount (CNY)';

  @override
  String get fuelAmountHint => 'Example: 980.0';

  @override
  String get fuelEfficiencyTitle => 'Fuel efficiency by device';

  @override
  String get fuelEfficiencyEmpty =>
      'No data yet. Add fuel and timing records first';

  @override
  String get fuelSupplierFilterLabel => 'Filter: supplier';

  @override
  String get fuelSupplierFilterHint => 'Type a keyword to filter (optional)';

  @override
  String get maintenancePageTitle => 'Service';

  @override
  String get maintenanceCreateSheetTitle => 'Add service';

  @override
  String get maintenanceEditSheetTitle => 'Edit service';

  @override
  String get maintenanceCancelAction => 'Cancel';

  @override
  String get maintenanceConfirmAction => 'Done';

  @override
  String get maintenanceDeleteConfirmTitle => 'Delete service record?';

  @override
  String maintenanceDeleteConfirmDateLine(String date) {
    return 'Date: $date';
  }

  @override
  String maintenanceDeleteConfirmItemLine(String item) {
    return 'Item: $item';
  }

  @override
  String maintenanceDeleteConfirmAmountLine(String amount) {
    return 'Amount: $amount';
  }

  @override
  String get maintenanceDeleteConfirmWarning => 'This cannot be undone.';

  @override
  String get maintenanceDeleteConfirmAction => 'Delete';

  @override
  String get maintenanceSummaryEmpty => 'Current-year service cost: no data';

  @override
  String get maintenanceSummaryTitle =>
      'Current-year service cost (device & shared)';

  @override
  String get maintenancePublicExpenseLabel => 'Shared cost';

  @override
  String get maintenanceTotalLabel => 'Total';

  @override
  String get maintenancePublicExpenseSwitchTitle =>
      'Shared cost (not tied to a device)';

  @override
  String get maintenanceDeviceLabel => 'Device';

  @override
  String get maintenanceDeviceHint => 'Select device';

  @override
  String get maintenanceNoActiveDeviceHint =>
      'No active devices. Add one on the Devices tab first';

  @override
  String get maintenanceItemRequiredLabel => 'Service item (required)';

  @override
  String get maintenanceItemHint => 'Example: oil change / service / repair';

  @override
  String get maintenanceAmountYuanLabel => 'Amount (CNY)';

  @override
  String get maintenanceAmountHint => 'Example: 980.0';

  @override
  String get maintenanceNoteOptionalLabel => 'Notes (optional)';

  @override
  String get maintenanceNoteHint => 'Example: includes labor / parts';

  @override
  String get accountCancelAction => 'Cancel';

  @override
  String get accountConfirmAction => 'Done';

  @override
  String get accountDeleteAction => 'Delete';

  @override
  String get accountProjectTitleLabel => 'Projects';

  @override
  String get accountDensityNormalTooltip => 'Comfortable view';

  @override
  String get accountDensityCompactTooltip => 'Compact view';

  @override
  String get accountFilterAction => 'Filter';

  @override
  String get accountClearFilterAction => 'Clear filter';

  @override
  String get accountMergeAction => 'Merge';

  @override
  String get accountOverviewTitle => 'Overview';

  @override
  String get accountNoDeviceData => 'No device data';

  @override
  String get accountTotalReceivableLabel => 'Receivable';

  @override
  String get accountReceivedLabel => 'Received';

  @override
  String get accountRemainingLabel => 'Remaining';

  @override
  String get accountReceiptRatioLabel => 'Collection';

  @override
  String get accountNetReceivedTooltip =>
      'Received cash after deducting fuel, service, and paid external work project costs.';

  @override
  String get accountNetReceivedLabel => 'Net received';

  @override
  String get accountProjectMissing => 'Project does not exist or was removed';

  @override
  String get accountOwnedProjectsEmpty =>
      'No projects yet. Timing records will create them automatically';

  @override
  String get accountSettledIconLabel => 'Settled icon';

  @override
  String get accountExportWorklogTooltip => 'Export worklog';

  @override
  String get accountExternalPayableLabel => 'External payable';

  @override
  String get accountExternalReceivableLabel => 'Project receivable';

  @override
  String get accountPendingSetup => 'Not set';

  @override
  String get accountGrossProfitLabel => 'Gross profit';

  @override
  String get accountPendingCalculation => 'Pending';

  @override
  String get accountExternalWorkAvatarLabel => 'EXT';

  @override
  String get accountExternalProjectsTitle => 'External projects';

  @override
  String get accountExternalProjectsEmpty =>
      'No external projects yet. Unlinked external work imports will appear here';

  @override
  String get accountProjectDetailTitle => 'Project details';

  @override
  String get accountCloseTooltip => 'Close';

  @override
  String get accountLocalDeviceLabel => 'Local devices';

  @override
  String get accountExternalDeviceLabel => 'External devices';

  @override
  String get accountBatchEditAction => 'Batch edit';

  @override
  String get accountDissolveMergeAction => 'Dissolve merge';

  @override
  String get accountPaymentsTitle => 'Payments';

  @override
  String get accountNoPayments => 'No payment records';

  @override
  String get accountEditAction => 'Edit';

  @override
  String get accountEquipmentMissing => 'No equipment';

  @override
  String accountRecordCountLabel(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$base · $_temp0';
  }

  @override
  String get accountAddPaymentAction => '+ Add payment';

  @override
  String accountProjectTotalSummary(String amount) {
    return 'Project total $amount';
  }

  @override
  String get accountSettledStatus => 'Settled';

  @override
  String get accountSettledRevokeAction => 'Settled, tap to revoke';

  @override
  String accountReceivedPercent(String percent) {
    return 'Received $percent%';
  }

  @override
  String accountPendingReceivable(String amount) {
    return 'Pending $amount';
  }

  @override
  String get accountSettleAction => 'Settle';

  @override
  String get accountRateSectionLabel => 'Device rates';

  @override
  String accountBreakingDeviceLabel(String name) {
    return '$name · breaker';
  }

  @override
  String accountPaymentRemarkLine(String remark) {
    return 'Note: $remark';
  }

  @override
  String get accountMergedPaymentSaveSuccess => 'Saved';

  @override
  String accountSaveFailureWithReason(String reason) {
    return 'Save failed: $reason';
  }

  @override
  String get accountSaved => 'Saved';

  @override
  String get accountMergedPaymentDeleteTitle => 'Delete payment?';

  @override
  String accountMergedPaymentDeleteContent(String date, String amount) {
    return 'This will delete the merged payment and its allocations:\n$date  $amount\n\nTiming records will not be deleted.';
  }

  @override
  String get accountDeleted => 'Deleted';

  @override
  String accountDeleteFailureWithReason(String reason) {
    return 'Delete failed: $reason';
  }

  @override
  String get accountDissolveMergeSuccess => 'Merge dissolved';

  @override
  String get accountDeleteConfirmTitle => 'Delete?';

  @override
  String accountPaymentDeleteConfirmContent(String date, String amount) {
    return 'Date: $date\nAmount: $amount';
  }

  @override
  String get accountWriteOffRevoked =>
      'Write-off revoked. Pending amount restored';

  @override
  String accountRevokeWriteOffFailure(String reason) {
    return 'Failed to revoke write-off: $reason';
  }

  @override
  String get accountWriteOffInvalid =>
      'This project\'s write-off record is inconsistent. Check write-off records first.';

  @override
  String get accountSettlementRevoked => 'Settlement status revoked';

  @override
  String accountRevokeSettlementFailure(String reason) {
    return 'Failed to revoke settlement status: $reason';
  }

  @override
  String get accountMergedMemberInvalid =>
      'Merged project members are inconsistent. Refresh and try again.';

  @override
  String get accountMergeSuccess => 'Merged';

  @override
  String get accountShareProjectTooltip => 'Share project';

  @override
  String get accountShareNameRequired =>
      'Enter the sender name or package name';

  @override
  String get accountShareProjectTitle => 'Share project';

  @override
  String get accountShareNameLabel => 'Sender name (you)';

  @override
  String get accountShareNameHint => 'Example: Wang, Zhang';

  @override
  String get accountShareNameHelp =>
      'The recipient will see this name under External projects after import.';

  @override
  String get accountGenerateSharePackageAction => 'Generate package';

  @override
  String get accountSettlementAlreadySettled => 'Project is already settled';

  @override
  String get accountInputInvalid => 'Invalid input';

  @override
  String get accountSaveFailureGeneric => 'Save failed. Try again later';

  @override
  String get accountSettlementDialogTitle => 'Settle project';

  @override
  String get accountWriteOffAmountLabel => 'Write-off amount';

  @override
  String get accountWriteOffReasonLabel =>
      'Write-off/reduction reason (optional)';

  @override
  String get accountSettlementHelper =>
      'After confirmation, this pending amount is treated as a write-off. It will no longer count as pending or received.';

  @override
  String get accountConfirmSettlementAction => 'Confirm settlement';

  @override
  String accountDeviceCountLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get accountDiggingBatchRateLabel => 'Bucket rate (integer)';

  @override
  String get accountBreakingBatchRateLabel => 'Breaker rate (integer)';

  @override
  String get accountBatchRateHelper =>
      'After saving, all devices in this project will update bucket/breaker rates separately. If a rate matches the device default, the override record is cleared.';

  @override
  String get accountSingleRateLabel => 'Rate';

  @override
  String get accountSingleRateHelper =>
      'Tip: changing back to the device default rate clears the override record.';

  @override
  String accountBatchRateTitle(String project) {
    return 'Batch edit rates: $project';
  }

  @override
  String accountBreakingRateTitle(String project) {
    return 'Edit breaker rate: $project';
  }

  @override
  String accountSingleRateTitle(String project) {
    return 'Edit rate: $project';
  }

  @override
  String get accountUpdated => 'Updated';

  @override
  String get accountFilterSheetTitle => 'Filter projects';

  @override
  String get accountFilterKeywordLabel => 'Keyword (contact / site)';

  @override
  String get accountFilterKeywordHint =>
      'Example: Wang / Xiuwen / metro station';

  @override
  String get accountClearAction => 'Clear';

  @override
  String get accountPaymentCreateTitle => 'Add payment';

  @override
  String get accountPaymentEditTitle => 'Edit payment';

  @override
  String accountProjectLine(String project) {
    return 'Project: $project';
  }

  @override
  String get accountPaymentAmountIntegerLabel => 'Amount (integer)';

  @override
  String get accountNoteOptionalLabel => 'Notes (optional)';

  @override
  String accountPaymentReceivableReceivedLine(
    String receivable,
    String received,
  ) {
    return 'Receivable: $receivable, received: $received';
  }

  @override
  String accountMergeFailureWithReason(String reason) {
    return 'Merge failed: $reason';
  }

  @override
  String get accountMergeSheetTitle => 'Merge projects';

  @override
  String get accountMergingAction => 'Merging';

  @override
  String get accountNoMergeableProjects => 'No mergeable projects';

  @override
  String get accountUnmergedSection => 'Unmerged';

  @override
  String get accountMergedSection => 'Merged';

  @override
  String get accountDissolveConfirmTitle => 'Dissolve merge?';

  @override
  String get accountDissolveIntro =>
      'After dissolving, these will return to normal projects:';

  @override
  String get accountDissolveHelp =>
      'Original timing records will not be deleted.\nDevices, hours, and rates will not change.';

  @override
  String get accountDissolvingAction => 'Dissolving';

  @override
  String accountDissolveFailureWithReason(String reason) {
    return 'Dissolve merge failed: $reason';
  }
}
