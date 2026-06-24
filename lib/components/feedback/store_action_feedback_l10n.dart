import '../../core/errors/store_failure.dart';
import '../../core/utils/store_feedback.dart';
import '../../l10n/gen/app_localizations.dart';

/// 把 [StoreActionFeedback]（core 产出的 code）映射为本地化展示文案。
/// 保持 core/utils 不依赖 AppLocalizations：本地化只发生在 UI 层。
String localizeStoreActionFeedback(
  AppLocalizations l10n,
  StoreActionFeedback feedback,
) {
  if (feedback.isSuccess) {
    return feedback.successOverrideText ??
        _successText(l10n, feedback.action);
  }
  final actionLabel = _actionLabel(l10n, feedback.action);
  switch (feedback.failureType!) {
    case StoreFailureType.validation:
    case StoreFailureType.unknown:
      return l10n.storeActionFailureWithDetail(
        actionLabel,
        feedback.failureDetail ?? '',
      );
    case StoreFailureType.database:
      return l10n.storeActionFailureDatabase(actionLabel);
    case StoreFailureType.fileSystem:
      return l10n.storeActionFailureFileSystem(actionLabel);
  }
}

String _successText(AppLocalizations l10n, StoreActionKind action) {
  switch (action) {
    case StoreActionKind.save:
      return l10n.storeActionSaveSuccess;
    case StoreActionKind.delete:
      return l10n.storeActionDeleteSuccess;
    case StoreActionKind.update:
      return l10n.storeActionUpdateSuccess;
    case StoreActionKind.create:
      return l10n.storeActionCreateSuccess;
    case StoreActionKind.deactivate:
      return l10n.storeActionDeactivateSuccess;
  }
}

String _actionLabel(AppLocalizations l10n, StoreActionKind action) {
  switch (action) {
    case StoreActionKind.save:
      return l10n.storeActionSaveLabel;
    case StoreActionKind.delete:
      return l10n.storeActionDeleteLabel;
    case StoreActionKind.update:
      return l10n.storeActionUpdateLabel;
    case StoreActionKind.create:
      return l10n.storeActionCreateLabel;
    case StoreActionKind.deactivate:
      return l10n.storeActionDeactivateLabel;
  }
}
