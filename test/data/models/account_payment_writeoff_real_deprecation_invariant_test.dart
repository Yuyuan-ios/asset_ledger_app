import 'dart:io';

import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B4 审计收尾：account_payments / project_write_offs 读路径仍 fen 权威，
/// REAL amount 仅为兼容列保留（不移除、不改 NOT NULL）。生产聚合不直接读 amount REAL。
void main() {
  group('AccountPayment / ProjectWriteOff fen-authority', () {
    test('AccountPayment.fromMap prefers amount_fen over REAL amount', () {
      final payment = AccountPayment.fromMap({
        'id': 1,
        'project_id': 'p1',
        'project_key': 'Alpha||Site',
        'ymd': 20260601,
        // REAL 与 fen 故意不一致：必须以 amount_fen 为准。
        'amount': 1.0,
        'amount_fen': 99999,
        'source_type': 'manual',
      });
      expect(payment.amount, 999.99);
      expect(payment.amountFen, 99999);
    });

    test('AccountPayment.fromMap falls back to REAL amount when fen absent', () {
      final payment = AccountPayment.fromMap({
        'id': 1,
        'project_id': 'p1',
        'project_key': 'Alpha||Site',
        'ymd': 20260601,
        'amount': 12.34,
        'source_type': 'manual',
      });
      expect(payment.amount, 12.34);
    });

    test('ProjectWriteOff.fromMap prefers amount_fen over REAL amount', () {
      final writeOff = ProjectWriteOff.fromMap({
        'id': 'w1',
        'project_id': 'p1',
        'amount': 1.0,
        'amount_fen': 6050,
        'reason': 'rounding',
        'write_off_date': '2026-06-01',
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });
      expect(writeOff.amount, 60.50);
      expect(writeOff.amountFen, 6050);
    });
  });

  group('production aggregates use SUM(amount_fen), not REAL amount', () {
    const fenAggregateFiles = [
      'lib/data/repositories/project_write_off_repository.dart',
      'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      'lib/infrastructure/local/account/project_settlement_impact_service.dart',
    ];

    test('aggregate sites sum amount_fen and never SUM(amount) REAL', () {
      final realSum = RegExp(r'SUM\(\s*amount\s*\)', caseSensitive: false);
      for (final path in fenAggregateFiles) {
        final source = _read(path);
        expect(
          source.contains('SUM(amount_fen)'),
          isTrue,
          reason: '$path 应以 SUM(amount_fen) 为权威汇总',
        );
        expect(
          realSum.hasMatch(source),
          isFalse,
          reason: '$path 不应出现 SUM(amount) REAL 汇总',
        );
      }
    });
  });

  group('REAL compatibility columns retained (not removed, not NOT NULL)', () {
    test('account_payments keeps amount REAL NOT NULL and nullable amount_fen', () {
      final schema = _read('lib/data/db/schema/account_schema.dart');
      expect(schema.contains('amount REAL NOT NULL'), isTrue);
      expect(schema.contains('amount_fen INTEGER'), isTrue);
      // B0.5 no-NULL invariant 未被放宽：amount_fen 仍是 nullable INTEGER（无 NOT NULL）。
      expect(schema.contains('amount_fen INTEGER NOT NULL'), isFalse);
    });

    test('project_write_offs keeps amount REAL and nullable amount_fen', () {
      final schema = _read('lib/data/db/schema/account_schema.dart');
      expect(schema.contains('amount REAL NOT NULL CHECK (amount > 0)'), isTrue);
      expect(schema.contains('amount_fen INTEGER NOT NULL'), isFalse);
    });

    test('timing_records keeps income REAL NOT NULL and nullable income_fen', () {
      final schema = _read('lib/data/db/schema/timing_schema.dart');
      expect(schema.contains('income REAL NOT NULL'), isTrue);
      expect(schema.contains('income_fen INTEGER'), isTrue);
      expect(schema.contains('income_fen INTEGER NOT NULL'), isFalse);
    });
  });
}

String _read(String relativePath) => File(relativePath).readAsStringSync();
