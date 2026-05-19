import 'package:flutter/material.dart';

/// 顶部标题右侧的“分享 + 关闭”动作组。
///
/// 注意：AppBottomSheetShell 在提供 headerTrailing 时会替换默认关闭按钮，
/// 因此这里必须同时承载分享与关闭，保证原关闭行为不丢。
class ProjectDetailHeaderActions extends StatelessWidget {
  const ProjectDetailHeaderActions({
    super.key,
    required this.onShare,
    required this.onClose,
  });

  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '分享项目',
          icon: const Icon(Icons.ios_share),
          onPressed: onShare,
        ),
        IconButton(
          tooltip: '关闭',
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ],
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
            '对方导入后，会在“项目外协”中看到这个名称。',
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
