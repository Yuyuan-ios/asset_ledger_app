import 'dart:convert';

class VersionPolicy {
  VersionPolicy({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.updateUrl,
    String? title,
    String? content,
    Map<String, String>? channelUrls,
  }) : title = _nonEmptyString(title) ?? fallbackTitle,
       content = _nonEmptyString(content) ?? fallbackContent,
       channelUrls = Map.unmodifiable(channelUrls ?? const {});

  static const String platformIos = 'ios';
  static const String platformAndroid = 'android';

  static const String channelXiaomi = 'xiaomi';
  static const String channelHuawei = 'huawei';
  static const String channelOppo = 'oppo';
  static const String channelVivo = 'vivo';
  static const String channelTencent = 'tencent';
  static const String channelOfficial = 'official';
  static const String channelPlay = 'play';

  static const Set<String> androidChannels = {
    channelXiaomi,
    channelHuawei,
    channelOppo,
    channelVivo,
    channelTencent,
    channelOfficial,
    channelPlay,
  };

  static const String fallbackTitle = '发现新版本';
  static const String fallbackContent = '更新以获得更稳定的体验。';

  final String latestVersion;
  final String minSupportedVersion;
  final String updateUrl;
  final Map<String, String> channelUrls;
  final String title;
  final String content;

  static VersionPolicy? fromJsonString(
    String source, {
    required String platform,
  }) {
    try {
      return fromJson(jsonDecode(source), platform: platform);
    } on FormatException {
      return null;
    }
  }

  static VersionPolicy? fromJson(Object? decoded, {required String platform}) {
    if (decoded is! Map) return null;

    final rawPolicy = decoded[platform];
    if (rawPolicy is! Map) return null;

    final latestVersion = _nonEmptyString(rawPolicy['latestVersion']);
    final minSupportedVersion = _nonEmptyString(
      rawPolicy['minSupportedVersion'],
    );
    final updateUrl = _nonEmptyString(rawPolicy['updateUrl']);
    if (latestVersion == null ||
        minSupportedVersion == null ||
        updateUrl == null) {
      return null;
    }

    return VersionPolicy(
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
      updateUrl: updateUrl,
      title: _nonEmptyString(rawPolicy['title']),
      content: _nonEmptyString(rawPolicy['content']),
      channelUrls: _stringMap(rawPolicy['channelUrls']),
    );
  }

  String updateUrlFor({required String platform, required String channel}) {
    if (platform != platformAndroid) return updateUrl;
    return channelUrls[channel] ?? updateUrl;
  }

  VersionPolicyUpdateDetails updateDetailsFor({
    required String platform,
    required String channel,
  }) {
    return VersionPolicyUpdateDetails(
      updateUrl: updateUrlFor(platform: platform, channel: channel),
      title: title,
      content: content,
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static Map<String, String>? _stringMap(Object? value) {
    if (value is! Map) return null;

    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) continue;

      final mappedValue = _nonEmptyString(entry.value);
      if (mappedValue == null) continue;
      result[key] = mappedValue;
    }
    return result;
  }
}

class VersionPolicyUpdateDetails {
  const VersionPolicyUpdateDetails({
    required this.updateUrl,
    required this.title,
    required this.content,
  });

  final String updateUrl;
  final String title;
  final String content;
}
