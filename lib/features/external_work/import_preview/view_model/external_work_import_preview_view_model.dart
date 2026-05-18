import 'package:flutter/foundation.dart';

import '../../../../data/share/jztshare/project_external_work_import_preview.dart';
import '../use_cases/confirm_external_work_import_use_case.dart';
import '../use_cases/external_work_import_preview_session.dart';
import '../use_cases/prepare_external_work_import_preview_use_case.dart';

enum ExternalWorkImportPreviewStatus {
  idle,
  loadingPreview,
  ready,
  importing,
  success,
  error,
}

class ExternalWorkImportPreviewViewModel extends ChangeNotifier {
  ExternalWorkImportPreviewViewModel({
    required ExternalWorkImportPreviewPreparer preparePreview,
    required ExternalWorkImportConfirmer confirmImport,
  }) : _preparePreview = preparePreview,
       _confirmImport = confirmImport;

  final ExternalWorkImportPreviewPreparer _preparePreview;
  final ExternalWorkImportConfirmer _confirmImport;

  ExternalWorkImportPreviewStatus _status =
      ExternalWorkImportPreviewStatus.idle;
  ExternalWorkImportPreviewSession? _session;
  String? _errorMessage;
  String? _successMessage;

  ExternalWorkImportPreviewStatus get status => _status;
  ExternalWorkImportPreviewSession? get session => _session;
  ExternalWorkImportPreview? get preview => _session?.preview;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isBusy {
    return _status == ExternalWorkImportPreviewStatus.loadingPreview ||
        _status == ExternalWorkImportPreviewStatus.importing;
  }

  bool get canConfirm {
    final preview = _session?.preview;
    return _status == ExternalWorkImportPreviewStatus.ready &&
        preview != null &&
        !preview.duplicateSummary.hasBlockingDuplicates;
  }

  bool get hasBlockingDuplicates {
    return _session?.preview.duplicateSummary.hasBlockingDuplicates ?? false;
  }

  Future<void> prepare(String content) async {
    _setStatus(ExternalWorkImportPreviewStatus.loadingPreview);
    try {
      _session = await _preparePreview.execute(content);
      _errorMessage = null;
      _successMessage = null;
      _status = ExternalWorkImportPreviewStatus.ready;
    } on ExternalWorkImportPreviewFailure catch (error) {
      _session = null;
      _errorMessage = error.message;
      _successMessage = null;
      _status = ExternalWorkImportPreviewStatus.error;
    } catch (_) {
      _session = null;
      _errorMessage = '导入预览生成失败，请稍后重试';
      _successMessage = null;
      _status = ExternalWorkImportPreviewStatus.error;
    }
    notifyListeners();
  }

  Future<void> confirmImport() async {
    final session = _session;
    if (session == null || !canConfirm) return;

    _setStatus(ExternalWorkImportPreviewStatus.importing);
    try {
      final result = await _confirmImport.execute(session);
      _errorMessage = null;
      _successMessage = '已导入 ${result.insertedRecordCount} 条项目外协记录';
      _status = ExternalWorkImportPreviewStatus.success;
    } on ExternalWorkImportPreviewFailure catch (error) {
      _errorMessage = error.message;
      _successMessage = null;
      _status = ExternalWorkImportPreviewStatus.error;
    } catch (_) {
      _errorMessage = '导入失败，请稍后重试';
      _successMessage = null;
      _status = ExternalWorkImportPreviewStatus.error;
    }
    notifyListeners();
  }

  void cancel() {
    _session = null;
    _errorMessage = null;
    _successMessage = null;
    _status = ExternalWorkImportPreviewStatus.idle;
    notifyListeners();
  }

  void _setStatus(ExternalWorkImportPreviewStatus status) {
    _status = status;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}

String externalWorkDuplicateStatusLabel(ExternalWorkDuplicateStatus status) {
  switch (status) {
    case ExternalWorkDuplicateStatus.none:
      return '可导入';
    case ExternalWorkDuplicateStatus.sameShareAlreadyImported:
      return '已导入过';
    case ExternalWorkDuplicateStatus.sameSourceRecordAlreadyImported:
      return '存在相同来源记录';
    case ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported:
      return '存在可疑重复记录';
  }
}
