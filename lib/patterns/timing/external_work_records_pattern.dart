import 'package:flutter/material.dart';

import '../../components/avatars/linked_external_work_badge.dart';
import '../../components/feedback/app_records_empty_hint.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/external_work_record.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../features/timing/view_models/external_work_records_view_model.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

const double _externalWorkEmptyTitleFontSize = 16;
const double _externalWorkEmptySubtitleFontSize = 15;

List<Widget> buildTimingExternalWorkRecordSlivers({
  required List<TimingExternalWorkRecordItem> items,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
}) {
  // 分组 / 标题 fallback / 状态 / 摘要等展示判断由 feature 层 builder 计算（C7）。
  // pattern 只负责渲染 VM 与回调点击事件。
  final vm = ExternalWorkRecordsViewModelBuilder.build(items);
  if (vm.isEmpty) {
    return const <Widget>[
      SliverToBoxAdapter(
        child: AppRecentRecordsEmptyState(
          title: '暂无外协项目记录',
          subtitle: '从他人分享的 .jzt 文件导入后，会显示在这里',
          titleFontSize: _externalWorkEmptyTitleFontSize,
          subtitleFontSize: _externalWorkEmptySubtitleFontSize,
        ),
      ),
    ];
  }

  return <Widget>[
    for (final yearGroup in vm.yearGroups) ...[
      SliverToBoxAdapter(child: _ExternalWorkYearHeader(year: yearGroup.year)),
      for (
        var sourceIndex = 0;
        sourceIndex < yearGroup.sourceGroups.length;
        sourceIndex += 1
      ) ...[
        if (sourceIndex > 0)
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: _ExternalWorkRecordGroupCard(
            rows: [
              for (final package
                  in yearGroup.sourceGroups[sourceIndex].packages) ...[
                _ExternalWorkBatchRow(
                  package: package,
                  expanded: expandedAggregateKeys.contains(package.key),
                  onToggle: package.isAggregate
                      ? () => onToggleAggregate(package.key)
                      : null,
                  onTap: onTapRecord == null
                      ? null
                      : () => onTapRecord(package.representativeItem),
                ),
                if (expandedAggregateKeys.contains(package.key))
                  for (final row in package.childRows)
                    _ExternalWorkChildRow(
                      row: row,
                      onTap: onTapRecord == null
                          ? null
                          : () => onTapRecord(row.item),
                    ),
              ],
            ],
          ),
        ),
      ],
    ],
  ];
}

Set<String> timingExternalWorkAggregateKeys(
  List<TimingExternalWorkRecordItem> items,
) {
  return ExternalWorkRecordsViewModelBuilder.aggregateKeys(items);
}

int timingExternalWorkTopLevelCount(List<TimingExternalWorkRecordItem> items) {
  return ExternalWorkRecordsViewModelBuilder.topLevelCount(items);
}

class ExternalWorkRecordDetailContent extends StatelessWidget {
  const ExternalWorkRecordDetailContent({
    super.key,
    required this.item,
    this.packageItems,
    this.onLinkProject,
    this.onUnlinkProject,
  });

  final TimingExternalWorkRecordItem item;
  final List<TimingExternalWorkRecordItem>? packageItems;
  final VoidCallback? onLinkProject;
  final VoidCallback? onUnlinkProject;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final detailItems = packageItems ?? [item];
    final records = detailItems.map((item) => item.record);
    final linked = detailItems.any((item) => item.isLinked);
    final linkAction = linked ? onUnlinkProject : onLinkProject;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExternalWorkDetailCard(
            children: [
              const _ExternalWorkDetailRow(label: '来源', value: '从分享包导入'),
              _ExternalWorkDetailRow(label: '分享人', value: item.displayName),
              _ExternalWorkDetailRow(
                label: '地址',
                value: _detailSiteText(detailItems),
              ),
              _ExternalWorkDetailRow(
                label: '设备',
                value: _detailEquipmentText(record),
              ),
              _ExternalWorkDetailRow(
                label: '日期',
                value: FormatUtils.date(record.workDate),
              ),
              _ExternalWorkDetailRow(
                label: '工时 / 数量',
                value: _hoursText(record.hoursMilli),
              ),
              _ExternalWorkDetailRow(
                label: '单价',
                value: _sourceUnitPriceText(records),
              ),
              _ExternalWorkDetailRow(
                label: '金额',
                value: _moneyFen(record.amountFen),
              ),
              if (record.projectReceivedFen > 0)
                _ExternalWorkDetailRow(
                  label: '已收项目款',
                  value: _moneyFen(record.projectReceivedFen),
                ),
              _ExternalWorkDetailRow(
                label: '导入时间',
                value: _blankFallback(
                  item.batch?.importedAt ?? record.createdAt,
                ),
              ),
              _ExternalWorkDetailRow(label: '当前状态', value: _statusText(record)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '这条记录来自他人分享，当前不可编辑。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: TimingColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (linkAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: linkAction,
                child: Text(linked ? '解除关联' : '关联到本地项目'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const double _externalWorkGroupRadius = 8;
const double _externalWorkInnerDividerLeftInset =
    TimingTokens.recordRowPaddingLeft +
    TimingTokens.recordAvatarSize +
    TimingTokens.recordAvatarRightGap;
const Color _externalWorkAvatarColor = Color(0xFFE9F0EB);
const Color _externalWorkAvatarTextColor = Color(0xFF3F8059);

class _ExternalWorkRecordGroupCard extends StatelessWidget {
  const _ExternalWorkRecordGroupCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_externalWorkGroupRadius),
      child: ColoredBox(
        color: SheetColors.background,
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index += 1) ...[
              if (index > 0) const _ExternalWorkInnerDivider(),
              rows[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _ExternalWorkInnerDivider extends StatelessWidget {
  const _ExternalWorkInnerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: _externalWorkInnerDividerLeftInset),
      child: Divider(
        height: TimingTokens.recordDividerThickness,
        thickness: TimingTokens.recordDividerThickness,
        color: TimingColors.divider,
      ),
    );
  }
}

class _ExternalWorkYearHeader extends StatelessWidget {
  const _ExternalWorkYearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: TimingTokens.dateHeaderLeftInset),
      child: Text(
        '$year年',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: TimingTokens.dateHeaderFontSize,
          color: AppColors.textPrimary,
          height: TimingTokens.dateHeaderLineHeight,
        ),
      ),
    );
  }
}

class _ExternalWorkBatchRow extends StatelessWidget {
  const _ExternalWorkBatchRow({
    required this.package,
    required this.expanded,
    this.onTap,
    this.onToggle,
  });

  final ExternalWorkPackageVm package;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return _ExternalWorkRecordRowBase(
      title: package.title,
      subtitle: package.equipmentSummaryMain,
      subtitleEmphasisSuffix: package.equipmentSummarySuffix,
      subtitleSecondary: package.recordCountLabel,
      valueTop: package.dateText,
      valueBottom: package.hoursText,
      linked: package.hasLinkedRecord,
      onTap: onTap,
      onToggle: onToggle,
      expanded: expanded,
    );
  }
}

class _ExternalWorkChildRow extends StatelessWidget {
  const _ExternalWorkChildRow({required this.row, this.onTap});

  final ExternalWorkRecordRowVm row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ExternalWorkRecordRowBase(
      title: row.title,
      subtitle: row.subtitle,
      valueTop: row.dateText,
      valueBottom: row.hoursText,
      linked: row.isLinked,
      onTap: onTap,
      dense: true,
      hideAvatar: true,
    );
  }
}

class _ExternalWorkRecordRowBase extends StatelessWidget {
  const _ExternalWorkRecordRowBase({
    required this.title,
    required this.subtitle,
    required this.valueTop,
    required this.valueBottom,
    this.subtitleEmphasisSuffix,
    this.subtitleSecondary,
    this.onTap,
    this.linked = false,
    this.onToggle,
    this.expanded = false,
    this.dense = false,
    this.hideAvatar = false,
  });

  final String title;
  final String subtitle;
  final String valueTop;
  final String valueBottom;
  final String? subtitleEmphasisSuffix;
  final String? subtitleSecondary;
  final VoidCallback? onTap;
  final bool linked;
  final VoidCallback? onToggle;
  final bool expanded;
  final bool dense;
  final bool hideAvatar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordTitleFontSize,
      color: AppColors.textPrimary,
      height: TimingTokens.recordTitleLineHeight,
    );
    final subTitleStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordSubTitleFontSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1,
    );
    final subTitleSecondaryStyle = subTitleStyle?.copyWith(
      fontSize: TimingTokens.recordValueFontSize - 1,
      fontWeight: FontWeight.w400,
      height: 1,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordValueFontSize,
      color: AppColors.textPrimary,
      height: 1,
    );

    final subtitleWidget = onToggle == null
        ? _ExternalWorkSubtitleText(
            emphasis: subtitle,
            emphasisSuffix: subtitleEmphasisSuffix,
            secondary: subtitleSecondary,
            emphasisStyle: subTitleStyle,
            secondaryStyle: subTitleSecondaryStyle,
          )
        : _ExternalWorkToggleLabel(
            label: subtitle,
            labelSuffix: subtitleEmphasisSuffix,
            secondaryLabel: subtitleSecondary,
            expanded: expanded,
            style: subTitleStyle,
            secondaryStyle: subTitleSecondaryStyle,
            onTap: onToggle!,
          );

    return Material(
      color: SheetColors.background,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: dense
              ? TimingTokens.recordRowHeight - 4
              : TimingTokens.recordRowHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TimingTokens.recordRowPaddingLeft,
              0,
              TimingTokens.recordRowPaddingRight,
              0,
            ),
            child: Row(
              children: [
                if (hideAvatar)
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: const SizedBox(
                      width: TimingTokens.recordAvatarSize,
                      height: TimingTokens.recordAvatarSize,
                    ),
                  )
                else
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: _ExternalWorkAvatar(linked: linked),
                  ),
                const SizedBox(width: TimingTokens.recordAvatarRightGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      subtitleWidget,
                    ],
                  ),
                ),
                const SizedBox(width: TimingTokens.recordValueLeftGap),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (valueTop.isNotEmpty) ...[
                      Text(valueTop, style: valueStyle),
                      const SizedBox(height: TimingTokens.recordValueBottomGap),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(valueBottom, style: valueStyle)],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalWorkSubtitleText extends StatelessWidget {
  const _ExternalWorkSubtitleText({
    required this.emphasis,
    required this.emphasisStyle,
    required this.secondaryStyle,
    this.emphasisSuffix,
    this.secondary,
  });

  final String emphasis;
  final String? emphasisSuffix;
  final String? secondary;
  final TextStyle? emphasisStyle;
  final TextStyle? secondaryStyle;

  @override
  Widget build(BuildContext context) {
    final secondaryText = secondary;
    final suffixText = emphasisSuffix;
    if ((suffixText == null || suffixText.isEmpty) &&
        (secondaryText == null || secondaryText.isEmpty)) {
      return Text(
        emphasis,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: emphasisStyle,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(text: emphasis, style: emphasisStyle),
          if (suffixText != null && suffixText.isNotEmpty)
            TextSpan(text: suffixText, style: secondaryStyle),
          if (secondaryText != null && secondaryText.isNotEmpty)
            TextSpan(text: secondaryText, style: secondaryStyle),
        ],
      ),
    );
  }
}

class _ExternalWorkToggleLabel extends StatelessWidget {
  const _ExternalWorkToggleLabel({
    required this.label,
    required this.expanded,
    required this.style,
    required this.secondaryStyle,
    required this.onTap,
    this.labelSuffix,
    this.secondaryLabel,
  });

  final String label;
  final String? labelSuffix;
  final String? secondaryLabel;
  final bool expanded;
  final TextStyle? style;
  final TextStyle? secondaryStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _ExternalWorkSubtitleText(
                emphasis: label,
                emphasisSuffix: labelSuffix,
                secondary: secondaryLabel,
                emphasisStyle: style,
                secondaryStyle: secondaryStyle,
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalWorkAvatar extends StatelessWidget {
  const _ExternalWorkAvatar({required this.linked});

  final bool linked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TimingTokens.recordAvatarSize,
      height: TimingTokens.recordAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: TimingTokens.recordAvatarSize,
            height: TimingTokens.recordAvatarSize,
            decoration: const BoxDecoration(
              color: _externalWorkAvatarColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '协',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _externalWorkAvatarTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (linked)
            Positioned(
              right: -2,
              bottom: -2,
              child: LinkedExternalWorkBadge(
                key: const Key('external-work-avatar-link-badge'),
                borderColor: SheetColors.background,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExternalWorkDetailCard extends StatelessWidget {
  const _ExternalWorkDetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SheetColors.fieldBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(children: children),
      ),
    );
  }
}

class _ExternalWorkDetailRow extends StatelessWidget {
  const _ExternalWorkDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: TimingColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _detailSiteText(List<TimingExternalWorkRecordItem> items) {
  final sites = <String>[];
  for (final item in items) {
    final site = item.record.siteSnapshot.trim();
    if (site.isNotEmpty && !sites.contains(site)) sites.add(site);
  }
  return sites.isEmpty ? '-' : sites.join('、');
}

String _detailEquipmentText(ExternalWorkRecord record) {
  final parts = [
    record.equipmentBrand?.trim(),
    record.equipmentModel?.trim(),
    record.equipmentType?.trim(),
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  return parts.isEmpty ? '设备未填写' : parts.join(' / ');
}

String _hoursText(int hoursMilli) {
  return FormatUtils.hours(hoursMilli / 1000);
}

/// 计时页 "外协项目记录" 详情专用：展示**来源方**原始单价（不是接收方复核）。
///
/// 规则：
/// - 只汇总同一外协包内 hours 记录的明确 sourceUnitPriceFen。
/// - 多个明确单价按记录出现顺序去重，用 "、" 拼接。
/// - rent / 台班及 sourceUnitPriceFen 为 null 的记录不参与汇总。
/// - 没有任何明确来源单价时显示"未知"。
/// 0 是合法的"真实来源单价为 0"语义，仍按 ¥0 / h 显示。
///
/// 重要：这里**不要**回退到 `localUnitPriceFen`。
/// localUnitPriceFen 是接收方未来本地复核的外协应付/结算单价，账户页
/// 外协卡片才走 `localUnitPriceFen ?? sourceUnitPriceFen` 作为有效应付价；
/// 在计时页详情拉它会把"接收方复核值"伪装成"来源事实"，破坏审计语义。
String _sourceUnitPriceText(Iterable<ExternalWorkRecord> records) {
  final seen = <int>{};
  final values = <String>[];
  for (final record in records) {
    if (record.recordKind != ExternalWorkRecordKind.hours) continue;
    final price = record.sourceUnitPriceFen;
    if (price == null || !seen.add(price)) continue;
    values.add('${_moneyFen(price)} / h');
  }
  return values.isEmpty ? '未知' : values.join('、');
}

String _moneyFen(int fen) {
  return FormatUtils.money(fen / 100);
}

String _statusText(ExternalWorkRecord record) {
  if (record.status == ExternalWorkRecordStatus.active) {
    return record.linkedProjectId?.trim().isNotEmpty == true ? '已关联' : '待处理';
  }
  switch (record.status) {
    case ExternalWorkRecordStatus.active:
      return '待处理';
    case ExternalWorkRecordStatus.ignored:
      return '已忽略';
    case ExternalWorkRecordStatus.archived:
      return '已归档';
    case ExternalWorkRecordStatus.voided:
      return '已作废';
  }
}

String _blankFallback(String? text) {
  final value = text?.trim();
  return value == null || value.isEmpty ? '-' : value;
}
