import 'dart:convert';

import 'package:asset_ledger/data/share/jztshare/project_external_work_import_preview.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_result.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/external_work_import_preview_session.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/view/external_work_import_preview_page.dart';
import 'package:asset_ledger/features/external_work/import_preview/view_model/external_work_import_preview_copy.dart';
import 'package:asset_ledger/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalWorkImportPreviewPage', () {
    testWidgets('shows preview summary and line details', (tester) async {
      final preparer = _FakePreparer(_session());
      final confirmer = _FakeConfirmer();
      await tester.pumpWidget(
        _app(_page(preparer, confirmer, initialContent: _encodedEnvelope())),
      );

      await tester.pump();

      expect(find.text('外协项目记录'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('生成预览'), findsNothing);
      expect(find.text('王师傅'), findsOneWidget);
      expect(find.text('2 条'), findsOneWidget);
      expect(find.text('一号工地、二号工地'), findsOneWidget);
      expect(find.text('1.5小时'), findsOneWidget);
      expect(find.text('¥500.00'), findsOneWidget);
      expect(find.text('可导入'), findsNWidgets(2));
      expect(preparer.callCount, 1);
    });

    testWidgets('shows parser error without crashing', (tester) async {
      final preparer = _FakePreparer(
        _session(),
        failure: const ExternalWorkImportPreviewFailure(
          'payload_hash_mismatch',
        ),
      );
      await tester.pumpWidget(
        _app(
          _page(preparer, _FakeConfirmer(), initialContent: _encodedEnvelope()),
        ),
      );

      await tester.pump();

      expect(find.textContaining('校验失败'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);
    });

    testWidgets('confirm import calls confirmer and shows success', (
      tester,
    ) async {
      final preparer = _FakePreparer(_session());
      final confirmer = _FakeConfirmer();
      await tester.pumpWidget(
        _app(_page(preparer, confirmer, initialContent: _encodedEnvelope())),
      );

      await tester.pump();
      final confirmButton = find.byKey(
        const Key('external-work-import-preview-confirm'),
      );
      await tester.tap(confirmButton.last);
      await tester.pump();

      expect(confirmer.callCount, 1);
      expect(find.textContaining('可在外协项目记录中查看'), findsOneWidget);
    });

    testWidgets('keeps action buttons outside the scrolling preview content', (
      tester,
    ) async {
      final preparer = _FakePreparer(_session());
      await tester.pumpWidget(
        _app(
          _page(preparer, _FakeConfirmer(), initialContent: _encodedEnvelope()),
        ),
      );

      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(
            const Key('external-work-import-preview-cancel'),
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(
            const Key('external-work-import-preview-confirm'),
          ),
        ),
        findsNothing,
      );
    });
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

ExternalWorkImportPreviewPage _page(
  ExternalWorkImportPreviewPreparer preparer,
  ExternalWorkImportConfirmer confirmer, {
  String? initialContent,
}) {
  return ExternalWorkImportPreviewPage(
    initialContent: initialContent,
    viewModel: ExternalWorkImportPreviewViewModel(
      preparePreview: preparer,
      confirmImport: confirmer,
      copy: ExternalWorkImportPreviewCopy(l10n: AppLocalizationsZh()),
    ),
  );
}

class _FakePreparer implements ExternalWorkImportPreviewPreparer {
  _FakePreparer(this.session, {this.failure});

  final ExternalWorkImportPreviewSession session;
  final ExternalWorkImportPreviewFailure? failure;
  int callCount = 0;

  @override
  Future<ExternalWorkImportPreviewSession> execute(String content) async {
    callCount++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return session;
  }
}

class _FakeConfirmer implements ExternalWorkImportConfirmer {
  int callCount = 0;

  @override
  Future<ProjectExternalWorkImportResult> execute(
    ExternalWorkImportPreviewSession session,
  ) async {
    callCount++;
    return ProjectExternalWorkImportResult.imported(preview: session.preview);
  }
}

ExternalWorkImportPreviewSession _session() {
  return ExternalWorkImportPreviewSession(
    parsed: const JztShareEnvelopeParser().parseProjectExternalWorkShare(
      _encodedEnvelope(),
    ),
    preview: ExternalWorkImportPreview(
      shareId: 'share-1',
      senderName: '王师傅',
      sourceInstallationUuid: 'install-1',
      recordCount: 2,
      totalHoursMilli: 1500,
      totalAmountFen: 50000,
      siteSummary: '一号工地、二号工地',
      duplicateSummary: const ExternalWorkDuplicateSummary(
        sameShareAlreadyImported: false,
        sameSourceRecordCount: 0,
        sameOriginFingerprintCount: 0,
      ),
      lines: [
        _previewLine(
          exportLineUuid: 'line-1',
          originFingerprint: 'fingerprint-1',
          siteSnapshot: '一号工地',
          hoursMilli: 1000,
          amountFen: 30000,
        ),
        _previewLine(
          exportLineUuid: 'line-2',
          originFingerprint: 'fingerprint-2',
          siteSnapshot: '二号工地',
          hoursMilli: 500,
          amountFen: 20000,
        ),
      ],
    ),
  );
}

ExternalWorkImportPreviewLine _previewLine({
  required String exportLineUuid,
  required String originFingerprint,
  required String siteSnapshot,
  required int hoursMilli,
  required int amountFen,
}) {
  return ExternalWorkImportPreviewLine(
    exportLineUuid: exportLineUuid,
    originFingerprint: originFingerprint,
    contactSnapshot: '甲方',
    siteSnapshot: siteSnapshot,
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: 30000,
    localUnitPriceFen: 30000,
    amountFen: amountFen,
    duplicateStatus: ExternalWorkDuplicateStatus.none,
    note: '现场记录',
  );
}

String _encodedEnvelope() {
  final payload = <String, Object?>{
    'share_id': 'share-1',
    'sender_name': '王师傅',
    'source_installation_uuid': 'install-1',
    'export_lines': [
      {
        'export_line_uuid': 'line-1',
        'origin_fingerprint': 'fingerprint-1',
        'contact_snapshot': '甲方',
        'site_snapshot': '一号工地',
        'equipment_brand': '三一',
        'equipment_model': '75',
        'equipment_type': 'excavator',
        'work_date': 20260518,
        'hours_milli': 1000,
        'source_unit_price_fen': 30000,
        'amount_fen': 30000,
        'note': '现场记录',
      },
    ],
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
  return jsonEncode(envelope);
}
