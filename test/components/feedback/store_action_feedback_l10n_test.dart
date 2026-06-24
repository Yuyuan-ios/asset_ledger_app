import 'package:asset_ledger/components/feedback/store_action_feedback_l10n.dart';
import 'package:asset_ledger/core/errors/store_failure.dart';
import 'package:asset_ledger/core/utils/store_feedback.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsZh();

  group('localizeStoreActionFeedback (zh) — equivalent to legacy copy', () {
    test('success codes map to centralized success copy', () {
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: true,
            action: StoreActionKind.save,
          ),
        ),
        '已保存',
      );
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: true,
            action: StoreActionKind.delete,
          ),
        ),
        '已删除',
      );
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: true,
            action: StoreActionKind.deactivate,
          ),
        ),
        '已停用',
      );
    });

    test('success override wins over default copy', () {
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: true,
            action: StoreActionKind.create,
            successOverrideText: '已新增设备',
          ),
        ),
        '已新增设备',
      );
    });

    test('failure codes map to the same "X失败：…" copy as before', () {
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: false,
            action: StoreActionKind.save,
            failureType: StoreFailureType.database,
          ),
        ),
        '保存失败：数据未保存，请稍后重试',
      );
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: false,
            action: StoreActionKind.delete,
            failureType: StoreFailureType.validation,
            failureDetail: 'brand 不能为空',
          ),
        ),
        '删除失败：brand 不能为空',
      );
      expect(
        localizeStoreActionFeedback(
          l10n,
          const StoreActionFeedback(
            isSuccess: false,
            action: StoreActionKind.update,
            failureType: StoreFailureType.fileSystem,
          ),
        ),
        '更新失败：请检查文件状态和访问权限',
      );
    });
  });
}
