import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/share/jztshare/jztshare_errors.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_result.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_importer.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('rich records import', () {
    const importer = ProjectExternalWorkImporter();

    test('parses records[] and prefers them over export_lines', () async {
      await _openDb();
      final parsed = _parsedRich(
        records: [
          _record(uuid: 'timing:11', hoursMilli: 8000, incomeFen: 80000),
          _record(
            uuid: 'timing:12',
            fingerprint: 'fp-12',
            hoursMilli: 5000,
            incomeFen: 50000,
          ),
        ],
        // 仅 1 条 legacy 兼容子集，故意与 records 数量不同
        exportLines: [_legacyLine(uuid: 'timing:11')],
      );

      expect(parsed.payload.hasRichRecords, isTrue);

      final preview = await importer.buildPreview(parsed);
      expect(preview.isRich, isTrue);
      // recordCount 取 rich records，不是 export_lines
      expect(preview.recordCount, 2);
      expect(preview.totalAmountFen, 130000);
    });

    test('summary mismatch uses actual records and keeps rich path', () async {
      await _openDb();
      final records = [
        _record(
          uuid: 'timing:21',
          fingerprint: 'fp-summary-21',
          hoursMilli: 1250,
          incomeFen: 11111,
        ),
        _record(
          uuid: 'timing:22',
          fingerprint: 'fp-summary-22',
          hoursMilli: 2750,
          incomeFen: 22222,
        ),
      ];
      final parsed = _parsedRich(
        shareId: 'summary-mismatch-share',
        records: records,
        exportLines: [_legacyLine(uuid: 'legacy-only')],
        summary: const {
          'device_count': 99,
          'record_count': 99,
          'total_income_fen': 1,
          'total_hours_milli': 2,
        },
      );

      expect(parsed.payload.hasRichRecords, isTrue);
      expect(parsed.payload.summary?.recordCount, 99);
      expect(parsed.payload.richRecords!.map((record) => record.incomeFen), [
        11111,
        22222,
      ]);
      expect(parsed.payload.richRecords!.map((record) => record.hoursMilli), [
        1250,
        2750,
      ]);

      final preview = await importer.buildPreview(parsed);
      expect(preview.isRich, isTrue);
      expect(preview.recordCount, records.length);
      expect(preview.totalAmountFen, 33333);
      expect(preview.totalHoursMilli, 4000);
      expect(preview.lines.map((line) => line.exportLineUuid), [
        'timing:21',
        'timing:22',
      ]);
      expect(preview.lines.every((line) => line.amountIsAuthoritative), isTrue);
    });

    test('falls back to export_lines when records[] absent', () async {
      await _openDb();
      final parsed = _parsedRich(
        records: null,
        exportLines: [_legacyLine(uuid: 'timing:11')],
      );

      expect(parsed.payload.hasRichRecords, isFalse);
      final preview = await importer.buildPreview(parsed);
      expect(preview.isRich, isFalse);
      expect(preview.recordCount, 1);
    });

    test('rent/台班 record only in records[] is previewed and imported '
        'with real income_fen (no hours*price recompute)', () async {
      final db = await _openDb();
      final parsed = _parsedRich(
        records: [
          _record(
            uuid: 'timing:13',
            fingerprint: 'fp-rent',
            type: 'rent',
            hoursMilli: 1000,
            incomeFen: 120000,
            startMeter: null,
            endMeter: null,
          ),
        ],
        exportLines: const [], // rent 不在 legacy 子集
      );

      final preview = await importer.buildPreview(parsed);
      expect(preview.recordCount, 1);
      expect(preview.totalAmountFen, 120000);

      final result = await importer.importParsed(
        parsed,
        importedAt: '2026-05-19T00:00:00.000Z',
      );
      expect(result.status, ProjectExternalWorkImportStatus.imported);

      final rows = await db.query('external_work_records');
      expect(rows, hasLength(1));
      expect(rows.single['source_record_uuid'], 'timing:13');
      expect(rows.single['amount_fen'], 120000);
      expect(rows.single['hours_milli'], 1000);
      // rent 没有单价语义；rich path 必须用 null 表达，绝不伪造 0。
      expect(rows.single['source_unit_price_fen'], isNull);
      expect(rows.single['local_unit_price_fen'], isNull);
      expect(rows.single['record_kind'], 'rent');
    });

    test(
      'manual override amount (income != hours*price) imported as-is',
      () async {
        final db = await _openDb();
        final parsed = _parsedRich(
          records: [
            _record(
              uuid: 'timing:14',
              fingerprint: 'fp-override',
              hoursMilli: 3000,
              incomeFen: 33334, // 不等于任何 AmountPolicy(3000, price)
            ),
          ],
          exportLines: const [],
        );

        final result = await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        expect(result.status, ProjectExternalWorkImportStatus.imported);

        final rows = await db.query('external_work_records');
        expect(rows.single['amount_fen'], 33334);
      },
    );

    test(
      'missing required rich record field fails without legacy fallback',
      () async {
        final db = await _openDb();
        const requiredFields = [
          'source_record_uuid',
          'work_date',
          'income_fen',
          'hours_milli',
          'source_device_id',
        ];

        for (final field in requiredFields) {
          final brokenRecord = _record(
            uuid: 'timing:missing-$field',
            fingerprint: 'fp-missing-$field',
            incomeFen: 12345,
          )..remove(field);

          expect(
            () => _parsedRich(
              shareId: 'missing-$field',
              records: [brokenRecord],
              exportLines: [_legacyLine(uuid: 'legacy-$field')],
            ),
            throwsA(
              isA<JztShareParseException>()
                  .having(
                    (error) => error.code,
                    'code',
                    JztShareErrorCodes.invalidPayload,
                  )
                  .having((error) => error.message, 'message', contains(field)),
            ),
          );
        }

        expect(await db.query('external_import_batches'), isEmpty);
        expect(await db.query('external_work_records'), isEmpty);
      },
    );

    test(
      'rich override amount survives readback and local field update',
      () async {
        final db = await _openDb();
        const recordId = 'external:rich-update-share:timing:31';
        final recordRepo = SqfliteExternalWorkRecordRepository();
        final parsed = _parsedRich(
          shareId: 'rich-update-share',
          records: [
            _record(
              uuid: 'timing:31',
              fingerprint: 'fp-rich-update',
              hoursMilli: 3000,
              incomeFen: 33334,
            ),
          ],
          exportLines: const [],
        );

        final result = await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        expect(result.status, ProjectExternalWorkImportStatus.imported);

        final readBack = (await recordRepo.listByBatchId(
          'rich-update-share',
        )).single;
        expect(readBack.id, recordId);
        expect(readBack.amountFen, 33334);
        expect(readBack.amountOverridesPolicy, isFalse);

        await db.insert(
          'projects',
          const Project(
            id: 'project:rich-linked',
            contact: '张三',
            site: '工地A',
            createdAt: '2026-05-19T00:00:00.000Z',
            updatedAt: '2026-05-19T00:00:00.000Z',
          ).toMap(),
        );
        final updated = await recordRepo.updateLocalFields(
          recordId: recordId,
          linkedProjectId: 'project:rich-linked',
          status: ExternalWorkRecordStatus.ignored,
          note: '本机复核',
          updatedAt: '2026-05-19T01:00:00.000Z',
        );

        expect(updated, 1);
        final updatedRecord = (await recordRepo.listByBatchId(
          'rich-update-share',
        )).single;
        expect(updatedRecord.amountFen, 33334);
        // 人工覆写金额：rich path 不写伪造单价；本测试也未通过 updateLocalFields
        // 设置单价，应保持 null。
        expect(updatedRecord.localUnitPriceFen, isNull);
        expect(updatedRecord.linkedProjectId, 'project:rich-linked');
        expect(updatedRecord.status, ExternalWorkRecordStatus.ignored);
        expect(updatedRecord.note, '本机复核');
        expect(updatedRecord.updatedAt, '2026-05-19T01:00:00.000Z');
      },
    );

    test('duplicate: re-importing same rich package is rejected '
        '(export_lines empty but records non-empty)', () async {
      final db = await _openDb();
      final parsed = _parsedRich(
        records: [_record(uuid: 'timing:13', incomeFen: 120000)],
        exportLines: const [],
      );

      final first = await importer.importParsed(
        parsed,
        importedAt: '2026-05-19T00:00:00.000Z',
      );
      expect(first.status, ProjectExternalWorkImportStatus.imported);

      final second = await importer.importParsed(
        parsed,
        importedAt: '2026-05-19T01:00:00.000Z',
      );
      expect(second.status, ProjectExternalWorkImportStatus.rejectedDuplicate);
      expect(second.preview.duplicateSummary.sameShareAlreadyImported, true);
      expect(await db.query('external_work_records'), hasLength(1));
      expect(await db.query('external_import_batches'), hasLength(1));
    });

    test('rolls back when a rich record violates a constraint', () async {
      final db = await _openDb();
      final parsed = _parsedRich(
        records: [
          _record(uuid: 'dup', fingerprint: 'fp-a', incomeFen: 1000),
          _record(uuid: 'dup', fingerprint: 'fp-b', incomeFen: 2000),
        ],
        exportLines: const [],
      );

      await expectLater(
        importer.importParsed(parsed, importedAt: '2026-05-19T00:00:00.000Z'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('external_import_batches'), isEmpty);
      expect(await db.query('external_work_records'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
    });

    test(
      'rich source_unit_price_fen (incl. project override) is preserved end-to-end',
      () async {
        final db = await _openDb();
        // 模拟导出端写入 200元/h 的项目覆盖单价：source_unit_price_fen = 20000。
        // 导入端必须原样保留，绝不反推、绝不替换为 0。
        final parsed = _parsedRich(
          records: [
            _record(
              uuid: 'timing:71',
              fingerprint: 'fp-override',
              hoursMilli: 7000,
              incomeFen: 140000,
              sourceUnitPriceFen: 20000,
            ),
          ],
          exportLines: const [],
        );
        final result = await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        expect(result.status, ProjectExternalWorkImportStatus.imported);

        final rows = await db.query('external_work_records');
        expect(rows, hasLength(1));
        expect(rows.single['source_unit_price_fen'], 20000);
        expect(rows.single['local_unit_price_fen'], 20000);
        expect(rows.single['amount_fen'], 140000);
        expect(rows.single['record_kind'], 'hours');
      },
    );

    test(
      'rich project_received_fen is persisted to imported records',
      () async {
        final db = await _openDb();
        final parsed = _parsedRich(
          projectReceivedFen: 45678,
          records: [
            _record(
              uuid: 'timing:72',
              fingerprint: 'fp-project-received',
              incomeFen: 120000,
            ),
          ],
          exportLines: const [],
        );

        final result = await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        expect(result.status, ProjectExternalWorkImportStatus.imported);

        final rows = await db.query('external_work_records');
        expect(rows, hasLength(1));
        expect(rows.single['project_received_fen'], 45678);
      },
    );

    test('rich record without source_unit_price_fen lands as NULL '
        '(import side does not derive from income÷hours)', () async {
      final db = await _openDb();
      // 人工覆写金额：income 不等于任何 hours×price 的整数解。导出端会写 null。
      // 导入端必须落 NULL，绝不反推 (33334/3=11111.33→11111) 后伪造写入。
      final parsed = _parsedRich(
        records: [
          _record(
            uuid: 'timing:73',
            fingerprint: 'fp-manual',
            hoursMilli: 3000,
            incomeFen: 33334,
            sourceUnitPriceFen: null,
          ),
        ],
        exportLines: const [],
      );
      final result = await importer.importParsed(
        parsed,
        importedAt: '2026-05-19T00:00:00.000Z',
      );
      expect(result.status, ProjectExternalWorkImportStatus.imported);

      final rows = await db.query('external_work_records');
      expect(rows, hasLength(1));
      expect(rows.single['source_unit_price_fen'], isNull);
      expect(rows.single['local_unit_price_fen'], isNull);
      expect(rows.single['amount_fen'], 33334);
      expect(rows.single['record_kind'], 'hours');
      // 双重防御：即便有人手动用 income÷hours 算了 11111，也必须不在 DB 里。
      expect(rows.single['source_unit_price_fen'], isNot(11111));
    });

    test(
      'rent rich record lands as record_kind=rent with NULL unit price',
      () async {
        final db = await _openDb();
        final parsed = _parsedRich(
          records: [
            _record(
              uuid: 'timing:81',
              fingerprint: 'fp-rent',
              type: 'rent',
              hoursMilli: 1000,
              incomeFen: 120000,
              startMeter: null,
              endMeter: null,
              sourceUnitPriceFen: null,
            ),
          ],
          exportLines: const [],
        );
        final result = await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        expect(result.status, ProjectExternalWorkImportStatus.imported);

        final rows = await db.query('external_work_records');
        expect(rows.single['record_kind'], 'rent');
        expect(rows.single['source_unit_price_fen'], isNull);
        expect(rows.single['local_unit_price_fen'], isNull);
      },
    );

    test(
      'legacy payload (no source_unit_price_fen key) still imports under hours kind',
      () async {
        final db = await _openDb();
        // 加法式兼容：老 payload 完全没有 source_unit_price_fen 字段。
        final parsed = _parsedRich(
          records: [
            _record(
              uuid: 'timing:91',
              fingerprint: 'fp-legacy',
              hoursMilli: 8000,
              incomeFen: 80000,
              // sourceUnitPriceFen 未提供（_missing）= key 不存在
            ),
          ],
          exportLines: const [],
        );
        await importer.importParsed(
          parsed,
          importedAt: '2026-05-19T00:00:00.000Z',
        );
        final rows = await db.query('external_work_records');
        expect(rows.single['record_kind'], 'hours');
        expect(rows.single['source_unit_price_fen'], isNull);
      },
    );
  });
}

ParsedProjectExternalWorkShare _parsedRich({
  String shareId = 'rich-share-1',
  int projectReceivedFen = 0,
  required List<Map<String, Object?>>? records,
  required List<Map<String, Object?>> exportLines,
  Map<String, Object?>? summary,
}) {
  final payload = <String, Object?>{
    'share_id': shareId,
    'sender_name': '李工',
    'source_installation_uuid': 'install-uuid',
    'export_lines': exportLines,
    if (records != null) ...{
      'protocol_version': 1,
      'fingerprint_version': 1,
      'summary':
          summary ??
          {
            'device_count': 1,
            'record_count': records.length,
            'total_income_fen': 0,
            'total_hours_milli': 0,
          },
      'project_snapshot': {
        'source_project_id': 'p-1',
        'source_project_key': '张三|工地A',
        'contact_snapshot': '张三',
        'site_snapshot': '工地A',
        'project_received_fen': projectReceivedFen,
      },
      'devices': [
        {
          'source_device_id': 1,
          'name': 'HITACHI 1#',
          'brand': 'HITACHI',
          'model': 'ZX200',
          'type': 'excavator',
          'display_name': 'HITACHI 1#',
          'record_count': records.length,
          'total_hours_milli': 0,
          'total_income_fen': 0,
        },
      ],
      'records': records,
      'device_groups': const [],
    },
  };
  final envelope = <String, Object?>{
    'magic': JztShareEnvelope.magicValue,
    'format_version': JztShareEnvelope.supportedFormatVersion,
    'package_type': JztShareEnvelope.projectExternalWorkShareType,
    'producer': {
      'app_name': 'FleetLedger',
      'app_version': '1.0.1',
      'platform': 'ios',
    },
    'created_at': '2026-05-19T00:00:00.000Z',
    'share_id': shareId,
    'integrity': {
      'payload_encoding': JztShareEnvelope.jsonPayloadEncoding,
      'payload_sha256': JztShareEnvelopeValidator.payloadSha256(payload),
    },
    'payload': payload,
  };
  return const JztShareEnvelopeParser().parseProjectExternalWorkShare(
    jsonEncode(envelope),
  );
}

Map<String, Object?> _record({
  required String uuid,
  String fingerprint = 'fp-1',
  String type = 'hours',
  int hoursMilli = 8000,
  required int incomeFen,
  Object? sourceUnitPriceFen = _missing,
  double? startMeter = 100.0,
  double? endMeter = 108.0,
}) {
  return {
    'source_record_uuid': uuid,
    'source_timing_record_id': int.tryParse(uuid.split(':').last) ?? 1,
    'source_project_id': 'p-1',
    'source_device_id': 1,
    'work_date': 20240101,
    'type': type,
    'start_meter': startMeter,
    'end_meter': endMeter,
    'hours_milli': hoursMilli,
    'income_fen': incomeFen,
    'is_breaking': false,
    'origin_fingerprint': fingerprint,
    if (!identical(sourceUnitPriceFen, _missing))
      'source_unit_price_fen': sourceUnitPriceFen,
  };
}

const _missing = Object();

Map<String, Object?> _legacyLine({required String uuid}) {
  return {
    'export_line_uuid': uuid,
    'origin_fingerprint': 'fp-legacy-$uuid',
    'contact_snapshot': '张三',
    'site_snapshot': '工地A',
    'equipment_brand': 'HITACHI',
    'equipment_model': 'ZX200',
    'equipment_type': 'excavator',
    'work_date': 20240101,
    'hours_milli': 8000,
    'source_unit_price_fen': 10000,
    'amount_fen': 80000,
  };
}

Future<Database> _openDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await DbSchema.create(db);
      },
    );
  };
  return AppDatabase.database;
}
