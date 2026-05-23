import 'package:flutter/material.dart';

import '../../components/feedback/app_records_empty_hint.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/external_work_record.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

List<Widget> buildTimingExternalWorkRecordSlivers({
  required List<TimingExternalWorkRecordItem> items,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
}) {
  if (items.isEmpty) {
    return const <Widget>[
      SliverToBoxAdapter(
        child: AppRecentRecordsEmptyState(
          title: '暂无项目外协记录',
          subtitle: '从他人分享的 .jzt 文件导入后，会显示在这里',
        ),
      ),
    ];
  }

  final displayRows = _buildExternalWorkDisplayRows(
    items: items,
    expandedAggregateKeys: expandedAggregateKeys,
    onToggleAggregate: onToggleAggregate,
    onTapRecord: onTapRecord,
  );

  return <Widget>[
    SliverToBoxAdapter(child: _ExternalWorkRecordGroupCard(rows: displayRows)),
  ];
}

Set<String> timingExternalWorkAggregateKeys(
  List<TimingExternalWorkRecordItem> items,
) {
  return _buildExternalWorkAggregateGroups(
    items,
  ).map((group) => group.key).toSet();
}

int timingExternalWorkTopLevelCount(List<TimingExternalWorkRecordItem> items) {
  final aggregateGroups = _buildExternalWorkAggregateGroups(items);
  final groupedItemKeys = <String>{
    for (final group in aggregateGroups)
      for (final item in group.items) _externalWorkItemKey(item),
  };

  return aggregateGroups.length +
      items
          .where(
            (item) => !groupedItemKeys.contains(_externalWorkItemKey(item)),
          )
          .length;
}

List<Widget> _buildExternalWorkDisplayRows({
  required List<TimingExternalWorkRecordItem> items,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  required ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
}) {
  final aggregateGroups = _buildExternalWorkAggregateGroups(items);
  final groupedItemKeys = <String>{
    for (final group in aggregateGroups)
      for (final item in group.items) _externalWorkItemKey(item),
  };

  final rows = <Widget>[];
  for (final group in aggregateGroups) {
    final expanded = expandedAggregateKeys.contains(group.key);
    rows.add(
      _ExternalWorkAggregateRow(
        group: group,
        expanded: expanded,
        onTap: () => onToggleAggregate(group.key),
      ),
    );
    if (expanded) {
      rows.addAll(
        group.items.map(
          (item) => _ExternalWorkRecordRow(
            item: item,
            hideAvatar: true,
            titleOverride: FormatUtils.date(item.record.workDate),
            valueDateOverride: '',
            onTap: onTapRecord == null ? null : () => onTapRecord(item),
          ),
        ),
      );
    }
  }

  rows.addAll(
    items
        .where((item) => !groupedItemKeys.contains(_externalWorkItemKey(item)))
        .map(
          (item) => _ExternalWorkRecordRow(
            item: item,
            onTap: onTapRecord == null ? null : () => onTapRecord(item),
          ),
        ),
  );
  return rows;
}

List<_ExternalWorkAggregateGroup> _buildExternalWorkAggregateGroups(
  List<TimingExternalWorkRecordItem> items,
) {
  final grouped = <String, List<TimingExternalWorkRecordItem>>{};
  for (final item in items) {
    grouped.putIfAbsent(_externalWorkAggregateKey(item), () => []).add(item);
  }

  final groups = <_ExternalWorkAggregateGroup>[];
  for (final entry in grouped.entries) {
    if (entry.value.length < 2) continue;
    groups.add(_ExternalWorkAggregateGroup.fromItems(entry.key, entry.value));
  }

  groups.sort((a, b) {
    final byDate = b.latestWorkDate.compareTo(a.latestWorkDate);
    if (byDate != 0) return byDate;
    return b.latestCreatedAt.compareTo(a.latestCreatedAt);
  });
  return groups;
}

String _externalWorkItemKey(TimingExternalWorkRecordItem item) {
  return 'external-${item.record.id}';
}

String _externalWorkAggregateKey(TimingExternalWorkRecordItem item) {
  final record = item.record;
  return [
    record.importBatchId,
    item.displayName,
    record.siteSnapshot,
    record.equipmentBrand ?? '',
    record.equipmentModel ?? '',
    record.equipmentType ?? '',
    record.linkedProjectId ?? '',
  ].map((part) => part.trim()).join('|');
}

class _ExternalWorkAggregateGroup {
  _ExternalWorkAggregateGroup._({
    required this.key,
    required this.items,
    required this.displayName,
    required this.site,
    required this.equipment,
    required this.earliestWorkDate,
    required this.latestWorkDate,
    required this.latestCreatedAt,
    required this.totalHoursMilli,
  });

  final String key;
  final List<TimingExternalWorkRecordItem> items;
  final String displayName;
  final String site;
  final String equipment;
  final int earliestWorkDate;
  final int latestWorkDate;
  final String latestCreatedAt;
  final int totalHoursMilli;

  factory _ExternalWorkAggregateGroup.fromItems(
    String key,
    List<TimingExternalWorkRecordItem> items,
  ) {
    final sortedItems = [...items]
      ..sort((a, b) {
        final byDate = a.record.workDate.compareTo(b.record.workDate);
        if (byDate != 0) return byDate;
        return a.record.createdAt.compareTo(b.record.createdAt);
      });
    final first = sortedItems.first;
    return _ExternalWorkAggregateGroup._(
      key: key,
      items: sortedItems,
      displayName: first.displayName,
      site: first.record.siteSnapshot.trim(),
      equipment: _listEquipmentText(first.record),
      earliestWorkDate: sortedItems.first.record.workDate,
      latestWorkDate: sortedItems.last.record.workDate,
      latestCreatedAt: sortedItems.last.record.createdAt,
      totalHoursMilli: sortedItems.fold<int>(
        0,
        (sum, item) => sum + item.record.hoursMilli,
      ),
    );
  }
}

class ExternalWorkRecordDetailContent extends StatelessWidget {
  const ExternalWorkRecordDetailContent({
    super.key,
    required this.item,
    required this.onClose,
    this.onDelete,
  });

  final TimingExternalWorkRecordItem item;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
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
                value: _blankFallback(record.siteSnapshot),
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
                value: _sourceUnitPriceText(record),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton(onPressed: onClose, child: const Text('知道了')),
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除记录'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                ),
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

class _ExternalWorkAggregateRow extends StatelessWidget {
  const _ExternalWorkAggregateRow({
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  final _ExternalWorkAggregateGroup group;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ExternalWorkRecordRowBase(
      title: _externalWorkTitle(group.displayName, group.site),
      subtitle: group.equipment,
      valueTop: _dateRangeText(group.earliestWorkDate, group.latestWorkDate),
      valueBottom:
          '${group.items.length}条 / ${_hoursText(group.totalHoursMilli)}',
      trailingIcon: Icon(
        expanded ? Icons.expand_less : Icons.expand_more,
        size: 18,
        color: TimingColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _ExternalWorkRecordRow extends StatelessWidget {
  const _ExternalWorkRecordRow({
    required this.item,
    this.onTap,
    this.hideAvatar = false,
    this.titleOverride,
    this.valueDateOverride,
  });

  final TimingExternalWorkRecordItem item;
  final VoidCallback? onTap;
  final bool hideAvatar;
  final String? titleOverride;
  final String? valueDateOverride;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    return _ExternalWorkRecordRowBase(
      title: titleOverride ?? _titleText(item),
      subtitle: _listEquipmentText(record),
      valueTop: valueDateOverride ?? FormatUtils.date(record.workDate),
      valueBottom: _hoursText(record.hoursMilli),
      hideAvatar: hideAvatar,
      linked: !hideAvatar && item.isLinked,
      onTap: onTap,
    );
  }
}

class _ExternalWorkRecordRowBase extends StatelessWidget {
  const _ExternalWorkRecordRowBase({
    required this.title,
    required this.subtitle,
    required this.valueTop,
    required this.valueBottom,
    this.onTap,
    this.hideAvatar = false,
    this.linked = false,
    this.trailingIcon,
  });

  final String title;
  final String subtitle;
  final String valueTop;
  final String valueBottom;
  final VoidCallback? onTap;
  final bool hideAvatar;
  final bool linked;
  final Widget? trailingIcon;

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
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordValueFontSize,
      color: AppColors.textPrimary,
      height: 1,
    );

    return Material(
      color: SheetColors.background,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: TimingTokens.recordRowHeight,
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
                  const SizedBox(width: TimingTokens.recordAvatarSize)
                else
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: const _ExternalWorkAvatar(),
                  ),
                const SizedBox(width: TimingTokens.recordAvatarRightGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          if (linked) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: '已关联本地项目',
                              child: Icon(
                                Icons.link,
                                size: 15,
                                color: TimingColors.chartIncome,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subTitleStyle,
                      ),
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
                      children: [
                        Text(valueBottom, style: valueStyle),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 2),
                          trailingIcon!,
                        ],
                      ],
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

class _ExternalWorkAvatar extends StatelessWidget {
  const _ExternalWorkAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
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

String _titleText(TimingExternalWorkRecordItem item) {
  return _externalWorkTitle(item.displayName, item.record.siteSnapshot);
}

String _externalWorkTitle(String displayName, String site) {
  final normalizedSite = site.trim();
  if (normalizedSite.isEmpty) return displayName;
  return '$displayName · $normalizedSite';
}

String _dateRangeText(int earliestYmd, int latestYmd) {
  if (earliestYmd == latestYmd) return FormatUtils.date(earliestYmd);
  return '${FormatUtils.date(earliestYmd)}-${FormatUtils.date(latestYmd)}';
}

String _listEquipmentText(ExternalWorkRecord record) {
  final brand = record.equipmentBrand?.trim() ?? '';
  final model = record.equipmentModel?.trim() ?? '';
  if (brand.isEmpty && model.isEmpty) return '设备未填写';
  if (model.isEmpty) return brand;
  if (brand.isEmpty) return model;
  return '$brand $model';
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

/// 计时页 "项目外协记录" 详情专用：展示**来源方**原始单价（不是接收方复核）。
///
/// 规则：
/// - rent / 台班：永远显示"不适用"（来源无单价语义）。
/// - hours + sourceUnitPriceFen 有值：显示 ¥xxx / h。
/// - hours + sourceUnitPriceFen 为 null：显示"未知"。
/// 0 是合法的"真实来源单价为 0"语义，仍按 ¥0 / h 显示。
///
/// 重要：这里**不要**回退到 `localUnitPriceFen`。
/// localUnitPriceFen 是接收方未来本地复核的外协应付/结算单价，账户页
/// 外协卡片才走 `localUnitPriceFen ?? sourceUnitPriceFen` 作为有效应付价；
/// 在计时页详情拉它会把"接收方复核值"伪装成"来源事实"，破坏审计语义。
String _sourceUnitPriceText(ExternalWorkRecord record) {
  if (record.recordKind == ExternalWorkRecordKind.rent) {
    return '不适用';
  }
  final price = record.sourceUnitPriceFen;
  if (price == null) return '未知';
  return '${_moneyFen(price)} / h';
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
