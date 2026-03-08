import 'package:flutter/material.dart';
import '../../core/foundation/radius.dart' as foundation;
import '../../tokens/mapper/bottom_sheet_tokens.dart';
import '../../tokens/mapper/core_tokens.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color backgroundColor = Colors.transparent,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}

/// 编辑类 BottomSheet 的统一打开入口。
///
/// 目的：
/// 1) 统一 `showAppBottomSheet + AppBottomSheetShell` 调用样板代码
/// 2) 页面仅关注业务 child 与 onConfirm 提交逻辑
Future<T?> openEditorSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder childBuilder,
  VoidCallback? onConfirm,
  void Function(BuildContext sheetContext)? onCancel,
  bool useSafeArea = true,
  bool scrollable = false,
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
  double dividerToContentGap = BottomSheetTokens.dividerToContentGap,
}) {
  return showAppBottomSheet<T>(
    context: context,
    useSafeArea: useSafeArea,
    builder: (sheetContext) {
      return AppBottomSheetShell(
        title: title,
        scrollable: scrollable,
        contentPadding: contentPadding,
        dividerToContentGap: dividerToContentGap,
        onCancel: () {
          if (onCancel != null) {
            onCancel(sheetContext);
            return;
          }
          Navigator.of(sheetContext).pop();
        },
        onConfirm: onConfirm,
        child: childBuilder(sheetContext),
      );
    },
  );
}

/// 通用 BottomSheet 壳（Shell）
///
/// 设计目标：
/// 1) 统一圆角、拖拽把手、SafeArea、默认高度
/// 2) 只负责容器，不承载业务内容
/// 3) content 由外部 child 传入，便于在 account / timing / fuel / maintenance 复用
///
/// 用法：
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => AppBottomSheetShell(
///     title: '标题(可选)',
///     child: YourDetailContent(),
///   ),
/// );
class AppBottomSheetShell extends StatelessWidget {
  final String? title;
  final Widget child;
  final double initialHeightFactor;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;
  final double radius;
  final TextStyle? titleStyle;
  final Widget? headerTrailing;
  final double handleWidth;
  final Color? handleColor;
  final double headerSideInset;
  final double dividerSideInset;
  final double headerToDividerGap;
  final double dividerToContentGap;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelText;
  final String confirmText;
  final bool footerEnabled;

  const AppBottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.initialHeightFactor = BottomSheetTokens.heightFactor,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(
      BottomSheetTokens.outerHPadding,
      BottomSheetTokens.outerTopPadding,
      BottomSheetTokens.outerHPadding,
      BottomSheetTokens.shellContentBottomPadding,
    ),
    this.radius = BottomSheetTokens.radius,
    this.titleStyle,
    this.headerTrailing,
    this.handleWidth = BottomSheetTokens.handleWidth,
    this.handleColor,
    this.headerSideInset = 0,
    this.dividerSideInset = 0,
    this.headerToDividerGap = BottomSheetTokens.headerToDividerGap,
    this.dividerToContentGap = BottomSheetTokens.dividerToContentGap,
    this.onCancel,
    this.onConfirm,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.footerEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final keyboardInset = media.viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final hasFooter = footerEnabled && (onCancel != null || onConfirm != null);

    final factor = initialHeightFactor.clamp(
      BottomSheetTokens.minHeightFactor,
      BottomSheetTokens.maxHeightFactor,
    );
    final sheetHeight = h * factor;

    final sheet = Material(
      color: SheetColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: BottomSheetTokens.shellTopGap),
              _DragHandle(width: handleWidth, color: handleColor),
              const SizedBox(height: BottomSheetTokens.shellHandleBottomGap),

              if (title != null && title!.trim().isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        BottomSheetTokens.outerHPadding + headerSideInset,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              titleStyle ??
                              const TextStyle(
                                fontSize: BottomSheetTokens.titleSize,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (headerTrailing != null)
                        headerTrailing!
                      else
                        IconButton(
                          tooltip: '关闭',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: headerToDividerGap),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dividerSideInset),
                  child: const Divider(
                    height: BottomSheetTokens.dividerThickness,
                    thickness: BottomSheetTokens.dividerThickness,
                  ),
                ),
                SizedBox(height: dividerToContentGap),
              ],

              Expanded(
                child: Padding(
                  padding: contentPadding,
                  child: scrollable
                      ? SingleChildScrollView(
                          // 让 sheet 内部滚动更顺滑
                          physics: const BouncingScrollPhysics(),
                          child: child,
                        )
                      : child,
                ),
              ),
              if (hasFooter) ...[
                const SizedBox(height: BottomSheetTokens.footerContentGap),
                _BottomSheetFooter(
                  onCancel: onCancel,
                  onConfirm: onConfirm,
                  cancelText: cancelText,
                  confirmText: confirmText,
                ),
                _FooterKeyboardCompensation(),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardVisible
            ? (keyboardInset - BottomSheetTokens.keyboardTopOverlap).clamp(
                0.0,
                keyboardInset,
              )
            : 0.0,
      ),
      child: Align(alignment: Alignment.bottomCenter, child: sheet),
    );
  }
}

/// 顶部拖拽把手（统一样式）
class _DragHandle extends StatelessWidget {
  final double width;
  final Color? color;

  const _DragHandle({this.width = BottomSheetTokens.handleWidth, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: BottomSheetTokens.handleHeight,
      decoration: BoxDecoration(
        color: color ?? SheetColors.handle,
        borderRadius: BorderRadius.circular(foundation.AppRadius.pill),
      ),
    );
  }
}

class _BottomSheetFooter extends StatelessWidget {
  const _BottomSheetFooter({
    required this.onCancel,
    required this.onConfirm,
    required this.cancelText,
    required this.confirmText,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelText;
  final String confirmText;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardVisible = media.viewInsets.bottom > 0;
    final bottomPadding = keyboardVisible
        ? 0.0
        : BottomSheetTokens.footerBottom + media.viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BottomSheetTokens.footerHorizontal,
        0,
        BottomSheetTokens.footerHorizontal,
        bottomPadding,
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: BottomSheetTokens.actionTextSize,
              ),
              foregroundColor: AppColors.brand.withValues(alpha: 0.8),
            ),
            child: Text(cancelText),
          ),
          const Spacer(),
          SizedBox(
            width: BottomSheetTokens.actionButtonWidth,
            height: BottomSheetTokens.actionButtonHeight,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    BottomSheetTokens.actionButtonRadius,
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: BottomSheetTokens.actionTextSize,
                ),
              ),
              child: Text(confirmText),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterKeyboardCompensation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return SizedBox(
      height: keyboardVisible ? BottomSheetTokens.keyboardTopOverlap : 0.0,
    );
  }
}
