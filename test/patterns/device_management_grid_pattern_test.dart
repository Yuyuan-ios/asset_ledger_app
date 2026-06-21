import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/device_management_grid_pattern.dart';
import 'package:asset_ledger/tokens/mapper/device_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses one-row height for zero to four devices', (tester) async {
    for (final count in [0, 1, 4]) {
      await _pumpGrid(tester, _devices(count));

      expect(_gridSize(tester).height, DeviceManagementGridTokens.oneRowHeight);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uses two-row height and keeps second row fully visible', (
    tester,
  ) async {
    for (final count in [5, 8]) {
      await _pumpGrid(tester, _devices(count));

      expect(_gridSize(tester).height, DeviceManagementGridTokens.twoRowHeight);
      _expectLabelInsideGrid(tester, '$count#挖掘机');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps long press delete entry available', (tester) async {
    Device? longPressed;

    await _pumpGrid(
      tester,
      _devices(1),
      onDeviceLongPress: (device) => longPressed = device,
    );

    await tester.longPress(find.text('1#挖掘机'));
    await tester.pump();

    expect(longPressed?.id, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpGrid(
  WidgetTester tester,
  List<Device> devices, {
  ValueChanged<Device>? onDeviceLongPress,
}) {
  return tester.pumpWidget(
    _localizedApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: DeviceTokens.pageContentWidth,
            child: DeviceManagementGrid(
              devices: devices,
              onDeviceTap: (_) {},
              onDeviceLongPress: onDeviceLongPress ?? (_) {},
              resolveIndexLabel: (device) => '${device.id}#',
            ),
          ),
        ),
      ),
    ),
  );
}

Size _gridSize(WidgetTester tester) {
  return tester.getSize(find.byKey(_gridKey));
}

void _expectLabelInsideGrid(WidgetTester tester, String label) {
  final gridBottom = tester.getBottomLeft(find.byKey(_gridKey)).dy;
  final labelBottom = tester.getBottomLeft(find.text(label)).dy;

  expect(labelBottom, lessThanOrEqualTo(gridBottom));
}

List<Device> _devices(int count) {
  return List<Device>.generate(count, (index) {
    final id = index + 1;
    return Device(
      id: id,
      name: 'Device $id',
      brand: id.isEven ? 'SANY' : 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    );
  });
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

const _gridKey = ValueKey<String>('device-management-grid-card');
