import 'package:flutter/material.dart';

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

  const AppBottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.initialHeightFactor = 0.88,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;

    // 防御：高度比例限制到合理范围
    final factor = initialHeightFactor.clamp(0.2, 0.98);
    final sheetHeight = h * factor;

    final sheet = Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // ───────────────────── 顶部拖拽把手 ─────────────────────
              const SizedBox(height: 10),
              _DragHandle(),
              const SizedBox(height: 8),

              // ───────────────────── 可选标题栏 ─────────────────────
              if (title != null && title!.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      // 右侧关闭按钮（统一体验）
                      IconButton(
                        tooltip: '关闭',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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
        bottom: media.viewInsets.bottom, // 键盘顶起
      ),
      child: Align(alignment: Alignment.bottomCenter, child: sheet),
    );
  }
}

/// 顶部拖拽把手（统一样式）
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
