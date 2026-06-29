import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/account/account_dialog_shell_pattern.dart';
import '../../model/account_view_model.dart';
import '../../model/project_title_formatter.dart';

class DissolveMergeConfirmDialog extends StatefulWidget {
  const DissolveMergeConfirmDialog({
    super.key,
    required this.project,
    required this.onConfirm,
    required this.onError,
  });

  final AccountProjectVM project;
  final Future<void> Function() onConfirm;
  final void Function(String message) onError;

  @override
  State<DissolveMergeConfirmDialog> createState() =>
      _DissolveMergeConfirmDialogState();
}

class _DissolveMergeConfirmDialogState
    extends State<DissolveMergeConfirmDialog> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = widget.project.memberProjectKeys.map((key) {
      return ProjectTitleFormatter.fromProjectKey(key);
    }).toList();

    return AccountDialogShell(
      title: l10n.accountDissolveConfirmTitle,
      cancelText: l10n.accountCancelAction,
      confirmText: _submitting
          ? l10n.accountDissolvingAction
          : l10n.accountDissolveMergeAction,
      onCancel: _submitting ? null : () => Navigator.of(context).pop(false),
      onConfirm: _submitting ? null : _confirm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDissolveIntro),
          const SizedBox(height: 8),
          for (final project in projects) Text(project),
          const SizedBox(height: 12),
          Text(l10n.accountDissolveHelp),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
    });

    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      widget.onError(
        AppLocalizations.of(
          context,
        ).accountDissolveFailureWithReason(error.toString()),
      );
    }
  }
}
