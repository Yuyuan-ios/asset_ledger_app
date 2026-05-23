import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_preview.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_result.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/external_work_import_preview_session.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ExternalWorkImportPreviewViewModel', () {
    test('builds preview state from a valid share package', () async {
      await _openCurrentInMemoryDb();
      final viewModel = _viewModel();

      await viewModel.prepare(
        _encodedEnvelope(
          lines: [
            _line(siteSnapshot: '一号工地', hoursMilli: 1000),
            _line(
              exportLineUuid: 'line-2',
              originFingerprint: 'fingerprint-2',
              siteSnapshot: '二号工地',
              hoursMilli: 500,
              unitPriceFen: 40000,
            ),
          ],
        ),
      );

      expect(viewModel.status, ExternalWorkImportPreviewStatus.ready);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.preview?.senderName, '王师傅');
      expect(viewModel.preview?.recordCount, 2);
      expect(viewModel.preview?.totalHoursMilli, 1500);
      expect(viewModel.preview?.siteSummary, '一号工地、二号工地');
      expect(viewModel.canConfirm, isTrue);
    });

    test('shows hash mismatch errors without crashing', () async {
      await _openCurrentInMemoryDb();
      final viewModel = _viewModel();

      await viewModel.prepare(
        _encodedEnvelope(
          integrityMutator: (integrity) {
            integrity['payload_sha256'] =
                '0000000000000000000000000000000000000000000000000000000000000000';
          },
        ),
      );

      expect(viewModel.status, ExternalWorkImportPreviewStatus.error);
      expect(viewModel.errorMessage, contains('校验失败'));
      expect(viewModel.preview, isNull);
    });

    test('shows unsupported version errors without crashing', () async {
      await _openCurrentInMemoryDb();
      final viewModel = _viewModel();

      await viewModel.prepare(
        _encodedEnvelope(
          envelopeMutator: (envelope) {
            envelope['format_version'] = 99;
          },
        ),
      );

      expect(viewModel.status, ExternalWorkImportPreviewStatus.error);
      expect(viewModel.errorMessage, contains('版本暂不支持'));
      expect(viewModel.preview, isNull);
    });

    test('duplicate share_id becomes blocking preview state', () async {
      await _openCurrentInMemoryDb();
      final first = _viewModel();
      await first.prepare(_encodedEnvelope());
      await first.confirmImport();

      final second = _viewModel();
      await second.prepare(_encodedEnvelope());

      expect(second.status, ExternalWorkImportPreviewStatus.ready);
      expect(second.hasBlockingDuplicates, isTrue);
      expect(second.canConfirm, isFalse);
      expect(
        second.preview?.lines.single.duplicateStatus,
        ExternalWorkDuplicateStatus.sameShareAlreadyImported,
      );
    });

    test(
      'confirm import writes external records and keeps core tables empty',
      () async {
        final db = await _openCurrentInMemoryDb();
        final viewModel = _viewModel();

        await viewModel.prepare(_encodedEnvelope());
        await viewModel.confirmImport();

        expect(viewModel.status, ExternalWorkImportPreviewStatus.success);
        expect(viewModel.successMessage, contains('项目外协记录'));
        expect(await db.query('external_work_records'), hasLength(1));
        expect(await db.query('timing_records'), isEmpty);
        expect(await db.query('account_payments'), isEmpty);
        expect(await db.query('projects'), isEmpty);
      },
    );

    test('confirm import failure becomes error state', () async {
      await _openCurrentInMemoryDb();
      final session = await const PrepareExternalWorkImportPreviewUseCase()
          .execute(_encodedEnvelope());
      final viewModel = ExternalWorkImportPreviewViewModel(
        preparePreview: _StaticPreparer(session),
        confirmImport: const _FailingConfirmer(),
      );

      await viewModel.prepare(_encodedEnvelope());
      await viewModel.confirmImport();

      expect(viewModel.status, ExternalWorkImportPreviewStatus.error);
      expect(viewModel.errorMessage, '导入事务失败');
    });
  });
}

ExternalWorkImportPreviewViewModel _viewModel() {
  return ExternalWorkImportPreviewViewModel(
    preparePreview: const PrepareExternalWorkImportPreviewUseCase(),
    confirmImport: const ConfirmExternalWorkImportUseCase(),
  );
}

class _StaticPreparer implements ExternalWorkImportPreviewPreparer {
  const _StaticPreparer(this.session);

  final ExternalWorkImportPreviewSession session;

  @override
  Future<ExternalWorkImportPreviewSession> execute(String content) async {
    return session;
  }
}

class _FailingConfirmer implements ExternalWorkImportConfirmer {
  const _FailingConfirmer();

  @override
  Future<ProjectExternalWorkImportResult> execute(
    ExternalWorkImportPreviewSession session,
  ) async {
    throw const ExternalWorkImportPreviewFailure(
      'transaction_failed',
      '导入事务失败',
    );
  }
}

String _encodedEnvelope({
  List<Map<String, Object?>>? lines,
  void Function(Map<String, Object?> envelope)? envelopeMutator,
  void Function(Map<String, Object?> integrity)? integrityMutator,
  bool updateHash = true,
}) {
  final payload = <String, Object?>{
    'share_id': 'share-1',
    'sender_name': '王师傅',
    'source_installation_uuid': 'install-1',
    'export_lines': lines ?? [_line()],
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

Map<String, Object?> _line({
  String exportLineUuid = 'line-1',
  String originFingerprint = 'fingerprint-1',
  String siteSnapshot = '一号工地',
  int hoursMilli = 1500,
  int unitPriceFen = 38000,
}) {
  return {
    'export_line_uuid': exportLineUuid,
    'origin_fingerprint': originFingerprint,
    'contact_snapshot': '甲方',
    'site_snapshot': siteSnapshot,
    'equipment_brand': '三一',
    'equipment_model': '75',
    'equipment_type': 'excavator',
    'work_date': 20260518,
    'hours_milli': hoursMilli,
    'source_unit_price_fen': unitPriceFen,
    'amount_fen': ExternalWorkRecord.calculateAmountFen(
      hoursMilli: hoursMilli,
      unitPriceFen: unitPriceFen,
    ),
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
