import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../domain/version_gate_decision.dart';
import '../domain/version_policy.dart';

enum UpdateChannelEnvironment { playStore, directStore }

typedef UpdateUrlLauncher = Future<bool> Function(Uri uri);

typedef InAppUpdateLauncher =
    Future<bool> Function(VersionGateDecision decision);

/// Opens [uri] in an external application (browser / store app).
///
/// Lives in the application layer so both the optional prompt and the forced
/// blocker (presentation) and [UpdateDelivery] depend on it one-directionally,
/// avoiding the previous presentation↔application import cycle.
Future<bool> launchExternalUpdateUrl(Uri uri) {
  return url_launcher.launchUrl(
    uri,
    mode: url_launcher.LaunchMode.externalApplication,
  );
}

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
