import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/account/view/account_page.dart';
import '../features/device/state/device_controller.dart';
import '../features/device/view/device_page.dart';
import '../features/fuel/state/fuel_controller.dart';
import '../features/fuel/view/fuel_page.dart';
import '../features/maintenance/view/maintenance_page.dart';
import '../features/timing/state/timing_controller.dart';
import '../features/timing/view/timing_page.dart';
import '../patterns/timing/tab_bar_pattern.dart';
import '../core/theme/app_theme.dart';

class AssetLedgerApp extends StatelessWidget {
  const AssetLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asset Ledger',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: AppTheme.light(),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TimingPage(),
    FuelPage(),
    AccountPage(),
    MaintenancePage(),
    DevicePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final deviceStore = context.read<DeviceStore>();
      final timingStore = context.read<TimingStore>();
      final fuelStore = context.read<FuelStore>();
      await deviceStore.loadAll();
      await timingStore.loadAll();
      await fuelStore.loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: ComponentTabBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
