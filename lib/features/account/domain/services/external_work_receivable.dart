import '../../../../data/models/external_import_batch.dart';
import '../../../../data/models/external_work_record.dart';
import '../../../timing/state/timing_external_work_store.dart';

/// 单条外协记录的客户侧应收（分）。
///
/// 重要：当前数据模型没有“我对项目方设置的客户侧单价”字段。三个金额字段都
/// 在成本侧——
/// - sourceUnitPriceFen 是来源方（外协朋友）原始成本单价（只读事实）；
/// - localUnitPriceFen 是接收方本地复核的外协应付/结算单价；
/// - amountFen 由应付单价算出，是外协应付成本总额。
/// 客户结算/项目收入单价不在记录上（见 ExternalWorkRecord 字段注释）。
///
/// 因此客户侧应收按“成本下限”入账：externalCustomerReceivable = amountFen，
/// 即“客户至少应付”的下限，不含我方加价（markup）。真正的 markup/利润需要
/// 后续为外协记录新增客户侧单价字段后才能表达。
///
/// 切勿用 sourceUnitPriceFen × hours 充当客户应收：那是成本单价，且当
/// localUnitPriceFen 缺省时恒等于 amountFen，会把成本伪装成收入、利润恒为 0。
int externalWorkRecordReceivableFen(ExternalWorkRecord record) {
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

  /// 外协应付成本总额。
  final int externalPayableFen;

  /// 我方已收的外协项目款。当前恒为 0：projectReceivedFen 是来源方累计实收
  /// 口径，不能当作项目方付给我（见 gate #4），故不计入已收。
  final int externalReceivedFen;

  /// 外协客户侧剩余应收，按总额截断到不小于 0。
  final int externalRemainingFen;

  /// 外协利润（externalCustomerReceivableFen - externalPayableFen），允许为
  /// 负数；当前成本下限口径下应收=应付，故恒为 0，待新增客户侧单价后才非零。
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
