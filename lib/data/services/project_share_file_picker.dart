import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 用户选中的分享包文件（仅承载内容来源，不做协议判断）。
class PickedShareFile {
  const PickedShareFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;
}

/// 选择项目外协分享包文件。抽象出来便于在 use case 测试中注入 fake，
/// 避免触发 file_picker 平台插件。返回 null 表示用户取消。
abstract class ProjectShareFilePicker {
  Future<PickedShareFile?> pick();
}

/// 基于 file_picker 的真实实现（与 LocalBackup 文件选择同款用法）。
class FilePickerProjectShareFilePicker implements ProjectShareFilePicker {
  const FilePickerProjectShareFilePicker();

  @override
  Future<PickedShareFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      // 主扩展名 .jzt；兼容历史 .jztshare。
      allowedExtensions: const ['jzt', 'jztshare'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return PickedShareFile(name: file.name, path: file.path, bytes: file.bytes);
  }
}
