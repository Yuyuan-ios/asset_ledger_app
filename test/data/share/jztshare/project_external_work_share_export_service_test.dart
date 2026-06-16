import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/share/jztshare/jztshare_errors.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_builder.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_export_service.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_rich_payload.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = ProjectExternalWorkShareBuilder();
  const service = ProjectExternalWorkShareExportService();
  const parser = JztShareEnvelopeParser();
  const producer = JztShareProducer(
    appName: 'FleetLedger',
    appVersion: '1.0.1+3',
    platform: 'iOS',
  );
  final createdAt = DateTime.utc(2024, 5, 1, 12);

  final deviceA = Device(
    id: 1,
    name: 'HITACHI 1#',
    brand: 'HITACHI',
    model: 'ZX200',
    defaultUnitPrice: 100.0,
    baseMeterHours: 0.0,
    equipmentType: EquipmentType.excavator,
  );

  // r1: hours，income == hours×单价 → 进 export_lines。
  final r1 = TimingRecord(
    id: 11,
    deviceId: 1,
    startDate: 20240101,
    contact: '张三',
    site: '工地A',
    type: TimingType.hours,
    startMeter: 100.0,
    endMeter: 108.0,
    hours: 8.0,
    income: 800.0,
  );
  // r3: rent，与 r1 同设备 → 混合 device group；只进 rich records。
  final r3 = TimingRecord(
    id: 13,
    deviceId: 1,
    startDate: 20240103,
    contact: '张三',
    site: '工地A',
    type: TimingType.rent,
    startMeter: 0.0,
    endMeter: 0.0,
    hours: 2.0,
    income: 500.0,
  );

  // record 11 桶里混入了一条 misbucket（timingRecordId=999）历史，
  // 以及两条 createdAt 相同的历史用于 tie-break。
  final calcHistoryMap = <int, List<TimingCalculationHistory>>{
    11: [
      TimingCalculationHistory(
        id: 'a',
        timingRecordId: 11,
        createdAt: DateTime.utc(2024, 1, 1, 10),
        expression: '4+4',
        result: 8.0,
        ticketCount: 1,
      ),
      TimingCalculationHistory(
        id: 'b',
        timingRecordId: 11,
        createdAt: DateTime.utc(2024, 1, 1, 10),
        expression: '5+3',
        result: 8.0,
        ticketCount: 2,
      ),
      TimingCalculationHistory(
        id: 'z-misbucket',
        timingRecordId: 999, // 不属于 record 11
        createdAt: DateTime.utc(2024, 1, 1, 23),
        expression: '1+1',
        result: 2.0,
        ticketCount: 9,
      ),
    ],
  };

  ProjectExternalWorkShareRichPayload payload() => builder.build(
    shareId: 'share-5c',
    senderName: '李工',
    sourceInstallationUuid: 'install-uuid',
    records: [r3, r1],
    deviceMap: {1: deviceA},
    calcHistoryMap: calcHistoryMap,
  );

  test('envelope is project_external_work_share and parser recognizes it', () {
    final result = service.buildEnvelope(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
    );
    final root = jsonDecode(result.content) as Map<String, Object?>;
    expect(root['magic'], JztShareEnvelope.magicValue);
    expect(root['package_type'], JztShareEnvelope.projectExternalWorkShareType);
    expect(root['package_type'], isNot('backup'));

    final parsed = parser.parseProjectExternalWorkShare(result.content);
    expect(parsed.envelope.packageType, 'project_external_work_share');
    expect(parsed.envelope.shareId, 'share-5c');
    expect(parsed.payload.shareId, 'share-5c');

    expect(result.packageId, 'share-5c');
    expect(result.recordCount, 2);
    expect(result.deviceCount, 1);
    expect(result.totalIncomeFen, 130000); // 80000 + 50000
  });

  test('payloadSha256 is stable and matches canonical validator', () {
    final p = payload();
    final r1res = service.buildEnvelope(
      payload: p,
      producer: producer,
      createdAt: createdAt,
    );
    final r2res = service.buildEnvelope(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
    );
    expect(r1res.payloadSha256, r2res.payloadSha256);
    expect(
      r1res.payloadSha256,
      JztShareEnvelopeValidator.payloadSha256(p.toMap()),
    );
    expect(r1res.payloadSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('tampering payload breaks the integrity hash', () {
    final result = service.buildEnvelope(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
    );
    final root = jsonDecode(result.content) as Map<String, Object?>;
    final p = root['payload'] as Map<String, Object?>;
    final summary = p['summary'] as Map<String, Object?>;
    summary['total_income_fen'] = 999999; // 篡改
    final tampered = jsonEncode(root);

    try {
      parser.parseProjectExternalWorkShare(tampered);
      fail('expected JztShareParseException');
    } on JztShareParseException catch (e) {
      expect(e.code, JztShareErrorCodes.payloadHashMismatch);
    }
  });

  test('legacy export_lines kept; rent stays rich-only', () {
    final result = service.buildEnvelope(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
    );
    final parsed = parser.parseProjectExternalWorkShare(result.content);
    expect(parsed.payload.exportLines.length, 1);
    expect(
      parsed.payload.exportLines.first.exportLineUuid,
      matches(RegExp(r'^rec-[0-9a-f]{24}$')),
    );
    expect(parsed.payload.exportLines.first.exportLineUuid, isNot('timing:11'));

    final p =
        (jsonDecode(result.content) as Map<String, Object?>)['payload']
            as Map<String, Object?>;
    final records = p['records'] as List<Object?>;
    expect(records.length, 2); // 富 records 含 rent
    final rentRec = records.cast<Map<String, Object?>>().firstWhere(
      (r) => r['source_timing_record_id'] == 13,
    );
    expect(rentRec['type'], 'rent');
    expect(rentRec['start_meter'], isNull);
    expect(rentRec['income_fen'], 50000); // 真实 income，未重算
  });

  test('rich sections retained and fingerprint_version == 2', () {
    final result = service.buildEnvelope(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
    );
    final p =
        (jsonDecode(result.content) as Map<String, Object?>)['payload']
            as Map<String, Object?>;
    for (final key in [
      'summary',
      'project_snapshot',
      'devices',
      'records',
      'device_groups',
    ]) {
      expect(p.containsKey(key), isTrue, reason: 'missing $key');
    }
    expect(p['fingerprint_version'], 2);
    expect(p['protocol_version'], 1);
    final hoursRec = (p['records'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((r) => r['source_timing_record_id'] == 11);
    expect(hoursRec['income_fen'], 80000);
  });

  test('filledCalculation excludes misbucket and tie-breaks by id', () {
    final p = payload();
    final rec11 = p.records.firstWhere((r) => r.sourceTimingRecordId == 11);
    expect(rec11.filledCalculation, isNotNull);
    // misbucket(999, 更晚 createdAt) 不应被选中
    expect(rec11.filledCalculation!.expression, isNot('1+1'));
    // createdAt 相同，按 id 升序较大者：'b' > 'a'
    expect(rec11.filledCalculation!.expression, '5+3');
    expect(rec11.filledCalculation!.ticketCount, 2);
  });

  test('deviceGroups mixed hours+rent: locked current semantics', () {
    final p = payload();
    final g1 = p.deviceGroups.firstWhere((g) => g.sourceDeviceId == 1);
    expect(g1.recordIds, [11, 13]);
    // meter span 仅来自 hours 行
    expect(g1.firstStartMeter, 100.0);
    expect(g1.lastEndMeter, 108.0);
    expect(g1.meterSpanMilli, 8000);
    // totalHoursMilli 含 rent 工时(8000+2000)
    expect(g1.totalHoursMilli, 10000);
    // 故 meterError 受 rent 影响 = |8000 - 10000|
    expect(g1.meterErrorMilli, 2000);
  });

  test('exportToDirectory writes a parseable .jzt file', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_5c_');
    addTearDown(() => dir.delete(recursive: true));

    final result = await service.exportToDirectory(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
      directory: dir,
    );
    expect(result.filePath, isNotNull);
    expect(result.fileName, '李工_20240501.jzt');
    final file = File(result.filePath!);
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(jsonDecode(content), isA<Map<String, Object?>>());
    final parsed = parser.parseProjectExternalWorkShare(content);
    expect(parsed.envelope.shareId, 'share-5c');
  });

  test('same-name exports do not silently overwrite (_2, _3)', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_5d_');
    addTearDown(() => dir.delete(recursive: true));

    final r1res = await service.exportToDirectory(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
      directory: dir,
    );
    final r2res = await service.exportToDirectory(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
      directory: dir,
    );
    final r3res = await service.exportToDirectory(
      payload: payload(),
      producer: producer,
      createdAt: createdAt,
      directory: dir,
    );
    expect(r1res.fileName, '李工_20240501.jzt');
    expect(r2res.fileName, '李工_20240501_2.jzt');
    expect(r3res.fileName, '李工_20240501_3.jzt');
    for (final r in [r1res, r2res, r3res]) {
      expect(await File(r.filePath!).exists(), isTrue);
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jzt'))
        .toList();
    expect(files.length, 3); // 三个文件都在，没被覆盖
  });

  test('file name strips illegal characters', () {
    final p = builder.build(
      shareId: 's',
      senderName: r'a/b:c*d e',
      sourceInstallationUuid: 'u',
      records: [r1],
      deviceMap: {1: deviceA},
      calcHistoryMap: const {},
    );
    final result = service.buildEnvelope(
      payload: p,
      producer: producer,
      createdAt: createdAt,
    );
    expect(result.fileName, endsWith('.jzt'));
    expect(result.fileName, isNot(contains('.jztshare')));
    expect(result.fileName, isNot(contains('/')));
    expect(result.fileName, matches(RegExp(r'^[^\\/:*?"<>|]+\.jzt$')));
    expect(result.fileName, 'a_b_c_d_e_20240501.jzt');
  });
}
