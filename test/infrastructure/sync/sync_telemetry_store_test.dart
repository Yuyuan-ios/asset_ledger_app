import 'package:asset_ledger/infrastructure/sync/sync_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesSyncTelemetryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists and reads the last sync telemetry snapshot', () async {
      const store = SharedPreferencesSyncTelemetryStore();
      const telemetry = SyncTelemetry(
        trigger: 'manual',
        status: SyncTelemetryStatus.completed,
        pullApplied: 2,
        pullConflicts: 1,
        pushPushed: 3,
        pushFailed: 4,
        timestamp: '2026-06-02T03:04:05.000Z',
      );

      await store.write(telemetry);
      final stored = await store.read();

      expect(stored, isNotNull);
      expect(stored!.trigger, 'manual');
      expect(stored.status, SyncTelemetryStatus.completed);
      expect(stored.pullApplied, 2);
      expect(stored.pullConflicts, 1);
      expect(stored.pushPushed, 3);
      expect(stored.pushFailed, 4);
      expect(stored.reason, isNull);
      expect(stored.error, isNull);
      expect(stored.timestamp, '2026-06-02T03:04:05.000Z');
    });
  });
}
