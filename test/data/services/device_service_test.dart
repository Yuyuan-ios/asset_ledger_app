import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/services/device_service.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    SubscriptionService.setPlanForDebug(Plan.free);
  });

  group('DeviceService.nextIndex', () {
    test('fills the first missing index among active devices of the same brand', () {
      final result = DeviceService.nextIndex(
        brand: 'SANY',
        activeDevices: const [
          Device(
            id: 1,
            name: 'SANY 2#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'SANY 3#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 3,
            name: 'SANY 9#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
            isActive: false,
          ),
          Device(
            id: 4,
            name: 'CAT 1#',
            brand: 'CAT',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
      );

      expect(result, 1);
    });

    test('builds the next display name from the trimmed brand', () {
      final result = DeviceService.nextDisplayName(
        brand: '  CAT  ',
        activeDevices: const [
          Device(
            id: 1,
            name: 'CAT 1#',
            brand: 'CAT',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
      );

      expect(result, 'CAT 2#');
    });
  });

  group('DeviceService.applyCustomAvatar', () {
    const device = Device(
      id: 1,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
      customAvatarPath: '/tmp/old.png',
    );

    test('throws when a free plan writes a non-empty avatar path', () {
      SubscriptionService.setPlanForDebug(Plan.free);

      expect(
        () => DeviceService.applyCustomAvatar(
          device: device,
          customAvatarPath: '/tmp/new.png',
        ),
        throwsException,
      );
    });

    test('clears the avatar path when the input is blank', () {
      final updated = DeviceService.applyCustomAvatar(
        device: device,
        customAvatarPath: '   ',
      );

      expect(updated.customAvatarPath, isNull);
    });

    test('writes a trimmed avatar path when the plan is pro', () {
      SubscriptionService.setPlanForDebug(Plan.pro);

      final updated = DeviceService.applyCustomAvatar(
        device: device,
        customAvatarPath: '  /tmp/new.png  ',
      );

      expect(updated.customAvatarPath, '/tmp/new.png');
    });
  });
}
