import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProjectDetailShareButton extends StatelessWidget {
  const ProjectDetailShareButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        key: const Key('project-detail-share-button'),
        tooltip: '分享项目',
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
      setState(() => _error = '请输入分享人姓名或包名');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('分享项目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _shareNameMaxLength,
            decoration: InputDecoration(
              labelText: '分享人姓名或包名',
              hintText: '例如：老王外协记录',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            '对方导入后，会在“外协项目”中看到这个名称。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('生成分享包')),
      ],
    );
  }
}
