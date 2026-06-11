import 'dart:convert';
import 'dart:io';

import '../../../../data/services/project_share_file_picker.dart';
import '../../../../data/share/jztshare/share_envelope.dart';

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

/// 选择 .jzt 文件并按 UTF-8 读取文本内容。
/// 只负责“选择 → 读取文本”，不解析 envelope（解析仍由现有 parser 负责）。
class PickExternalWorkShareFileUseCase {
  const PickExternalWorkShareFileUseCase(this._picker);

  final ProjectShareFilePicker _picker;

  static const String invalidTypeMessage = '请选择 FleetLedger .jzt 分享包';
  static const String readErrorMessage = '读取分享包失败，请重新选择文件';
  static const String fileTooLargeMessage = '分享包文件过大，无法导入';

  Future<PickShareFileResult> pick() async {
    final PickedShareFile? picked;
    try {
      picked = await _picker.pick();
    } catch (_) {
      return const PickShareFileError(readErrorMessage);
    }
    if (picked == null) return const PickShareFileCancelled();

    if (!isJztExtension(picked.name)) {
      return const PickShareFileError(invalidTypeMessage);
    }

    try {
      final bytes = picked.bytes;
      final String content;
      if (bytes != null) {
        if (bytes.length > JztShareEnvelope.maxContentBytes) {
          return const PickShareFileError(fileTooLargeMessage);
        }
        content = utf8.decode(bytes);
      } else {
        final file = _fileFromPath(picked.path);
        // 先查文件长度再读取,避免把超大文件整个载入内存。
        if (await file.length() > JztShareEnvelope.maxContentBytes) {
          return const PickShareFileError(fileTooLargeMessage);
        }
        content = await file.readAsString();
      }
      if (content.trim().isEmpty) {
        return const PickShareFileError(readErrorMessage);
      }
      return PickShareFileContent(content);
    } catch (_) {
      return const PickShareFileError(readErrorMessage);
    }
  }

  static bool isJztExtension(String name) =>
      name.toLowerCase().endsWith('.jzt');

  File _fileFromPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('selected file path is unavailable');
    }
    return File(path);
  }
}
