import 'package:flutter/material.dart';

import '../features/account/view/account_page.dart';
import '../features/device/view/device_page.dart';
import '../features/fuel/view/fuel_page.dart';
import '../features/maintenance/view/maintenance_page.dart';
import '../features/timing/view/timing_page.dart';
import '../patterns/timing/tab_bar_pattern.dart';

class AppRouterEntry extends StatefulWidget {
  const AppRouterEntry({super.key});

  @override
  State<AppRouterEntry> createState() => _AppRouterEntryState();
}

class _AppRouterEntryState extends State<AppRouterEntry> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TimingPage(),
    FuelPage(),
    AccountPage(),
    MaintenancePage(),
    DevicePage(),
  ];

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
