import '../../core/money/amount_policy.dart';
import 'external_work_parse.dart';

enum ExternalWorkRecordStatus { active, ignored, archived, voided }

/// 导入记录的计价种类。来源于富 records 的 `type` 字段；legacy export_lines
/// 路径只产出 hours 行。UI 据此决定单价为 null 时显示"未知"还是"不适用"。
enum ExternalWorkRecordKind { hours, rent }

ExternalWorkRecordKind externalWorkRecordKindFromName(
  String? name, {
  ExternalWorkRecordKind fallback = ExternalWorkRecordKind.hours,
}) {
  switch (name) {
    case 'hours':
      return ExternalWorkRecordKind.hours;
    case 'rent':
      return ExternalWorkRecordKind.rent;
    default:
      return fallback;
  }
}

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
    this.projectReceivedFen = 0,
    this.linkedProjectId,
    this.recordKind = ExternalWorkRecordKind.hours,
    this.status = ExternalWorkRecordStatus.active,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.amountOverridesPolicy = false,
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
    int projectReceivedFen = 0,
    String? linkedProjectId,
    ExternalWorkRecordKind recordKind = ExternalWorkRecordKind.hours,
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
      projectReceivedFen: projectReceivedFen,
      linkedProjectId: linkedProjectId,
      recordKind: recordKind,
      status: status,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )..validate();
  }

  /// 富事实层导入路径：amountFen 为来源真实金额（rich `income_fen`），
  /// 原样写入，禁止按 AmountPolicy 重算。rent/台班/人工覆写金额记录走此路径。
  /// 单价未知时传 null，绝不伪造 0；导入端不会反推单价。
  factory ExternalWorkRecord.imported({
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
    required int amountFen,
    int? sourceUnitPriceFen,
    int? localUnitPriceFen,
    int projectReceivedFen = 0,
    ExternalWorkRecordKind recordKind = ExternalWorkRecordKind.hours,
    String? linkedProjectId,
    ExternalWorkRecordStatus status = ExternalWorkRecordStatus.active,
    String? note,
    required String createdAt,
    required String updatedAt,
  }) {
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
      localUnitPriceFen: localUnitPriceFen,
      amountFen: amountFen,
      projectReceivedFen: projectReceivedFen,
      linkedProjectId: linkedProjectId,
      recordKind: recordKind,
      status: status,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      amountOverridesPolicy: true,
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

  /// 来源方原始单价（分）。**只读事实**，导入时来自分享包 rich record。
  /// null 代表来源未知，0 代表真实来源单价为 0，二者不可互换。
  /// rent / 台班 / 人工覆写金额 / 设备缺失等情况导入时直接为 null；
  /// legacy export_lines 路径导入的记录恒为非 null。
  /// 展示用途：计时页 "项目外协记录" 详情显示此字段（来源事实视图）。
  final int? sourceUnitPriceFen;

  /// 接收方本地复核的外协应付 / 结算单价（分）。null 表示尚未本地覆盖。
  /// 后期账户页外协卡片用 `localUnitPriceFen ?? sourceUnitPriceFen` 作为
  /// "有效外协应付单价"，参与外协应付 / 利润核算；客户结算 / 项目收入单价
  /// 不在这里，仍走接收方自己的项目/设备单价。
  /// 注意：计时页详情**不**展示这个字段，避免把"接收方复核值"伪装为"来源"。
  final int? localUnitPriceFen;
  final int amountFen;

  /// 来源项目在导出时的累计实收款（分）。旧分享包 / 本地旧库默认为 0。
  final int projectReceivedFen;
  final String? linkedProjectId;

  /// 计价种类。legacy 导入路径恒为 hours；rich 导入路径按来源 type 保留。
  final ExternalWorkRecordKind recordKind;
  final ExternalWorkRecordStatus status;
  final String? note;
  final String createdAt;
  final String updatedAt;

  /// true：amountFen 为来源真实金额，validate() 跳过 AmountPolicy 一致性校验。
  /// 仅内存态，不入库列；持久化读回（fromMap）后为 false（读路径不重校金额）。
  final bool amountOverridesPolicy;

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
    Object? sourceUnitPriceFen = _sentinel,
    Object? localUnitPriceFen = _sentinel,
    int? amountFen,
    int? projectReceivedFen,
    Object? linkedProjectId = _sentinel,
    ExternalWorkRecordKind? recordKind,
    ExternalWorkRecordStatus? status,
    Object? note = _sentinel,
    String? createdAt,
    String? updatedAt,
    bool? amountOverridesPolicy,
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
      sourceUnitPriceFen: identical(sourceUnitPriceFen, _sentinel)
          ? this.sourceUnitPriceFen
          : sourceUnitPriceFen as int?,
      localUnitPriceFen: identical(localUnitPriceFen, _sentinel)
          ? this.localUnitPriceFen
          : localUnitPriceFen as int?,
      amountFen: amountFen ?? this.amountFen,
      projectReceivedFen: projectReceivedFen ?? this.projectReceivedFen,
      linkedProjectId: identical(linkedProjectId, _sentinel)
          ? this.linkedProjectId
          : linkedProjectId as String?,
      recordKind: recordKind ?? this.recordKind,
      status: status ?? this.status,
      note: identical(note, _sentinel) ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      amountOverridesPolicy:
          amountOverridesPolicy ?? this.amountOverridesPolicy,
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
      'project_received_fen': projectReceivedFen,
      'linked_project_id': linkedProjectId,
      'record_kind': recordKind.name,
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
      sourceUnitPriceFen: _optionalNonNegativeIntCell(
        map,
        'source_unit_price_fen',
      ),
      localUnitPriceFen: _optionalNonNegativeIntCell(
        map,
        'local_unit_price_fen',
      ),
      amountFen: reader.requiredNonNegativeInt('amount_fen'),
      projectReceivedFen:
          _optionalNonNegativeIntCell(map, 'project_received_fen') ?? 0,
      linkedProjectId: reader.optionalString('linked_project_id'),
      recordKind: externalWorkRecordKindFromName(map['record_kind'] as String?),
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
    if (amountOverridesPolicy) return;
    // 非 imported 路径要求单价存在并与 AmountPolicy 一致；仅 imported 允许 null。
    final price = localUnitPriceFen;
    if (price == null) {
      throw ExternalDataParseException(
        'local_unit_price_fen must not be null on policy-checked path',
      );
    }
    final expectedAmountFen = calculateAmountFen(
      hoursMilli: hoursMilli,
      unitPriceFen: price,
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

/// DB / map 单元格的可空非负整数读取：键不存在或值为 null → null；
/// 数值 < 0 或非整数立刻报错（保持 schema CHECK >= 0 的语义）。
int? _optionalNonNegativeIntCell(Map<String, Object?> map, String key) {
  if (!map.containsKey(key)) return null;
  final value = map[key];
  if (value == null) return null;
  if (value is int) {
    if (value < 0) {
      throw ExternalDataParseException('$key must be >= 0');
    }
    return value;
  }
  if (value is num) {
    final asInt = value.toInt();
    if (asInt != value || asInt < 0) {
      throw ExternalDataParseException('$key must be a non-negative integer');
    }
    return asInt;
  }
  throw ExternalDataParseException('$key must be an integer');
}
