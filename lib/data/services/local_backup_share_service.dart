import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class LocalBackupShareException implements Exception {
  const LocalBackupShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackupShareService {
  const LocalBackupShareService();

  Future<void> shareBackupFile({
    required String filePath,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw const LocalBackupShareException('备份文件路径为空');
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw const LocalBackupShareException('备份文件不存在');
    }

    final fileName = p.basename(normalizedPath);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(normalizedPath, mimeType: 'application/json')],
          fileNameOverrides: [fileName],
          subject: subject ?? 'FleetLedger 本地备份',
          title: 'FleetLedger 本地备份',
          text: text ?? '这是一份 FleetLedger 本地备份文件，请妥善保存。',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (_) {
      throw const LocalBackupShareException('无法打开分享面板');
    }
  }
}
