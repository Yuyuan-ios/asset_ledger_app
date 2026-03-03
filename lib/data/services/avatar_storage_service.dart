// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';

// 1.1 path_provider：拿到 App 私有目录（iOS/Android/macOS 都可）
import 'package:path_provider/path_provider.dart';

// 1.2 path：拼接路径 / 取文件名
import 'package:path/path.dart' as p;

// 1.3 image_picker：XFile 类型（你选相册/拍照拿到的就是它）
import 'package:image_picker/image_picker.dart';

// =====================================================================
// ============================== 二、AvatarStorageService ==============================
// =====================================================================
//
// 设计目标：
// - UI/Store 不关心“图片存哪里、怎么命名、怎么拷贝”
// - 只要给我一个 XFile，我就返回一个“稳定的本地路径”
// - 未来要换成云端 URL / 压缩裁剪 / 多尺寸，只改这里
//
// 层级：Service（能力服务）
// =====================================================================

class AvatarStorageService {
  // -------------------------------------------------------------------
  // 2.1 头像目录名（放在 App Support 目录下）
  // -------------------------------------------------------------------
  static const String _dirName = 'device_avatars';
  static Future<Directory> Function()? _supportDirectoryResolver;
  static String Function()? _filenameResolver;

  // -------------------------------------------------------------------
  // 2.2 保存：把用户选的图片拷贝进 App 私有目录，返回新路径
  //
  // 说明：
  // - 返回的路径用于写入 Device.customAvatarPath
  // - 文件名用时间戳，避免冲突
  // -------------------------------------------------------------------
  static Future<String> saveXFile(XFile file) async {
    final sourcePath = file.path.trim();
    if (sourcePath.isEmpty) {
      throw ArgumentError('图片路径不能为空');
    }

    final src = File(sourcePath);
    if (!await src.exists()) {
      throw FileSystemException('图片文件不存在', sourcePath);
    }

    // ① 拿到 App 私有目录（macOS/桌面也稳定）
    final baseDir = await _resolveSupportDirectory();

    // ② 确保子目录存在
    final avatarDir = Directory(p.join(baseDir.path, _dirName));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // ③ 生成目标文件名（保留原扩展名；没有就用 .jpg）
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath)
        : '.jpg';
    final filename = _resolveFilename(ext);

    final targetPath = p.join(avatarDir.path, filename);

    // ④ 拷贝进私有目录（用 copy 保证原文件即便被系统清理，我们仍有备份）
    try {
      await src.copy(targetPath);
    } on FileSystemException catch (e) {
      throw FileSystemException('头像保存失败', targetPath, e.osError);
    }

    return targetPath;
  }

  // -------------------------------------------------------------------
  // 2.3 删除：按路径删除（可选）
  //
  // 说明：
  // - 现在先不强制删除旧文件（避免误删用户正在用的）
  // - 未来你要做“清理无引用头像”，我们再做一个维护脚本/任务
  // -------------------------------------------------------------------
  static Future<void> deleteIfExists(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    final normalizedPath = path.trim();
    final entityType = await FileSystemEntity.type(normalizedPath);
    if (entityType == FileSystemEntityType.notFound) return;
    if (entityType != FileSystemEntityType.file) {
      throw FileSystemException('头像路径不是文件', normalizedPath);
    }

    final f = File(normalizedPath);
    try {
      await f.delete();
    } on FileSystemException catch (e) {
      throw FileSystemException('头像删除失败', normalizedPath, e.osError);
    }
  }

  @visibleForTesting
  static void setTestOverrides({
    Future<Directory> Function()? supportDirectoryResolver,
    String Function()? filenameResolver,
  }) {
    _supportDirectoryResolver = supportDirectoryResolver;
    _filenameResolver = filenameResolver;
  }

  @visibleForTesting
  static void resetTestOverrides() {
    _supportDirectoryResolver = null;
    _filenameResolver = null;
  }

  static Future<Directory> _resolveSupportDirectory() async {
    if (_supportDirectoryResolver != null) {
      return _supportDirectoryResolver!();
    }
    return getApplicationSupportDirectory();
  }

  static String _resolveFilename(String ext) {
    if (_filenameResolver != null) {
      return _filenameResolver!();
    }
    return 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}
