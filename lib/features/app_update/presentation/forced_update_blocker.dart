import 'package:flutter/material.dart';

import '../application/update_delivery.dart';
import '../domain/version_gate_decision.dart';
import '../domain/version_policy.dart';

// V7: l10n
const String _updateNowText = '立即更新';

Future<void> showForcedUpdateBlocker({
  required BuildContext context,
  required VersionGateDecision decision,
  required UpdateDelivery delivery,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) {
        return ForcedUpdateBlockerPage(decision: decision, delivery: delivery);
      },
    ),
  );
}

class ForcedUpdateBlockerPage extends StatelessWidget {
  const ForcedUpdateBlockerPage({
    super.key,
    required this.decision,
    required this.delivery,
  });

  final VersionGateDecision decision;
  final UpdateDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final title = _nonEmpty(decision.title) ?? VersionPolicy.fallbackTitle;
    final content =
        _nonEmpty(decision.content) ?? VersionPolicy.fallbackContent;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF261F1A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: const Color(0xFF4A4038),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _handleUpdate,
                  child: const Text(_updateNowText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    await delivery.launch(decision);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
