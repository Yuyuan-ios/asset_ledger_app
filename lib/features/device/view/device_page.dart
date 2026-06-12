// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../../../tokens/mapper/core_tokens.dart';
import '../domain/services/device_business_ledger.dart';
import 'device_page_actions.dart';
import 'device_page_sections.dart';
import 'device_account_center_page.dart';
import 'device_account_status.dart';
import 'device_backup_widgets.dart';

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
              child: const Text('知道了'),
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

  Future<void> _openCloudBackup() async {
    if (_isCloudBackupBusy) return;

    if (!_cloudBackupController.isAvailable) {
      await _showAccountSyncPlaceholder(
        title: '云端备份服务暂未配置',
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
          title: '需要登录',
          message: '请先完成手机号登录，再使用云端备份。',
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
          title: const Text('云端备份'),
          content: const Text('你可以上传当前本机数据，也可以从云端备份恢复到本机。云端恢复会完整替换当前本机业务数据。'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_CloudBackupAction.restoreFromCloud),
              child: const Text('从云端恢复'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_CloudBackupAction.uploadCurrent),
              child: const Text('上传当前数据'),
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
          title: '云端备份失败',
          message: result.errorMessage ?? '云端备份上传失败，请稍后重试。',
        );
        return;
      }
      await _showAccountSyncPlaceholder(
        title: '云端备份已上传',
        message:
            '当前数据已保存到云端。\n'
            '备份 ID：${result.backupId ?? '-'}\n'
            '大小：${_cloudBackupController.formatPayloadSize(result.payloadBytes)}',
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
        title: '无法读取云端备份',
        message: listResult.errorMessage ?? '云端备份列表读取失败，请稍后重试。',
      );
      return;
    }
    if (listResult.backups.isEmpty) {
      await _showAccountSyncPlaceholder(
        title: '暂无云端备份',
        message: '当前账号下还没有可恢复的云端备份。',
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
          title: const Text('选择云端备份'),
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
              child: const Text('取消'),
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
              title: const Text('确认从云端恢复？'),
              content: Text(
                '将恢复 $backupTime 的云端备份。恢复后，当前本机业务数据会被这份云端备份替换；恢复前 App 会先自动导出当前数据备份。',
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('确认恢复'),
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
          title: '本地备份失败',
          message: result.errorMessage ?? '备份失败，请稍后重试。',
        );
        return;
      }

      final filePath = result.filePath;
      final shouldShare = action == _ManualBackupAction.backupAndShare;
      if (filePath == null || filePath.trim().isEmpty) {
        await _showAccountSyncPlaceholder(
          title: '本地备份已生成',
          message: '备份文件已生成，但文件路径异常。你仍可稍后从本地备份列表中选择该文件。',
        );
        return;
      }

      if (!shouldShare) {
        await _showAccountSyncPlaceholder(
          title: '本地备份已生成',
          message: '备份已生成，可在本地恢复时选择这份备份。',
        );
        return;
      }

      await _shareManualBackup(filePath);
      if (!mounted) return;
      await _showAccountSyncPlaceholder(
        title: '本地备份已生成',
        message: '备份文件已生成，请确认已保存到安全位置。',
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
          title: const Text('本地备份'),
          content: const Text('导出一份当前数据备份文件。你可以仅保存在本机，也可以立即分享或保存到其他位置。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ManualBackupAction.backupOnly),
              child: const Text('仅备份'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ManualBackupAction.backupAndShare),
              child: const Text('备份并分享'),
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
        title: '本地备份已生成',
        message: '备份文件已生成，但无法打开分享面板。你仍可在本地备份列表中找到它。',
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
      _toast('已取消选择');
      return;
    }

    if (!preview.isValid) {
      await _showAccountSyncPlaceholder(
        title: '无法预览备份文件',
        message: preview.errorMessage ?? '这不是有效的 FleetLedger 备份文件',
      );
      return;
    }

    final backupJson = previewResult.decodedJson;
    if (backupJson == null) {
      await _showAccountSyncPlaceholder(
        title: '无法预览备份文件',
        message: '备份文件格式不完整',
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
          title: const Text('选择备份文件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请选择由 FleetLedger 导出的备份文件。通常建议选择最近一次手动备份；恢复前备份用于撤回最近几次恢复操作前的数据。',
                ),
                const SizedBox(height: 12),
                if (!hasRecognizedBackups)
                  const Text('暂无可识别的本地备份文件，可点击“从文件选择”选择其他位置的 JSON 备份。'),
                if (manualBackups.isNotEmpty)
                  BackupFileSection(
                    title: '手动备份',
                    backups: manualBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(BackupFileSelection.local(backup)),
                  ),
                if (preRestoreBackups.isNotEmpty)
                  BackupFileSection(
                    title: '恢复前备份（防误操）',
                    backups: preRestoreBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(BackupFileSelection.local(backup)),
                  ),
                if (legacyBackups.isNotEmpty)
                  BackupFileSection(
                    title: '旧版备份',
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
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(const BackupFileSelection.filePicker()),
              child: const Text('从文件选择'),
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
        ? '未知'
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
              title: const Text('备份文件预览'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('这是一个 FleetLedger 本地备份文件。'),
                    const SizedBox(height: 12),
                    BackupPreviewLine(label: '备份时间', value: exportedAtText),
                    BackupPreviewLine(
                      label: '数据库版本',
                      value: preview.schemaVersion?.toString() ?? '未知',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '包含数据：',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    BackupPreviewLine(
                      label: '设备',
                      value: '${preview.deviceCount} 台',
                    ),
                    BackupPreviewLine(
                      label: '计时记录',
                      value: '${preview.timingRecordCount} 条',
                    ),
                    BackupPreviewLine(
                      label: '油费记录',
                      value: '${preview.fuelRecordCount} 条',
                    ),
                    BackupPreviewLine(
                      label: '维修记录',
                      value: '${preview.maintenanceRecordCount} 条',
                    ),
                    BackupPreviewLine(
                      label: '收款记录',
                      value: '${preview.incomeRecordCount} 条',
                    ),
                    BackupPreviewLine(
                      label: '项目相关设置',
                      value:
                          '${preview.tableCounts['project_device_rates'] ?? 0} 条',
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
                    const Text('恢复后，当前本机的业务数据会被这份备份替换。'),
                    if (isRestoring) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text('正在恢复，请勿关闭 App...')),
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
                  child: const Text('我知道了'),
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
                        : const Text('确认恢复'),
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
              title: const Text('确认恢复备份？'),
              content: const Text(
                '恢复后，当前本机的设备、计时、油费、维修、收款和项目相关设置等业务数据将被所选备份替换。恢复前，App 会先自动导出一份当前数据备份，便于必要时找回。当前版本仅支持完整覆盖恢复，不支持合并恢复。',
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('确认恢复'),
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
      title: '恢复完成',
      message:
          '已恢复以下业务数据：\n'
          '设备：${counts['devices'] ?? 0}\n'
          '计时记录：${counts['timing_records'] ?? 0}\n'
          '油费记录：${counts['fuel_logs'] ?? 0}\n'
          '维修记录：${counts['maintenance_records'] ?? 0}\n'
          '收款记录：${counts['account_payments'] ?? 0}\n'
          '项目相关设置：${counts['project_device_rates'] ?? 0}\n\n'
          '恢复前已自动备份当前数据。',
    );
  }

  Future<void> _showRestoreFailureDialog(BackupRestoreResult result) async {
    final backupNote = result.autoBackupPath == null
        ? ''
        : '\n\n恢复前已成功自动备份当前数据。';
    await _showAccountSyncPlaceholder(
      title: '恢复失败',
      message: '${result.message}$backupNote',
    );
  }

  Future<void> _openSyncInfoPlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: '多端同步说明',
      message: '云端备份未来用于保存数据与换机恢复；多端同步是多台设备之间的实时数据同步，当前版本暂不支持自动多端同步。',
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
    final store = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();
    final devices = store.activeDevices;
    final businessLedgers = _deviceBusinessLedgerUseCase.execute(
      timingRecords: timingStore.records,
      devices: devices,
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
                    devices: devices,
                    handlers: DevicePageSectionHandlers(
                      onOpenUpgradePage: _openUpgradePage,
                      onOpenAccountCenter: _openAccountCenter,
                      accountCenterSubtitle: deviceAccountCenterSubtitle(
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
