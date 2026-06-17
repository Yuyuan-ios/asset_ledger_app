// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/sync_runtime.dart';
import '../../../app/phone_login_gate.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../application/controllers/cloud_backup_controller.dart';
import '../application/controllers/local_backup_controller.dart';
import '../application/controllers/subscription_controller.dart';
import '../domain/entities/device.dart';
import '../domain/entities/local_backup_entities.dart';
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../patterns/device/device_page_header_search_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../domain/services/device_business_ledger.dart';
import 'device_page_actions.dart';
import 'device_page_sections.dart';
import 'device_account_center_page.dart';
import 'device_account_status.dart';
import 'device_backup_widgets.dart';
import '../../sync/sync_conflict_review_page.dart';

// =====================================================================
// ============================== 二、DevicePage：设备页入口 ==============================
// =====================================================================

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

enum _ManualBackupAction { backupOnly, backupAndShare }

enum _CloudBackupAction { uploadCurrent, restoreFromCloud }

// =====================================================================
// ============================== 三、State：仅做 UI 状态与交互 ==============================
// =====================================================================

class _DevicePageState extends State<DevicePage> {
  static const _phoneLoginStore = SharedPreferencesPhoneLoginStore();
  static const _subscriptionController = SubscriptionController();
  static const _deviceBusinessLedgerUseCase = DeviceBusinessLedgerUseCase();

  bool _isExportingBackup = false;
  bool _isCloudBackupBusy = false;
  PhoneLoginSession _loginSession = const PhoneLoginSession.unauthenticated();

  LocalBackupController get _localBackupController =>
      context.read<LocalBackupController>();

  CloudBackupController get _cloudBackupController =>
      context.read<CloudBackupController>();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _subscriptionController.notifier.addListener(_handleSubscriptionChanged);
    Future.microtask(() async {
      await _loadLoginSession();
      await _subscriptionController.init();
    });
  }

  @override
  void dispose() {
    _subscriptionController.notifier.removeListener(_handleSubscriptionChanged);
    super.dispose();
  }

  void _handleSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<PhoneLoginSession> _loadLoginSession() async {
    final session = await _phoneLoginStore.read();
    if (!mounted) return session;
    setState(() => _loginSession = session);
    return session;
  }

  // -------------------------------------------------------------------
  // 3.1 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _showAccountSyncPlaceholder({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceDoneAction),
            ),
          ],
        );
      },
    );
  }

  // =====================================================================
  // ============================== 四、新增/编辑弹窗（同一套表单复用） ==============================
  // =====================================================================
  Future<void> _openDeviceDialog({
    Device? device,
    String? initialBrand,
    EquipmentType? initialEquipmentType,
  }) async {
    await DevicePageActions.openDeviceDialog(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
      device: device,
      initialBrand: initialBrand,
      initialEquipmentType: initialEquipmentType,
    );
  }

  Future<void> _openAddDeviceFlow() async {
    await DevicePageActions.openAddDeviceFlow(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _retryLoad() async {
    await DevicePageActions.retryLoad(context.read<DeviceStore>());
  }

  Future<void> _openRateApp() async {
    await DevicePageActions.openRateApp(
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _openTermsPage() async {
    await DevicePageActions.openTermsPage(context);
  }

  Future<void> _openPrivacyPage() async {
    await DevicePageActions.openPrivacyPage(context);
  }

  Future<void> _openContactSupport() async {
    await DevicePageActions.openSupportPage(
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _openUpgradePage() async {
    await DevicePageActions.openUpgradePage(context);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _restorePurchases() async {
    await _subscriptionController.restorePurchases();
  }

  Future<PhoneLoginSession> _openPhoneLogin() async {
    final initialSession = _loginSession;
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhoneLoginPage(
          verificationService: const HttpPhoneVerificationService(),
          initialAgreementAccepted: initialSession.privacyAccepted,
          onLoggedIn:
              ({
                required String phoneNumber,
                required String authToken,
                required int? tokenExpiresAt,
              }) async {
                await _phoneLoginStore.save(
                  PhoneLoginSession(
                    loggedIn: true,
                    privacyAccepted: true,
                    phoneNumber: phoneNumber,
                    authToken: authToken,
                    tokenExpiresAt: tokenExpiresAt,
                  ),
                );
                if (navigator.mounted) navigator.pop();
              },
          onLoginSkipped: () async {
            await _phoneLoginStore.save(
              PhoneLoginSession.skipped(
                privacyAccepted: initialSession.privacyAccepted,
              ),
            );
            if (navigator.mounted) navigator.pop();
          },
          onOpenPrivacyPolicy: () => DevicePageActions.openPrivacyPage(context),
          onOpenTerms: () => DevicePageActions.openTermsPage(context),
        ),
      ),
    );
    return _loadLoginSession();
  }

  Future<void> _openAccountCenter() async {
    final syncRuntime = context.read<SyncRuntime?>();
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(
          milliseconds: DeviceTokens.avatarPickerForwardDurationMs,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: DeviceTokens.avatarPickerReverseDurationMs,
        ),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AccountCenterPage(
              loginSession: _loginSession,
              subscriptionListenable: _subscriptionController.notifier,
              onOpenPhoneLogin: _openPhoneLogin,
              onOpenUpgradePage: _openUpgradePage,
              onRestorePurchases: _restorePurchases,
              onOpenLocalBackup: _openLocalBackup,
              onOpenLocalRestore: _openLocalRestorePreview,
              onOpenSyncInfo: _openSyncInfoPlaceholder,
              onOpenCloudBackup: _openCloudBackup,
              onOpenSyncConflictReview: _openSyncConflictReview,
              syncConflictReviewAvailable: syncRuntime?.isAvailable ?? false,
              cloudBackupAvailable: _cloudBackupController.isAvailable,
              cloudBackupUnavailableMessage:
                  _cloudBackupController.unavailableMessage,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(offset),
            child: child,
          );
        },
      ),
    );
    if (!mounted) return;
    await _loadLoginSession();
  }

  Future<void> _openSyncConflictReview() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SyncConflictReviewPage()),
    );
  }

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
                        restoreBlockReason,
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

  String? _restoreBlockReason(BackupPreview preview) {
    return _localBackupController.restoreBlockReason(preview);
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

  Future<void> _openSyncInfoPlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: _l10n.deviceSyncInfoTitle,
      message: _l10n.deviceSyncInfoMessage,
    );
  }

  String _formatDateTime(DateTime value) {
    return _localBackupController.formatBackupTimeForDisplay(value);
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();
    final activeDevices = store.activeDevices;
    final allDevices = store.allDevices;
    final businessLedgers = _deviceBusinessLedgerUseCase.execute(
      timingRecords: timingStore.records,
      devices: allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
      writeOffs: accountStore.writeOffs,
      activeMergeGroups: accountStore.activeMergeGroups,
      settledProjectIds: accountStore.settledProjectIds,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: DeviceTokens.pageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ListView(
                padding: const EdgeInsets.only(
                  top: 0,
                  bottom: DeviceTokens.pageBottomPadding,
                ),
                children: [
                  const DevicePageHeaderSearch(),
                  if (store.failure != null) ...[
                    const SizedBox(height: DeviceTokens.loadErrorTopGap),
                    StoreErrorBanner(
                      message: storeErrorMessage(store, action: '读取')!,
                      onRetry: store.loading ? null : () => _retryLoad(),
                    ),
                  ],
                  ...buildDevicePageSections(
                    l10n: l10n,
                    devices: activeDevices,
                    handlers: DevicePageSectionHandlers(
                      onOpenUpgradePage: _openUpgradePage,
                      onOpenAccountCenter: _openAccountCenter,
                      accountCenterSubtitle: deviceAccountCenterSubtitle(
                        l10n: l10n,
                        session: _loginSession,
                        subscription: _subscriptionController.snapshot,
                      ),
                      onOpenAddDeviceFlow: _openAddDeviceFlow,
                      onOpenRateApp: _openRateApp,
                      onOpenTermsPage: _openTermsPage,
                      onOpenPrivacyPage: _openPrivacyPage,
                      onOpenContact: _openContactSupport,
                      onDeviceTap: (d) => _openDeviceDialog(device: d),
                      onDeviceLongPress: (d) async {
                        await DevicePageActions.deactivateDevice(
                          context: context,
                          store: context.read<DeviceStore>(),
                          device: d,
                          isMounted: () => mounted,
                          toast: _toast,
                        );
                      },
                      businessLedgers: businessLedgers,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
