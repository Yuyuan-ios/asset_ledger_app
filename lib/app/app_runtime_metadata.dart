import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../features/app_update/domain/version_policy.dart';

class AppRuntimeMetadata {
  AppRuntimeMetadata._();

  static const String channel = String.fromEnvironment(
    'APP_CHANNEL',
    defaultValue: VersionPolicy.channelOfficial,
  );

  static String get platform {
    return Platform.isIOS
        ? VersionPolicy.platformIos
        : VersionPolicy.platformAndroid;
  }

  static Future<String> currentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<String?> cloudApiVersionHeader() async {
    final version = (await currentVersion()).trim();
    return version.isEmpty ? null : version;
  }
}
