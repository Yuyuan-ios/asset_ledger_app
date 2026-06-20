import 'package:flutter/widgets.dart';

import '../domain/version_gate_decision.dart';

typedef VersionCheckRunner =
    Future<VersionGateDecision> Function({required bool isColdStart});

typedef UpdatePromptPresenter =
    Future<void> Function(BuildContext context, VersionGateDecision decision);

typedef ForcedUpdatePresenter =
    Future<void> Function(BuildContext context, VersionGateDecision decision);

class UpdatePromptCoordinator {
  UpdatePromptCoordinator({
    required VersionCheckRunner checkVersion,
    required UpdatePromptPresenter showPrompt,
    required ForcedUpdatePresenter showForcedBlocker,
  }) : _checkVersion = checkVersion,
       _showPrompt = showPrompt,
       _showForcedBlocker = showForcedBlocker;

  factory UpdatePromptCoordinator.noop() {
    return UpdatePromptCoordinator(
      checkVersion: ({required bool isColdStart}) async {
        return const VersionGateDecision.none();
      },
      showPrompt: (context, decision) async {},
      showForcedBlocker: (context, decision) async {},
    );
  }

  final VersionCheckRunner _checkVersion;
  final UpdatePromptPresenter _showPrompt;
  final ForcedUpdatePresenter _showForcedBlocker;

  var _hasCheckedFromTimingPage = false;
  var _hasShownForcedBlocker = false;
  var _hasShownOptionalPrompt = false;

  Future<void> onTimingPageEntered(BuildContext context) async {
    final isColdStart = !_hasCheckedFromTimingPage;
    _hasCheckedFromTimingPage = true;

    try {
      final decision = await _checkVersion(isColdStart: isColdStart);
      if (decision.level == VersionGateLevel.forced) {
        if (_hasShownForcedBlocker) return;

        if (!context.mounted) return;
        _hasShownForcedBlocker = true;
        await _showForcedBlocker(context, decision);
        return;
      }

      if (decision.level != VersionGateLevel.optional) return;
      if (_hasShownOptionalPrompt) return;

      _hasShownOptionalPrompt = true;
      if (!context.mounted) return;
      await _showPrompt(context, decision);
    } catch (_) {
      // Version checks are fail-open and must never block page entry.
    }
  }
}
