import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/device/model/brand_catalog.dart';
import 'package:asset_ledger/features/device/model/device_create_flow.dart';
import 'package:asset_ledger/features/device/model/device_type_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceTypeCatalog', () {
    test('exposes all 7 device types plus custom across 5 categories', () {
      final ids = DeviceTypeCatalog.allTypes.map((t) => t.id).toSet();
      expect(
        ids,
        containsAll(<String>{
          'excavator',
          'loader',
          'roller',
          'handling_vehicle',
          'agricultural_machine',
          'drone',
          'robot',
          'custom',
        }),
      );
      expect(DeviceTypeCatalog.categories.map((c) => c.id).toSet(), {
        'construction',
        'agriculture',
        'unmanned',
        'smart',
        'other',
      });
    });

    test('excavator/loader/roller are available and map to EquipmentType', () {
      final available = DeviceTypeCatalog.allTypes
          .where((t) => t.isAvailable)
          .map((t) => t.id)
          .toSet();
      expect(available, {'excavator', 'loader', 'roller'});

      final excavator = DeviceTypeCatalog.byId('excavator')!;
      expect(excavator.equipmentType, EquipmentType.excavator);
      expect(excavator.createFlow, DeviceCreateFlow.engineeringEditor);

      final loader = DeviceTypeCatalog.byId('loader')!;
      expect(loader.equipmentType, EquipmentType.loader);
      expect(loader.createFlow, DeviceCreateFlow.engineeringEditor);

      // Phase 2：压路机端到端接通，复用工程机械编辑器。
      final roller = DeviceTypeCatalog.byId('roller')!;
      expect(roller.equipmentType, EquipmentType.roller);
      expect(roller.createFlow, DeviceCreateFlow.engineeringEditor);
      expect(roller.createFlow.isImplemented, isTrue);
    });

    test('coming-soon types have no EquipmentType and are not creatable', () {
      for (final id in [
        'handling_vehicle',
        'agricultural_machine',
        'drone',
        'robot',
        'custom',
      ]) {
        final def = DeviceTypeCatalog.byId(id)!;
        expect(def.isAvailable, isFalse, reason: id);
        expect(def.equipmentType, isNull, reason: id);
        expect(def.createFlow, DeviceCreateFlow.comingSoon, reason: id);
        expect(def.createFlow.isImplemented, isFalse, reason: id);
      }
    });

    test('quick entries are the four common construction types', () {
      expect(DeviceTypeCatalog.quickEntries.map((t) => t.id).toList(), [
        'excavator',
        'loader',
        'roller',
        'handling_vehicle',
      ]);
    });

    test('fromEquipmentType round-trips; defaults to excavator', () {
      expect(
        DeviceTypeCatalog.fromEquipmentType(EquipmentType.loader).id,
        'loader',
      );
      expect(
        DeviceTypeCatalog.fromEquipmentType(EquipmentType.roller).id,
        'roller',
      );
      expect(DeviceTypeCatalog.defaultType.id, 'excavator');
      expect(DeviceTypeCatalog.byId('nope'), isNull);
    });

    test('roller persists via a stable dbValue round-trip', () {
      expect(EquipmentType.roller.dbValue, 'roller');
      expect(EquipmentTypeX.fromDbValue('roller'), EquipmentType.roller);
    });
  });

  group('BrandCatalog.groupsByTypeId', () {
    test('robot brands are grouped by country, not by robot subtype', () {
      final groups = BrandCatalog.groupsByTypeId('robot');
      final cn = groups[BrandCountry.cn]!.map((b) => b.value).toSet();
      final us = groups[BrandCountry.us]!.map((b) => b.value).toSet();

      expect(
        cn,
        containsAll(<String>{
          'Unitree',
          'UBTECH',
          'AgiBot',
          'XPeng',
          'Li Auto',
        }),
      );
      expect(
        us,
        containsAll(<String>{
          'Tesla',
          'Boston Dynamics',
          'Figure AI',
          'Agility Robotics',
        }),
      );
      // 机器人不出现在工程机械专属的日/韩分组里。
      expect(groups[BrandCountry.jp], isEmpty);
      expect(groups[BrandCountry.kr], isEmpty);
    });

    test('excavator keeps its existing engineering brands', () {
      final groups = BrandCatalog.groupsByTypeId('excavator');
      final all = groups.values.expand((e) => e).map((b) => b.value).toSet();
      expect(all, containsAll(<String>{'SANY', 'Komatsu', 'CAT', 'HYUNDAI'}));
    });

    test('roller now has a brand wall (Phase 2)', () {
      final groups = BrandCatalog.groupsByTypeId('roller');
      final all = groups.values.expand((e) => e).map((b) => b.value).toSet();
      expect(all, containsAll(<String>{'XCMG', 'SANY', 'LiuGong', 'CAT'}));
    });

    test('types without a brand library return empty groups', () {
      final groups = BrandCatalog.groupsByTypeId('handling_vehicle');
      expect(groups.values.every((e) => e.isEmpty), isTrue);
    });

    test('query filters by Chinese name, English name or value', () {
      expect(
        BrandCatalog.groupsByTypeId(
          'robot',
          query: '宇树',
        )[BrandCountry.cn]!.map((b) => b.value),
        ['Unitree'],
      );
      expect(
        BrandCatalog.groupsByTypeId(
          'robot',
          query: 'tesla',
        )[BrandCountry.us]!.map((b) => b.value),
        ['Tesla'],
      );
      final none = BrandCatalog.groupsByTypeId('robot', query: 'zzz');
      expect(none.values.every((e) => e.isEmpty), isTrue);
    });
  });

  testWidgets('excavator bucket SVG glyph parses and renders', (tester) async {
    expect(DeviceTypeCatalog.byId('excavator')!.svgGlyph, isNotNull);
    await tester.pumpWidget(
      MaterialApp(
        home: SvgPicture.string(
          kExcavatorBucketSvg,
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.orange, BlendMode.srcIn),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
