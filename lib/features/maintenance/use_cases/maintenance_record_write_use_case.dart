import '../../../data/models/maintenance_record.dart';

abstract class MaintenanceRecordWriteUseCase {
  Future<int> create(MaintenanceRecord record);

  Future<void> update(MaintenanceRecord record);

  Future<void> deleteById(int id);
}
