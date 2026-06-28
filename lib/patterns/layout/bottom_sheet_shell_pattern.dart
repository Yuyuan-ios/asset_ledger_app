import 'package:flutter/material.dart';
import '../../components/surfaces/app_glass_surface.dart';
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
    sheetAnimationStyle: const AnimationStyle(
      duration: BottomSheetTokens.animationDuration,
      reverseDuration: BottomSheetTokens.reverseAnimationDuration,
    ),
    builder: (_) => _AppBottomSheetFeedbackHost(builder: builder),
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
  WidgetBuilder? titleTrailingBuilder,
  WidgetBuilder? headerTrailingBuilder,
  WidgetBuilder? footerCenterBuilder,
  String cancelText = '取消',
  String confirmText = '确定',
  Color? cancelForegroundColor,
  bool footerEnabled = true,
  bool useSafeArea = true,
  Color? backgroundColor,
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
        backgroundColor: backgroundColor,
        dividerToContentGap: dividerToContentGap,
        onCancel: () {
          if (onCancel != null) {
            onCancel(sheetContext);
            return;
          }
          Navigator.of(sheetContext).pop();
        },
        onConfirm: onConfirm,
        titleTrailing: titleTrailingBuilder?.call(sheetContext),
        headerTrailing: headerTrailingBuilder?.call(sheetContext),
        footerCenter: footerCenterBuilder?.call(sheetContext),
        cancelText: cancelText,
        confirmText: confirmText,
        cancelForegroundColor: cancelForegroundColor,
        footerEnabled: footerEnabled,
        child: childBuilder(sheetContext),
      );
    },
  );
}

class _AppBottomSheetFeedbackHost extends StatelessWidget {
  const _AppBottomSheetFeedbackHost({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        key: const ValueKey('app-bottom-sheet-feedback-host'),
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Builder(builder: builder),
      ),
    );
  }
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
  final Widget? titleTrailing;
  final Widget? headerTrailing;
  final double handleWidth;
  final Color? handleColor;
  final Color? backgroundColor;
  final double headerSideInset;
  final double dividerSideInset;
  final double headerToDividerGap;
  final double dividerToContentGap;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Widget? footerCenter;
  final String cancelText;
  final String confirmText;
  final Color? cancelForegroundColor;
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
    this.titleTrailing,
    this.headerTrailing,
    this.handleWidth = BottomSheetTokens.handleWidth,
    this.handleColor,
    this.backgroundColor,
    this.headerSideInset = 0,
    this.dividerSideInset = 0,
    this.headerToDividerGap = BottomSheetTokens.headerToDividerGap,
    this.dividerToContentGap = BottomSheetTokens.dividerToContentGap,
    this.onCancel,
    this.onConfirm,
    this.footerCenter,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.cancelForegroundColor,
    this.footerEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final keyboardInset = media.viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final hasFooter = footerEnabled && (onCancel != null || onConfirm != null);
    final keyboardBottomGap = keyboardVisible
        ? (keyboardInset - BottomSheetTokens.keyboardTopOverlap).clamp(
            0.0,
            keyboardInset,
          )
        : 0.0;

    final factor = initialHeightFactor.clamp(
      BottomSheetTokens.minHeightFactor,
      BottomSheetTokens.maxHeightFactor,
    );
    final sheetHeight = h * factor;

    final sheetBorderRadius = BorderRadius.vertical(
      top: Radius.circular(radius),
    );
    final sheetContent = SafeArea(
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
                  horizontal: BottomSheetTokens.outerHPadding + headerSideInset,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
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
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 6),
                            titleTrailing!,
                          ],
                        ],
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
              _SoftHeaderDivider(horizontalInset: dividerSideInset),
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
                center: footerCenter,
                cancelText: cancelText,
                confirmText: confirmText,
                cancelForegroundColor: cancelForegroundColor,
              ),
              _FooterKeyboardCompensation(),
            ],
          ],
        ),
      ),
    );
    final sheet = _BottomSheetSurface(
      backgroundColor: backgroundColor,
      borderRadius: sheetBorderRadius,
      child: sheetContent,
    );

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        _BottomSheetKeyboardGapFill(
          height: keyboardBottomGap,
          backgroundColor: backgroundColor,
        ),
        Padding(
          padding: EdgeInsets.only(bottom: keyboardBottomGap),
          child: Align(alignment: Alignment.bottomCenter, child: sheet),
        ),
      ],
    );
  }
}

class _BottomSheetKeyboardGapFill extends StatelessWidget {
  const _BottomSheetKeyboardGapFill({
    required this.height,
    required this.backgroundColor,
  });

  final double height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ColoredBox(
          color: backgroundColor ?? GlassTokens.surfaceBottomBackground,
          child: SizedBox(
            key: const ValueKey('app-bottom-sheet-keyboard-gap-fill'),
            width: double.infinity,
            height: height,
          ),
        ),
      ),
    );
  }
}

class _BottomSheetSurface extends StatelessWidget {
  const _BottomSheetSurface({
    required this.backgroundColor,
    required this.borderRadius,
    required this.child,
  });

  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final explicitBackground = backgroundColor;
    if (explicitBackground != null) {
      return Material(
        color: explicitBackground,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return AppGlassSurface(
      borderRadius: borderRadius,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _SoftHeaderDivider extends StatelessWidget {
  const _SoftHeaderDivider({required this.horizontalInset});

  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: BottomSheetTokens.dividerThickness,
      margin: EdgeInsets.symmetric(horizontal: 16 + horizontalInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00D8CEC4),
            Color(0x78D8CEC4),
            Color(0x78D8CEC4),
            Color(0x00D8CEC4),
          ],
          stops: [0.0, 0.06, 0.94, 1.0],
        ),
      ),
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
    this.center,
    required this.cancelText,
    required this.confirmText,
    this.cancelForegroundColor,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Widget? center;
  final String cancelText;
  final String confirmText;
  final Color? cancelForegroundColor;

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
              foregroundColor:
                  cancelForegroundColor ??
                  AppColors.brand.withValues(alpha: 0.8),
            ),
            child: Text(cancelText),
          ),
          Expanded(child: Center(child: center ?? const SizedBox.shrink())),
          SizedBox(
            width: BottomSheetTokens.actionButtonWidth,
            height: BottomSheetTokens.actionButtonHeight,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryActionCapsule,
                foregroundColor: SheetColors.actionOn,
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
