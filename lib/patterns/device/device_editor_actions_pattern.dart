import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

class DeviceEditorActionsPattern {
  const DeviceEditorActionsPattern._();

  static List<Widget> build({
    required BuildContext context,
    required bool saving,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        onPressed: saving ? null : onCancel,
        child: Text(l10n.deviceCancelAction),
      ),
      FilledButton(
        onPressed: saving ? null : onConfirm,
        child: Text(l10n.deviceConfirmAction),
      ),
    ];
  }
}
