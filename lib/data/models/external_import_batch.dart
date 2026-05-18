import 'external_work_parse.dart';

enum ExternalImportBatchStatus { active, ignored, archived, voided }

class ExternalImportBatch {
  const ExternalImportBatch({
    required this.id,
    required this.sourceShareId,
    required this.sourceDisplayName,
    required this.recordCount,
    required this.totalHoursMilli,
    required this.totalAmountFen,
    required this.siteSummary,
    required this.importedAt,
    this.status = ExternalImportBatchStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceShareId;
  final String sourceDisplayName;
  final int recordCount;
  final int totalHoursMilli;
  final int totalAmountFen;
  final String siteSummary;
  final String importedAt;
  final ExternalImportBatchStatus status;
  final String createdAt;
  final String updatedAt;

  ExternalImportBatch copyWith({
    String? id,
    String? sourceShareId,
    String? sourceDisplayName,
    int? recordCount,
    int? totalHoursMilli,
    int? totalAmountFen,
    String? siteSummary,
    String? importedAt,
    ExternalImportBatchStatus? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return ExternalImportBatch(
      id: id ?? this.id,
      sourceShareId: sourceShareId ?? this.sourceShareId,
      sourceDisplayName: sourceDisplayName ?? this.sourceDisplayName,
      recordCount: recordCount ?? this.recordCount,
      totalHoursMilli: totalHoursMilli ?? this.totalHoursMilli,
      totalAmountFen: totalAmountFen ?? this.totalAmountFen,
      siteSummary: siteSummary ?? this.siteSummary,
      importedAt: importedAt ?? this.importedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    _validate();
    return {
      'id': id,
      'source_share_id': sourceShareId,
      'source_display_name': sourceDisplayName,
      'record_count': recordCount,
      'total_hours_milli': totalHoursMilli,
      'total_amount_fen': totalAmountFen,
      'site_summary': siteSummary,
      'imported_at': importedAt,
      'status': status.name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ExternalImportBatch fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    return ExternalImportBatch(
      id: reader.requiredString('id'),
      sourceShareId: reader.requiredString('source_share_id'),
      sourceDisplayName: reader.requiredString('source_display_name'),
      recordCount: reader.requiredNonNegativeInt('record_count'),
      totalHoursMilli: reader.requiredNonNegativeInt('total_hours_milli'),
      totalAmountFen: reader.requiredNonNegativeInt('total_amount_fen'),
      siteSummary: reader.optionalString('site_summary') ?? '',
      importedAt: reader.requiredString('imported_at'),
      status: parseExternalStatus<ExternalImportBatchStatus>(
        raw: map['status'],
        values: ExternalImportBatchStatus.values,
        nameOf: (status) => status.name,
        fallback: ExternalImportBatchStatus.active,
      ),
      createdAt: reader.requiredString('created_at'),
      updatedAt: reader.requiredString('updated_at'),
    );
  }

  void _validate() {
    ExternalImportBatch.fromMap(toUncheckedMap());
  }

  Map<String, Object?> toUncheckedMap() {
    return {
      'id': id,
      'source_share_id': sourceShareId,
      'source_display_name': sourceDisplayName,
      'record_count': recordCount,
      'total_hours_milli': totalHoursMilli,
      'total_amount_fen': totalAmountFen,
      'site_summary': siteSummary,
      'imported_at': importedAt,
      'status': status.name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
