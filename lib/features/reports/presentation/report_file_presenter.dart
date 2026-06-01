import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

class ReportShareSheetException implements Exception {
  const ReportShareSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ReportFilePresenter {
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  });
}

class SystemReportFilePresenter implements ReportFilePresenter {
  const SystemReportFilePresenter();

  @override
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw const ReportShareSheetException('分享文件路径为空');
    }
    if (!await File(normalizedPath).exists()) {
      throw const ReportShareSheetException('分享文件不存在');
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              normalizedPath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: [fileName],
          subject: subject,
          title: subject,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (_) {
      throw const ReportShareSheetException('分享面板打开失败，可稍后重试');
    }
  }
}
