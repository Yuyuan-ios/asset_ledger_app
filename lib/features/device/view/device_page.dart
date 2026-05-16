// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/store_feedback.dart';
import '../../../data/db/database.dart';
import '../../../data/models/backup_preview.dart';
import '../../../data/models/backup_restore_result.dart';
import '../../../data/models/device.dart';
import '../../../data/services/local_backup_export_service.dart';
import '../../../data/services/local_backup_file_naming.dart';
import '../../../data/services/local_backup_import_preview_service.dart';
import '../../../data/services/local_backup_restore_service.dart';
import '../../../data/services/local_backup_share_service.dart';
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../patterns/device/device_page_header_search_pattern.dart';
import '../../../patterns/device/device_action_card_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_page_actions.dart';
import 'device_page_sections.dart';

// =====================================================================
// ============================== 二、DevicePage：设备页入口 ==============================
// =====================================================================

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

enum _ManualBackupAction { backupOnly, backupAndShare }

// =====================================================================
// ============================== 三、State：仅做 UI 状态与交互 ==============================
// =====================================================================

class _DevicePageState extends State<DevicePage> {
  bool _isExportingBackup = false;

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

  Future<void> _openAccountCenter() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(
          milliseconds: DeviceTokens.avatarPickerForwardDurationMs,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: DeviceTokens.avatarPickerReverseDurationMs,
        ),
        pageBuilder: (context, animation, secondaryAnimation) => _AccountCenterPage(
          onOpenUpgradePage: _openUpgradePage,
          onOpenLocalBackup: _openLocalBackup,
          onOpenLocalRestore: _openLocalRestorePreview,
          onOpenSyncInfo: _openSyncInfoPlaceholder,
          onOpenLoginSyncInfo: () => _showAccountSyncPlaceholder(
            title: '云端备份与协作记录',
            message:
                '云备份、换机恢复和协作记录等能力后续将继续做，Pro 用户将优先开放。当前版本仍以本机数据为准，请定期使用手动本地备份保存数据。',
          ),
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
  }

  Future<void> _openLocalBackup() async {
    if (_isExportingBackup) return;

    final action = await _chooseManualBackupAction();
    if (action == null || !mounted) return;

    setState(() {
      _isExportingBackup = true;
    });

    try {
      final result = await LocalBackupExportService.exportJsonBackup();
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
      await const LocalBackupShareService().shareBackupFile(
        filePath: filePath,
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } on LocalBackupShareException catch (_) {
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
    final importService = const LocalBackupImportPreviewService();
    final previewResult = await _selectBackupForPreview(importService);
    if (!mounted) return;

    final preview = previewResult.preview;
    if (preview.isCancelled) {
      _toast('已取消选择');
      return;
    }

    if (!preview.isValid) {
      await _showAccountSyncPlaceholder(
        title: '无法预览备份文件',
        message: preview.errorMessage ?? '这不是有效的机账通备份文件',
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

  Future<BackupPreviewLoadResult> _selectBackupForPreview(
    LocalBackupImportPreviewService importService,
  ) async {
    final localBackups = await importService.listLocalBackups();
    if (!mounted) {
      return const BackupPreviewLoadResult(preview: BackupPreview.cancelled());
    }

    final selection = await showDialog<_BackupFileSelection>(
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
                  '请选择由机账通导出的备份文件。通常建议选择最近一次手动备份；恢复前备份用于撤回最近几次恢复操作前的数据。',
                ),
                const SizedBox(height: 12),
                if (!hasRecognizedBackups)
                  const Text('暂无可识别的本地备份文件，可点击“从文件选择”选择其他位置的 JSON 备份。'),
                if (manualBackups.isNotEmpty)
                  _BackupFileSection(
                    title: '手动备份',
                    backups: manualBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(_BackupFileSelection.local(backup)),
                  ),
                if (preRestoreBackups.isNotEmpty)
                  _BackupFileSection(
                    title: '恢复前备份（防误操）',
                    backups: preRestoreBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(_BackupFileSelection.local(backup)),
                  ),
                if (legacyBackups.isNotEmpty)
                  _BackupFileSection(
                    title: '旧版备份',
                    backups: legacyBackups,
                    onSelected: (backup) => Navigator.of(
                      dialogContext,
                    ).pop(_BackupFileSelection.local(backup)),
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
              ).pop(const _BackupFileSelection.filePicker()),
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
      return importService.pickAndPreviewBackupWithJson();
    }

    final backup = selection.backup;
    if (backup == null) {
      return const BackupPreviewLoadResult(preview: BackupPreview.cancelled());
    }
    return importService.previewLocalBackupFile(backup);
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
                    const Text('这是一个机账通本地备份文件。'),
                    const SizedBox(height: 12),
                    _BackupPreviewLine(label: '备份时间', value: exportedAtText),
                    _BackupPreviewLine(
                      label: '数据库版本',
                      value: preview.schemaVersion?.toString() ?? '未知',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '包含数据：',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _BackupPreviewLine(
                      label: '设备',
                      value: '${preview.deviceCount} 台',
                    ),
                    _BackupPreviewLine(
                      label: '计时记录',
                      value: '${preview.timingRecordCount} 条',
                    ),
                    _BackupPreviewLine(
                      label: '油费记录',
                      value: '${preview.fuelRecordCount} 条',
                    ),
                    _BackupPreviewLine(
                      label: '维修记录',
                      value: '${preview.maintenanceRecordCount} 条',
                    ),
                    _BackupPreviewLine(
                      label: '收款记录',
                      value: '${preview.incomeRecordCount} 条',
                    ),
                    _BackupPreviewLine(
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

                            final result =
                                await const LocalBackupRestoreService()
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
    final schemaVersion = preview.schemaVersion;
    if (schemaVersion == null) return '备份文件格式不完整，暂不能恢复。';
    if (schemaVersion < AppDatabase.schemaVersion) {
      return '当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。';
    }
    if (schemaVersion > AppDatabase.schemaVersion) {
      return '备份文件版本较新，请升级 App 后再试。';
    }
    return null;
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
    return LocalBackupFileNaming.formatBackupTimeForDisplay(value);
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeviceStore>();
    final devices = store.activeDevices;

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

class _BackupFileSelection {
  const _BackupFileSelection.local(this.backup) : useFilePicker = false;
  const _BackupFileSelection.filePicker() : backup = null, useFilePicker = true;

  final LocalBackupFile? backup;
  final bool useFilePicker;
}

class _BackupFileSection extends StatelessWidget {
  const _BackupFileSection({
    required this.title,
    required this.backups,
    required this.onSelected,
  });

  final String title;
  final List<LocalBackupFile> backups;
  final ValueChanged<LocalBackupFile> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TimingColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < backups.length; index += 1)
            _BackupFileTile(
              backup: backups[index],
              onTap: () => onSelected(backups[index]),
            ),
        ],
      ),
    );
  }
}

class _BackupFileTile extends StatelessWidget {
  const _BackupFileTile({required this.backup, required this.onTap});

  final LocalBackupFile backup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = backup.backupTime ?? backup.modifiedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        _titleForKind(backup.kind),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${LocalBackupFileNaming.formatBackupTimeForDisplay(time)} · ${_formatFileSize(backup.size)}',
      ),
      onTap: onTap,
    );
  }

  static String _titleForKind(LocalBackupFileKind kind) {
    switch (kind) {
      case LocalBackupFileKind.manual:
        return '机账通手动备份';
      case LocalBackupFileKind.preRestore:
        return '恢复前备份';
      case LocalBackupFileKind.legacy:
        return '旧版机账通备份';
      case LocalBackupFileKind.unknown:
        return '机账通备份';
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _BackupPreviewLine extends StatelessWidget {
  const _BackupPreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '$label：',
              style: const TextStyle(color: TimingColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCenterPage extends StatelessWidget {
  const _AccountCenterPage({
    required this.onOpenUpgradePage,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenLoginSyncInfo,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenLoginSyncInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '账户中心',
          style: TextStyle(
            fontSize: DeviceTokens.avatarPickerTitleFontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: DeviceTokens.pageHorizontalPadding,
            );

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                DeviceTokens.pageBottomPadding,
              ),
              children: [
                _AccountCenterContent(
                  onOpenUpgradePage: onOpenUpgradePage,
                  onOpenLocalBackup: onOpenLocalBackup,
                  onOpenLocalRestore: onOpenLocalRestore,
                  onOpenSyncInfo: onOpenSyncInfo,
                  onOpenLoginSyncInfo: onOpenLoginSyncInfo,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountCenterContent extends StatelessWidget {
  const _AccountCenterContent({
    required this.onOpenUpgradePage,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenLoginSyncInfo,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenLoginSyncInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeviceSectionGroup(
          title: '个人资料',
          children: [
            DeviceActionCard(
              title: '升级 Pro，支持持续维护',
              leading: const _UpgradeLeadingIcon(),
              trailingIcon: Icons.chevron_right,
              onTap: onOpenUpgradePage,
            ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: '数据安全',
          children: [
            DeviceActionCard(
              title: '云端备份与协作记录',
              subtitle: 'Pro 功能，即将上线',
              leading: const _AccountCenterIcon(Icons.account_circle_outlined),
              onTap: onOpenLoginSyncInfo,
            ),
            DeviceActionCard(
              title: '手动本地备份',
              subtitle: '导出当前数据，便于保存与迁移',
              leading: const _AccountCenterIcon(Icons.ios_share),
              onTap: onOpenLocalBackup,
            ),
            DeviceActionCard(
              title: '本地恢复',
              subtitle: '从备份文件恢复本机数据',
              leading: const _AccountCenterIcon(Icons.restore),
              onTap: onOpenLocalRestore,
            ),
            DeviceActionCard(
              title: '多端同步说明',
              subtitle: '当前版本暂不支持自动多端同步',
              leading: const _AccountCenterIcon(Icons.cloud_outlined),
              onTap: onOpenSyncInfo,
            ),
          ],
        ),
      ],
    );
  }
}

class _UpgradeLeadingIcon extends StatelessWidget {
  const _UpgradeLeadingIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DeviceActionCardTokens.premiumBadgeSize,
      height: DeviceActionCardTokens.premiumBadgeSize,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(
          DeviceActionCardTokens.premiumBadgeRadius,
        ),
      ),
      child: const Icon(
        Icons.workspace_premium,
        color: Colors.white,
        size: DeviceActionCardTokens.premiumBadgeIconSize,
      ),
    );
  }
}

class _AccountCenterIcon extends StatelessWidget {
  const _AccountCenterIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.brand, size: 22),
    );
  }
}
