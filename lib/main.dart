import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/identity/app_identity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // R5.21：在 AppProviders.build()（同步）之前完成 ownerId 持久化初始化，
  // 保证 IdentityProviders 拿到的是首次启动持久化的 owner id，而不是
  // 进程级 in-memory UUID。
  await AppIdentityService.initialize();
  runApp(const AssetLedgerApp());
}
