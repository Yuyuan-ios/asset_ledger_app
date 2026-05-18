import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_payload.dart';
import 'package:asset_ledger/data/share/jztshare/jztshare_errors.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('JztShareEnvelopeParser', () {
    const parser = JztShareEnvelopeParser();

    test('parses a valid project_external_work_share package', () {
      final result = parser.parseProjectExternalWorkShare(_encodedEnvelope());

      expect(result.envelope.magic, JztShareEnvelope.magicValue);
      expect(
        result.envelope.packageType,
        JztShareEnvelope.projectExternalWorkShareType,
      );
      expect(result.payload.shareId, 'share-1');
      expect(result.payload.senderName, '王师傅');
      expect(result.payload.exportLines, hasLength(1));
      expect(result.payload.exportLines.single.hoursMilli, 1500);
    });

    test('rejects invalid JSON without leaking parser exceptions', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare('not-json'),
        JztShareErrorCodes.invalidJson,
      );
    });

    test('rejects missing or mismatched magic', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope.remove('magic');
            },
          ),
        ),
        JztShareErrorCodes.missingMagic,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope['magic'] = 'OTHER';
            },
          ),
        ),
        JztShareErrorCodes.invalidMagic,
      );
    });

    test('rejects unsupported format_version', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope['format_version'] = 99;
            },
          ),
        ),
        JztShareErrorCodes.unsupportedFormatVersion,
      );
    });

    test('rejects unsupported package_type', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope['package_type'] = 'project_backup_share';
            },
          ),
        ),
        JztShareErrorCodes.unsupportedPackageType,
      );
    });

    test('rejects malformed producer and integrity sections', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope['producer'] = 'bad';
            },
          ),
        ),
        JztShareErrorCodes.invalidProducer,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope.remove('integrity');
            },
          ),
        ),
        JztShareErrorCodes.invalidIntegrity,
      );
    });

    test('rejects unsupported payload encoding', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            integrityMutator: (integrity) {
              integrity['payload_encoding'] = 'base64';
            },
          ),
        ),
        JztShareErrorCodes.unsupportedPayloadEncoding,
      );
    });

    test('rejects missing, malformed, and mismatched payload_sha256', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            integrityMutator: (integrity) {
              integrity.remove('payload_sha256');
            },
          ),
        ),
        JztShareErrorCodes.missingPayloadSha256,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            integrityMutator: (integrity) {
              integrity['payload_sha256'] = 'not-a-hash';
            },
          ),
        ),
        JztShareErrorCodes.invalidPayloadSha256,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            integrityMutator: (integrity) {
              integrity['payload_sha256'] =
                  '0000000000000000000000000000000000000000000000000000000000000000';
            },
          ),
        ),
        JztShareErrorCodes.payloadHashMismatch,
      );
    });

    test('rejects missing payload', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope.remove('payload');
            },
          ),
        ),
        JztShareErrorCodes.missingPayload,
      );
    });

    test('rejects missing, non-array, and oversized export_lines', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            payloadMutator: (payload) {
              payload.remove('export_lines');
            },
          ),
        ),
        JztShareErrorCodes.invalidExportLines,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            payloadMutator: (payload) {
              payload['export_lines'] = 'bad';
            },
          ),
        ),
        JztShareErrorCodes.invalidExportLines,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            payloadMutator: (payload) {
              payload['export_lines'] = List<Object?>.generate(
                ProjectExternalWorkSharePayload.maxExportLines + 1,
                (index) => _line(exportLineUuid: 'line-$index'),
              );
            },
          ),
        ),
        JztShareErrorCodes.exportLinesTooMany,
      );
    });

    test('rejects negative integer money and hour fields', () {
      for (final field in [
        'hours_milli',
        'source_unit_price_fen',
        'amount_fen',
      ]) {
        expectParseCode(
          () => parser.parseProjectExternalWorkShare(
            _encodedEnvelope(
              payloadMutator: (payload) {
                final lines = payload['export_lines']! as List<Object?>;
                final line = Map<String, Object?>.from(
                  lines.single! as Map<String, Object?>,
                );
                line[field] = -1;
                payload['export_lines'] = [line];
              },
            ),
          ),
          JztShareErrorCodes.invalidLine,
          reason: field,
        );
      }
    });

    test('rejects oversized integer money and hour fields', () {
      for (final field in [
        'hours_milli',
        'source_unit_price_fen',
        'amount_fen',
      ]) {
        expectParseCode(
          () => parser.parseProjectExternalWorkShare(
            _encodedEnvelope(
              payloadMutator: (payload) {
                final lines = payload['export_lines']! as List<Object?>;
                final line = Map<String, Object?>.from(
                  lines.single! as Map<String, Object?>,
                );
                line[field] = 1000000000001;
                payload['export_lines'] = [line];
              },
            ),
          ),
          JztShareErrorCodes.invalidLine,
          reason: field,
        );
      }
    });

    test('rejects illegal field types without direct enum lookup crashes', () {
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            payloadMutator: (payload) {
              payload['export_lines'] = ['bad-line'];
            },
          ),
        ),
        JztShareErrorCodes.invalidLine,
      );
      expectParseCode(
        () => parser.parseProjectExternalWorkShare(
          _encodedEnvelope(
            envelopeMutator: (envelope) {
              envelope['package_type'] = 7;
            },
          ),
        ),
        JztShareErrorCodes.missingPackageType,
      );
    });

    test('ignores unknown fields and keeps payload line fields minimal', () {
      final result = parser.parseProjectExternalWorkShare(
        _encodedEnvelope(
          payloadMutator: (payload) {
            payload['unknown_payload_field'] = 'safe';
            final lines = payload['export_lines']! as List<Object?>;
            final line = Map<String, Object?>.from(
              lines.single! as Map<String, Object?>,
            );
            line['unknown_line_field'] = 42;
            payload['export_lines'] = [line];
          },
        ),
      );

      expect(result.payload.exportLines.single.exportLineUuid, 'line-1');
      expect(result.payload.exportLines.single.note, '现场记录');
    });

    test(
      'parser does not write external_work_records or timing_records',
      () async {
        final db = await _openCurrentInMemoryDb();

        parser.parseProjectExternalWorkShare(_encodedEnvelope());

        expect(await db.query('external_work_records'), isEmpty);
        expect(await db.query('timing_records'), isEmpty);
      },
    );

    test('canonical payload hash is stable across object key order', () {
      final left = {
        'b': 1,
        'a': {
          'd': true,
          'c': ['x'],
        },
      };
      final right = {
        'a': {
          'c': ['x'],
          'd': true,
        },
        'b': 1,
      };

      expect(
        JztShareEnvelopeValidator.payloadSha256(left),
        JztShareEnvelopeValidator.payloadSha256(right),
      );
    });

    test('jztshare parser code does not call enum.values.byName', () {
      final dir = Directory('lib/data/share/jztshare');
      final source = dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(source, isNot(contains('enum.values.byName')));
    });
  });
}

void expectParseCode(
  Object? Function() callback,
  String code, {
  String? reason,
}) {
  expect(
    callback,
    throwsA(
      isA<JztShareParseException>().having((error) => error.code, 'code', code),
    ),
    reason: reason,
  );
}

String _encodedEnvelope({
  void Function(Map<String, Object?> payload)? payloadMutator,
  void Function(Map<String, Object?> envelope)? envelopeMutator,
  void Function(Map<String, Object?> integrity)? integrityMutator,
  bool updateHash = true,
}) {
  final payload = _payload();
  payloadMutator?.call(payload);
  final envelope = <String, Object?>{
    'magic': JztShareEnvelope.magicValue,
    'format_version': JztShareEnvelope.supportedFormatVersion,
    'package_type': JztShareEnvelope.projectExternalWorkShareType,
    'producer': {'app_name': '机账通', 'app_version': '1.0.1', 'platform': 'ios'},
    'created_at': '2026-05-18T00:00:00.000Z',
    'share_id': 'share-1',
    'integrity': {
      'payload_encoding': JztShareEnvelope.jsonPayloadEncoding,
      'payload_sha256': JztShareEnvelopeValidator.payloadSha256(payload),
    },
    'payload': payload,
  };
  envelopeMutator?.call(envelope);
  final integrity = envelope['integrity'];
  if (integrity is Map<String, Object?>) {
    if (updateHash && envelope['payload'] is Map<String, Object?>) {
      integrity['payload_sha256'] = JztShareEnvelopeValidator.payloadSha256(
        envelope['payload']! as Map<String, Object?>,
      );
    }
    integrityMutator?.call(integrity);
  }
  return jsonEncode(envelope);
}

Map<String, Object?> _payload() {
  return {
    'share_id': 'share-1',
    'sender_name': '王师傅',
    'source_installation_uuid': 'install-1',
    'export_lines': [_line()],
  };
}

Map<String, Object?> _line({String exportLineUuid = 'line-1'}) {
  return {
    'export_line_uuid': exportLineUuid,
    'origin_fingerprint': 'fingerprint-1',
    'contact_snapshot': '甲方',
    'site_snapshot': '一号工地',
    'equipment_brand': '三一',
    'equipment_model': '75',
    'equipment_type': 'excavator',
    'work_date': 20260518,
    'hours_milli': 1500,
    'source_unit_price_fen': 38000,
    'amount_fen': 57000,
    'note': '现场记录',
  };
}

Future<Database> _openCurrentInMemoryDb() {
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
