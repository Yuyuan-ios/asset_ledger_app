import 'package:asset_ledger/features/app_update/application/update_delivery.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps play channel to playStore environment', () {
    final delivery = UpdateDelivery(channel: VersionPolicy.channelPlay);

    expect(delivery.environment, UpdateChannelEnvironment.playStore);
  });

  test('maps non-play channels to directStore environment', () {
    for (final channel in const {
      VersionPolicy.channelXiaomi,
      VersionPolicy.channelHuawei,
      VersionPolicy.channelOppo,
      VersionPolicy.channelVivo,
      VersionPolicy.channelTencent,
      VersionPolicy.channelOfficial,
    }) {
      final delivery = UpdateDelivery(channel: channel);

      expect(delivery.environment, UpdateChannelEnvironment.directStore);
    }
  });

  test('directStore launches parsed update URL', () async {
    final launched = <Uri>[];
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelOfficial,
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(_decision(updateUrl: 'https://example.com/download'));

    expect(launched, [Uri.parse('https://example.com/download')]);
  });

  test('invalid update URL is ignored without crashing', () async {
    final launched = <Uri>[];
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelOfficial,
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(_decision(updateUrl: 'not a url'));

    expect(launched, isEmpty);
  });

  test('playStore without in-app launcher falls back to URL launch', () async {
    final launched = <Uri>[];
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelPlay,
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(
      _decision(updateUrl: 'https://play.google.com/store/apps/details?id=x'),
    );

    expect(launched, [
      Uri.parse('https://play.google.com/store/apps/details?id=x'),
    ]);
  });

  test('playStore in-app launcher handled skips URL launch', () async {
    final launched = <Uri>[];
    var inAppCalls = 0;
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelPlay,
      inAppUpdateLauncher: (decision) async {
        inAppCalls++;
        return true;
      },
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(_decision(updateUrl: 'https://example.com/download'));

    expect(inAppCalls, 1);
    expect(launched, isEmpty);
  });

  test('playStore in-app launcher false falls back to URL launch', () async {
    final launched = <Uri>[];
    var inAppCalls = 0;
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelPlay,
      inAppUpdateLauncher: (decision) async {
        inAppCalls++;
        return false;
      },
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(_decision(updateUrl: 'https://example.com/download'));

    expect(inAppCalls, 1);
    expect(launched, [Uri.parse('https://example.com/download')]);
  });

  test('playStore in-app launcher error falls back to URL launch', () async {
    final launched = <Uri>[];
    var inAppCalls = 0;
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelPlay,
      inAppUpdateLauncher: (decision) async {
        inAppCalls++;
        throw StateError('in-app update failed');
      },
      urlLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await delivery.launch(_decision(updateUrl: 'https://example.com/download'));

    expect(inAppCalls, 1);
    expect(launched, [Uri.parse('https://example.com/download')]);
  });

  test('URL launcher error does not escape', () async {
    final delivery = UpdateDelivery(
      channel: VersionPolicy.channelOfficial,
      urlLauncher: (uri) async {
        throw StateError('launch failed');
      },
    );

    await delivery.launch(_decision(updateUrl: 'https://example.com/download'));
  });
}

VersionGateDecision _decision({required String updateUrl}) {
  return VersionGateDecision.optional(
    updateUrl: updateUrl,
    title: '发现新版本',
    content: '更新以获得更稳定的体验。',
  );
}
