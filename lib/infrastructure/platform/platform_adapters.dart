import 'package:flutter/widgets.dart';

abstract class StorageAdapter {
  Future<bool> exists(String path);

  Future<void> delete(String path);
}

abstract class ShareAdapter {
  Future<void> shareFile({required String path, String? subject, String? text});
}

abstract class PermissionAdapter {
  Future<bool> ensureStorageAccess();
}

abstract class DialogAdapter {
  Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确定',
  });
}

abstract class FilePickerAdapter {
  Future<String?> pickBackupFile();
}

abstract class DatabaseAdapter {
  Future<String> databasePath(String databaseName);
}

abstract class PathProviderAdapter {
  Future<String> appDocumentsPath();

  Future<String> temporaryPath();
}

class PlatformAdapterBundle {
  const PlatformAdapterBundle({
    required this.storage,
    required this.share,
    required this.permission,
    required this.dialog,
    required this.filePicker,
    required this.database,
    required this.pathProvider,
  });

  final StorageAdapter storage;
  final ShareAdapter share;
  final PermissionAdapter permission;
  final DialogAdapter dialog;
  final FilePickerAdapter filePicker;
  final DatabaseAdapter database;
  final PathProviderAdapter pathProvider;
}
