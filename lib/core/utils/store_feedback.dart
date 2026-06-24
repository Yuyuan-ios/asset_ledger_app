import 'base_store.dart';
import '../errors/store_failure.dart';

/// 用户操作类型。core 只产出 code，由 UI 层
/// （`components/feedback/store_action_feedback_l10n.dart`）映射为本地化文案，
/// core/utils 不持有 AppLocalizations、不含展示用中文。
enum StoreActionKind { save, delete, update, create, deactivate, read }

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

/// 返回 [stores] 中第一个处于失败态的结构化反馈（不含本地化文案），全部成功则 null。
/// 供「读取/加载」错误路径用：调用方（含无 l10n 的 view_data builder）拿到 code，
/// 由 UI 层 mapper 本地化。
StoreActionFeedback? firstStoreActionFailure(
  Iterable<BaseStore> stores, {
  required StoreActionKind action,
}) {
  for (final store in stores) {
    final feedback = storeActionFeedback(store, action: action);
    if (!feedback.isSuccess) return feedback;
  }
  return null;
}
