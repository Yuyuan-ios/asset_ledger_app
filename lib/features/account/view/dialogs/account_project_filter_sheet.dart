import 'package:flutter/material.dart';

import '../../../../components/fields/app_auto_suggest_field.dart';
import '../../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../../tokens/mapper/bottom_sheet_tokens.dart';

enum AccountProjectFilterResultType { ok, clear, cancel }

class AccountProjectFilterResult {
  final AccountProjectFilterResultType type;
  final String keyword;

  const AccountProjectFilterResult._(this.type, this.keyword);

  const AccountProjectFilterResult.clear()
    : this._(AccountProjectFilterResultType.clear, '');

  const AccountProjectFilterResult.cancel()
    : this._(AccountProjectFilterResultType.cancel, '');

  AccountProjectFilterResult.ok(String keyword)
    : this._(AccountProjectFilterResultType.ok, keyword.trim());
}

Future<AccountProjectFilterResult?> showAccountProjectFilterSheet(
  BuildContext context, {
  required String initialKeyword,
  required List<String> suggestions,
}) {
  return showModalBottomSheet<AccountProjectFilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: const AnimationStyle(
      duration: BottomSheetTokens.animationDuration,
      reverseDuration: BottomSheetTokens.reverseAnimationDuration,
    ),
    builder: (_) => AccountProjectFilterSheet(
      initialKeyword: initialKeyword,
      suggestions: suggestions,
    ),
  );
}

class AccountProjectFilterSheet extends StatefulWidget {
  const AccountProjectFilterSheet({
    super.key,
    required this.initialKeyword,
    required this.suggestions,
  });

  final String initialKeyword;
  final List<String> suggestions;

  @override
  State<AccountProjectFilterSheet> createState() =>
      _AccountProjectFilterSheetState();
}

class _AccountProjectFilterSheetState extends State<AccountProjectFilterSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(AccountProjectFilterResult result) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    List<String> buildSuggestions(String keyword) {
      final query = keyword.trim();
      if (query.isEmpty) return widget.suggestions;
      return widget.suggestions
          .where((value) => value.contains(query))
          .toList(growable: false);
    }

    return AppBottomSheetShell(
      title: '筛选项目',
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      onCancel: () => _close(const AccountProjectFilterResult.cancel()),
      onConfirm: () => _close(AccountProjectFilterResult.ok(_controller.text)),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 0),
            child: Column(
              children: [
                AutoSuggestField(
                  controller: _controller,
                  label: '关键词（联系人 / 工地）',
                  hint: '例如：王涛 / 修文 / 地铁站',
                  suggestionsBuilder: buildSuggestions,
                  onSelected: (value) => _controller.text = value,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        _close(const AccountProjectFilterResult.clear()),
                    child: const Text('清空'),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
