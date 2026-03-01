import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_providers.dart';
import 'data/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SubscriptionService.setPlanForDebug(Plan.pro);
  await SubscriptionService.refresh();

  runApp(
    MultiProvider(
      providers: AppProviders.build(),
      child: const AssetLedgerApp(),
    ),
  );
}
