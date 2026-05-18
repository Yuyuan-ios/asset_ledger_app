import 'package:flutter/material.dart';

// [新增] 引入语义化排版令牌；项目 lint(no_textstyle_in_migrated_modules)
// 禁止 timing/ 等已迁移模块直接调用 TextStyle 构造器。
import '../../../../core/foundation/typography.dart';
import '../../domain/entities/timing_entities.dart';

import '../model/staged_timing_calculation_history.dart';

const _historyCardBackground = Color(0xFF181818);
const _historyCardBorder = Color(0xFF2A2A2A);
const _historyTextPrimary = Color(0xFFF0F0F0);
const _historyTextSecondary = Color(0xFF9A9A9A);
const _historyEmptyText = Color(0xFF8E8E8E);
const _appliedBackground = Color(0xFF123D38);
const _appliedBorder = Color(0xFF1F8A7D);
const _appliedText = Color(0xFF7DE0D2);

class CalculationHistoryList extends StatelessWidget {
  const CalculationHistoryList({
    super.key,
    this.existingHistories = const [],
    this.stagedHistories = const [],
    this.latestAppliedHistory,
  });

  final List<TimingCalculationHistory> existingHistories;
  final List<StagedTimingCalculationHistory> stagedHistories;
  final StagedTimingCalculationHistory? latestAppliedHistory;

  @override
  Widget build(BuildContext context) {
    final items = _historyItems();
    if (items.isEmpty) {
      return Center(
        child: Text(
          '暂无计算记录',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: _historyEmptyText,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final history = items[index];
        return _HistoryTile(history: history);
      },
    );
  }

  List<_HistoryListItem> _historyItems() {
    final items = <_HistoryListItem>[
      for (final history in existingHistories)
        _HistoryListItem(
          createdAt: history.createdAt,
          expression: history.expression,
          result: history.result,
          ticketCount: history.ticketCount,
          isApplied: false,
        ),
      for (final history in stagedHistories)
        _HistoryListItem(
          createdAt: history.createdAt,
          expression: history.expression,
          result: history.result,
          ticketCount: history.ticketCount,
          isApplied: identical(history, latestAppliedHistory),
        ),
    ];

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

class _HistoryListItem {
  const _HistoryListItem({
    required this.createdAt,
    required this.expression,
    required this.result,
    required this.ticketCount,
    required this.isApplied,
  });

  final DateTime createdAt;
  final String expression;
  final double result;
  final int ticketCount;
  final bool isApplied;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.history});

  final _HistoryListItem history;

  @override
  Widget build(BuildContext context) {
    final expression = history.expression.split('+').join(' + ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _historyCardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _historyCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDate(history.createdAt)} | 票据 ${history.ticketCount} 张',
            style: AppTypography.caption(
              context,
              fontSize: 12,
              color: _historyTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              style: AppTypography.body(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _historyTextPrimary,
              ),
              children: [
                TextSpan(
                  text: '$expression = ${history.result.toStringAsFixed(1)} h',
                ),
                if (history.isApplied) ...[
                  const TextSpan(text: '  '),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _AppliedBadge(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _AppliedBadge extends StatelessWidget {
  const _AppliedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _appliedBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _appliedBorder),
      ),
      child: Text(
        '已填入工时',
        style: AppTypography.caption(
          context,
          fontSize: 12,
          color: _appliedText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
