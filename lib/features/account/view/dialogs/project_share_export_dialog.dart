import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/account/account_dialog_shell_pattern.dart';
import '../../../../patterns/layout/sheet_text_field_pattern.dart';

class ProjectDetailShareButton extends StatelessWidget {
  const ProjectDetailShareButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        key: const Key('project-detail-share-button'),
        tooltip: l10n.accountShareProjectTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF111111),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(math.pi),
          child: const Icon(Icons.reply_rounded, size: 32),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

const int _shareNameMaxLength = 30;

/// 轻量输入弹窗：返回去空格后的非空名称；取消返回 null。
Future<String?> showProjectShareNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ProjectShareNameDialog(),
  );
}

class _ProjectShareNameDialog extends StatefulWidget {
  const _ProjectShareNameDialog();

  @override
  State<_ProjectShareNameDialog> createState() =>
      _ProjectShareNameDialogState();
}

class _ProjectShareNameDialogState extends State<_ProjectShareNameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).accountShareNameRequired,
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AccountDialogShell(
      title: l10n.accountShareProjectTitle,
      cancelText: l10n.accountCancelAction,
      confirmText: l10n.accountGenerateSharePackageAction,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTextFieldPattern(
            controller: _controller,
            autofocus: true,
            maxLength: _shareNameMaxLength,
            labelText: l10n.accountShareNameLabel,
            hintText: l10n.accountShareNameHint,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountShareNameHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
