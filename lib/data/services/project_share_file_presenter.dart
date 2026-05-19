import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// 调起系统分享面板分享 .jztshare 文件失败时抛出。
class ProjectShareSheetException implements Exception {
  const ProjectShareSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 把已生成的 .jztshare 文件交给系统分享面板。
///
/// 抽象出来便于在 widget/use case 测试中注入 fake，避免触发平台插件。
abstract class ProjectShareFilePresenter {
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
  });
}

/// 基于 share_plus 的真实实现（与 LocalBackupShareService 同款用法）。
class SystemProjectShareFilePresenter implements ProjectShareFilePresenter {
  const SystemProjectShareFilePresenter();

  @override
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw const ProjectShareSheetException('分享文件路径为空');
    }
    if (!await File(normalizedPath).exists()) {
      throw const ProjectShareSheetException('分享文件不存在');
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          // .jztshare 本质是 JSON 数据包；分享真实文件，而非文本/路径串。
          files: [XFile(normalizedPath, mimeType: 'application/json')],
          fileNameOverrides: [fileName],
          subject: subject,
          title: subject,
          text: text,
        ),
      );
      // 用户取消（dismissed）不会抛异常，按非错误处理。
    } catch (_) {
      throw const ProjectShareSheetException('分享面板打开失败，可稍后重试');
    }
  }
}
