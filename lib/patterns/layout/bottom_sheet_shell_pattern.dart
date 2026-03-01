import 'package:flutter/material.dart';
import '../../core/foundation/radius.dart' as foundation;
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

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
  /// 顶部标题（可选；不传就不显示标题区）
  final String? title;

  /// 内容区域（必填）
  final Widget child;

  /// 默认高度比例（相对屏幕高度）
  /// 例如 0.88 表示占屏幕高度 88%
  final double initialHeightFactor;

  /// 是否允许内容滚动（通常需要：列表/表单）
  final bool scrollable;

  /// 内容内边距（默认 16）
  final EdgeInsetsGeometry contentPadding;

  /// 圆角（默认 20）
  final double radius;
  final TextStyle? titleStyle;
  final Widget? headerTrailing;
  final double handleWidth;
  final Color? handleColor;
  final double headerSideInset;
  final double dividerSideInset;
  final double headerToDividerGap;
  final double dividerToContentGap;

  const AppBottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.initialHeightFactor = SheetTokens.heightFactor,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(
      SheetTokens.outerHPadding,
      SheetTokens.outerTopPadding,
      SheetTokens.outerHPadding,
      SheetTokens.shellContentBottomPadding,
    ),
    this.radius = SheetTokens.radius,
    this.titleStyle,
    this.headerTrailing,
    this.handleWidth = SheetTokens.handleWidth,
    this.handleColor,
    this.headerSideInset = 0,
    this.dividerSideInset = 0,
    this.headerToDividerGap = SheetTokens.headerToDividerGap,
    this.dividerToContentGap = SheetTokens.dividerToContentGap,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final keyboardInset = media.viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;

    // 防御：高度比例限制到合理范围（与 token 上限保持一致，避免“改 token 无效”）
    final factor = initialHeightFactor.clamp(
      SheetTokens.minHeightFactor,
      SheetTokens.maxHeightFactor,
    );
    final sheetHeight = h * factor;

    final sheet = Material(
      color: AppColors.sheetBackground,
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
              // ───────────────────── 顶部拖拽把手 ─────────────────────
              const SizedBox(height: SheetTokens.shellTopGap),
              _DragHandle(width: handleWidth, color: handleColor),
              const SizedBox(height: SheetTokens.shellHandleBottomGap),

              // ───────────────────── 可选标题栏 ─────────────────────
              if (title != null && title!.trim().isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SheetTokens.outerHPadding + headerSideInset,
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
                                fontSize: SheetTokens.titleSize,
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
                    height: SheetTokens.dividerThickness,
                    thickness: SheetTokens.dividerThickness,
                  ),
                ),
                SizedBox(height: dividerToContentGap),
              ],

              // ───────────────────── 内容区域 ─────────────────────
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
            ],
          ),
        ),
      ),
    );

    // 外层透明遮罩 + 顶部留空，保证圆角露出来
    return Padding(
      padding: EdgeInsets.only(
        // 键盘弹起时轻微覆盖键盘顶部，减少 iOS 顶部圆角的突兀感
        bottom: keyboardVisible
            ? (keyboardInset - SheetTokens.keyboardTopOverlap).clamp(
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

  const _DragHandle({this.width = SheetTokens.handleWidth, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: SheetTokens.handleHeight,
      decoration: BoxDecoration(
        color: color ?? AppColors.sheetHandle,
        borderRadius: BorderRadius.circular(foundation.AppRadius.pill),
      ),
    );
  }
}
