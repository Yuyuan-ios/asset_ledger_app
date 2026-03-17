import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/account/state/account_payment_store.dart';
import '../features/account/view/account_page.dart';
import '../features/device/view/device_page.dart';
import '../features/fuel/view/fuel_page.dart';
import '../features/maintenance/view/maintenance_page.dart';
import '../features/timing/view/timing_page.dart';
import '../patterns/timing/tab_bar_pattern.dart';

typedef AppRouterPageBuilder = Widget Function();
typedef AppRouterWarmup = Future<void> Function(BuildContext context);

class AppRouterEntry extends StatefulWidget {
  const AppRouterEntry({
    super.key,
    this.initialTimingTargetYear,
    this.initialTimingTargetMonth,
    this.pageBuilders,
    this.deferredWarmup,
  });

  final int? initialTimingTargetYear;
  final int? initialTimingTargetMonth;
  final List<AppRouterPageBuilder>? pageBuilders;
  final AppRouterWarmup? deferredWarmup;

  @override
  State<AppRouterEntry> createState() => _AppRouterEntryState();
}

class _AppRouterEntryState extends State<AppRouterEntry> {
  int _currentIndex = 0;

  late final List<AppRouterPageBuilder> _pageBuilders;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pageBuilders = widget.pageBuilders ?? _defaultPageBuilders();
    _pages = List<Widget?>.filled(_pageBuilders.length, null, growable: false);
    _ensurePageBuilt(_currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final warmup = widget.deferredWarmup ?? _warmUpDeferredStores;
      unawaited(warmup(context));
    });
  }

  int? _resolveTimingTargetYear() {
    if (widget.initialTimingTargetYear != null) {
      return widget.initialTimingTargetYear;
    }
    return null;
  }

  int? _resolveTimingTargetMonth() {
    final month = widget.initialTimingTargetMonth;
    if (month != null && month >= 1 && month <= 12) {
      return month;
    }
    return null;
  }

  List<AppRouterPageBuilder> _defaultPageBuilders() {
    final timingYear = _resolveTimingTargetYear();
    final timingMonth = _resolveTimingTargetMonth();

    return [
      () => TimingPage(
        initialTargetYear: timingYear,
        initialTargetMonth: timingMonth,
      ),
      () => const FuelPage(),
      () => const AccountPage(),
      () => const MaintenancePage(),
      () => const DevicePage(),
    ];
  }

  void _ensurePageBuilt(int index) {
    _pages[index] ??= _pageBuilders[index]();
  }

  Future<void> _warmUpDeferredStores(BuildContext context) async {
    await context.read<AccountPaymentStore>().loadAll();
  }

  void _handleTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _ensurePageBuilt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _pages.length,
          (index) => _pages[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: ComponentTabBar(
        currentIndex: _currentIndex,
        onTap: _handleTabTap,
      ),
    );
  }
}
