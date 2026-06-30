import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/services/subscription_service.dart';
import 'app_bootstrap.dart';
import 'app_providers.dart';

class AppRuntimeBootstrap extends StatefulWidget {
  const AppRuntimeBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<AppRuntimeBootstrap> createState() => _AppRuntimeBootstrapState();
}

class _AppRuntimeBootstrapState extends State<AppRuntimeBootstrap> {
  late final Future<AppProviderBundle> _bundleFuture = _prepareBundle();

  Future<AppProviderBundle> _prepareBundle() async {
    await SubscriptionService.init();
    await AppBootstrap.seedDemoDataForRuntimeAccessIfNeeded();
    final bundle = AppProviders.build();
    await AppBootstrap.preload(
      deviceStore: bundle.deviceStore,
      timingStore: bundle.timingStore,
      fuelStore: bundle.fuelStore,
      maintenanceStore: bundle.maintenanceStore,
      projectRateStore: bundle.projectRateStore,
      accountStore: bundle.accountStore,
    );
    return bundle;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppProviderBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (bundle == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return MultiProvider(providers: bundle.providers, child: widget.child);
      },
    );
  }
}
