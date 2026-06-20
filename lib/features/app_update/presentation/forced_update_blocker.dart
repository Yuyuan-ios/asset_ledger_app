import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../application/update_delivery.dart';
import '../domain/version_gate_decision.dart';

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
    final l10n = AppLocalizations.of(context);
    final title = _nonEmpty(decision.title) ?? l10n.appUpdateFallbackTitle;
    final content =
        _nonEmpty(decision.content) ?? l10n.appUpdateFallbackContent;

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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _handleUpdate,
                  child: Text(l10n.appUpdateActionUpdateNow),
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
