import 'dart:convert';
import 'dart:io';

import '../../../../data/services/project_share_file_picker.dart';

/// 文件选择 + 读取结果（视图据此决定取消/报错/进入预览）。
sealed class PickShareFileResult {
  const PickShareFileResult();
}

/// 用户取消选择，不视为错误。
class PickShareFileCancelled extends PickShareFileResult {
  const PickShareFileCancelled();
}

/// 扩展名不支持或读取失败，message 为可直接展示的友好文案。
class PickShareFileError extends PickShareFileResult {
  const PickShareFileError(this.message);
  final String message;
}

/// 读取成功，content 为原始文本（交给现有预览 prepare 流程，按 JSON 解析）。
class PickShareFileContent extends PickShareFileResult {
  const PickShareFileContent(this.content);
  final String content;
}

/// 选择 .jzt / 历史 .jztshare 文件并按 UTF-8 读取文本内容。
/// 只负责“选择 → 读取文本”，不解析 envelope（解析仍由现有 parser 负责）。
class PickExternalWorkShareFileUseCase {
  const PickExternalWorkShareFileUseCase(this._picker);

  final ProjectShareFilePicker _picker;

  static const String _invalidTypeMessage = '请选择机账通 .jzt 分享包';
  static const String _readErrorMessage = '读取分享包失败，请重新选择文件';

  Future<PickShareFileResult> pick() async {
    final PickedShareFile? picked;
    try {
      picked = await _picker.pick();
    } catch (_) {
      return const PickShareFileError(_readErrorMessage);
    }
    if (picked == null) return const PickShareFileCancelled();

    final lower = picked.name.toLowerCase();
    // 主扩展名 .jzt；兼容历史 .jztshare（不在主文案强化旧扩展名）。
    if (!lower.endsWith('.jzt') && !lower.endsWith('.jztshare')) {
      return const PickShareFileError(_invalidTypeMessage);
    }

    try {
      final bytes = picked.bytes;
      final content = bytes != null
          ? utf8.decode(bytes)
          : await _readFromPath(picked.path);
      if (content.trim().isEmpty) {
        return const PickShareFileError(_readErrorMessage);
      }
      return PickShareFileContent(content);
    } catch (_) {
      return const PickShareFileError(_readErrorMessage);
    }
  }

  Future<String> _readFromPath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('selected file path is unavailable');
    }
    return File(path).readAsString();
  }
}
