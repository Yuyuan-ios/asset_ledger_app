import 'package:flutter/material.dart';

// =====================================================================
// ============================== AutoSuggestField（通用联想输入框） ==============================
// =====================================================================
//
// 目标：
// - 全 App 统一“输入框 + 下拉联想”体验（供应人/联系人/工地等）
// - Page 不写联想 UI 细节，只提供 suggestionsBuilder(query)
// - Widget 不持久化业务数据，只负责交互
//
// 关键修复：
// - 不能在 build() 里 new FocusNode()（会泄漏且引发生命周期断言）
// - 若外部没传 focusNode：内部创建并在 dispose() 释放
// - RawAutocomplete 已绑定外部 controller，不做“内部/外部 controller 同步”
// =====================================================================

class AutoSuggestField extends StatefulWidget {
  final TextEditingController controller;

  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  final List<String> Function(String query) suggestionsBuilder;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onChanged;

  /// 可选：外部传入 focusNode（跨组件控制焦点时用）
  final FocusNode? focusNode;

  const AutoSuggestField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestionsBuilder,
    required this.onSelected,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.focusNode,
  });

  @override
  State<AutoSuggestField> createState() => _AutoSuggestFieldState();
}

class _AutoSuggestFieldState extends State<AutoSuggestField> {
  FocusNode? _innerNode;

  FocusNode get _node => widget.focusNode ?? (_innerNode ??= FocusNode());

  @override
  void dispose() {
    // 只释放内部创建的 FocusNode（外部传入的不归我们管）
    _innerNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _node,

      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim();
        if (q.isEmpty) {
          // 允许你仍然返回“最近候选”，由 Store/Service 决定
          return widget.suggestionsBuilder('');
        }
        return widget.suggestionsBuilder(q);
      },

      displayStringForOption: (s) => s,

      onSelected: (v) {
        widget.onSelected(v);
        widget.onChanged?.call(v);
      },

      fieldViewBuilder: (context, textEditingController, focusNode, _) {
        // 注意：textEditingController 就是 widget.controller（我们已传入）
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(opt),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
