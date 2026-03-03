import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

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
  final InputDecoration? decoration;
  final InputDecoration Function(InputDecoration base)? decorationBuilder;
  final TextStyle? textStyle;
  final double optionsElevation;
  final BorderRadius optionsBorderRadius;
  final BoxConstraints optionsConstraints;

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
    this.decoration,
    this.decorationBuilder,
    this.textStyle,
    this.optionsElevation = SheetTokens.suggestMenuElevation,
    this.optionsBorderRadius = const BorderRadius.all(
      Radius.circular(SheetTokens.suggestMenuRadius),
    ),
    this.optionsConstraints = const BoxConstraints(
      maxHeight: SheetTokens.suggestMenuMaxHeight,
      minWidth: SheetTokens.suggestMenuMinWidth,
    ),
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
        final baseDecoration =
            widget.decoration ??
            InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: SheetTokens.fieldTextSize,
                color: SheetColors.hint,
              ),
              labelStyle: const TextStyle(
                fontSize: SheetTokens.fieldLabelSize,
                color: SheetColors.textPrimary,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              filled: true,
              fillColor: SheetColors.fieldBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SheetTokens.fieldContentHPadding,
                vertical: SheetTokens.fieldContentVPadding,
              ),
              suffixIcon: const Padding(
                padding: EdgeInsets.only(
                  right: SheetTokens.fieldSuffixRightPadding,
                ),
                child: Icon(Icons.arrow_drop_down, color: SheetColors.muted),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
                borderSide: const BorderSide(
                  color: SheetColors.fieldBorder,
                  width: SheetTokens.fieldBorderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
                borderSide: const BorderSide(
                  color: SheetColors.fieldBorder,
                  width: SheetTokens.fieldBorderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
                borderSide: const BorderSide(
                  color: SheetColors.fieldBorder,
                  width: SheetTokens.fieldBorderWidth,
                ),
              ),
            );

        // 注意：textEditingController 就是 widget.controller（我们已传入）
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          style:
              widget.textStyle ??
              const TextStyle(
                fontSize: SheetTokens.fieldTextSize,
                color: SheetColors.textPrimary,
              ),
          decoration: widget.decorationBuilder != null
              ? widget.decorationBuilder!(baseDecoration)
              : baseDecoration,
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: widget.optionsElevation,
            borderRadius: widget.optionsBorderRadius,
            child: ConstrainedBox(
              constraints: widget.optionsConstraints,
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
