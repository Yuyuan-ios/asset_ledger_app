import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_service.dart';

/// 阶段 C Step 4：把 [TimingService.currentMeter] 包在 feature/device 的
/// application 层，让 device picker builder（pattern 层）与 feature view 文件
/// 都不必直接 import `data/services`。
///
/// 给定一批计时记录，返回一个"按设备求当前码表（小时）"的闭包，供
/// `buildDeviceEditorContext` / `buildDevicePickerItems` 使用。
double Function({required int deviceId, required double baseMeterHours})
deviceCurrentMeterResolver(List<TimingRecord> records) {
  return ({required int deviceId, required double baseMeterHours}) {
    return TimingService.currentMeter(
      records,
      deviceId,
      baseMeterHours: baseMeterHours,
    );
  };
}
