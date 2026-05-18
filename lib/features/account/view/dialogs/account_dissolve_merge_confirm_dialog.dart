import 'package:flutter/material.dart';

import '../../domain/entities/account_entities.dart';
import '../../model/account_view_model.dart';

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
    final projects = widget.project.memberProjectKeys.map((key) {
      return ProjectKey.fromKey(key).displayName;
    }).toList();

    return AlertDialog(
      title: const Text('解除合并？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('解除后将恢复为普通项目：'),
          const SizedBox(height: 8),
          for (final project in projects) Text(project),
          const SizedBox(height: 12),
          const Text('原始计时记录不会删除。\n设备、工时、单价不会改变。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _confirm,
          child: Text(_submitting ? '解除中' : '解除合并'),
        ),
      ],
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
      widget.onError('解除合并失败：$error');
    }
  }
}
