import 'package:asset_ledger/features/app_update/domain/version_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionPolicy', () {
    test('parses the V1 version-policy example shape', () {
      final policy = VersionPolicy.fromJsonString(
        _v1PolicyJson,
        platform: VersionPolicy.platformAndroid,
      );

      expect(policy, isNotNull);
      expect(policy!.latestVersion, '1.4.0');
      expect(policy.minSupportedVersion, '1.0.0');
      expect(policy.updateUrl, 'https://example.com/download');
      expect(policy.title, '发现新版本');
      expect(policy.content, '更新以获得更稳定的体验。');
      expect(
        policy.updateUrlFor(
          platform: VersionPolicy.platformAndroid,
          channel: VersionPolicy.channelXiaomi,
        ),
        'mimarket://details?id=com.example.fleetledger',
      );
    });

    test('keeps title and content null when optional copy is missing', () {
      final policy = VersionPolicy.fromJsonString('''
        {
          "ios": {
            "latestVersion": "1.4.0",
            "minSupportedVersion": "1.0.0",
            "updateUrl": "itms-apps://apps.apple.com/app/idXXXXXXXX"
          }
        }
        ''', platform: VersionPolicy.platformIos);

      expect(policy, isNotNull);
      expect(policy!.title, isNull);
      expect(policy.content, isNull);

      final details = policy.updateDetailsFor(
        platform: VersionPolicy.platformIos,
        channel: VersionPolicy.channelPlay,
      );
      expect(details.title, isNull);
      expect(details.content, isNull);
    });

    test('returns null when critical fields are missing', () {
      final missingLatest = VersionPolicy.fromJsonString('''
        {
          "android": {
            "minSupportedVersion": "1.0.0",
            "updateUrl": "https://example.com/download"
          }
        }
        ''', platform: VersionPolicy.platformAndroid);
      final missingMin = VersionPolicy.fromJsonString('''
        {
          "android": {
            "latestVersion": "1.4.0",
            "updateUrl": "https://example.com/download"
          }
        }
        ''', platform: VersionPolicy.platformAndroid);

      expect(missingLatest, isNull);
      expect(missingMin, isNull);
    });

    test('selects android channelUrls hit and falls back on channel miss', () {
      final policy = VersionPolicy.fromJsonString(
        _v1PolicyJson,
        platform: VersionPolicy.platformAndroid,
      )!;

      expect(
        policy.updateUrlFor(
          platform: VersionPolicy.platformAndroid,
          channel: VersionPolicy.channelHuawei,
        ),
        'appmarket://details?id=com.example.fleetledger',
      );
      expect(
        policy.updateUrlFor(
          platform: VersionPolicy.platformAndroid,
          channel: 'unknown',
        ),
        'https://example.com/download',
      );
    });

    test('falls back to updateUrl when android channelUrls are absent', () {
      final policy = VersionPolicy.fromJsonString('''
        {
          "android": {
            "latestVersion": "1.4.0",
            "minSupportedVersion": "1.0.0",
            "updateUrl": "https://example.com/download"
          }
        }
        ''', platform: VersionPolicy.platformAndroid)!;

      expect(
        policy.updateUrlFor(
          platform: VersionPolicy.platformAndroid,
          channel: VersionPolicy.channelPlay,
        ),
        'https://example.com/download',
      );
    });

    test('ignores channelUrls for ios and uses updateUrl directly', () {
      final policy = VersionPolicy.fromJsonString(
        _v1PolicyJson,
        platform: VersionPolicy.platformIos,
      )!;

      expect(
        policy.updateUrlFor(
          platform: VersionPolicy.platformIos,
          channel: VersionPolicy.channelPlay,
        ),
        'itms-apps://apps.apple.com/app/idXXXXXXXX',
      );
    });

    test('returns null for invalid JSON', () {
      expect(
        VersionPolicy.fromJsonString('not json', platform: 'android'),
        isNull,
      );
    });
  });
}

const String _v1PolicyJson = '''
{
  "ios": {
    "latestVersion": "1.4.0",
    "minSupportedVersion": "1.0.0",
    "updateUrl": "itms-apps://apps.apple.com/app/idXXXXXXXX",
    "title": "发现新版本",
    "content": "更新以获得更稳定的体验。"
  },
  "android": {
    "latestVersion": "1.4.0",
    "minSupportedVersion": "1.0.0",
    "updateUrl": "https://example.com/download",
    "channelUrls": {
      "xiaomi": "mimarket://details?id=com.example.fleetledger",
      "huawei": "appmarket://details?id=com.example.fleetledger",
      "oppo": "oppomarket://details?packagename=com.example.fleetledger",
      "vivo": "vivomarket://details?id=com.example.fleetledger",
      "tencent": "market://details?id=com.example.fleetledger",
      "official": "https://example.com/download",
      "play": "https://play.google.com/store/apps/details?id=com.example.fleetledger"
    },
    "title": "发现新版本",
    "content": "更新以获得更稳定的体验。"
  }
}
''';
