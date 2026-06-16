import '../../../../data/models/external_import_batch.dart';
import '../../../../data/models/external_work_record.dart';
import '../../../timing/state/timing_external_work_store.dart';

/// 单条外协记录的客户侧应收（分）。
///
/// - hours 记录且有来源项目有效单价：hours × sourceUnitPriceFen。
/// - 其余（无明确单价 / rent / 台班）：回退到 amountFen。该回退仅适用于
///   rich/legacy 导入事实中保留下来的来源金额；不得用 localUnitPriceFen 伪造。
///
/// localUnitPriceFen 是接收方本地复核的外协应付/结算单价，不是客户侧应收
/// 单价，故不参与客户侧应收计算。
int externalWorkRecordReceivableFen(ExternalWorkRecord record) {
  final sourcePrice = record.sourceUnitPriceFen;
  if (record.recordKind == ExternalWorkRecordKind.hours &&
      sourcePrice != null) {
    return ExternalWorkRecord.calculateAmountFen(
      hoursMilli: record.hoursMilli,
      unitPriceFen: sourcePrice,
    );
  }
  return record.amountFen;
}

ExternalWorkReceivableAmounts externalWorkRecordReceivableAmounts(
  ExternalWorkRecord record,
) {
  final customerReceivableFen = externalWorkRecordReceivableFen(record);
  final payableFen = record.amountFen;
  final receivedFen = record.projectReceivedFen;
  return ExternalWorkReceivableAmounts(
    externalCustomerReceivableFen: customerReceivableFen,
    externalPayableFen: payableFen,
    externalReceivedFen: receivedFen,
    externalRemainingFen: _remainingFen(customerReceivableFen, receivedFen),
    externalProfitFen: customerReceivableFen - payableFen,
  );
}

class ExternalWorkReceivableAmounts {
  const ExternalWorkReceivableAmounts({
    required this.externalCustomerReceivableFen,
    required this.externalPayableFen,
    required this.externalReceivedFen,
    required this.externalRemainingFen,
    required this.externalProfitFen,
  });

  final int externalCustomerReceivableFen;
  final int externalPayableFen;
  final int externalReceivedFen;
  final int externalRemainingFen;
  final int externalProfitFen;
}

/// 外协客户侧应收汇总（账户页联动用）。
class ExternalWorkReceivableRollup {
  const ExternalWorkReceivableRollup({
    required this.externalCustomerReceivableFen,
    required this.externalPayableFen,
    required this.externalReceivedFen,
    required this.externalRemainingFen,
    required this.externalProfitFen,
    required this.totalPaidExternalWorkFen,
    required this.receivableFenByProjectId,
    required this.hoursByProjectId,
  });

  const ExternalWorkReceivableRollup.empty()
    : externalCustomerReceivableFen = 0,
      externalPayableFen = 0,
      externalReceivedFen = 0,
      externalRemainingFen = 0,
      externalProfitFen = 0,
      totalPaidExternalWorkFen = 0,
      receivableFenByProjectId = const {},
      hoursByProjectId = const {};

  /// 外协客户侧应收之和（每个 importBatch 只计一次）。
  final int externalCustomerReceivableFen;

  /// 外协应付成本总额。
  final int externalPayableFen;

  /// 项目方/客户方已付给我的外协项目款（每个 importBatch 只计一次）。
  final int externalReceivedFen;

  /// 外协客户侧剩余应收，按总额截断到不小于 0。
  final int externalRemainingFen;

  /// 外协利润，允许为负数。
  final int externalProfitFen;

  /// 已支付外协项目款。当前没有持久化数据源，保持 0，不能用应付金额冒充。
  final int totalPaidExternalWorkFen;

  /// 已关联外协包按 linkedProjectId 汇总的客户侧应收（分），用于项目展示信息。
  final Map<String, int> receivableFenByProjectId;

  /// 已关联外协包按 linkedProjectId 汇总的工时，用于项目卡片"总共"展示。
  final Map<String, double> hoursByProjectId;

  int get totalReceivableFen => externalCustomerReceivableFen;
  int get totalReceivedFen => externalReceivedFen;
}

/// 按 importBatch 汇总外协客户侧应收：总额（每包一次）+ 已关联项目维度分摊。
ExternalWorkReceivableRollup rollupExternalWorkReceivable(
  List<TimingExternalWorkRecordItem> items, {
  int? summaryYear,
}) {
  final byBatch = <String, List<TimingExternalWorkRecordItem>>{};
  for (final item in items) {
    if (item.record.status != ExternalWorkRecordStatus.active) continue;
    if (item.batch?.status != ExternalImportBatchStatus.active) continue;
    if (summaryYear != null && item.record.workDate ~/ 10000 != summaryYear) {
      continue;
    }
    final batchId = item.record.importBatchId.trim();
    if (batchId.isEmpty) continue;
    byBatch.putIfAbsent(batchId, () => []).add(item);
  }

  var customerReceivableFen = 0;
  var payableFen = 0;
  var receivedFen = 0;
  final byProject = <String, int>{};
  final byHoursProject = <String, double>{};

  for (final batchItems in byBatch.values) {
    final batchCustomerReceivableFen = batchItems.fold<int>(
      0,
      (sum, item) => sum + externalWorkRecordReceivableFen(item.record),
    );
    final batchPayableFen = batchItems.fold<int>(
      0,
      (sum, item) => sum + item.record.amountFen,
    );
    final batchReceivedFen = batchItems.fold<int>(0, (max, item) {
      final recordReceivedFen = item.record.projectReceivedFen;
      return recordReceivedFen > max ? recordReceivedFen : max;
    });
    final batchHours = batchItems.fold<double>(
      0,
      (sum, item) => sum + item.record.hoursMilli / 1000,
    );

    customerReceivableFen += batchCustomerReceivableFen;
    payableFen += batchPayableFen;
    receivedFen += batchReceivedFen;

    final linkedProjectId = batchItems
        .map((item) => item.record.linkedProjectId?.trim() ?? '')
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (linkedProjectId.isEmpty) continue;
    byProject[linkedProjectId] =
        (byProject[linkedProjectId] ?? 0) + batchCustomerReceivableFen;
    byHoursProject[linkedProjectId] =
        (byHoursProject[linkedProjectId] ?? 0) + batchHours;
  }

  return ExternalWorkReceivableRollup(
    externalCustomerReceivableFen: customerReceivableFen,
    externalPayableFen: payableFen,
    externalReceivedFen: receivedFen,
    externalRemainingFen: _remainingFen(customerReceivableFen, receivedFen),
    externalProfitFen: customerReceivableFen - payableFen,
    totalPaidExternalWorkFen: 0,
    receivableFenByProjectId: Map.unmodifiable(byProject),
    hoursByProjectId: Map.unmodifiable(byHoursProject),
  );
}

int _remainingFen(int receivableFen, int receivedFen) {
  final remainingFen = receivableFen - receivedFen;
  return remainingFen > 0 ? remainingFen : 0;
}
