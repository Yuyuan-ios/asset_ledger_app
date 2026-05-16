import 'package:flutter/material.dart';

// [新增] 引入语义化排版令牌；项目 lint(no_textstyle_in_migrated_modules)
// 禁止 timing/ 等已迁移模块直接调用 TextStyle 构造器。
import '../../../../core/foundation/typography.dart';
import '../model/staged_timing_calculation_history.dart';
import '../model/timing_calculation_history.dart';

class CalculationHistoryList extends StatelessWidget {
  const CalculationHistoryList({
    super.key,
    this.existingHistories = const [],
    this.stagedHistories = const [],
  });

  final List<TimingCalculationHistory> existingHistories;
  final List<StagedTimingCalculationHistory> stagedHistories;

  @override
  Widget build(BuildContext context) {
    final items = _historyItems();
    if (items.isEmpty) {
      // [修改] TextStyle → AppTypography.body：满足 no_textstyle_in_migrated_modules
      return Center(
        child: Text(
          '暂无计算记录',
          style: AppTypography.body(context, color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
          sourceLabel: '已保存',
          createdAt: history.createdAt,
          expression: history.expression,
          result: history.result,
          ticketCount: history.ticketCount,
        ),
      for (final history in stagedHistories)
        _HistoryListItem(
          sourceLabel: '本次',
          createdAt: history.createdAt,
          expression: history.expression,
          result: history.result,
          ticketCount: history.ticketCount,
        ),
    ];

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

class _HistoryListItem {
  const _HistoryListItem({
    required this.sourceLabel,
    required this.createdAt,
    required this.expression,
    required this.result,
    required this.ticketCount,
  });

  final String sourceLabel;
  final DateTime createdAt;
  final String expression;
  final double result;
  final int ticketCount;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.history});

  final _HistoryListItem history;

  @override
  Widget build(BuildContext context) {
    final expression = history.expression.split('+').join(' + ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [修改] 头部 12px/w600 灰色提示 → AppTypography.caption
          Text(
            '[${history.sourceLabel}] ${_formatDate(history.createdAt)} ｜ '
            '票据 ${history.ticketCount} 张',
            style: AppTypography.caption(
              context,
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // [修改] 结果 14px/w700 → AppTypography.body
          Text(
            '$expression = ${history.result.toStringAsFixed(1)} h',
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
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
