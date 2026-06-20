import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/version_gate_decision.dart';
import 'update_prompt_coordinator.dart';

class ForcedUpdateController {
  ForcedUpdateController({
    required GlobalKey<NavigatorState> navigatorKey,
    required ForcedUpdatePresenter showForcedBlocker,
  }) : _navigatorKey = navigatorKey,
       _showForcedBlocker = showForcedBlocker;

  final GlobalKey<NavigatorState> _navigatorKey;
  final ForcedUpdatePresenter _showForcedBlocker;

  var _handled = false;
  VersionGateDecision? _pendingDecision;

  void signalUpgradeRequired(VersionGateDecision decision) {
    if (_handled) return;

    final selectedDecision = _pendingDecision ?? decision;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _pendingDecision = selectedDecision;
      return;
    }

    _handled = true;
    _pendingDecision = null;
    unawaited(_showBlocker(context, selectedDecision));
  }

  Future<void> _showBlocker(
    BuildContext context,
    VersionGateDecision decision,
  ) async {
    try {
      await _showForcedBlocker(context, decision);
    } catch (_) {
      // 传输层 426 只负责触发强制更新入口,展示失败不能反向打断 API 调用链。
    }
  }
}
