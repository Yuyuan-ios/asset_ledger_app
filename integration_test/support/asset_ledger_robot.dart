import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

class AssetLedgerRobot {
  AssetLedgerRobot(this.$);

  final PatrolIntegrationTester $;

  Future<void> openTab(String label) async {
    await $.tester.tap(find.bySemanticsLabel(label));
    await $.pumpAndSettle();
  }

  Future<void> addDevice({
    String brand = 'SANY',
    String unitPrice = '350',
    String baseMeter = '10',
    String model = 'PATROL-01',
  }) async {
    await openTab('设备');
    await $.tester.tap(find.text('添加设备'));
    await $.pumpAndSettle();

    expect(find.text('选择设备头像'), findsOneWidget);
    await $.tester.tap(find.text(brand));
    await $.pumpAndSettle();

    expect(find.text('新增设备'), findsOneWidget);
    await enterTextField('默认单价（>0，必填）', unitPrice);
    await enterTextField('基准码表（>=0，必填）', baseMeter);
    await enterTextField('型号（选填）', model);
    await tapConfirm();
  }

  Future<void> addDefaultDevice() async {
    await addDevice(model: 'SETUP-DEVICE');
    expect(find.text('已新增设备'), findsOneWidget);
  }

  Future<void> addRentTimingRecord({
    required String contact,
    required String site,
    required String amount,
  }) async {
    await openTab('计时');
    await $.tester.tap(find.text('+ 新建'));
    await $.pumpAndSettle();

    expect(find.text('新建计时'), findsOneWidget);
    await $.tester.tap(find.text('租金'));
    await $.pumpAndSettle();

    await enterTextField('联系人', contact);
    await enterTextField('使用地址/工地', site);
    await enterTextField('金额（元）', amount);
    await tapConfirm();
  }

  Future<void> addFuelRecord({
    required String supplier,
    required String liters,
    required String amount,
  }) async {
    await openTab('燃油');
    await $.tester.tap(find.text('+ 新建'));
    await $.pumpAndSettle();

    expect(find.text('新增燃油'), findsOneWidget);
    await enterTextField('供应人（必填）', supplier);
    await enterTextField('加油量（升）', liters);
    await enterTextField('金额（元）', amount);
    await tapConfirm();
  }

  Future<void> tapConfirm() async {
    await $.tester.tap(find.text('确定'));
    await $.pumpAndSettle();
  }

  Future<void> enterTextField(String label, String value) async {
    await $.tester.enterText(_textFieldByLabel(label), value);
    await $.pumpAndSettle();
  }

  Finder textFieldByLabel(String label) => _textFieldByLabel(label);

  Finder _textFieldByLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField(label: $label)',
    );
  }
}
