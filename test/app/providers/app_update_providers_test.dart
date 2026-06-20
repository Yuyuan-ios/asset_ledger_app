import 'package:asset_ledger/app/providers/app_update_providers.dart';
import 'package:asset_ledger/app/version_policy_config.dart';
import 'package:asset_ledger/features/app_update/application/update_prompt_coordinator.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_cache.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('available config wires forced and optional presenters', (
    WidgetTester tester,
  ) async {
    final source = _StaticVersionPolicySource(_forcedPolicyJson);
    var optionalCalls = 0;
    var forcedCalls = 0;
    final appUpdate = AppUpdateProviders.build(
      endpointConfig: VersionPolicyEndpointConfig.available(
        uri: Uri.parse('https://example.com/app/version-policy.json'),
      ),
      sourceFactory: ({required Uri uri}) => source,
      cacheFactory: _MemoryVersionPolicyCache.new,
      currentVersionProvider: () async => '0.9.0',
      platform: 'android',
      showPrompt: (context, decision) async {
        optionalCalls++;
      },
      showForcedBlocker: (context, decision) async {
        forcedCalls++;
      },
    );

    final (coordinator, context) = await _pumpCoordinator(tester, appUpdate);

    await coordinator.onTimingPageEntered(context);

    expect(source.fetchCalls, 1);
    expect(forcedCalls, 1);
    expect(optionalCalls, 0);
  });

  testWidgets('available config keeps optional presenter path', (
    WidgetTester tester,
  ) async {
    final source = _StaticVersionPolicySource(_optionalPolicyJson);
    var optionalCalls = 0;
    var forcedCalls = 0;
    final appUpdate = AppUpdateProviders.build(
      endpointConfig: VersionPolicyEndpointConfig.available(
        uri: Uri.parse('https://example.com/app/version-policy.json'),
      ),
      sourceFactory: ({required Uri uri}) => source,
      cacheFactory: _MemoryVersionPolicyCache.new,
      currentVersionProvider: () async => '1.2.0',
      platform: 'android',
      showPrompt: (context, decision) async {
        optionalCalls++;
      },
      showForcedBlocker: (context, decision) async {
        forcedCalls++;
      },
    );

    final (coordinator, context) = await _pumpCoordinator(tester, appUpdate);

    await coordinator.onTimingPageEntered(context);

    expect(source.fetchCalls, 1);
    expect(optionalCalls, 1);
    expect(forcedCalls, 0);
  });

  testWidgets(
    'unavailable config provides no-op coordinator without creating source',
    (WidgetTester tester) async {
      var sourceFactoryCalls = 0;
      var optionalCalls = 0;
      var forcedCalls = 0;
      final appUpdate = AppUpdateProviders.build(
        endpointConfig: const VersionPolicyEndpointConfig.unavailable(
          '版本策略暂未配置',
        ),
        sourceFactory: ({required Uri uri}) {
          sourceFactoryCalls++;
          return _ThrowingVersionPolicySource();
        },
        showPrompt: (context, decision) async {
          optionalCalls++;
        },
        showForcedBlocker: (context, decision) async {
          forcedCalls++;
        },
      );

      final (coordinator, context) = await _pumpCoordinator(tester, appUpdate);

      await coordinator.onTimingPageEntered(context);

      expect(sourceFactoryCalls, 0);
      expect(forcedCalls, 0);
      expect(optionalCalls, 0);
    },
  );
}

Future<(UpdatePromptCoordinator, BuildContext)> _pumpCoordinator(
  WidgetTester tester,
  AppUpdateProviders appUpdate,
) async {
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
  return (coordinator, context);
}

const String _forcedPolicyJson = '''
{
  "android": {
    "latestVersion": "1.4.0",
    "minSupportedVersion": "1.0.0",
    "updateUrl": "https://example.com/download",
    "title": "发现新版本",
    "content": "请更新后继续使用。"
  }
}
''';

const String _optionalPolicyJson = '''
{
  "android": {
    "latestVersion": "1.4.0",
    "minSupportedVersion": "1.0.0",
    "updateUrl": "https://example.com/download",
    "title": "发现新版本",
    "content": "更新以获得更稳定的体验。"
  }
}
''';

class _StaticVersionPolicySource implements VersionPolicySource {
  _StaticVersionPolicySource(this.policyJson);

  final String policyJson;
  var fetchCalls = 0;

  @override
  Future<String> fetchPolicyJson() async {
    fetchCalls++;
    return policyJson;
  }
}

class _ThrowingVersionPolicySource implements VersionPolicySource {
  @override
  Future<String> fetchPolicyJson() {
    throw StateError('network source should not be created or called');
  }
}

class _MemoryVersionPolicyCache implements VersionPolicyCache {
  VersionPolicyCacheEntry? _entry;

  @override
  Future<void> clear() async {
    _entry = null;
  }

  @override
  Future<VersionPolicyCacheEntry?> read() async {
    return _entry;
  }

  @override
  Future<void> write(VersionPolicyCacheEntry entry) async {
    _entry = entry;
  }
}
