import 'cloud_work_record_dto.dart';

class LocalCloudMapper {
  const LocalCloudMapper._();

  static Map<String, Object?> workRecordToPayload(CloudWorkRecordDto dto) {
    return dto.toMap()..removeWhere((_, value) => value == null);
  }
}
