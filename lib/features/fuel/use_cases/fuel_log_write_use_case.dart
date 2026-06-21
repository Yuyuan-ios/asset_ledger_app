import '../../../data/models/fuel_log.dart';

abstract class FuelLogWriteUseCase {
  Future<int> create(FuelLog log);

  Future<void> update(FuelLog log);

  Future<void> deleteById(int id);
}
