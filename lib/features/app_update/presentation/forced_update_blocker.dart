import 'package:flutter/material.dart';

import '../domain/version_gate_decision.dart';
import '../domain/version_policy.dart';
import 'optional_update_prompt.dart';

// V7: l10n
const String _updateNowText = '立即更新';

Future<void> showForcedUpdateBlocker({
  required BuildContext context,
  required VersionGateDecision decision,
  UpdateUrlLauncher launcher = launchExternalUpdateUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) {
        return ForcedUpdateBlockerPage(decision: decision, launcher: launcher);
      },
    ),
  );
}

class ForcedUpdateBlockerPage extends StatelessWidget {
  const ForcedUpdateBlockerPage({
    super.key,
    required this.decision,
    required this.launcher,
  });

  final VersionGateDecision decision;
  final UpdateUrlLauncher launcher;

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
                  onPressed: () => _handleUpdate(context),
                  child: const Text(_updateNowText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    final rawUrl = decision.updateUrl?.trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return;

    try {
      await launcher(uri);
    } catch (_) {
      // Store launch failures must not crash the forced-update route.
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
