import 'base_store.dart';
import '../errors/store_failure.dart';

/// 用户操作类型。core 只产出 code，由 UI 层
/// （`components/feedback/store_action_feedback_l10n.dart`）映射为本地化文案，
/// core/utils 不持有 AppLocalizations、不含展示用中文。
enum StoreActionKind { save, delete, update, create, deactivate }

/// 结构化操作反馈：成功/失败 + 操作 code + 失败原因 code/detail。
/// 可选 [successOverrideText] 给调用方传入已本地化的自定义成功文案（如 device
/// 的「已新增 / 已更新」按场景区分）；为 null 时由 UI mapper 取该 action 的默认成功文案。
class StoreActionFeedback {
  final bool isSuccess;
  final StoreActionKind action;
  final StoreFailureType? failureType;
  final String? failureDetail;
  final String? successOverrideText;

  const StoreActionFeedback({
    required this.isSuccess,
    required this.action,
    this.failureType,
    this.failureDetail,
    this.successOverrideText,
  });
}

/// 读取 [store] 当前失败态，产出结构化反馈（不含本地化文案）。
StoreActionFeedback storeActionFeedback(
  BaseStore store, {
  required StoreActionKind action,
  String? successOverrideText,
}) {
  final failure = store.failure;
  if (failure == null) {
    return StoreActionFeedback(
      isSuccess: true,
      action: action,
      successOverrideText: successOverrideText,
    );
  }
  return StoreActionFeedback(
    isSuccess: false,
    action: action,
    failureType: failure.type,
    failureDetail: failure.message,
  );
}

// ---------------------------------------------------------------------------
// 以下 String 版仍服务 view_data 的「读取」错误路径与 device_page 直读，
// 尚含硬编码中文模板；S4b 后续片再迁（见 docs/operations/tech-debt.md）。
// ---------------------------------------------------------------------------

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
