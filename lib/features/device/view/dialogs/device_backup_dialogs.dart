part of '../device_page.dart';

mixin _DeviceBackupDialogs on State<DevicePage> {
  AppLocalizations get _l10n;
  LocalBackupController get _localBackupController;
  CloudBackupController get _cloudBackupController;
  bool get _isExportingBackup;
  set _isExportingBackup(bool value);
  bool get _isCloudBackupBusy;
  set _isCloudBackupBusy(bool value);
  Future<PhoneLoginSession> _loadLoginSession();
  Future<PhoneLoginSession> _openPhoneLogin();
  Future<void> _openUpgradePage();
  Future<void> _showAccountSyncPlaceholder({
    required String title,
    required String message,
  });
  void _toast(String msg);

  Future<void> _openCloudBackup() async {
    if (_isCloudBackupBusy) return;

    if (!_cloudBackupController.isAvailable) {
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceCloudBackupUnavailableTitle,
        message: _cloudBackupController.unavailableMessage,
      );
      return;
    }

    var session = await _loadLoginSession();
    if (!mounted) return;
    if (!session.isAuthenticated) {
      session = await _openPhoneLogin();
      if (!mounted) return;
      if (!session.isAuthenticated) {
        await _showAccountSyncPlaceholder(
          title: _l10n.deviceLoginRequiredTitle,
          message: _l10n.deviceCloudBackupLoginRequiredMessage,
        );
        return;
      }
    }

    final canUseCloudBackup = await _ensureCloudBackupEntitlement();
    if (!canUseCloudBackup || !mounted) return;

    final action = await _chooseCloudBackupAction();
    if (action == null || !mounted) return;
    switch (action) {
      case _CloudBackupAction.uploadCurrent:
        await _uploadCloudBackup();
        break;
      case _CloudBackupAction.restoreFromCloud:
        await _restoreCloudBackup();
        break;
    }
  }

  Future<bool> _ensureCloudBackupEntitlement() {
    return requireProFeature(
      context,
      title: _l10n.deviceCloudBackupProTitle,
      message: _l10n.deviceCloudBackupProMessage,
      isAllowed:
          _DevicePageState._subscriptionController.snapshot.allowsProFeatures,
      isAllowedAfterUpgrade: () =>
          _DevicePageState._subscriptionController.snapshot.allowsProFeatures,
      openUpgrade: (_) => _openUpgradePage(),
      confirmText: _l10n.deviceUpgradeNowTitle,
      cancelText: _l10n.deviceCancelAction,
    );
  }

  Future<_CloudBackupAction?> _chooseCloudBackupAction() {
    return showDialog<_CloudBackupAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_l10n.deviceCloudBackupTitle),
          content: Text(_l10n.deviceCloudBackupChooseMessage),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceCancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_CloudBackupAction.restoreFromCloud),
              child: Text(_l10n.deviceCloudRestoreAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_CloudBackupAction.uploadCurrent),
              child: Text(_l10n.deviceCloudUploadAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadCloudBackup() async {
    setState(() => _isCloudBackupBusy = true);
    try {
      final result = await _cloudBackupController.uploadCurrent();
      if (!mounted) return;
      if (!result.success) {
        await _showAccountSyncPlaceholder(
          title: _l10n.deviceCloudBackupFailureTitle,
          message:
              result.errorMessage ??
              _l10n.deviceCloudBackupUploadFailureMessage,
        );
        return;
      }
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceCloudBackupUploadedTitle,
        message: _l10n.deviceCloudBackupUploadedMessage(
          result.backupId ?? '-',
          _cloudBackupController.formatPayloadSize(result.payloadBytes),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCloudBackupBusy = false);
      }
    }
  }

  Future<void> _restoreCloudBackup() async {
    setState(() => _isCloudBackupBusy = true);
    final listResult = await _cloudBackupController.listRemote();
    if (mounted) {
      setState(() => _isCloudBackupBusy = false);
    }
    if (!mounted) return;
    if (!listResult.success) {
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceCloudBackupReadFailureTitle,
        message:
            listResult.errorMessage ??
            _l10n.deviceCloudBackupReadFailureMessage,
      );
      return;
    }
    if (listResult.backups.isEmpty) {
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceCloudBackupEmptyTitle,
        message: _l10n.deviceCloudBackupEmptyMessage,
      );
      return;
    }

    final selected = await _selectCloudBackup(listResult.backups);
    if (selected == null || !mounted) return;
    final confirmed = await _confirmCloudRestore(selected);
    if (!confirmed || !mounted) return;

    setState(() => _isCloudBackupBusy = true);
    try {
      final result = await _cloudBackupController.restoreFromCloud(
        selected.backupId,
      );
      if (!mounted) return;
      if (result.success) {
        await _reloadStoresAfterRestore();
        if (!mounted) return;
        await _showRestoreSuccessDialog(result);
        return;
      }
      await _showRestoreFailureDialog(result);
    } finally {
      if (mounted) {
        setState(() => _isCloudBackupBusy = false);
      }
    }
  }

  Future<CloudBackupMetadata?> _selectCloudBackup(
    List<CloudBackupMetadata> backups,
  ) {
    return showDialog<CloudBackupMetadata>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_l10n.deviceCloudBackupSelectTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _cloudBackupController.formatRemoteTimeForDisplay(
                      backup.createdAtIso,
                    ),
                  ),
                  subtitle: Text(
                    'Schema v${backup.dbSchemaVersion} · '
                    '${_cloudBackupController.formatPayloadSize(backup.payloadBytes)}',
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceCancelAction),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmCloudRestore(CloudBackupMetadata backup) async {
    final backupTime = _cloudBackupController.formatRemoteTimeForDisplay(
      backup.createdAtIso,
    );
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(_l10n.deviceCloudRestoreConfirmTitle),
              content: Text(_l10n.deviceCloudRestoreConfirmMessage(backupTime)),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_l10n.deviceCancelAction),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_l10n.deviceRestoreConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _openLocalBackup() async {
    if (_isExportingBackup) return;

    final action = await _chooseManualBackupAction();
    if (action == null || !mounted) return;

    setState(() {
      _isExportingBackup = true;
    });

    try {
      final result = await _localBackupController.exportJsonBackup();
      if (!mounted) return;

      if (!result.success) {
        await _showAccountSyncPlaceholder(
          title: _l10n.deviceLocalBackupFailureTitle,
          message: result.errorMessage ?? _l10n.deviceLocalBackupFailureMessage,
        );
        return;
      }

      final filePath = result.filePath;
      final shouldShare = action == _ManualBackupAction.backupAndShare;
      if (filePath == null || filePath.trim().isEmpty) {
        await _showAccountSyncPlaceholder(
          title: _l10n.deviceLocalBackupGeneratedTitle,
          message: _l10n.deviceLocalBackupPathInvalidMessage,
        );
        return;
      }

      if (!shouldShare) {
        await _showAccountSyncPlaceholder(
          title: _l10n.deviceLocalBackupGeneratedTitle,
          message: _l10n.deviceLocalBackupOnlySuccessMessage,
        );
        return;
      }

      await _shareManualBackup(filePath);
      if (!mounted) return;
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceLocalBackupGeneratedTitle,
        message: _l10n.deviceLocalBackupSharedSuccessMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingBackup = false;
        });
      }
    }
  }

  Future<_ManualBackupAction?> _chooseManualBackupAction() async {
    if (!mounted) return null;

    return showDialog<_ManualBackupAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_l10n.deviceManualBackupTitle),
          content: Text(_l10n.deviceManualBackupDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceCancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ManualBackupAction.backupOnly),
              child: Text(_l10n.deviceBackupOnlyAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ManualBackupAction.backupAndShare),
              child: Text(_l10n.deviceBackupAndShareAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareManualBackup(String filePath) async {
    try {
      await _localBackupController.shareBackupFile(
        filePath: filePath,
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (_) {
      if (!mounted) return;
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceLocalBackupGeneratedTitle,
        message: _l10n.deviceLocalBackupShareUnavailableMessage,
      );
    }
  }

  Rect? _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  Future<void> _openLocalRestorePreview() async {
    final previewResult = await _selectBackupForPreview();
    if (!mounted) return;

    final preview = previewResult.preview;
    if (preview.isCancelled) {
      _toast(_l10n.deviceBackupSelectionCancelled);
      return;
    }

    if (!preview.isValid) {
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceBackupPreviewUnavailableTitle,
        message: preview.errorMessage ?? _l10n.deviceInvalidBackupFileMessage,
      );
      return;
    }

    final backupJson = previewResult.decodedJson;
    if (backupJson == null) {
      await _showAccountSyncPlaceholder(
        title: _l10n.deviceBackupPreviewUnavailableTitle,
        message: _l10n.deviceBackupIncompleteMessage,
      );
      return;
    }

    await _showBackupPreviewDialog(preview, backupJson);
  }

  Future<BackupPreviewLoadResult> _selectBackupForPreview() async {
    final localBackups = await _localBackupController.listLocalBackups();
    if (!mounted) {
      return const BackupPreviewLoadResult(preview: BackupPreview.cancelled());
    }

    final selection = await showDialog<BackupFileSelection>(
      context: context,
      builder: (dialogContext) {
        final manualBackups = _backupsOfKind(
          localBackups,
          LocalBackupFileKind.manual,
        );
        final preRestoreBackups = _backupsOfKind(
          localBackups,
          LocalBackupFileKind.preRestore,
        ).take(3).toList(growable: false);
        final legacyBackups = _backupsOfKind(
          localBackups,
          LocalBackupFileKind.legacy,
        );
        final hasRecognizedBackups =
            manualBackups.isNotEmpty ||
            preRestoreBackups.isNotEmpty ||
            legacyBackups.isNotEmpty;

        return AlertDialog(
          title: Text(_l10n.deviceBackupSelectFileTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_l10n.deviceBackupSelectFileMessage),
                const SizedBox(height: 12),
                if (!hasRecognizedBackups)
                  Text(_l10n.deviceBackupNoRecognizedFiles),
                if (manualBackups.isNotEmpty)
                  BackupFileSection(
                    title: _l10n.deviceBackupManualSection,
                    backups: manualBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(BackupFileSelection.local(backup)),
                  ),
                if (preRestoreBackups.isNotEmpty)
                  BackupFileSection(
                    title: _l10n.deviceBackupPreRestoreSection,
                    backups: preRestoreBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(BackupFileSelection.local(backup)),
                  ),
                if (legacyBackups.isNotEmpty)
                  BackupFileSection(
                    title: _l10n.deviceBackupLegacySection,
                    backups: legacyBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(BackupFileSelection.local(backup)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceCancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(const BackupFileSelection.filePicker()),
              child: Text(_l10n.deviceBackupFromFileAction),
            ),
          ],
        );
      },
    );

    if (selection == null) {
      return const BackupPreviewLoadResult(preview: BackupPreview.cancelled());
    }

    if (selection.useFilePicker) {
      return _localBackupController.pickAndPreviewBackupWithJson();
    }

    final backup = selection.backup;
    if (backup == null) {
      return const BackupPreviewLoadResult(preview: BackupPreview.cancelled());
    }
    return _localBackupController.previewLocalBackupFile(backup);
  }

  List<LocalBackupFile> _backupsOfKind(
    List<LocalBackupFile> backups,
    LocalBackupFileKind kind,
  ) {
    return backups.where((backup) => backup.kind == kind).toList();
  }

  Future<void> _showBackupPreviewDialog(
    BackupPreview preview,
    Map<String, dynamic> backupJson,
  ) async {
    if (!mounted) return;

    final exportedAt = preview.exportedAt?.toLocal();
    final exportedAtText = exportedAt == null
        ? _l10n.deviceUnknownValue
        : _formatDateTime(exportedAt);
    final restoreBlockReason = _restoreBlockReason(preview);
    final canRestore = restoreBlockReason == null;
    var isRestoring = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(_l10n.deviceBackupPreviewTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_l10n.deviceBackupPreviewIntro),
                    const SizedBox(height: 12),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupTimeLabel,
                      value: exportedAtText,
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupSchemaVersionLabel,
                      value:
                          preview.schemaVersion?.toString() ??
                          _l10n.deviceUnknownValue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _l10n.deviceBackupIncludedDataLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupDeviceCountLabel,
                      value: _l10n.deviceMachineCountWithUnit(
                        preview.deviceCount,
                      ),
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupTimingRecordCountLabel,
                      value: _l10n.deviceCountWithUnit(
                        preview.timingRecordCount,
                      ),
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupFuelRecordCountLabel,
                      value: _l10n.deviceCountWithUnit(preview.fuelRecordCount),
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupMaintenanceRecordCountLabel,
                      value: _l10n.deviceCountWithUnit(
                        preview.maintenanceRecordCount,
                      ),
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupIncomeRecordCountLabel,
                      value: _l10n.deviceCountWithUnit(
                        preview.incomeRecordCount,
                      ),
                    ),
                    BackupPreviewLine(
                      label: _l10n.deviceBackupProjectSettingsCountLabel,
                      value: _l10n.deviceCountWithUnit(
                        preview.tableCounts['project_device_rates'] ?? 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (preview.warningMessage != null) ...[
                      Text(
                        preview.warningMessage!,
                        style: const TextStyle(color: AppColors.brand),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (restoreBlockReason != null) ...[
                      Text(
                        _restoreBlockReasonText(restoreBlockReason),
                        style: const TextStyle(color: AppColors.brand),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(_l10n.deviceBackupRestoreWarning),
                    if (isRestoring) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_l10n.deviceRestoringMessage)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: isRestoring
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_l10n.deviceDoneAction),
                ),
                if (canRestore)
                  TextButton(
                    onPressed: isRestoring
                        ? null
                        : () async {
                            final confirmed = await _confirmLocalRestore();
                            if (!confirmed || !mounted) return;

                            setDialogState(() {
                              isRestoring = true;
                            });

                            final result = await _localBackupController
                                .restoreFromDecodedJson(backupJson);
                            if (!mounted || !dialogContext.mounted) return;

                            if (result.success) {
                              await _reloadStoresAfterRestore();
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              await _showRestoreSuccessDialog(result);
                              return;
                            }

                            setDialogState(() {
                              isRestoring = false;
                            });
                            await _showRestoreFailureDialog(result);
                          },
                    child: isRestoring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_l10n.deviceRestoreConfirmAction),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  RestoreBlockReason? _restoreBlockReason(BackupPreview preview) {
    return _localBackupController.restoreBlockReason(preview);
  }

  String _restoreBlockReasonText(RestoreBlockReason reason) {
    switch (reason) {
      case RestoreBlockReason.incompleteFormat:
        return _l10n.deviceRestoreBlockIncompleteFormat;
      case RestoreBlockReason.olderUnsupported:
        return _l10n.deviceRestoreBlockOlderUnsupported;
      case RestoreBlockReason.newerVersion:
        return _l10n.deviceRestoreBlockNewerVersion;
    }
  }

  Future<bool> _confirmLocalRestore() async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(_l10n.deviceLocalRestoreConfirmTitle),
              content: Text(_l10n.deviceLocalRestoreConfirmMessage),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_l10n.deviceCancelAction),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_l10n.deviceRestoreConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _reloadStoresAfterRestore() async {
    await Future.wait([
      context.read<DeviceStore>().loadAll(),
      context.read<TimingStore>().loadAll(),
      context.read<FuelStore>().loadAll(),
      context.read<MaintenanceStore>().loadAll(),
      context.read<AccountPaymentStore>().loadAll(),
      context.read<ProjectRateStore>().loadAll(),
      context.read<AccountStore>().loadAll(),
    ]);
  }

  Future<void> _showRestoreSuccessDialog(BackupRestoreResult result) async {
    final counts = result.restoredCounts;
    await _showAccountSyncPlaceholder(
      title: _l10n.deviceRestoreSuccessTitle,
      message: _l10n.deviceRestoreSuccessMessage(
        counts['devices'] ?? 0,
        counts['timing_records'] ?? 0,
        counts['fuel_logs'] ?? 0,
        counts['maintenance_records'] ?? 0,
        counts['account_payments'] ?? 0,
        counts['project_device_rates'] ?? 0,
      ),
    );
  }

  Future<void> _showRestoreFailureDialog(BackupRestoreResult result) async {
    final backupNote = result.autoBackupPath == null
        ? ''
        : _l10n.deviceRestoreAutoBackupNote;
    await _showAccountSyncPlaceholder(
      title: _l10n.deviceRestoreFailureTitle,
      message: '${result.message}$backupNote',
    );
  }

  String _formatDateTime(DateTime value) {
    return _localBackupController.formatBackupTimeForDisplay(value);
  }
}
