import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../application/update_delivery.dart';
import '../domain/version_gate_decision.dart';

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
    final l10n = AppLocalizations.of(context);
    final title = _nonEmpty(decision.title) ?? l10n.appUpdateFallbackTitle;
    final content =
        _nonEmpty(decision.content) ?? l10n.appUpdateFallbackContent;

    return AppBottomSheetShell(
      title: title,
      scrollable: false,
      initialHeightFactor: 0.36,
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      cancelText: l10n.appUpdateActionLater,
      confirmText: l10n.appUpdateActionUpdateNow,
      onCancel: onClose,
      onConfirm: () => _handleUpdate(context),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: SheetColors.textPrimary,
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
