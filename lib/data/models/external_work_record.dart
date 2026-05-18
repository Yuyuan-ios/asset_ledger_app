import '../../core/money/amount_policy.dart';
import 'external_work_parse.dart';

enum ExternalWorkRecordStatus { active, ignored, archived, voided }

class ExternalWorkRecord {
  const ExternalWorkRecord({
    required this.id,
    required this.importBatchId,
    required this.sourceShareId,
    required this.sourceRecordUuid,
    required this.sourceInstallationUuid,
    required this.originFingerprint,
    required this.collaboratorName,
    required this.contactSnapshot,
    required this.siteSnapshot,
    this.equipmentBrand,
    this.equipmentModel,
    this.equipmentType,
    required this.workDate,
    required this.hoursMilli,
    required this.sourceUnitPriceFen,
    required this.localUnitPriceFen,
    required this.amountFen,
    this.linkedProjectId,
    this.status = ExternalWorkRecordStatus.active,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExternalWorkRecord.create({
    required String id,
    required String importBatchId,
    required String sourceShareId,
    required String sourceRecordUuid,
    required String sourceInstallationUuid,
    required String originFingerprint,
    required String collaboratorName,
    required String contactSnapshot,
    required String siteSnapshot,
    String? equipmentBrand,
    String? equipmentModel,
    String? equipmentType,
    required int workDate,
    required int hoursMilli,
    required int sourceUnitPriceFen,
    int? localUnitPriceFen,
    String? linkedProjectId,
    ExternalWorkRecordStatus status = ExternalWorkRecordStatus.active,
    String? note,
    required String createdAt,
    required String updatedAt,
  }) {
    final localPriceFen = localUnitPriceFen ?? sourceUnitPriceFen;
    final amountFen = calculateAmountFen(
      hoursMilli: hoursMilli,
      unitPriceFen: localPriceFen,
    );
    return ExternalWorkRecord(
      id: id,
      importBatchId: importBatchId,
      sourceShareId: sourceShareId,
      sourceRecordUuid: sourceRecordUuid,
      sourceInstallationUuid: sourceInstallationUuid,
      originFingerprint: originFingerprint,
      collaboratorName: collaboratorName,
      contactSnapshot: contactSnapshot,
      siteSnapshot: siteSnapshot,
      equipmentBrand: equipmentBrand,
      equipmentModel: equipmentModel,
      equipmentType: equipmentType,
      workDate: workDate,
      hoursMilli: hoursMilli,
      sourceUnitPriceFen: sourceUnitPriceFen,
      localUnitPriceFen: localPriceFen,
      amountFen: amountFen,
      linkedProjectId: linkedProjectId,
      status: status,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )..validate();
  }

  final String id;
  final String importBatchId;
  final String sourceShareId;
  final String sourceRecordUuid;
  final String sourceInstallationUuid;
  final String originFingerprint;
  final String collaboratorName;
  final String contactSnapshot;
  final String siteSnapshot;
  final String? equipmentBrand;
  final String? equipmentModel;
  final String? equipmentType;
  final int workDate;
  final int hoursMilli;
  final int sourceUnitPriceFen;
  final int localUnitPriceFen;
  final int amountFen;
  final String? linkedProjectId;
  final ExternalWorkRecordStatus status;
  final String? note;
  final String createdAt;
  final String updatedAt;

  ExternalWorkRecord copyWith({
    String? id,
    String? importBatchId,
    String? sourceShareId,
    String? sourceRecordUuid,
    String? sourceInstallationUuid,
    String? originFingerprint,
    String? collaboratorName,
    String? contactSnapshot,
    String? siteSnapshot,
    Object? equipmentBrand = _sentinel,
    Object? equipmentModel = _sentinel,
    Object? equipmentType = _sentinel,
    int? workDate,
    int? hoursMilli,
    int? sourceUnitPriceFen,
    int? localUnitPriceFen,
    int? amountFen,
    Object? linkedProjectId = _sentinel,
    ExternalWorkRecordStatus? status,
    Object? note = _sentinel,
    String? createdAt,
    String? updatedAt,
  }) {
    return ExternalWorkRecord(
      id: id ?? this.id,
      importBatchId: importBatchId ?? this.importBatchId,
      sourceShareId: sourceShareId ?? this.sourceShareId,
      sourceRecordUuid: sourceRecordUuid ?? this.sourceRecordUuid,
      sourceInstallationUuid:
          sourceInstallationUuid ?? this.sourceInstallationUuid,
      originFingerprint: originFingerprint ?? this.originFingerprint,
      collaboratorName: collaboratorName ?? this.collaboratorName,
      contactSnapshot: contactSnapshot ?? this.contactSnapshot,
      siteSnapshot: siteSnapshot ?? this.siteSnapshot,
      equipmentBrand: identical(equipmentBrand, _sentinel)
          ? this.equipmentBrand
          : equipmentBrand as String?,
      equipmentModel: identical(equipmentModel, _sentinel)
          ? this.equipmentModel
          : equipmentModel as String?,
      equipmentType: identical(equipmentType, _sentinel)
          ? this.equipmentType
          : equipmentType as String?,
      workDate: workDate ?? this.workDate,
      hoursMilli: hoursMilli ?? this.hoursMilli,
      sourceUnitPriceFen: sourceUnitPriceFen ?? this.sourceUnitPriceFen,
      localUnitPriceFen: localUnitPriceFen ?? this.localUnitPriceFen,
      amountFen: amountFen ?? this.amountFen,
      linkedProjectId: identical(linkedProjectId, _sentinel)
          ? this.linkedProjectId
          : linkedProjectId as String?,
      status: status ?? this.status,
      note: identical(note, _sentinel) ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    validate();
    return toUncheckedMap();
  }

  Map<String, Object?> toUncheckedMap() {
    return {
      'id': id,
      'import_batch_id': importBatchId,
      'source_share_id': sourceShareId,
      'source_record_uuid': sourceRecordUuid,
      'source_installation_uuid': sourceInstallationUuid,
      'origin_fingerprint': originFingerprint,
      'collaborator_name': collaboratorName,
      'contact_snapshot': contactSnapshot,
      'site_snapshot': siteSnapshot,
      'equipment_brand': equipmentBrand,
      'equipment_model': equipmentModel,
      'equipment_type': equipmentType,
      'work_date': workDate,
      'hours_milli': hoursMilli,
      'source_unit_price_fen': sourceUnitPriceFen,
      'local_unit_price_fen': localUnitPriceFen,
      'amount_fen': amountFen,
      'linked_project_id': linkedProjectId,
      'status': status.name,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ExternalWorkRecord fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    return ExternalWorkRecord(
      id: reader.requiredString('id'),
      importBatchId: reader.requiredString('import_batch_id'),
      sourceShareId: reader.requiredString('source_share_id'),
      sourceRecordUuid: reader.requiredString('source_record_uuid'),
      sourceInstallationUuid: reader.requiredString('source_installation_uuid'),
      originFingerprint: reader.requiredString('origin_fingerprint'),
      collaboratorName: reader.requiredString('collaborator_name'),
      contactSnapshot: reader.requiredString('contact_snapshot'),
      siteSnapshot: reader.requiredString('site_snapshot'),
      equipmentBrand: reader.optionalString('equipment_brand'),
      equipmentModel: reader.optionalString('equipment_model'),
      equipmentType: reader.optionalString('equipment_type'),
      workDate: reader.requiredNonNegativeInt('work_date'),
      hoursMilli: reader.requiredNonNegativeInt('hours_milli'),
      sourceUnitPriceFen: reader.requiredNonNegativeInt(
        'source_unit_price_fen',
      ),
      localUnitPriceFen: reader.requiredNonNegativeInt('local_unit_price_fen'),
      amountFen: reader.requiredNonNegativeInt('amount_fen'),
      linkedProjectId: reader.optionalString('linked_project_id'),
      status: parseExternalStatus<ExternalWorkRecordStatus>(
        raw: map['status'],
        values: ExternalWorkRecordStatus.values,
        nameOf: (status) => status.name,
        fallback: ExternalWorkRecordStatus.active,
      ),
      note: reader.optionalString('note'),
      createdAt: reader.requiredString('created_at'),
      updatedAt: reader.requiredString('updated_at'),
    );
  }

  void validate() {
    ExternalWorkRecord.fromMap(toUncheckedMap());
    final expectedAmountFen = calculateAmountFen(
      hoursMilli: hoursMilli,
      unitPriceFen: localUnitPriceFen,
    );
    if (amountFen != expectedAmountFen) {
      throw ExternalDataParseException('amount_fen does not match policy');
    }
  }

  static int calculateAmountFen({
    required int hoursMilli,
    required int unitPriceFen,
  }) {
    final reader = ExternalFieldReader({
      'hours_milli': hoursMilli,
      'unit_price_fen': unitPriceFen,
    });
    final safeHoursMilli = reader.requiredNonNegativeInt('hours_milli');
    final safeUnitPriceFen = reader.requiredNonNegativeInt('unit_price_fen');
    return AmountPolicy.calculateAmount(
      hours: WorkHours(safeHoursMilli),
      unitPrice: UnitPrice(safeUnitPriceFen),
    ).fen;
  }
}

const _sentinel = Object();
