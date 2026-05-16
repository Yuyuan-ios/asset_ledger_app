import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';
import 'app/app_providers.dart';
import 'data/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
