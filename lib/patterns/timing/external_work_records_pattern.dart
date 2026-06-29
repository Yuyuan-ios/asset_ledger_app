import 'package:flutter/material.dart';

import '../../components/avatars/linked_external_work_badge.dart';
import '../../components/buttons/app_brand_outline_action_button.dart';
import '../../components/feedback/app_records_empty_hint.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../features/timing/view_models/external_work_records_view_model.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../layout/record_card_surface.dart';

const double _externalWorkEmptyTitleFontSize = 16;
const double _externalWorkEmptySubtitleFontSize = 15;

List<Widget> buildTimingExternalWorkRecordSlivers({
  required AppLocalizations l10n,
  required List<TimingExternalWorkRecordItem> items,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
}) {
  final text = ExternalWorkRecordsText(l10n: l10n);
  // 分组 / 标题 fallback / 状态 / 摘要等展示判断由 feature 层 builder 计算（C7）。
  // pattern 只负责渲染 VM 与回调点击事件。
  final vm = ExternalWorkRecordsViewModelBuilder.build(items, text);
  if (vm.isEmpty) {
    return <Widget>[
      SliverToBoxAdapter(
        child: AppRecentRecordsEmptyState(
          title: l10n.externalWorkRecordsEmptyTitle,
          subtitle: l10n.externalWorkRecordsEmptySubtitle,
          titleFontSize: _externalWorkEmptyTitleFontSize,
          subtitleFontSize: _externalWorkEmptySubtitleFontSize,
        ),
      ),
    ];
  }

  return <Widget>[
    for (final yearGroup in vm.yearGroups) ...[
      for (
        var sourceIndex = 0;
        sourceIndex < yearGroup.sourceGroups.length;
        sourceIndex += 1
      ) ...[
        if (sourceIndex > 0)
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _ExternalWorkYearHeaderDelegate(
            yearLabel: text.yearLabel(yearGroup.year),
            sourceName: yearGroup.sourceGroups[sourceIndex].sourceName,
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    final text = ExternalWorkRecordsText(l10n: l10n);
    // 详情展示字段（site / equipment / 单价 / 金额 / 工时 / 状态 / 导入时间 /
    // linked）由 feature 层 builder 计算（C8）。pattern 只渲染 VM + 回调。
    final vm = ExternalWorkRecordsViewModelBuilder.buildDetail(
      item: item,
      text: text,
      packageItems: packageItems,
    );
    final linkAction = vm.isLinked ? onUnlinkProject : onLinkProject;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExternalWorkDetailCard(
            children: [
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsSourceLabel,
                value: vm.sourceText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsSourceNameLabel,
                value: vm.sourceNameText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsSiteLabel,
                value: vm.siteText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsDeviceLabel,
                value: vm.equipmentText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsDateLabel,
                value: vm.workDateText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsHoursQuantityLabel,
                value: vm.hoursText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsUnitPriceLabel,
                value: vm.sourceUnitPriceText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsAmountLabel,
                value: vm.amountText,
              ),
              if (vm.showProjectReceived)
                _ExternalWorkDetailRow(
                  label: l10n.externalWorkRecordsProjectReceivedLabel,
                  value: vm.projectReceivedText,
                ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsImportedAtLabel,
                value: vm.importedAtText,
              ),
              _ExternalWorkDetailRow(
                label: l10n.externalWorkRecordsCurrentStatusLabel,
                value: vm.statusText,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.externalWorkRecordsReadOnlyNotice,
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
                style: appBrandOutlineActionButtonStyle(),
                child: Text(
                  vm.isLinked
                      ? l10n.timingExternalWorkUnlinkAction
                      : l10n.externalWorkRecordsLinkAction,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const double _externalWorkInnerDividerLeftInset =
    TimingTokens.recordRowPaddingLeft +
    TimingTokens.recordAvatarSize +
    TimingTokens.recordAvatarRightGap;
const double _externalWorkYearHeaderExtent =
    (TimingTokens.dateHeaderFontSize * TimingTokens.dateHeaderLineHeight) +
    TimingTokens.recordDividerThickness +
    TimingTokens.recordDividerThickness;
const double _externalWorkYearHeaderPinnedProbeExtent = 0.01;
const double _externalWorkYearHeaderDividerHorizontalInset = 12;
const Color _externalWorkYearHeaderDividerColor = Color(0x66D9D9D9);
const Color _externalWorkAvatarColor = Color(0xFFE9F0EB);
const Color _externalWorkAvatarTextColor = Color(0xFF3F8059);

class _ExternalWorkRecordGroupCard extends StatelessWidget {
  const _ExternalWorkRecordGroupCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return RecordCardSurface(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index += 1) ...[
            if (index > 0) const _ExternalWorkInnerDivider(),
            rows[index],
          ],
        ],
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
  const _ExternalWorkYearHeader({
    required this.yearLabel,
    required this.sourceName,
    required this.showSourceName,
  });

  final String yearLabel;
  final String sourceName;
  final bool showSourceName;

  @override
  Widget build(BuildContext context) {
    final normalizedSourceName = sourceName.trim();
    final label = showSourceName && normalizedSourceName.isNotEmpty
        ? '$yearLabel · $normalizedSourceName'
        : yearLabel;
    return ColoredBox(
      color: AppColors.scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: TimingTokens.dateHeaderLeftInset,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: TimingTokens.dateHeaderFontSize,
                color: AppColors.textPrimary,
                height: TimingTokens.dateHeaderLineHeight,
              ),
            ),
          ),
          const _ExternalWorkYearHeaderDivider(),
        ],
      ),
    );
  }
}

class _ExternalWorkYearHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ExternalWorkYearHeaderDelegate({
    required this.yearLabel,
    required this.sourceName,
  });

  final String yearLabel;
  final String sourceName;

  @override
  double get minExtent => _externalWorkYearHeaderExtent;

  @override
  double get maxExtent =>
      _externalWorkYearHeaderExtent + _externalWorkYearHeaderPinnedProbeExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _ExternalWorkYearHeader(
      yearLabel: yearLabel,
      sourceName: sourceName,
      showSourceName: shrinkOffset > 0 || overlapsContent,
    );
  }

  @override
  bool shouldRebuild(covariant _ExternalWorkYearHeaderDelegate oldDelegate) {
    return yearLabel != oldDelegate.yearLabel ||
        sourceName != oldDelegate.sourceName;
  }
}

class _ExternalWorkYearHeaderDivider extends StatelessWidget {
  const _ExternalWorkYearHeaderDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      indent: _externalWorkYearHeaderDividerHorizontalInset,
      endIndent: _externalWorkYearHeaderDividerHorizontalInset,
      height: TimingTokens.recordDividerThickness,
      thickness: TimingTokens.recordDividerThickness,
      color: _externalWorkYearHeaderDividerColor,
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
    final l10n = AppLocalizations.of(context);
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
                    child: _ExternalWorkAvatar(
                      linked: linked,
                      avatarLabel: l10n.externalWorkRecordsAvatarLabel,
                    ),
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
  const _ExternalWorkAvatar({required this.linked, required this.avatarLabel});

  final bool linked;
  final String avatarLabel;

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
              avatarLabel,
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
