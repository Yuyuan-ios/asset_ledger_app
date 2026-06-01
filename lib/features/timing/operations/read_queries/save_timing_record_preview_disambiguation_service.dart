import 'timing_operation_read_query_service.dart';

class SaveTimingRecordDisambiguationRequest {
  const SaveTimingRecordDisambiguationRequest({
    required this.context,
    this.deviceKeyword,
    this.timingRecordId,
    this.recordDate,
    this.from,
    this.to,
    this.deviceId,
    this.limit = 5,
  }) : assert(limit > 0);

  final TimingOperationReadQueryContext context;
  final String? deviceKeyword;
  final String? timingRecordId;
  final DateTime? recordDate;
  final DateTime? from;
  final DateTime? to;
  final int? deviceId;
  final int limit;

  bool get hasDeviceHint =>
      _hasText(deviceKeyword) || _normalizedDeviceId != null;

  bool get hasTimingHint =>
      _hasText(timingRecordId) ||
      recordDate != null ||
      from != null ||
      to != null ||
      _normalizedDeviceId != null;

  String? get _normalizedDeviceId {
    final id = deviceId;
    if (id == null || id <= 0) return null;
    return id.toString();
  }
}

enum SaveTimingRecordDisambiguationStatus {
  resolved,
  ambiguous,
  notFound,
  forbidden,
  insufficientInput;

  String get wireName {
    switch (this) {
      case SaveTimingRecordDisambiguationStatus.resolved:
        return 'resolved';
      case SaveTimingRecordDisambiguationStatus.ambiguous:
        return 'ambiguous';
      case SaveTimingRecordDisambiguationStatus.notFound:
        return 'not_found';
      case SaveTimingRecordDisambiguationStatus.forbidden:
        return 'forbidden';
      case SaveTimingRecordDisambiguationStatus.insufficientInput:
        return 'insufficient_input';
    }
  }

  static SaveTimingRecordDisambiguationStatus fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown SaveTimingRecordDisambiguationStatus',
      );
    }
    return parsed;
  }

  static SaveTimingRecordDisambiguationStatus? tryParse(String? wireName) {
    for (final value in SaveTimingRecordDisambiguationStatus.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

enum SaveTimingRecordDisambiguationCandidateType {
  device,
  timingRecord;

  String get wireName {
    switch (this) {
      case SaveTimingRecordDisambiguationCandidateType.device:
        return 'device';
      case SaveTimingRecordDisambiguationCandidateType.timingRecord:
        return 'timing_record';
    }
  }

  static SaveTimingRecordDisambiguationCandidateType fromWireName(
    String wireName,
  ) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown SaveTimingRecordDisambiguationCandidateType',
      );
    }
    return parsed;
  }

  static SaveTimingRecordDisambiguationCandidateType? tryParse(
    String? wireName,
  ) {
    for (final value in SaveTimingRecordDisambiguationCandidateType.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

class SaveTimingRecordDisambiguationCandidate {
  const SaveTimingRecordDisambiguationCandidate({
    required this.type,
    required this.id,
    required this.displayLabel,
    this.confidence,
    required this.redacted,
    this.reason,
  });

  final SaveTimingRecordDisambiguationCandidateType type;
  final String id;
  final String displayLabel;
  final double? confidence;
  final bool redacted;
  final String? reason;

  Map<String, Object?> toMap() {
    return {
      'type': type.wireName,
      'id': id,
      'display_label': displayLabel,
      'confidence': confidence,
      'redacted': redacted,
      'reason': reason,
    };
  }
}

class SaveTimingRecordDisambiguationResult {
  SaveTimingRecordDisambiguationResult({
    required this.status,
    Iterable<SaveTimingRecordDisambiguationCandidate> candidates = const [],
    Iterable<String> warnings = const [],
    required this.redacted,
    required this.scopeLimited,
  }) : candidates = List.unmodifiable(candidates),
       warnings = List.unmodifiable(warnings);

  final SaveTimingRecordDisambiguationStatus status;
  final List<SaveTimingRecordDisambiguationCandidate> candidates;
  final List<String> warnings;
  final bool redacted;
  final bool scopeLimited;

  bool get isResolved =>
      status == SaveTimingRecordDisambiguationStatus.resolved;

  SaveTimingRecordDisambiguationCandidate? get singleCandidate {
    return isResolved && candidates.length == 1 ? candidates.single : null;
  }

  Map<String, Object?> toMap() {
    return {
      'status': status.wireName,
      'candidates': candidates.map((item) => item.toMap()).toList(),
      'warnings': List<String>.from(warnings),
      'redacted': redacted,
      'scope_limited': scopeLimited,
    };
  }
}

class SaveTimingRecordPreviewDisambiguationService {
  const SaveTimingRecordPreviewDisambiguationService({
    required TimingOperationReadQueryService readQueryService,
  }) : _readQueryService = readQueryService;

  final TimingOperationReadQueryService _readQueryService;

  Future<SaveTimingRecordDisambiguationResult> disambiguate(
    SaveTimingRecordDisambiguationRequest request,
  ) async {
    if (_isForbiddenContext(request.context)) {
      return SaveTimingRecordDisambiguationResult(
        status: SaveTimingRecordDisambiguationStatus.forbidden,
        redacted: true,
        scopeLimited: true,
      );
    }

    if (!_hasAnyHint(request)) {
      return SaveTimingRecordDisambiguationResult(
        status: SaveTimingRecordDisambiguationStatus.insufficientInput,
        redacted: false,
        scopeLimited: false,
      );
    }

    if (_hasText(request.timingRecordId)) {
      return _disambiguateTimingRecords(
        request,
        recordId: request.timingRecordId,
        confidence: 1.0,
        reason: '匹配计时记录 ID',
      );
    }

    final hasDateHint =
        request.recordDate != null ||
        request.from != null ||
        request.to != null;
    if (request.hasDeviceHint && hasDateHint) {
      final deviceResult = await _queryDevices(request);
      final deviceDisambiguation = _deviceResult(request, deviceResult);
      if (!deviceDisambiguation.isResolved) return deviceDisambiguation;

      return _disambiguateTimingRecords(
        request,
        deviceId: deviceDisambiguation.singleCandidate!.id,
        confidence: 0.8,
        reason: '匹配设备和日期范围',
      );
    }

    if (hasDateHint || request.deviceId != null) {
      return _disambiguateTimingRecords(
        request,
        deviceId: request.deviceId?.toString(),
        confidence: 0.8,
        reason: hasDateHint ? '匹配日期范围' : '匹配设备',
      );
    }

    if (request.hasDeviceHint) {
      final deviceResult = await _queryDevices(request);
      return _deviceResult(request, deviceResult);
    }

    return SaveTimingRecordDisambiguationResult(
      status: SaveTimingRecordDisambiguationStatus.insufficientInput,
      redacted: false,
      scopeLimited: false,
    );
  }

  Future<TimingOperationQueryResult<DeviceQueryItem>> _queryDevices(
    SaveTimingRecordDisambiguationRequest request,
  ) {
    return _readQueryService.queryDevices(
      context: request.context,
      input: DeviceQueryInput(
        keyword: request.deviceKeyword,
        deviceId: request.deviceId?.toString(),
        activeOnly: true,
        limit: request.limit,
      ),
    );
  }

  Future<SaveTimingRecordDisambiguationResult> _disambiguateTimingRecords(
    SaveTimingRecordDisambiguationRequest request, {
    String? recordId,
    String? deviceId,
    required double confidence,
    required String reason,
  }) async {
    final (from, to) = _dateRange(request);
    final queryResult = await _readQueryService.queryTimingRecords(
      context: request.context,
      input: TimingRecordQueryInput(
        recordId: recordId,
        deviceId: deviceId,
        from: from,
        to: to,
        limit: request.limit,
      ),
    );
    return _timingResult(queryResult, confidence: confidence, reason: reason);
  }

  SaveTimingRecordDisambiguationResult _deviceResult(
    SaveTimingRecordDisambiguationRequest request,
    TimingOperationQueryResult<DeviceQueryItem> queryResult,
  ) {
    if (_isForbiddenQueryResult(request.context, queryResult)) {
      return _forbidden(queryResult);
    }
    final candidates = [
      for (final item in queryResult.items)
        SaveTimingRecordDisambiguationCandidate(
          type: SaveTimingRecordDisambiguationCandidateType.device,
          id: item.id,
          displayLabel: item.displayName,
          confidence: _hasText(request.deviceKeyword) ? 0.9 : 1.0,
          redacted: item.redacted,
          reason: _hasText(request.deviceKeyword) ? '匹配设备关键词' : '匹配设备 ID',
        ),
    ];
    return _resultFromCandidates(
      candidates: candidates,
      warnings: queryResult.warnings,
      redacted: queryResult.redacted,
      scopeLimited: queryResult.scopeLimited,
    );
  }

  SaveTimingRecordDisambiguationResult _timingResult(
    TimingOperationQueryResult<TimingRecordQueryItem> queryResult, {
    required double confidence,
    required String reason,
  }) {
    if (_isForbiddenQueryResult(null, queryResult)) {
      return _forbidden(queryResult);
    }
    final candidates = [
      for (final item in queryResult.items)
        SaveTimingRecordDisambiguationCandidate(
          type: SaveTimingRecordDisambiguationCandidateType.timingRecord,
          id: item.id,
          displayLabel: _timingLabel(item),
          confidence: confidence,
          redacted: item.redacted,
          reason: reason,
        ),
    ];
    return _resultFromCandidates(
      candidates: candidates,
      warnings: queryResult.warnings,
      redacted: queryResult.redacted,
      scopeLimited: queryResult.scopeLimited,
    );
  }

  SaveTimingRecordDisambiguationResult _resultFromCandidates({
    required List<SaveTimingRecordDisambiguationCandidate> candidates,
    required List<String> warnings,
    required bool redacted,
    required bool scopeLimited,
  }) {
    final status = switch (candidates.length) {
      0 => SaveTimingRecordDisambiguationStatus.notFound,
      1 => SaveTimingRecordDisambiguationStatus.resolved,
      _ => SaveTimingRecordDisambiguationStatus.ambiguous,
    };
    return SaveTimingRecordDisambiguationResult(
      status: status,
      candidates: candidates,
      warnings: warnings,
      redacted: redacted,
      scopeLimited: scopeLimited,
    );
  }

  SaveTimingRecordDisambiguationResult _forbidden(
    TimingOperationQueryResult<Object?> queryResult,
  ) {
    return SaveTimingRecordDisambiguationResult(
      status: SaveTimingRecordDisambiguationStatus.forbidden,
      warnings: queryResult.warnings,
      redacted: queryResult.redacted,
      scopeLimited: true,
    );
  }

  bool _isForbiddenQueryResult(
    TimingOperationReadQueryContext? context,
    TimingOperationQueryResult<Object?> queryResult,
  ) {
    if (queryResult.warnings.any(_isForbiddenWarning)) return true;
    final actor = context?.actor;
    if (actor == null) return false;
    if (actor.isUnknown || actor.isSystem) return true;
    if (actor.isAgent && !actor.hasDelegatedScope) return true;
    return false;
  }

  bool _isForbiddenContext(TimingOperationReadQueryContext context) {
    final actor = context.actor;
    if (actor.isUnknown || actor.isSystem) return true;
    if (actor.isAgent && !actor.hasDelegatedScope) return true;
    return false;
  }
}

(DateTime?, DateTime?) _dateRange(
  SaveTimingRecordDisambiguationRequest request,
) {
  final date = request.recordDate;
  if (date != null) return (date, date);
  return (request.from, request.to);
}

String _timingLabel(TimingRecordQueryItem item) {
  final parts = <String>[
    item.workDate,
    item.deviceName?.trim().isNotEmpty == true
        ? item.deviceName!.trim()
        : '设备 ${item.deviceId}',
    '${_trimTrailingZeros(item.hours)} 小时',
  ];
  return parts.join(' · ');
}

String _trimTrailingZeros(double value) {
  final text = value.toStringAsFixed(2);
  return text
      .replaceFirst(RegExp(r'\.00$'), '')
      .replaceFirst(RegExp(r'0$'), '');
}

bool _hasAnyHint(SaveTimingRecordDisambiguationRequest request) {
  return _hasText(request.deviceKeyword) ||
      _hasText(request.timingRecordId) ||
      request.recordDate != null ||
      request.from != null ||
      request.to != null ||
      request.deviceId != null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

bool _isForbiddenWarning(String warning) {
  final normalized = warning.toLowerCase();
  return normalized.contains('scope expired') ||
      normalized.contains('forbidden') ||
      normalized.contains('denied');
}
