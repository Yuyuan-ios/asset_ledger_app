import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../tokens/mapper/core_tokens.dart';
import '../application/controllers/local_backup_controller.dart';
import '../domain/entities/local_backup_entities.dart';

class BackupFileSelection {
  const BackupFileSelection.local(this.backup) : useFilePicker = false;
  const BackupFileSelection.filePicker() : backup = null, useFilePicker = true;

  final LocalBackupFile? backup;
  final bool useFilePicker;
}

class BackupFileSection extends StatelessWidget {
  const BackupFileSection({
    super.key,
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
            BackupFileTile(
              backup: backups[index],
              onTap: () => onSelected(backups[index]),
            ),
        ],
      ),
    );
  }
}

class BackupFileTile extends StatelessWidget {
  const BackupFileTile({
    super.key,
    required this.backup,
    required this.onTap,
    this.controller,
  });

  final LocalBackupFile backup;
  final VoidCallback onTap;
  final LocalBackupController? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedController =
        controller ?? context.read<LocalBackupController>();
    final time = backup.backupTime ?? backup.modifiedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        titleForKind(backup.kind),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${resolvedController.formatBackupTimeForDisplay(time)} · ${formatFileSize(backup.size)}',
      ),
      onTap: onTap,
    );
  }

  static String titleForKind(LocalBackupFileKind kind) {
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

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class BackupPreviewLine extends StatelessWidget {
  const BackupPreviewLine({
    super.key,
    required this.label,
    required this.value,
  });

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
