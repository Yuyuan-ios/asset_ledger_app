import 'base_store.dart';
import '../errors/store_failure.dart';

class StoreActionFeedback {
  final bool isSuccess;
  final String message;

  const StoreActionFeedback({
    required this.isSuccess,
    required this.message,
  });
}

String? storeErrorMessage(BaseStore store, {required String action}) {
  final failure = store.failure;
  if (failure == null) return null;

  switch (failure.type) {
    case StoreFailureType.validation:
      return '$action失败：${failure.message}';
    case StoreFailureType.database:
      return '$action失败：数据未保存，请稍后重试';
    case StoreFailureType.fileSystem:
      return '$action失败：请检查文件状态和访问权限';
    case StoreFailureType.unknown:
      return '$action失败：${failure.message}';
  }
}

StoreActionFeedback storeActionFeedback(
  BaseStore store, {
  required String action,
  String? successMessage,
}) {
  final error = storeErrorMessage(store, action: action);
  if (error != null) {
    return StoreActionFeedback(isSuccess: false, message: error);
  }
  return StoreActionFeedback(
    isSuccess: true,
    message: successMessage ?? _defaultSuccessMessage(action),
  );
}

String? firstStoreErrorMessage(
  Iterable<BaseStore> stores, {
  required String action,
}) {
  for (final store in stores) {
    final message = storeErrorMessage(store, action: action);
    if (message != null) return message;
  }
  return null;
}

String _defaultSuccessMessage(String action) {
  switch (action) {
    case '保存':
      return '已保存';
    case '删除':
      return '已删除';
    case '更新':
      return '已更新';
    case '新增':
      return '已新增';
    case '停用':
      return '已停用';
    default:
      return '操作已完成';
  }
}
