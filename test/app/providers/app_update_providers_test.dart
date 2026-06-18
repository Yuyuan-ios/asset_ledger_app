import 'package:asset_ledger/app/providers/app_update_providers.dart';
import 'package:asset_ledger/app/version_policy_config.dart';
import 'package:asset_ledger/features/app_update/application/update_prompt_coordinator.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'unavailable config provides no-op coordinator without creating source',
    (WidgetTester tester) async {
      var sourceFactoryCalls = 0;
      var showCalls = 0;
      final appUpdate = AppUpdateProviders.build(
        endpointConfig: const VersionPolicyEndpointConfig.unavailable(
          '版本策略暂未配置',
        ),
        sourceFactory: ({required Uri uri}) {
          sourceFactoryCalls++;
          return _ThrowingVersionPolicySource();
        },
        showPrompt: (context, decision) async {
          showCalls++;
        },
      );

      late UpdatePromptCoordinator coordinator;
      late BuildContext context;
      await tester.pumpWidget(
        MultiProvider(
          providers: appUpdate.providers,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (builderContext) {
                context = builderContext;
                coordinator = builderContext.read<UpdatePromptCoordinator>();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await coordinator.onTimingPageEntered(context);

      expect(sourceFactoryCalls, 0);
      expect(showCalls, 0);
    },
  );
}

class _ThrowingVersionPolicySource implements VersionPolicySource {
  @override
  Future<String> fetchPolicyJson() {
    throw StateError('network source should not be created or called');
  }
}
