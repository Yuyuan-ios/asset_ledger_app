import '../../models/external_work_parse.dart';
import 'jztshare_errors.dart';

class ProjectExternalWorkShareLine {
  const ProjectExternalWorkShareLine({
    required this.exportLineUuid,
    required this.originFingerprint,
    required this.contactSnapshot,
    required this.siteSnapshot,
    this.equipmentBrand,
    this.equipmentModel,
    this.equipmentType,
    required this.workDate,
    required this.hoursMilli,
    required this.sourceUnitPriceFen,
    required this.amountFen,
    this.note,
  });

  final String exportLineUuid;
  final String originFingerprint;
  final String contactSnapshot;
  final String siteSnapshot;
  final String? equipmentBrand;
  final String? equipmentModel;
  final String? equipmentType;
  final int workDate;
  final int hoursMilli;
  final int sourceUnitPriceFen;
  final int amountFen;
  final String? note;

  static ProjectExternalWorkShareLine fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    try {
      return ProjectExternalWorkShareLine(
        exportLineUuid: reader.requiredString('export_line_uuid'),
        originFingerprint: reader.requiredString('origin_fingerprint'),
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
        amountFen: reader.requiredNonNegativeInt('amount_fen'),
        note: reader.optionalString('note'),
      );
    } on ExternalDataParseException catch (error) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidLine,
        error.message,
        map,
      );
    }
  }
}
