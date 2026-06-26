import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_calculation_history.dart';
import '../../../data/models/timing_record.dart';

/// 阶段 B Step 3：保存计时记录的事务化入口。
///
/// 把 "保存计时记录 + 项目身份解析 + 受影响合并解除 + 必要时撤销结清"
/// 收口在同一个本地数据库事务内完成；不再依赖 UI pending retry 来兜底
/// 一致性。
abstract class SaveTimingRecordWithImpactUseCase {
  Future<SaveTimingRecordPreparation> prepareForSave({
    required TimingRecord? editing,
    required TimingRecord record,
  });

  Future<SaveTimingRecordWithImpactResult> executeWithExecutor(
    OperationDatabaseExecutor executor, {
    required TimingRecord? editing,
    required SaveTimingRecordPreparation preparation,
    List<TimingCalculationHistory> calculationHistories = const [],
  });

  Future<SaveTimingRecordWithImpactResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  });
}

class SaveTimingRecordPreparation {
  const SaveTimingRecordPreparation({
    required this.recordToSave,
    required this.devices,
    required this.rates,
    required this.timestampIso,
  });

  final TimingRecord recordToSave;
  final List<Device> devices;
  final List<ProjectDeviceRate> rates;
  final String timestampIso;
}

/// 编辑保存计时记录时，事务内重读 DB 的旧记录失败 / 更新影响行数异常时抛出。
///
/// 触发条件：
/// - 编辑模式下传入的 [TimingRecord] 缺少 id。
/// - DB 中 id 对应的旧记录已不存在（其它入口删除 / 恢复 / 并发改动）。
/// - `updateWithExecutor` 返回行数 != 1（0 行：行已不存在；>1 行：约束异常）。
///
/// UI 层应作友好提示（例如"这条计时记录已不存在，请刷新后再试"），
/// 而不是把它当成普通保存失败重试。
class TimingRecordSaveStaleException implements Exception {
  const TimingRecordSaveStaleException(this.message);
  final String message;

  @override
  String toString() => 'TimingRecordSaveStaleException: $message';
}

class TimingRecordLimitExceededException implements Exception {
  static const String code = 'timing_record_limit_exceeded';

  const TimingRecordLimitExceededException({
    required this.currentCount,
    this.limit = 30,
  });

  final int currentCount;
  final int limit;

  String get message => code;

  @override
  String toString() => 'TimingRecordLimitExceededException: $message';
}

/// 事务化保存计时记录的执行结果。
class SaveTimingRecordWithImpactResult {
  const SaveTimingRecordWithImpactResult({
    required this.savedRecord,
    required this.projectChanged,
    required this.mergeDissolved,
    required this.settlementRevoked,
    required this.affectedProjectIds,
    required this.revokedProjectIds,
    this.userMessage,
  });

  /// 事务提交后落库的真实记录（包含解析后的 [TimingRecord.projectId]、
  /// 新增时的 DB 自增 id 等）。
  final TimingRecord savedRecord;

  /// 保存前后是否发生了 project_id 变化。
  /// 新建记录场景视为 false。
  final bool projectChanged;

  /// 是否在事务内自动解除了受影响的合并组。
  /// projectChanged = false 时永远为 false。
  final bool mergeDissolved;

  /// 是否有任意一个受影响项目在事务内被撤销结清。
  final bool settlementRevoked;

  /// 本次保存受影响的项目 id 集合（已去重 / 去空）。
  /// 至少包含 oldProjectId 和 newProjectId（如果都存在）；
  /// 若解除合并组，组内其它仍激活成员也会被包含进来。
  final List<String> affectedProjectIds;

  /// 真正被撤销结清的项目 id 列表（settled → active）。
  /// 子集 ⊆ [affectedProjectIds]。
  final List<String> revokedProjectIds;

  /// 给 UI 直接渲染的简短提示文案；nullable 表示无影响。
  final String? userMessage;
}
