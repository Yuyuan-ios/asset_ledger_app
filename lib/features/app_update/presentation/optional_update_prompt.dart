import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../application/update_delivery.dart';
import '../domain/version_gate_decision.dart';
import '../domain/version_policy.dart';

typedef UpdateUrlLauncher = Future<bool> Function(Uri uri);

// V7: l10n
const String _updateNowText = '立即更新';
// V7: l10n
const String _laterText = '稍后再说';

Future<void> showOptionalUpdatePrompt({
  required BuildContext context,
  required VersionGateDecision decision,
  required UpdateDelivery delivery,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return OptionalUpdatePromptSheet(
        decision: decision,
        delivery: delivery,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

Future<bool> launchExternalUpdateUrl(Uri uri) {
  return url_launcher.launchUrl(
    uri,
    mode: url_launcher.LaunchMode.externalApplication,
  );
}

class OptionalUpdatePromptSheet extends StatelessWidget {
  const OptionalUpdatePromptSheet({
    super.key,
    required this.decision,
    required this.delivery,
    required this.onClose,
  });

  final VersionGateDecision decision;
  final UpdateDelivery delivery;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = _nonEmpty(decision.title) ?? VersionPolicy.fallbackTitle;
    final content =
        _nonEmpty(decision.content) ?? VersionPolicy.fallbackContent;

    return AppBottomSheetShell(
      title: title,
      scrollable: false,
      initialHeightFactor: 0.36,
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      cancelText: _laterText,
      confirmText: _updateNowText,
      onCancel: onClose,
      onConfirm: () => _handleUpdate(context),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: const Color(0xFF312A25),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    await delivery.launch(decision);
    if (context.mounted) {
      onClose();
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
