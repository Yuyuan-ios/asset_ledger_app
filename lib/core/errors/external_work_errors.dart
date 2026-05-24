/// 关联 / 解除关联外协包时，目标 importBatch 已无可更新记录
/// （例如已被删除、stale state 或并发删除）。
///
/// 放在 core/errors 以便数据层抛出、表现层捕获并给出明确提示，
/// 同时避免表现层直接 import lib/data。
class ExternalWorkBatchUnavailableException implements Exception {
  const ExternalWorkBatchUnavailableException([
    this.message = '该外协包已不存在，请刷新后重试',
  ]);

  final String message;

  @override
  String toString() => 'ExternalWorkBatchUnavailableException: $message';
}
