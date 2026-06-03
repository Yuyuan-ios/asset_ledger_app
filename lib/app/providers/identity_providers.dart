import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/operations/operation_access_control.dart';
import '../identity/app_identity_service.dart';

/// Identity providers: 注入本机 ActorContext 及其他身份相关对象。
class IdentityProviders {
  IdentityProviders._({required this.actorContext, required this.providers});

  final ActorContext actorContext;
  final List<SingleChildWidget> providers;

  /// 构建默认的身份 providers。
  ///
  /// 为生产者路径提供一个真实的 [ActorContext]（actorType=owner），
  /// 替换之前各处手动构造默认 owner 的方式。
  /// 安全兜底：若无 provider 注入而直接读 context，抛 ProviderNotFoundException。
  factory IdentityProviders.build() {
    final actorContext = AppIdentityService.instance.currentActorContext();
    return IdentityProviders._(
      actorContext: actorContext,
      providers: [Provider<ActorContext>.value(value: actorContext)],
    );
  }
}
