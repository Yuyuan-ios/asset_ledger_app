import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/app_update/application/update_delivery.dart';
import '../../features/app_update/application/update_prompt_coordinator.dart';
import '../../features/app_update/domain/version_check_service.dart';
import '../../features/app_update/domain/version_gate_decision.dart';
import '../../features/app_update/domain/version_policy_cache.dart';
import '../../features/app_update/domain/version_policy_source.dart';
import '../../features/app_update/infrastructure/http_version_policy_source.dart';
import '../../features/app_update/infrastructure/prefs_version_policy_cache.dart';
import '../../features/app_update/presentation/forced_update_blocker.dart';
import '../../features/app_update/presentation/optional_update_prompt.dart';
import '../app_runtime_metadata.dart';
import '../version_policy_config.dart';

typedef VersionPolicySourceFactory =
    VersionPolicySource Function({required Uri uri});

typedef VersionPolicyCacheFactory = VersionPolicyCache Function();
typedef UpdateDeliveryFactory =
    UpdateDelivery Function({required String channel});

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
    String channel = AppRuntimeMetadata.channel,
    UpdateDeliveryFactory deliveryFactory = _createUpdateDelivery,
    UpdatePromptPresenter? showPrompt,
    ForcedUpdatePresenter? showForcedBlocker,
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
            currentVersionProvider ?? AppRuntimeMetadata.currentVersion,
        platform: platform ?? AppRuntimeMetadata.platform,
        channel: channel,
      );
      final delivery = deliveryFactory(channel: channel);
      coordinator = UpdatePromptCoordinator(
        checkVersion: service.check,
        showPrompt:
            showPrompt ??
            (context, decision) =>
                _showOptionalPrompt(context, decision, delivery),
        showForcedBlocker:
            showForcedBlocker ??
            (context, decision) =>
                _showForcedBlocker(context, decision, delivery),
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

  static UpdateDelivery _createUpdateDelivery({required String channel}) {
    return UpdateDelivery(channel: channel, inAppUpdateLauncher: null);
  }

  static Future<void> _showOptionalPrompt(
    BuildContext context,
    VersionGateDecision decision,
    UpdateDelivery delivery,
  ) {
    return showOptionalUpdatePrompt(
      context: context,
      decision: decision,
      delivery: delivery,
    );
  }

  static Future<void> _showForcedBlocker(
    BuildContext context,
    VersionGateDecision decision,
    UpdateDelivery delivery,
  ) {
    return showForcedUpdateBlocker(
      context: context,
      decision: decision,
      delivery: delivery,
    );
  }
}
