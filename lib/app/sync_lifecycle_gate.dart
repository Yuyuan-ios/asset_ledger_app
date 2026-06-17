import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sync_production_caller.dart';

typedef SyncLifecycleRun =
    Future<SyncProductionCallResult> Function(SyncProductionTrigger trigger);

class SyncLifecycleGate extends StatefulWidget {
  const SyncLifecycleGate({
    super.key,
    required this.child,
    this.caller,
    this.onRun,
  });

  final Widget child;
  final SyncProductionCaller? caller;
  final SyncLifecycleRun? onRun;

  @override
  State<SyncLifecycleGate> createState() => _SyncLifecycleGateState();
}

class _SyncLifecycleGateState extends State<SyncLifecycleGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run(SyncProductionTrigger.appStart));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_run(SyncProductionTrigger.foregroundResume));
    }
  }

  Future<void> _run(SyncProductionTrigger trigger) async {
    final onRun = widget.onRun;
    if (onRun != null) {
      await onRun(trigger);
      return;
    }
    final caller = widget.caller ?? _readCaller();
    if (caller == null) return;
    await caller.runOnce(trigger: trigger);
  }

  SyncProductionCaller? _readCaller() {
    try {
      return context.read<SyncProductionCaller?>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
