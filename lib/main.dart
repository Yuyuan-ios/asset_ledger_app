import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';
import 'app/app_providers.dart';
import 'app/identity/app_identity_service.dart';
import 'data/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // R5.21：在 AppProviders.build()（同步）之前完成 ownerId 持久化初始化，
  // 保证 IdentityProviders 拿到的是首次启动持久化的 owner id，而不是
  // 进程级 in-memory UUID。
  await AppIdentityService.initialize();
  await SubscriptionService.init();
  final appProviderBundle = AppProviders.build();
  await AppBootstrap.preload(
    deviceStore: appProviderBundle.deviceStore,
    timingStore: appProviderBundle.timingStore,
    fuelStore: appProviderBundle.fuelStore,
    maintenanceStore: appProviderBundle.maintenanceStore,
    projectRateStore: appProviderBundle.projectRateStore,
    accountStore: appProviderBundle.accountStore,
  );

  runApp(
    MultiProvider(
      providers: appProviderBundle.providers,
      child: const AssetLedgerApp(),
    ),
  );
}
