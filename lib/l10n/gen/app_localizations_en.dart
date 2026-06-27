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
  String get commonCreateAction => '+ New';

  @override
  String get timingSectionHeaderTitle => 'Timing';

  @override
  String get appUpdateActionUpdateNow => 'Update now';

  @override
  String get appUpdateActionLater => 'Later';

  @override
  String get appUpdateFallbackTitle => 'Update available';

  @override
  String get appUpdateFallbackContent => 'Update for a more stable experience.';

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
  String get externalWorkPickInvalidType =>
      'Select a FleetLedger .jzt share package';

  @override
  String get externalWorkPickReadFailure =>
      'Failed to read the share package. Select the file again';

  @override
  String get externalWorkPickFileTooLarge =>
      'The share package is too large to import';

  @override
  String get externalWorkImportPreviewTitle => 'External work records';

  @override
  String get externalWorkImportPreviewImportingAction => 'Importing';

  @override
  String get externalWorkImportPreviewSectionTitle => 'Preview';

  @override
  String get externalWorkImportPreviewSenderLabel => 'From';

  @override
  String get externalWorkImportPreviewRecordLabel => 'Records';

  @override
  String externalWorkImportPreviewRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String get externalWorkImportPreviewSiteLabel => 'Site';

  @override
  String get externalWorkImportPreviewTotalHoursLabel => 'Total hours';

  @override
  String get externalWorkImportPreviewTotalAmountLabel => 'Total amount';

  @override
  String get externalWorkImportPreviewLinesTitle => 'Record details';

  @override
  String externalWorkImportPreviewHoursValue(String hours) {
    return '$hours h';
  }

  @override
  String get externalWorkImportPreviewStatusImportable => 'Ready to import';

  @override
  String get externalWorkImportPreviewStatusImported => 'Already imported';

  @override
  String get externalWorkImportPreviewStatusSameSource => 'Same source exists';

  @override
  String get externalWorkImportPreviewStatusSuspiciousDuplicate =>
      'Possible duplicate';

  @override
  String externalWorkImportPreviewSameSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count same-source records',
      one: '1 same-source record',
    );
    return '$_temp0';
  }

  @override
  String externalWorkImportPreviewSuspiciousCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possible duplicates',
      one: '1 possible duplicate',
    );
    return '$_temp0';
  }

  @override
  String externalWorkImportPreviewImportedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count external work records',
      one: '1 external work record',
    );
    return 'Imported $_temp0';
  }

  @override
  String externalWorkImportPreviewSuccessBanner(String message) {
    return '$message. You can view it in external work records';
  }

  @override
  String get externalWorkImportPreviewGenericPrepareFailure =>
      'Failed to build the import preview. Try again later';

  @override
  String get externalWorkImportPreviewGenericImportFailure =>
      'Import failed. Try again later';

  @override
  String get externalWorkImportPreviewEmptyContent =>
      'Select or paste .jzt content first';

  @override
  String get externalWorkImportPreviewInvalidJson =>
      'The share package is not valid JSON';

  @override
  String get externalWorkImportPreviewInvalidPackage =>
      'This is not a valid FleetLedger share package';

  @override
  String get externalWorkImportPreviewUnsupportedVersion =>
      'This share package version is not supported';

  @override
  String get externalWorkImportPreviewUnsupportedPackage =>
      'This share package type is not supported';

  @override
  String get externalWorkImportPreviewIncompleteIntegrity =>
      'The share package integrity info is incomplete';

  @override
  String get externalWorkImportPreviewHashMismatch =>
      'Share package verification failed. Get the package again';

  @override
  String get externalWorkImportPreviewInvalidRecords =>
      'Share package records are incomplete or malformed';

  @override
  String get externalWorkImportPreviewInvalidBaseInfo =>
      'Share package base info is incomplete or malformed';

  @override
  String get externalWorkImportPreviewParseFailure =>
      'Unable to parse the share package';

  @override
  String get externalWorkImportPreviewDuplicateRejected =>
      'This share package was already imported or contains records from the same source';

  @override
  String get externalWorkRecordsEmptyTitle => 'No external work records';

  @override
  String get externalWorkRecordsEmptySubtitle =>
      'Records imported from shared .jzt files will appear here';

  @override
  String get externalWorkRecordsSourceImported => 'Imported from share package';

  @override
  String externalWorkRecordsBulletCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return ' • $_temp0';
  }

  @override
  String externalWorkRecordsMoreDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return ' + $_temp0';
  }

  @override
  String get externalWorkRecordsMissingDevice => 'Device not provided';

  @override
  String get externalWorkRecordsUnknown => 'Unknown';

  @override
  String get externalWorkRecordsStatusLinked => 'Linked';

  @override
  String get externalWorkRecordsStatusPending => 'Pending';

  @override
  String get externalWorkRecordsStatusIgnored => 'Ignored';

  @override
  String get externalWorkRecordsStatusArchived => 'Archived';

  @override
  String get externalWorkRecordsStatusVoided => 'Voided';

  @override
  String externalWorkRecordsYearLabel(int year) {
    return '$year';
  }

  @override
  String get externalWorkRecordsSourceLabel => 'Source';

  @override
  String get externalWorkRecordsSourceNameLabel => 'Shared by';

  @override
  String get externalWorkRecordsSiteLabel => 'Site';

  @override
  String get externalWorkRecordsDeviceLabel => 'Device';

  @override
  String get externalWorkRecordsDateLabel => 'Date';

  @override
  String get externalWorkRecordsHoursQuantityLabel => 'Hours / qty';

  @override
  String get externalWorkRecordsUnitPriceLabel => 'Unit price';

  @override
  String get externalWorkRecordsAmountLabel => 'Amount';

  @override
  String get externalWorkRecordsProjectReceivedLabel => 'Project received';

  @override
  String get externalWorkRecordsImportedAtLabel => 'Imported at';

  @override
  String get externalWorkRecordsCurrentStatusLabel => 'Status';

  @override
  String get externalWorkRecordsReadOnlyNotice =>
      'This record was shared by someone else and cannot be edited now.';

  @override
  String get externalWorkRecordsLinkAction => 'Link to local project';

  @override
  String get externalWorkRecordsAvatarLabel => 'EXT';

  @override
  String get externalWorkDetailSheetTitle => 'External work details';

  @override
  String get externalWorkDeleteSharePackageAction => 'Delete share package';

  @override
  String get externalWorkDeleteSharePackageTitle => 'Delete share package';

  @override
  String externalWorkDeleteSharePackageContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count external work records',
      one: '1 external work record',
    );
    return 'This will delete all $_temp0 imported from this share package. This cannot be undone.';
  }

  @override
  String get externalWorkDeleteAction => 'Delete';

  @override
  String get externalWorkReadAction => 'Read';

  @override
  String get externalWorkConfirmAction => 'OK';

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
  String get timingEntryLimitProTitle => 'Pro required';

  @override
  String get timingEntryLimitProMessage =>
      'The free plan supports up to 30 timing records. Upgrade to Pro to keep adding and maintaining more timing records.';

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
  String get fuelPageTitle => 'Energy';

  @override
  String get fuelCreateSheetTitle => 'Add energy';

  @override
  String get fuelEditSheetTitle => 'Edit energy';

  @override
  String get fuelCancelAction => 'Cancel';

  @override
  String get fuelConfirmAction => 'Done';

  @override
  String get fuelDeleteConfirmTitle => 'Delete energy record?';

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
  String get fuelSupplierHint => 'Example: Sinopec / charging station';

  @override
  String get fuelLitersLabel => 'Energy amount (L/kWh)';

  @override
  String get fuelLitersHint => 'Example: 120.0';

  @override
  String get fuelAmountYuanLabel => 'Amount (CNY)';

  @override
  String get fuelAmountHint => 'Example: 980.0';

  @override
  String get fuelEfficiencyTitle => 'Energy efficiency by device';

  @override
  String get fuelEfficiencyEmpty =>
      'No data yet. Add energy and timing records first';

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
      'Received cash after deducting energy, service, and paid external work project costs.';

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
  String accountExternalReceivableWithCustomerRate(String rate) {
    return 'Project receivable (receivable rate $rate)';
  }

  @override
  String accountExternalPayableWithSourceRate(String rate) {
    return 'Project payable (payable rate $rate)';
  }

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
  String get accountExternalWorkDetailTitle => 'External work details';

  @override
  String accountExternalHoursSummary(String hours) {
    return 'Hours $hours h';
  }

  @override
  String get accountExternalCustomerRateLabel => 'Receivable rate';

  @override
  String accountExternalPayableTotalSummary(String amount) {
    return 'Payable total $amount';
  }

  @override
  String accountExternalPaidPercent(int percent) {
    return 'Paid $percent%';
  }

  @override
  String accountExternalUnpaidAmount(String amount) {
    return 'Unpaid $amount';
  }

  @override
  String get accountExternalPaymentRecordsTitle => 'Payment records';

  @override
  String get accountExternalAddPayableAction => '+ Add payment';

  @override
  String get accountExternalPaymentsEmpty => 'Payment records coming soon';

  @override
  String get accountExternalCustomerRateEditTitle => 'Set receivable rate';

  @override
  String get accountExternalCustomerRateInputHint => 'Receivable rate (yuan)';

  @override
  String get accountExternalCustomerRateInvalid => 'Enter a valid amount';

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
  String get accountSettledPaymentSaveConfirmTitle =>
      'Reopen settlement and save payment?';

  @override
  String get accountSettledPaymentSaveConfirmContent =>
      'This project is settled. Saving this payment will first reopen the settlement and revoke the settlement write-off. Continue?';

  @override
  String accountSettledPaymentDeleteConfirmContent(String date, String amount) {
    return 'This project is settled. Deleting this payment will first reopen the settlement and revoke the settlement write-off.\n\nDate: $date\nAmount: $amount\n\nContinue?';
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
      'After saving, all devices in this project will update bucket/breaker project rates. Only this project is affected.';

  @override
  String get accountSingleRateLabel => 'Rate';

  @override
  String get accountSingleRateHelper =>
      'Tip: this rate is saved as this project\'s project rate. Only this project is affected.';

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

  @override
  String get deviceCancelAction => 'Cancel';

  @override
  String get deviceConfirmAction => 'OK';

  @override
  String get deviceDoneAction => 'Got it';

  @override
  String get devicePageTitle => 'Devices';

  @override
  String get deviceSearchHint => 'Search';

  @override
  String get deviceAccountSyncSectionTitle => 'Account & Sync';

  @override
  String get deviceAccountCenterTitle => 'Account center';

  @override
  String get deviceProfileSectionTitle => 'Profile';

  @override
  String get deviceUpgradeNowTitle => 'Upgrade now';

  @override
  String get deviceEquipmentSectionTitle => 'Equipment';

  @override
  String get deviceAddDeviceAction => 'Add device';

  @override
  String get deviceRateUsSectionTitle => 'Rate us';

  @override
  String get deviceRateAppAction => 'Rate the app';

  @override
  String get deviceTermsSectionTitle => 'Terms';

  @override
  String get deviceTermsTitle => 'Terms of Use';

  @override
  String get devicePrivacyTitle => 'Privacy Policy';

  @override
  String get deviceSupportSectionTitle => 'Support & Feedback';

  @override
  String get deviceContactDeveloperAction => 'Contact developer';

  @override
  String get deviceManagementTitle =>
      'Manage devices (long press icon to deactivate)';

  @override
  String get deviceEquipmentExcavator => 'Excavator';

  @override
  String get deviceEquipmentLoader => 'Loader';

  @override
  String get deviceEditorCreateTitle => 'Add device';

  @override
  String get deviceEditorEditTitle => 'Edit device';

  @override
  String get deviceBrandNotSelected => 'No brand selected (avatar)';

  @override
  String deviceBrandSelectedLine(
    String equipmentType,
    String brand,
    String preview,
  ) {
    return 'Brand: $equipmentType  $brand$preview';
  }

  @override
  String get deviceSelectAction => 'Select';

  @override
  String get deviceAvatarBrandDefault => 'Avatar: brand default';

  @override
  String get deviceAvatarCustomSet => 'Avatar: custom image set';

  @override
  String get deviceGalleryAction => 'Gallery';

  @override
  String get deviceDefaultAction => 'Default';

  @override
  String get deviceBaseMeterLabel => 'Base meter (>= 0, required)';

  @override
  String get deviceDefaultRateLabel => 'Default rate (> 0, required)';

  @override
  String get deviceBreakingRateOptionalLabel => 'Breaker rate (optional)';

  @override
  String get deviceBreakingRateHint =>
      'Leave blank if this device has no breaker';

  @override
  String get deviceModelOptionalLabel => 'Model (optional)';

  @override
  String get deviceCustomAvatarProTitle => 'Upgrade required';

  @override
  String get deviceCustomAvatarProMessage =>
      'Custom device avatars are a Pro feature. Upgrade to set a dedicated avatar for each device.';

  @override
  String get deviceAvatarGalleryChanged => 'Avatar changed from gallery';

  @override
  String deviceAvatarSaveFailure(String error) {
    return 'Avatar save failed: $error';
  }

  @override
  String get deviceAvatarSelectTitle => 'Choose device avatar';

  @override
  String get deviceAvatarEmpty =>
      'No brands in this category. Choose another type or add a custom avatar.';

  @override
  String get deviceBrandCountryChina => 'China';

  @override
  String get deviceBrandCountryJapan => 'Japan';

  @override
  String get deviceBrandCountryUs => 'United States';

  @override
  String get deviceBrandCountryKorea => 'Korea';

  @override
  String get deviceTypeSelectTitle => 'Select device type & brand';

  @override
  String get deviceTypeMoreChip => 'More';

  @override
  String get deviceTypeSheetTitle => 'Select device type';

  @override
  String get deviceTypeSearchHint => 'Search device type';

  @override
  String get deviceTypeSheetEmpty => 'No matching device type';

  @override
  String get deviceTypeComingSoonBadge => 'Coming soon';

  @override
  String deviceTypeComingSoonCta(String type) {
    return '$type creation coming soon';
  }

  @override
  String deviceCreateNextCta(String type) {
    return 'Next: create $type';
  }

  @override
  String get deviceBrandSectionTitle => 'Select brand';

  @override
  String get deviceBrandSearchHint => 'Search brand / enter custom';

  @override
  String get deviceBrandSearchEmptyTitle => 'No matching brand';

  @override
  String deviceBrandEmptyForType(String type) {
    return 'No $type brands yet — use a custom brand';
  }

  @override
  String get deviceBrandUseCustom => 'Use custom brand';

  @override
  String deviceBrandResetNotice(String type) {
    return 'Switched to $type; brand reset';
  }

  @override
  String get deviceBrandCustomDialogTitle => 'Custom brand';

  @override
  String get deviceBrandCustomDialogHint => 'Enter brand name';

  @override
  String get deviceBrandCustomConfirm => 'OK';

  @override
  String get deviceCategoryConstruction => 'Construction machinery';

  @override
  String get deviceCategoryAgriculture => 'Agricultural equipment';

  @override
  String get deviceCategoryUnmanned => 'Unmanned';

  @override
  String get deviceCategorySmart => 'Smart devices';

  @override
  String get deviceCategoryOther => 'Other';

  @override
  String get deviceTypeExcavatorDesc => 'Earthwork / mining / construction';

  @override
  String get deviceTypeLoaderDesc => 'Loading / transfer / construction';

  @override
  String get deviceTypeRollerName => 'Road roller';

  @override
  String get deviceTypeRollerDesc => 'Road / compaction / construction';

  @override
  String get deviceTypeHandlingVehicleName => 'Handling vehicle';

  @override
  String get deviceTypeHandlingVehicleDesc => 'Loading / transfer / handling';

  @override
  String get deviceTypeCraneName => 'Crane';

  @override
  String get deviceTypeCraneDesc => 'Lifting / hoisting / hauling';

  @override
  String get deviceTypeForkliftName => 'Forklift';

  @override
  String get deviceTypeForkliftDesc => 'Forking / warehousing / stacking';

  @override
  String get deviceTypeAgriMachineName => 'Agricultural machine';

  @override
  String get deviceTypeAgriMachineDesc => 'Farmland / operation / production';

  @override
  String get deviceTypeDroneName => 'Drone';

  @override
  String get deviceTypeDroneDesc => 'Inspection / spraying / mapping';

  @override
  String get deviceTypeRobotName => 'Robot';

  @override
  String get deviceTypeRobotDesc => 'Inspection / operation / interaction';

  @override
  String get deviceTypeCustomName => 'Custom device';

  @override
  String get deviceTypeCustomDesc => 'Other / custom';

  @override
  String get devicePickerLabel => 'Device ID';

  @override
  String get devicePickerEmptyHint =>
      'No active devices. Add one on the Devices page first.';

  @override
  String devicePickerItemWithMeter(String name, String meter) {
    return '$name (meter $meter h)';
  }

  @override
  String get devicePickerUnknownDevice => 'Unknown device';

  @override
  String devicePickerInactiveItemWithMeter(String name, String meter) {
    return '$name (inactive · meter $meter h)';
  }

  @override
  String get devicePickerUnknownInactive => 'Unknown device (inactive)';

  @override
  String get deviceDeactivateTitle => 'Deactivate device?';

  @override
  String deviceDeactivateContent(String name) {
    return 'Device: $name\n\nThis only deactivates the device. Timing, energy, and income history will not be deleted.\nAfter deactivation:\n• The device is hidden from the default Devices page\n• It can no longer be selected in timing dropdowns\n• Historical records still display by deviceId';
  }

  @override
  String get deviceDeactivateAction => 'Deactivate';

  @override
  String get deviceSaveAction => 'Save';

  @override
  String get deviceReadAction => 'Load';

  @override
  String get deviceSaveCreated => 'Device added';

  @override
  String get deviceSaveUpdated => 'Device updated';

  @override
  String get deviceDeactivateSuccess => 'Deactivated (history is kept)';

  @override
  String get deviceSaveFailureDataNotSaved =>
      'Save failed: data was not saved. Try again later';

  @override
  String get deviceLifecycleSetCostAction =>
      'Tap to set cost and residual value';

  @override
  String get deviceLifecycleNetProfitFormula =>
      'Lifecycle net profit = received + residual value - initial cost';

  @override
  String get deviceLifecyclePaybackNoCostStatus => 'Cost not set';

  @override
  String get deviceLifecyclePaybackNoCostResult =>
      'Set it to see payback progress and projected surplus';

  @override
  String deviceLifecyclePaybackPaidBackMultiplier(String multiplier) {
    return 'Paid back ${multiplier}x';
  }

  @override
  String get deviceLifecyclePaybackPaidBackFull => 'Paid back 100%';

  @override
  String deviceLifecyclePaybackPaidBackPercent(String percent) {
    return 'Paid back $percent%';
  }

  @override
  String deviceLifecyclePaybackPercentInProgress(String percent) {
    return 'Payback $percent%';
  }

  @override
  String deviceLifecyclePaybackProfit(String amount) {
    return 'Projected surplus $amount';
  }

  @override
  String get deviceLifecyclePaybackBreakeven => 'Paid back, no surplus yet';

  @override
  String deviceLifecyclePaybackShortfall(String amount) {
    return '$amount left to pay back';
  }

  @override
  String deviceLifecycleInitialInvestmentSemantics(String amount) {
    return 'Initial investment $amount';
  }

  @override
  String get deviceLifecycleInitialInvestmentUnsetValue => 'not set';

  @override
  String deviceLifecycleNetReceivedSemantics(String amount) {
    return 'Net received $amount';
  }

  @override
  String deviceLifecycleEstimatedResidualSemantics(String amount) {
    return 'Estimated resale residual $amount';
  }

  @override
  String deviceLifecyclePendingReceivableSemantics(String amount) {
    return 'Pending $amount';
  }

  @override
  String deviceLifecycleOperationSummary(String hours, int count) {
    return 'Operated: ${hours}h / $count items';
  }

  @override
  String get deviceLifecycleInitialInvestmentUnset =>
      'Initial investment not set';

  @override
  String deviceLifecycleInitialInvestmentAmount(String amount) {
    return 'Initial investment $amount';
  }

  @override
  String get deviceLifecycleSurplusLabel => 'Surplus';

  @override
  String get deviceLifecyclePaybackGapLabel => 'Payback gap';

  @override
  String get deviceLifecycleReceivedPrincipalLabel => 'Received principal';

  @override
  String get deviceLifecycleNetReceivedLabel => 'Net received';

  @override
  String get deviceLifecycleEstimatedResidualLabel =>
      'Estimated resale residual';

  @override
  String deviceLifecyclePendingReceivableLabel(String amount) {
    return 'Pending $amount';
  }

  @override
  String get deviceLifecycleAmountSheetTitle => 'Set device lifecycle amounts';

  @override
  String get deviceLifecycleAmountUpdateAction => 'Update';

  @override
  String get deviceLifecycleInitialCostLabel => 'Initial cost';

  @override
  String get deviceLifecycleEstimatedResidualInputLabel =>
      'Estimated resale residual';

  @override
  String get deviceLifecycleProjectedSurplusTitle => 'Projected surplus';

  @override
  String get deviceLifecyclePaybackRemainingTitle => 'Remaining to pay back';

  @override
  String get deviceLifecycleEstimatedResidualFormulaLabel =>
      '+ Estimated resale residual';

  @override
  String get deviceLifecycleInitialCostFormulaLabel => '- Initial cost';

  @override
  String get deviceLifecycleNetProfitFormulaLabel => '= Lifecycle net profit';

  @override
  String get deviceAccountStatusSectionTitle => 'Account status';

  @override
  String get deviceAccountCenterLoggedOutSubtitle =>
      'Not logged in · Log in for cloud backup';

  @override
  String deviceAccountCenterLoggedInSubtitle(String entitlement) {
    return 'Logged in · $entitlement';
  }

  @override
  String deviceAccountCenterLoggedInTailSubtitle(
    String tail,
    String entitlement,
  ) {
    return 'Logged in · ending $tail · $entitlement';
  }

  @override
  String get deviceAccountLoggedInTitle => 'Logged in';

  @override
  String get deviceAccountLoggedOutTitle => 'Not logged in';

  @override
  String get deviceAccountAuthLoggedOutSubtitle =>
      'Log in to use cloud backup and restore';

  @override
  String deviceAccountAuthTailSubtitle(String tail, String entitlement) {
    return 'Ending $tail · $entitlement';
  }

  @override
  String get deviceEntitlementPro => 'Pro active';

  @override
  String get deviceEntitlementMax => 'Max active';

  @override
  String get deviceEntitlementFree => 'Free plan';

  @override
  String deviceEntitlementExpires(String entitlement, String date) {
    return '$entitlement · valid until $date';
  }

  @override
  String get devicePhoneLoginAction => 'Phone login';

  @override
  String get devicePhoneLoginSubtitle =>
      'Log in to use cloud backup and purchase entitlement sync';

  @override
  String get devicePurchaseSectionTitle => 'Purchases';

  @override
  String get deviceUpgradeProTitle =>
      'Upgrade to Pro and support ongoing maintenance';

  @override
  String get deviceUpgradeProSubtitle => 'Remove the 30 timing record limit';

  @override
  String get deviceUpgradeProPrice => '6 yuan/year';

  @override
  String get deviceUpgradeProAction => 'Upgrade to Pro';

  @override
  String get deviceUpgradeMaxTitle => 'Upgrade to Max for cloud backup';

  @override
  String get deviceUpgradeMaxSubtitle =>
      'Includes Pro, with cloud backup and restore';

  @override
  String get deviceUpgradeMaxPrice => '24 yuan/year';

  @override
  String get deviceUpgradeMaxAction => 'Upgrade to Max';

  @override
  String get deviceRestorePurchasesAction => 'Restore purchases';

  @override
  String get deviceRestorePurchasesSubtitle =>
      'Restore purchased entitlements from the App Store';

  @override
  String get deviceRestoreResultRestoredPro => 'Pro subscription restored';

  @override
  String get deviceRestoreResultRestoredMax => 'Max subscription restored';

  @override
  String get deviceRestoreResultNoPurchase => 'No purchases to restore';

  @override
  String deviceRestoreResultFailed(String reason) {
    return 'Restore failed: $reason';
  }

  @override
  String deviceRestoreResultUnavailable(String reason) {
    return 'Subscription service unavailable: $reason';
  }

  @override
  String get deviceDataSecuritySectionTitle => 'Data safety';

  @override
  String get deviceCloudBackupTitle => 'Cloud backup';

  @override
  String get deviceCloudBackupAuthedSubtitle =>
      'Max feature. Upload current data and restore it when needed';

  @override
  String get deviceCloudBackupLoginSubtitle =>
      'Log in to use cloud backup and restore';

  @override
  String get deviceCloudBackupMaxSubtitle =>
      'Max feature. Upload current data and restore it when needed';

  @override
  String get deviceCloudBackupMaxTitle => 'Max required';

  @override
  String get deviceCloudBackupMaxMessage =>
      'Cloud backup and restore are Max features. Upgrade to Max to upload current data and restore it when needed.';

  @override
  String get deviceCloudBackupRequiresMax =>
      'Cloud backup and restore require Max. If already purchased, log in and restore purchases, then try again.';

  @override
  String get deviceCloudBackupNotConfigured =>
      'Cloud backup service is not configured yet';

  @override
  String get deviceManualBackupTitle => 'Export current data';

  @override
  String get deviceManualBackupSubtitle =>
      'Export this device\'s data for saving or migration';

  @override
  String get deviceLocalRestoreTitle => 'Local restore';

  @override
  String get deviceLocalRestoreSubtitle =>
      'Restore this device from a backup file';

  @override
  String get deviceCloudRestoreTitle => 'Cloud restore';

  @override
  String get deviceCloudRestoreSubtitle =>
      'Max feature. Restore data from a cloud backup';

  @override
  String get deviceSyncInfoTitle => 'Multi-device sync';

  @override
  String get deviceSyncInfoSubtitle =>
      'Automatic multi-device sync is not supported yet';

  @override
  String get deviceSyncInfoMessage =>
      'Cloud backup is for saving data and device migration. Multi-device sync means real-time data sync between devices, which is not supported in the current version.';

  @override
  String get deviceCloudBackupUnavailableTitle =>
      'Cloud backup is not configured';

  @override
  String get deviceLoginRequiredTitle => 'Login required';

  @override
  String get deviceCloudBackupLoginRequiredMessage =>
      'Please complete phone login before using cloud backup.';

  @override
  String get deviceCloudBackupChooseMessage =>
      'You can upload the current local data, or restore this device from a cloud backup. Cloud restore fully replaces current local business data.';

  @override
  String get deviceCloudRestoreAction => 'Restore from cloud';

  @override
  String get deviceCloudUploadAction => 'Upload current data';

  @override
  String get deviceCloudBackupFailureTitle => 'Cloud backup failed';

  @override
  String get deviceCloudBackupUploadFailureMessage =>
      'Cloud backup upload failed. Try again later.';

  @override
  String get deviceCloudBackupUploadedTitle => 'Cloud backup uploaded';

  @override
  String deviceCloudBackupUploadedMessage(String backupId, String size) {
    return 'Current data was saved to cloud.\nBackup ID: $backupId\nSize: $size';
  }

  @override
  String get deviceCloudBackupReadFailureTitle =>
      'Could not read cloud backups';

  @override
  String get deviceCloudBackupReadFailureMessage =>
      'Could not read the cloud backup list. Try again later.';

  @override
  String get deviceCloudBackupEmptyTitle => 'No cloud backups';

  @override
  String get deviceCloudBackupEmptyMessage =>
      'This account has no restorable cloud backups yet.';

  @override
  String get deviceCloudBackupSelectTitle => 'Choose cloud backup';

  @override
  String get deviceCloudRestoreConfirmTitle => 'Restore from cloud?';

  @override
  String deviceCloudRestoreConfirmMessage(String backupTime) {
    return 'This will restore the cloud backup from $backupTime. After restore, current local business data will be replaced by this cloud backup. The app will automatically export a current-data backup first.';
  }

  @override
  String get deviceRestoreConfirmAction => 'Confirm restore';

  @override
  String get deviceLocalBackupFailureTitle => 'Local backup failed';

  @override
  String get deviceLocalBackupFailureMessage =>
      'Backup failed. Try again later.';

  @override
  String get deviceLocalBackupGeneratedTitle => 'Local backup created';

  @override
  String get deviceLocalBackupPathInvalidMessage =>
      'A backup file was created, but its file path is invalid. You can still choose it later from the local backup list.';

  @override
  String get deviceLocalBackupOnlySuccessMessage =>
      'Backup created. You can choose it during local restore.';

  @override
  String get deviceLocalBackupSharedSuccessMessage =>
      'Backup file created. Please confirm it was saved to a safe location.';

  @override
  String get deviceLocalBackupShareUnavailableMessage =>
      'Backup file created, but the share sheet could not be opened. You can still find it in the local backup list.';

  @override
  String get deviceManualBackupDialogMessage =>
      'Export a backup file of current data. You can save it locally only, or immediately share/save it elsewhere.';

  @override
  String get deviceBackupOnlyAction => 'Backup only';

  @override
  String get deviceBackupAndShareAction => 'Backup and share';

  @override
  String get deviceBackupSelectionCancelled => 'Selection cancelled';

  @override
  String get deviceBackupPreviewUnavailableTitle =>
      'Could not preview backup file';

  @override
  String get deviceInvalidBackupFileMessage =>
      'This is not a valid FleetLedger backup file';

  @override
  String get deviceBackupIncompleteMessage =>
      'Backup file format is incomplete';

  @override
  String get deviceBackupSelectFileTitle => 'Choose backup file';

  @override
  String get deviceBackupSelectFileMessage =>
      'Choose a backup file exported by FleetLedger. Usually choose the latest manual backup; pre-restore backups are used to roll back recent restore attempts.';

  @override
  String get deviceBackupNoRecognizedFiles =>
      'No recognizable local backup files. Tap \"Choose from files\" to select a JSON backup elsewhere.';

  @override
  String get deviceBackupManualSection => 'Manual backups';

  @override
  String get deviceBackupPreRestoreSection => 'Pre-restore backups (safety)';

  @override
  String get deviceBackupLegacySection => 'Legacy backups';

  @override
  String get deviceBackupFromFileAction => 'Choose from files';

  @override
  String get deviceUnknownValue => 'Unknown';

  @override
  String get deviceBackupPreviewTitle => 'Backup file preview';

  @override
  String get deviceBackupPreviewIntro =>
      'This is a FleetLedger local backup file.';

  @override
  String get deviceBackupTimeLabel => 'Backup time';

  @override
  String get deviceBackupSchemaVersionLabel => 'Database version';

  @override
  String get deviceBackupIncludedDataLabel => 'Included data:';

  @override
  String get deviceBackupDeviceCountLabel => 'Devices';

  @override
  String get deviceBackupTimingRecordCountLabel => 'Timing records';

  @override
  String get deviceBackupFuelRecordCountLabel => 'Energy records';

  @override
  String get deviceBackupMaintenanceRecordCountLabel => 'Maintenance records';

  @override
  String get deviceBackupIncomeRecordCountLabel => 'Payment records';

  @override
  String get deviceBackupProjectSettingsCountLabel => 'Project settings';

  @override
  String deviceCountWithUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String deviceMachineCountWithUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count machines',
      one: '1 machine',
    );
    return '$_temp0';
  }

  @override
  String get deviceBackupRestoreWarning =>
      'After restore, current local business data will be replaced by this backup.';

  @override
  String get deviceRestoringMessage => 'Restoring. Do not close the app...';

  @override
  String get deviceLocalRestoreConfirmTitle => 'Restore backup?';

  @override
  String get deviceLocalRestoreConfirmMessage =>
      'After restore, current local devices, timing, energy, maintenance, payments, and project settings will be replaced by the selected backup. The app will automatically export a current-data backup first so you can recover it if needed. The current version only supports full replacement restore, not merge restore.';

  @override
  String get deviceRestoreSuccessTitle => 'Restore complete';

  @override
  String deviceRestoreSuccessMessage(
    int devices,
    int timingRecords,
    int fuelRecords,
    int maintenanceRecords,
    int accountPayments,
    int projectSettings,
  ) {
    return 'Restored business data:\nDevices: $devices\nTiming records: $timingRecords\nEnergy records: $fuelRecords\nMaintenance records: $maintenanceRecords\nPayment records: $accountPayments\nProject settings: $projectSettings\n\nCurrent data was automatically backed up before restore.';
  }

  @override
  String get deviceRestoreFailureTitle => 'Restore failed';

  @override
  String get deviceRestoreAutoBackupNote =>
      '\n\nCurrent data was automatically backed up before restore.';

  @override
  String get deviceBackupManualKindTitle => 'FleetLedger manual backup';

  @override
  String get deviceBackupPreRestoreKindTitle => 'Pre-restore backup';

  @override
  String get deviceBackupLegacyKindTitle => 'Legacy backup';

  @override
  String get deviceBackupUnknownKindTitle => 'FleetLedger backup';

  @override
  String get deviceLedgerSectionTitle => 'Device operations';

  @override
  String get deviceInactiveIndexLabel => 'Inactive';

  @override
  String get deviceUnitHour => 'h';

  @override
  String get deviceUnitShift => 'shifts';

  @override
  String get deviceUnitDay => 'days';

  @override
  String get deviceUnitRent => 'rental';

  @override
  String get deviceUnitMu => 'mu';

  @override
  String get deviceUnitAcre => 'acres';

  @override
  String get deviceUnitHectare => 'ha';

  @override
  String get deviceUnitTon => 't';

  @override
  String get deviceUnitCubicMeter => 'm³';

  @override
  String get deviceUnitTrip => 'trips';

  @override
  String get deviceUnitSortie => 'sorties';

  @override
  String get deviceUnitTask => 'tasks';

  @override
  String get deviceUpgradeProFallbackTitle =>
      'FleetLedger Pro annual subscription';

  @override
  String get deviceUpgradeMaxFallbackTitle =>
      'FleetLedger Max annual subscription';

  @override
  String get deviceUpgradePeriodYear => '1 year';

  @override
  String get deviceUpgradeUnitYear => 'year';

  @override
  String get deviceUpgradeProBody =>
      'Remove the 30 timing record limit for long-term tracking.';

  @override
  String get deviceUpgradeMaxBody =>
      'Includes Pro, plus cloud backup and restore.';

  @override
  String get deviceUpgradeLoadingProduct => 'Loading from App Store';

  @override
  String get deviceUpgradeUnitPricePending =>
      'Available after product details load';

  @override
  String get deviceUpgradePurchaseUnavailable =>
      'Subscription purchases are unavailable. Try again later.';

  @override
  String get deviceUpgradeLoadingProducts =>
      'Loading App Store subscription products...';

  @override
  String get deviceUpgradeProductsUnavailable =>
      'Subscription products are unavailable. Try again later.';

  @override
  String get deviceUpgradeTransactionPending =>
      'Waiting for App Store transaction result...';

  @override
  String get deviceUpgradeMaxUnlocked =>
      'Subscription active. Max entitlement unlocked.';

  @override
  String get deviceUpgradeProUnlocked =>
      'Subscription active. Pro entitlement unlocked.';

  @override
  String get deviceUpgradeButtonLoading => 'Loading...';

  @override
  String get deviceUpgradeButtonUnavailable => 'Unavailable';

  @override
  String get deviceUpgradeButtonProcessing => 'Processing...';

  @override
  String get deviceUpgradeButtonSubscribed => 'Subscribed';

  @override
  String get deviceUpgradeButtonUpgradeMax => 'Upgrade to Max';

  @override
  String get deviceUpgradeButtonContinue => 'Continue';

  @override
  String get deviceUpgradeBenefitClearLedger =>
      'Keep one more clear digital ledger';

  @override
  String get deviceUpgradeBenefitAutoRenewal =>
      'Pro and Max are annual auto-renewing subscriptions';

  @override
  String get deviceUpgradeBadgeIncludesPro => 'Includes Pro';

  @override
  String get deviceUpgradeSubscriptionDetailsTitle => 'Subscription details';

  @override
  String get deviceUpgradeSubscriptionNameLabel => 'Name';

  @override
  String get deviceUpgradeSubscriptionPeriodLabel => 'Period';

  @override
  String get deviceUpgradeSubscriptionPriceLabel => 'Price';

  @override
  String get deviceUpgradeUnitPriceLabel => 'Unit price';

  @override
  String get deviceUpgradeProductNotLoadedMessage =>
      'Purchasing is unavailable until App Store product details finish loading.';

  @override
  String get deviceUpgradeUnlocksPremiumMessage =>
      'Subscription unlocks Pro features while your subscription is active.';

  @override
  String get deviceUpgradeAutoRenewMessage =>
      'Subscriptions renew automatically unless auto-renewal is turned off at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple ID subscription settings.';

  @override
  String get deviceUpgradeReviewLegalMessage =>
      'Please review the Privacy Policy and Terms of Use before purchasing.';

  @override
  String get deviceUpgradePrivacyLinkLabel => 'Privacy Policy';

  @override
  String get deviceUpgradeTermsLinkLabel => 'Terms of Use';

  @override
  String get devicePrivacyEffectiveDate => 'Effective date: June 9, 2026';

  @override
  String get devicePrivacySection1Title => '1. Scope';

  @override
  String get devicePrivacySection1Body =>
      'Welcome to FleetLedger.\nFleetLedger is a recordkeeping and management tool for construction machinery operations. It helps users manage device work hours, energy consumption, project income and expenses, maintenance details, and device information.\n\nThis Privacy Policy explains how FleetLedger handles information related to your use of the app in the current version.\n\nThis policy applies to the current FleetLedger app version and related support pages.';

  @override
  String get devicePrivacySection2Title =>
      '2. Local data types involved in the current version';

  @override
  String get devicePrivacySection2Body =>
      'In the current version, the app mainly involves:\n• Device information, timing records, energy records, project income and expenses, maintenance details, and other business data you enter;\n• The phone number you enter on the phone login page, and your confirmation status for the Privacy Policy and Terms of Use;\n• Avatar or image files you actively choose and set;\n• Necessary local information created while using the app for local storage, page display, filtering, statistics, and feature decisions.\n\nThe business data above is mainly stored locally on your device. To provide SMS-code phone login, your phone number, verification request, login status, and necessary server responses are sent to the developer-configured account API, with SMS code sending and verification provided by Alibaba Cloud phone verification services. If you actively use cloud backup, the app uploads the current ledger backup to the developer-configured cloud backup service for backup listing and device migration restore. The current version does not integrate advertising SDKs, analytics SDKs, third-party tracking services, or automatic multi-device sync services.';

  @override
  String get devicePrivacySection3Title => '3. Data sources and purposes';

  @override
  String get devicePrivacySection3Body =>
      'Relevant data in the current version mainly comes from:\n• Your active input;\n• Your active uploads or selections;\n• Data formed locally on the device while using related features.\n\nThis data is mainly used to provide FleetLedger core features on your device, including:\n• Saving and displaying device operation records;\n• Generating statistics and page display content;\n• Supporting filtering, search, summaries, avatar display, and feature decisions;\n• Assisting with local troubleshooting and feature decisions when necessary.\n\nExcept for SMS-code phone login, cloud backup or restore initiated by you, and system capabilities you actively trigger such as app rating, email contact, or external links, the developer does not actively receive the business data you enter in the app.';

  @override
  String get devicePrivacySection4Title => '4. Permissions';

  @override
  String get devicePrivacySection4Body =>
      'FleetLedger may request system permissions when you actively perform related actions.';

  @override
  String get devicePrivacySection5Title =>
      '4.1 Image or photo library permissions';

  @override
  String get devicePrivacySection5Body =>
      'When you actively set a device avatar, choose an image, or update related display content, the app may request access to images or the photo library. This permission is only used to complete the action you initiated and will not automatically read your images without your consent.';

  @override
  String get devicePrivacySection6Title =>
      '4.2 External links and system capabilities';

  @override
  String get devicePrivacySection6Body =>
      'When you actively tap entries such as \"Rate app\", \"Contact developer\", \"Privacy Policy\", \"Terms of Use\", \"Upgrade/Subscription\", or \"Restore purchases\", the app may call system-provided browser, email, app store, or other capabilities to complete that action. These actions are system transitions initiated by you.';

  @override
  String get devicePrivacySection7Title =>
      '5. Information sharing, uploads, and third-party services';

  @override
  String get devicePrivacySection7Body =>
      'In the current version, business records you enter are mainly stored locally on your device. The phone number, SMS-code verification request, login status, and necessary server responses required for phone login are sent to the developer-configured account API, with SMS code sending and verification handled by Alibaba Cloud phone verification services. When you actively use cloud backup, the app uploads the current ledger backup to the developer-configured cloud backup service; when you actively restore from cloud, the app downloads the backup you choose under your account.\n\nThe developer does not sell, rent, or actively share these records with advertising networks, data brokers, or unrelated third parties.\n\nThe current version does not integrate:\n• Advertising services;\n• Analytics services;\n• Third-party tracking services;\n• Automatic multi-device sync services.\n\nThe SMS-code service integrated in the current version is used only for phone login verification, not for advertising, analytics, or third-party tracking.\n\nIf you actively use app-store rating, system email contact, upgrade, subscription, or restore-purchase capabilities, those flows are handled by Apple App Store, the device system, or the relevant platform under their own rules. If production builds enable server-side subscription verification, the app may send transaction verification information required to confirm subscription status to the developer-configured verification service. The developer does not directly collect bank card numbers, payment account passwords, or similar payment credentials.';

  @override
  String get devicePrivacySection8Title => '6. Data storage and security';

  @override
  String get devicePrivacySection8Body =>
      'Main business data in the current version is stored locally on your device. Cloud backups you actively upload are stored in the cloud backup space associated with your account for backup listing and restore. Login credentials required for SMS-code login are stored locally to maintain login status. Within the app\'s capabilities, we take reasonable measures to reduce risks of accidental loss, mistaken operation, or unauthorized access.\n\nPlease understand that no local device, operating system environment, or storage medium can guarantee absolute security. We recommend that you keep your device secure and handle important business data carefully.';

  @override
  String get devicePrivacySection9Title => '7. Data retention and deletion';

  @override
  String get devicePrivacySection9Body =>
      'In the current version, relevant business data is usually retained on your local device until one of the following occurs:\n• You actively delete related records;\n• You actively clear app data;\n• You uninstall the app;\n• Local data changes or is lost due to the device system, storage environment, or other abnormal conditions.\n\nIf you have not actively uploaded a cloud backup, the developer usually cannot restore ledger data stored only on your local device.';

  @override
  String get devicePrivacySection10Title => '8. Children and minors';

  @override
  String get devicePrivacySection10Body =>
      'FleetLedger is mainly intended for construction machinery operation records and management, and is not directed to children. If you are a minor, we recommend reading and using the app under guardian guidance.';

  @override
  String get devicePrivacySection11Title => '9. Future feature updates';

  @override
  String get devicePrivacySection11Body =>
      'In the current version, SMS-code phone login and cloud backup/restore initiated by the user are handled as described in this policy.\n\nIf future versions introduce capabilities including but not limited to:\n• Automatic multi-device sync;\n• Analytics tools;\n• Third-party service integrations;\n• Error log collection;\n• Other new features involving data upload, processing, or sharing,\n\nwe will update this Privacy Policy according to the actual feature and data flow at that time, and update App Store privacy disclosures accordingly.';

  @override
  String get devicePrivacySection12Title => '10. Privacy Policy updates';

  @override
  String get devicePrivacySection12Body =>
      'We may update this policy according to product changes, legal or regulatory requirements, or service changes. Updated versions will be published through in-app pages, support pages, or other reasonable methods.\n\nUnless otherwise stated, updated policies take effect from the publication date.';

  @override
  String get devicePrivacySection13Title => '11. Contact us';

  @override
  String get devicePrivacySection13Body =>
      'If you have questions about this Privacy Policy or want to contact us about privacy matters, you can contact the developer at:\n\nEmail: 582748196@qq.com';

  @override
  String get deviceTermsEffectiveDate => 'Effective date: 2026-03-17';

  @override
  String get deviceTermsSection1Title => '1. Scope and acceptance';

  @override
  String get deviceTermsSection1Body =>
      'These Terms of Use apply to the products and services provided by \"FleetLedger\" on iOS and Android. By downloading, installing, accessing, or continuing to use the app, you confirm that you have read and agree to be bound by these terms.';

  @override
  String get deviceTermsSection2Title => '2. Product features';

  @override
  String get deviceTermsSection2Body =>
      'The app is intended for construction machinery operations and is mainly used to record and manage device information, work hours, energy, project income and expenses, and maintenance details. App results are operational aids only and do not constitute financial, tax, legal, or other professional advice.';

  @override
  String get deviceTermsSection3Title => '3. User responsibility';

  @override
  String get deviceTermsSection3Body =>
      'You are responsible for ensuring that information you enter, save, export, or share is true, accurate, and complete, and that you have lawful rights to use the relevant data. You may not use the app to create, store, or distribute illegal, infringing, fraudulent, malicious, or otherwise unlawful content.';

  @override
  String get deviceTermsSection4Title => '4. Local data and backups';

  @override
  String get deviceTermsSection4Body =>
      'In the current version, device information, work hours, energy, project income and expenses, maintenance details, and other main business data are primarily stored locally. SMS-code phone login is verified through the developer-configured account API and SMS verification service to identify login status.\n\nYou understand and agree that the risk of local business data loss caused by device damage, system errors, accidental deletion, permission changes, uninstalling the app, or other reasons outside the developer\'s control is borne by you. We recommend making backups according to the importance of your business data.';

  @override
  String get deviceTermsSection5Title =>
      '5. Permissions, platform capabilities, and paid features';

  @override
  String get deviceTermsSection5Body =>
      'When you actively use image selection, app rating, upgrade/subscription, or restore-purchase capabilities, the app may call system permissions or platform capabilities provided by Apple App Store or Google Play. The name, period, price, and entitlement of auto-renewing subscriptions are subject to the purchase page and the relevant app store confirmation page. Subscriptions renew automatically unless you turn off auto-renewal at least 24 hours before the end of the current period. You can manage or cancel subscriptions in Apple ID subscription settings. Refund, cancellation, and renewal rules follow the relevant app store rules, and payment settlement is handled by the relevant platform.';

  @override
  String get deviceTermsSection6Title => '6. Intellectual property';

  @override
  String get deviceTermsSection6Body =>
      'The app\'s software code, interface design, copy structure, marks, and related content are owned by the developer unless otherwise provided by law or separately stated. Without permission, you may not illegally copy, reverse engineer, distribute, or commercially exploit the app.';

  @override
  String get deviceTermsSection7Title =>
      '7. Disclaimer and limitation of liability';

  @override
  String get deviceTermsSection7Body =>
      'The app is provided \"as is\" and \"as available\". We will continue improving the product experience, but do not guarantee that the app will always be uninterrupted, error-free, or fully meet your specific business needs. To the extent permitted by applicable law, the developer\'s liability for losses caused by your input errors, failure to back up in time, device failures, system limitations, third-party platform issues, or force majeure is limited to what is mandatorily required by law.';

  @override
  String get deviceTermsSection8Title => '8. Updates and contact';

  @override
  String get deviceTermsSection8Body =>
      'We may update these terms according to product iteration, platform policies, or changes in laws and regulations. If you continue using the app after an updated version is released, you are deemed to accept the updated terms. Questions: 582748196@qq.com.';

  @override
  String get syncConflictReviewTitle => 'Sync conflict review';

  @override
  String get syncConflictReviewEmpty => 'No conflicts to review';

  @override
  String get syncConflictReviewLoadFailure =>
      'Failed to load conflicts. Try again later';

  @override
  String get syncConflictResolveFailure => 'Resolution failed. Try again later';

  @override
  String get syncConflictReviewManualHint =>
      'For a manual merge, keep local first, then adjust it from the regular edit page.';

  @override
  String syncConflictReviewEntityTitle(String entityId) {
    return 'Timing record $entityId';
  }

  @override
  String syncConflictReviewReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get syncConflictReviewLocalLabel => 'Local current';

  @override
  String get syncConflictReviewRemoteLabel => 'Remote incoming';

  @override
  String get syncConflictReviewUseRemote => 'Use remote';

  @override
  String get syncConflictReviewUseLocal => 'Use local';

  @override
  String get syncConflictReviewMissingLocal => 'Local record no longer exists';

  @override
  String get syncConflictReviewMissingRemote =>
      'Remote record could not be parsed';

  @override
  String get syncConflictReviewDeletedSummary => 'Deleted record';

  @override
  String syncConflictReviewTimingSummary(
    int deviceId,
    String date,
    String hours,
    String amount,
  ) {
    return 'Device $deviceId · $date · $hours h · ¥$amount';
  }

  @override
  String get deviceRateEntryOpened => 'Opened the rating entry';

  @override
  String get deviceRateEntryUnavailable => 'Rating entry is unavailable';

  @override
  String get deviceSupportSiteOpened => 'Opened the support page';

  @override
  String get deviceSupportEmailFallback =>
      'Could not open the support page; switched to email';

  @override
  String deviceSupportUnavailable(String email) {
    return 'Could not open the support page; please retry later or email $email';
  }

  @override
  String get deviceRestoreBlockIncompleteFormat =>
      'The backup file is incomplete and cannot be restored.';

  @override
  String get deviceRestoreBlockOlderUnsupported =>
      'Restoring older backups is not supported in this version; please use a backup exported from the same version.';

  @override
  String get deviceRestoreBlockNewerVersion =>
      'The backup file is from a newer version; please update the app and try again.';

  @override
  String get deviceCustomAvatarNotAllowed =>
      'Custom avatars are not available on your current plan';

  @override
  String get storeActionSaveSuccess => 'Saved';

  @override
  String get storeActionDeleteSuccess => 'Deleted';

  @override
  String get storeActionUpdateSuccess => 'Updated';

  @override
  String get storeActionCreateSuccess => 'Created';

  @override
  String get storeActionDeactivateSuccess => 'Deactivated';

  @override
  String get storeActionReadSuccess => 'Loaded';

  @override
  String get storeActionSaveLabel => 'Save';

  @override
  String get storeActionDeleteLabel => 'Delete';

  @override
  String get storeActionUpdateLabel => 'Update';

  @override
  String get storeActionCreateLabel => 'Create';

  @override
  String get storeActionDeactivateLabel => 'Deactivate';

  @override
  String get storeActionReadLabel => 'Read';

  @override
  String storeActionFailureWithDetail(String action, String detail) {
    return '$action failed: $detail';
  }

  @override
  String storeActionFailureDatabase(String action) {
    return '$action failed: data was not saved, please try again later';
  }

  @override
  String storeActionFailureFileSystem(String action) {
    return '$action failed: please check file status and access permissions';
  }
}
