import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/services/device_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceService parsing edges', () {
    test('returns 1 when the requested brand is blank after trimming', () {
      final result = DeviceService.nextIndex(
        brand: '   ',
        activeDevices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
      );

      expect(result, 1);
    });

    test('parses numeric suffixes with optional spaces before the hash', () {
      expect(DeviceService.indexFromDisplayName('CAT 12#'), 12);
      expect(DeviceService.indexFromDisplayName('CAT 12   #'), 12);
    });

    test('returns null when the display name has no valid numeric suffix', () {
      expect(DeviceService.indexFromDisplayName('CAT #'), isNull);
      expect(DeviceService.indexFromDisplayName('CAT one#'), isNull);
    });
  });
}
