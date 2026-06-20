import '../domain/version_gate_decision.dart';
import '../domain/version_policy.dart';
import '../presentation/optional_update_prompt.dart';

enum UpdateChannelEnvironment { playStore, directStore }

typedef InAppUpdateLauncher =
    Future<bool> Function(VersionGateDecision decision);

class UpdateDelivery {
  UpdateDelivery({
    required String channel,
    UpdateUrlLauncher urlLauncher = launchExternalUpdateUrl,
    InAppUpdateLauncher? inAppUpdateLauncher,
  }) : _channel = channel,
       _urlLauncher = urlLauncher,
       // V5: in_app_update reserved hook, injected later per channel build.
       _inAppUpdateLauncher = inAppUpdateLauncher;

  final String _channel;
  final UpdateUrlLauncher _urlLauncher;
  final InAppUpdateLauncher? _inAppUpdateLauncher;

  UpdateChannelEnvironment get environment {
    return _channel == VersionPolicy.channelPlay
        ? UpdateChannelEnvironment.playStore
        : UpdateChannelEnvironment.directStore;
  }

  Future<void> launch(VersionGateDecision decision) async {
    if (environment == UpdateChannelEnvironment.playStore &&
        _inAppUpdateLauncher != null) {
      try {
        final handled = await _inAppUpdateLauncher(decision);
        if (handled) return;
      } catch (_) {
        // Fall back to URL delivery when the reserved in-app path fails.
      }
    }

    final rawUrl = decision.updateUrl?.trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return;

    try {
      await _urlLauncher(uri);
    } catch (_) {
      // Store launch failures must not crash update prompts.
    }
  }
}
