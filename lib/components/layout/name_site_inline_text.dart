import 'package:flutter/material.dart';

import '../../core/utils/display_text_formatter.dart';

/// 将“姓名 · 地址”两段文本以独立省略策略并排显示。
///
/// 关键能力：
/// - [name] 与 [site] 各自拥有省略空间，长文本不会让其中一侧完全消失；
/// - 当两侧均较长时，分别截断为类似 `Christopher John... · West Industrial...`；
/// - 当外部父布局没有固定占位时（例如卡片标题没有右侧按钮），可借助
///   [Expanded] 等让本组件吃满到父容器右边缘；当右侧存在固定内容时，本组件
///   只占据其分配到的约束。
class NameSiteInlineText extends StatelessWidget {
  const NameSiteInlineText({
    super.key,
    required this.name,
    this.site,
    this.nameStyle,
    this.siteStyle,
    this.separatorStyle,
    this.separator = DisplayTextFormatter.separator,
    this.maxLines = 1,
    this.textAlign,
  });

  final String name;
  final String? site;
  final TextStyle? nameStyle;
  final TextStyle? siteStyle;
  final TextStyle? separatorStyle;
  final String separator;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final trimmedSite = site?.trim() ?? '';

    if (trimmedSite.isEmpty) {
      return Text(
        trimmedName,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: maxLines > 1,
        textAlign: textAlign,
        style: nameStyle,
      );
    }
    if (trimmedName.isEmpty) {
      return Text(
        trimmedSite,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: maxLines > 1,
        textAlign: textAlign,
        style: siteStyle ?? nameStyle,
      );
    }

    final resolvedNameStyle = DefaultTextStyle.of(
      context,
    ).style.merge(nameStyle);
    final resolvedSiteStyle = DefaultTextStyle.of(
      context,
    ).style.merge(siteStyle ?? nameStyle);
    final resolvedSeparatorStyle = DefaultTextStyle.of(
      context,
    ).style.merge(separatorStyle ?? nameStyle);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return _buildRow(
            nameMax: double.infinity,
            siteMax: double.infinity,
            nameStyle: resolvedNameStyle,
            siteStyle: resolvedSiteStyle,
            separatorStyle: resolvedSeparatorStyle,
            trimmedName: trimmedName,
            trimmedSite: trimmedSite,
          );
        }

        final nameWidth = _measure(
          trimmedName,
          resolvedNameStyle,
          textScaler,
          textDirection,
        );
        final separatorWidth = _measure(
          separator,
          resolvedSeparatorStyle,
          textScaler,
          textDirection,
        );
        final siteWidth = _measure(
          trimmedSite,
          resolvedSiteStyle,
          textScaler,
          textDirection,
        );

        final available = (maxWidth - separatorWidth).clamp(0.0, maxWidth);
        double nameMax;
        double siteMax;
        if (nameWidth + siteWidth <= available) {
          // 自然宽度即可放下；保留一点点余量以容忍像素取整。
          nameMax = nameWidth + 0.5;
          siteMax = siteWidth + 0.5;
        } else {
          final half = available / 2;
          if (nameWidth <= half) {
            nameMax = nameWidth;
            siteMax = available - nameWidth;
          } else if (siteWidth <= half) {
            siteMax = siteWidth;
            nameMax = available - siteWidth;
          } else {
            nameMax = half;
            siteMax = available - half;
          }
        }

        return _buildRow(
          nameMax: nameMax,
          siteMax: siteMax,
          nameStyle: resolvedNameStyle,
          siteStyle: resolvedSiteStyle,
          separatorStyle: resolvedSeparatorStyle,
          trimmedName: trimmedName,
          trimmedSite: trimmedSite,
        );
      },
    );
  }

  Widget _buildRow({
    required double nameMax,
    required double siteMax,
    required TextStyle nameStyle,
    required TextStyle siteStyle,
    required TextStyle separatorStyle,
    required String trimmedName,
    required String trimmedSite,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: nameMax),
          child: Text(
            trimmedName,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: maxLines > 1,
            textAlign: textAlign,
            style: nameStyle,
          ),
        ),
        Text(separator, maxLines: 1, softWrap: false, style: separatorStyle),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: siteMax),
          child: Text(
            trimmedSite,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: maxLines > 1,
            textAlign: textAlign,
            style: siteStyle,
          ),
        ),
      ],
    );
  }

  double _measure(
    String text,
    TextStyle style,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final width = painter.size.width;
    painter.dispose();
    return width;
  }
}
