import 'package:flutter/material.dart';

import '../../components/feedback/app_records_empty_hint.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/external_work_record.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

List<Widget> buildTimingExternalWorkRecordSlivers({
  required List<TimingExternalWorkRecordItem> items,
  ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
  VoidCallback? onImportShareFile,
}) {
  if (items.isEmpty) {
    return <Widget>[
      SliverToBoxAdapter(
        child: Column(
          children: [
            const AppRecentRecordsEmptyState(
              title: '暂无项目外协记录',
              subtitle: '从他人分享的 .jzt 文件导入后，会显示在这里',
            ),
            if (onImportShareFile != null) ...[
              const SizedBox(height: 12),
              _ImportShareFileButton(onPressed: onImportShareFile),
            ],
          ],
        ),
      ),
    ];
  }

  return <Widget>[
    if (onImportShareFile != null)
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.centerRight,
          child: _ImportShareFileButton(onPressed: onImportShareFile),
        ),
      ),
    SliverToBoxAdapter(
      child: _ExternalWorkRecordGroupCard(
        rows: [
          for (final item in items)
            _ExternalWorkRecordRow(
              item: item,
              onTap: onTapRecord == null ? null : () => onTapRecord(item),
            ),
        ],
      ),
    ),
  ];
}

class _ImportShareFileButton extends StatelessWidget {
  const _ImportShareFileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('timing-external-work-import-share-file'),
      onPressed: onPressed,
      icon: const Icon(Icons.file_download_outlined, size: 18),
      label: const Text('导入项目外协包'),
    );
  }
}

class ExternalWorkRecordDetailContent extends StatelessWidget {
  const ExternalWorkRecordDetailContent({
    super.key,
    required this.item,
    required this.onClose,
  });

  final TimingExternalWorkRecordItem item;
  final VoidCallback onClose;

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
              _ExternalWorkDetailRow(label: '分享包', value: item.displayName),
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
                value: _moneyFen(_preferredUnitPriceFen(record)),
              ),
              _ExternalWorkDetailRow(
                label: '金额',
                value: _moneyFen(record.amountFen),
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

class _ExternalWorkRecordRow extends StatelessWidget {
  const _ExternalWorkRecordRow({required this.item, this.onTap});

  final TimingExternalWorkRecordItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
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
                              _titleText(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          if (item.isLinked) ...[
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
                        _listEquipmentText(record),
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
                    Text(FormatUtils.date(record.workDate), style: valueStyle),
                    const SizedBox(height: TimingTokens.recordValueBottomGap),
                    Text(_hoursText(record.hoursMilli), style: valueStyle),
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
  final site = item.record.siteSnapshot.trim();
  if (site.isEmpty) return item.displayName;
  return '${item.displayName} · $site';
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

int _preferredUnitPriceFen(ExternalWorkRecord record) {
  return record.localUnitPriceFen > 0
      ? record.localUnitPriceFen
      : record.sourceUnitPriceFen;
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
