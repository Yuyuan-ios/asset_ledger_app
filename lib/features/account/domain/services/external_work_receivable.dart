import '../../../../data/models/external_import_batch.dart';
import '../../../../data/models/external_work_record.dart';
import '../../../timing/state/timing_external_work_store.dart';

/// 单条外协记录的客户侧应收（分）。
///
/// 应收 = 我对项目方设置的客户侧应收单价 × 工时：
/// - hours 记录且 `customerUnitPriceFen` 已设：hours × customerUnitPriceFen。
/// - 未设客户单价（null）/ rent / 台班：回退到外协应付金额 `amountFen` 作占位
///   （未加价时应收暂等于应付、毛利为 0）。这不是把应付当“成本”，而是此包尚无
///   独立客户侧定价。
///
/// 边界：
/// - 切勿用 `sourceUnitPriceFen`：那是来源方（协作方）原始单价，属应付侧事实。
/// - 外协应付（externalPayableFen = amountFen）= 应付给协作方的款项，分享人侧
///   已定、不可改；客户单价只影响应收与毛利，绝不回写 amountFen。
int externalWorkRecordReceivableFen(ExternalWorkRecord record) {
  final customerPrice = record.customerUnitPriceFen;
  if (record.recordKind == ExternalWorkRecordKind.hours &&
      customerPrice != null) {
    return ExternalWorkRecord.calculateAmountFen(
      hoursMilli: record.hoursMilli,
      unitPriceFen: customerPrice,
    );
  }
  return record.amountFen;
}

ExternalWorkReceivableAmounts externalWorkRecordReceivableAmounts(
  ExternalWorkRecord record,
) {
  final customerReceivableFen = externalWorkRecordReceivableFen(record);
  final payableFen = record.amountFen;
  // projectReceivedFen 语义是“来源项目累计实收款”（来源方口径），不是“项目方
  // 已付给我的外协项目款”，故不计入我方已收（见模型字段注释 / gate #4）。
  const receivedFen = 0;
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

  /// 外协应付总额（应付给协作方的款项，分享人侧已定、不可改）。
  final int externalPayableFen;

  /// 我方已收的外协项目款。当前恒为 0：projectReceivedFen 是来源方累计实收
  /// 口径，不能当作项目方付给我（见 gate #4），故不计入已收。
  final int externalReceivedFen;

  /// 外协客户侧剩余应收，按总额截断到不小于 0。
  final int externalRemainingFen;

  /// 外协毛利（externalCustomerReceivableFen - externalPayableFen，应付=付给
  /// 协作方的款项），允许为负；未设客户单价时应收=应付故为 0，设了客户单价后
  /// 为真实毛利。
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
  // 外协已收恒为 0：projectReceivedFen 是来源方累计实收口径，非项目方付给我。
  const receivedFen = 0;
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
    final batchHours = batchItems.fold<double>(
      0,
      (sum, item) => sum + item.record.hoursMilli / 1000,
    );

    customerReceivableFen += batchCustomerReceivableFen;
    payableFen += batchPayableFen;

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
