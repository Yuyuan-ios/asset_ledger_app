import 'package:asset_ledger/data/models/timing_calculation_history.dart';

import '../../../data/models/timing_record.dart';
import '../state/timing_store.dart';
import 'save_timing_record_with_impact_use_case.dart';

/// Thin façade for the timing editor save flow.
///
/// 阶段 C Step 1（C1）后语义：
/// - 唯一权威保存路径是 [SaveTimingRecordWithImpactUseCase]（阶段 B Step 3 引入
///   的事务化路径：保存计时 + 解除合并 + 撤销结清 同一事务）。
/// - 本类作为 feature 层的薄包装：调用事务化路径、拉取最新 store 数据、把
///   impact 信息归一化成 UI 友好的 [SaveTimingRecordResult]。
/// - 不再保留"store.save + retry merge dissolve"的遗留两步保存路径，也不再
///   有 pending retry / [PendingTimingMergeDissolve]。Provider 缺失现在直接
///   fail-fast，由 [context.read] 抛 `ProviderNotFoundException`。
class SaveTimingRecordUseCase {
  const SaveTimingRecordUseCase({
    required TimingStore timingStore,
    required SaveTimingRecordWithImpactUseCase withImpact,
  }) : _timingStore = timingStore,
       _withImpact = withImpact;

  final TimingStore _timingStore;
  final SaveTimingRecordWithImpactUseCase _withImpact;

  Future<SaveTimingRecordResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final impact = await _withImpact.execute(
      editing: editing,
      record: record,
      calculationHistories: calculationHistories,
    );
    // 事务提交后刷新内存 store，让 UI 看到最新落库列表 + 级联后的状态。
    await _timingStore.loadAll();
    return SaveTimingRecordResult(
      mergeDissolved: impact.mergeDissolved,
      impact: impact,
    );
  }
}

class SaveTimingRecordResult {
  const SaveTimingRecordResult({
    required this.mergeDissolved,
    required this.impact,
  });

  final bool mergeDissolved;

  /// 事务化路径返回的完整 impact 信息。C1 起永不为 null。
  final SaveTimingRecordWithImpactResult impact;
}
