import '../../../../data/models/external_work_record.dart';

/// 单条外协记录的"外协设备应收"（分）：
/// - hours 记录且有源单价：hours × sourceUnitPriceFen；
/// - 其余（无明确单价 / rent / 台班）：默认 = 外协应付 amountFen（incomeFen）。
///
/// 绝不用 income / hours 反推单价；localUnitPriceFen 是接收方"外协应付/结算"
/// 单价，不是客户应收单价，故这里不参与设备应收计算。
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
