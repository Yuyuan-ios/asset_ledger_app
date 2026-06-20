import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/app_update/application/update_prompt_coordinator.dart';
import '../../features/app_update/domain/version_check_service.dart';
import '../../features/app_update/domain/version_gate_decision.dart';
import '../../features/app_update/domain/version_policy.dart';
import '../../features/app_update/domain/version_policy_cache.dart';
import '../../features/app_update/domain/version_policy_source.dart';
import '../../features/app_update/infrastructure/http_version_policy_source.dart';
import '../../features/app_update/infrastructure/prefs_version_policy_cache.dart';
import '../../features/app_update/presentation/forced_update_blocker.dart';
import '../../features/app_update/presentation/optional_update_prompt.dart';
import '../version_policy_config.dart';

typedef VersionPolicySourceFactory =
    VersionPolicySource Function({required Uri uri});

typedef VersionPolicyCacheFactory = VersionPolicyCache Function();

class AppUpdateProviders {
  AppUpdateProviders._({required this.coordinator, required this.providers});

  final UpdatePromptCoordinator coordinator;
  final List<SingleChildWidget> providers;

  factory AppUpdateProviders.build({
    VersionPolicyEndpointConfig? endpointConfig,
    VersionPolicySourceFactory sourceFactory = _createHttpPolicySource,
    VersionPolicyCacheFactory cacheFactory = _createPreferencesPolicyCache,
    CurrentVersionProvider? currentVersionProvider,
    String? platform,
    String channel = const String.fromEnvironment(
      'APP_CHANNEL',
      defaultValue: VersionPolicy.channelOfficial,
    ),
    UpdatePromptPresenter showPrompt = _showOptionalPrompt,
    ForcedUpdatePresenter showForcedBlocker = _showForcedBlocker,
  }) {
    final config = endpointConfig ?? VersionPolicyConfig.current;
    final UpdatePromptCoordinator coordinator;
    if (!config.isAvailable) {
      coordinator = UpdatePromptCoordinator.noop();
    } else {
      final service = VersionCheckService(
        source: sourceFactory(uri: config.uri!),
        cache: cacheFactory(),
        currentVersionProvider:
            currentVersionProvider ?? _packageInfoVersionProvider,
        platform: platform ?? _currentPlatform(),
        channel: channel,
      );
      coordinator = UpdatePromptCoordinator(
        checkVersion: service.check,
        showPrompt: showPrompt,
        showForcedBlocker: showForcedBlocker,
      );
    }

    return AppUpdateProviders._(
      coordinator: coordinator,
      providers: [Provider<UpdatePromptCoordinator>.value(value: coordinator)],
    );
  }

  static VersionPolicySource _createHttpPolicySource({required Uri uri}) {
    return HttpVersionPolicySource(uri: uri);
  }

  static VersionPolicyCache _createPreferencesPolicyCache() {
    return const SharedPreferencesVersionPolicyCache();
  }

  static Future<String> _packageInfoVersionProvider() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static String _currentPlatform() {
    return Platform.isIOS
        ? VersionPolicy.platformIos
        : VersionPolicy.platformAndroid;
  }

  static Future<void> _showOptionalPrompt(
    BuildContext context,
    VersionGateDecision decision,
  ) {
    return showOptionalUpdatePrompt(context: context, decision: decision);
  }

  static Future<void> _showForcedBlocker(
    BuildContext context,
    VersionGateDecision decision,
  ) {
    return showForcedUpdateBlocker(context: context, decision: decision);
  }
}
