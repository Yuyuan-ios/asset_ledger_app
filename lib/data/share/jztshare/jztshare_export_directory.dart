import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 解析项目分享(.jzt)导出目录（应用文档目录下的子目录）。
///
/// 路径逻辑集中在此，不散落到 Widget 层；单测通过 adapter 的
/// directoryResolver 注入临时目录，无需调用 path_provider。
class JztShareExportDirectory {
  const JztShareExportDirectory._();

  static const String subDirName = 'jztshare_exports';

  static Future<Directory> resolve() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, subDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
