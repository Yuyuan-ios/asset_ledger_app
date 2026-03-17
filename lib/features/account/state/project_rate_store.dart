import '../../../data/models/project_device_rate.dart';
import '../../../data/repositories/project_rate_repository.dart';
import '../../../core/utils/base_store.dart';

/// 项目设备单价覆盖的状态管理类
/// 负责管理“项目×设备”维度的自定义单价配置，包含加载、新增/更新、删除等核心操作
/// 继承自 BaseStore 以复用异步操作的异常处理、加载状态管理等通用能力
class ProjectRateStore extends BaseStore {
  ProjectRateStore(this._repository);

  final ProjectRateRepository _repository;

  /// 项目设备单价配置列表（私有变量）
  /// 下划线标记为私有，防止外部直接修改，保证数据的不可变特性
  List<ProjectDeviceRate> _rates = const [];

  Future<void> _reload() async {
    _rates = await _repository.listAll();
  }

  /// 对外暴露的只读单价配置列表
  /// 外部仅能读取，修改需通过类内提供的方法，保证数据操作的可控性
  List<ProjectDeviceRate> get rates => _rates;

  /// 加载所有项目设备单价配置
  /// 从数据仓库拉取完整的单价覆盖记录，更新本地状态
  Future<void> loadAll() async {
    // 调用 BaseStore 的 run 方法，统一处理异步操作的异常和加载状态
    await run(() async {
      await _reload();
    });
  }

  /// 新增/更新项目设备单价配置（Upsert 逻辑）
  /// 核心逻辑：存在则更新，不存在则插入，无需区分新增/编辑操作
  /// [r] 要保存的项目设备单价配置实体
  Future<void> upsert(ProjectDeviceRate r) async {
    await writeAndPatchLocalState(
      write: () async {
        await _repository.upsert(r);
        return r;
      },
      patch: (nextRate) {
        final index = _rates.indexWhere(
          (item) =>
              item.projectKey == nextRate.projectKey &&
              item.deviceId == nextRate.deviceId &&
              item.isBreaking == nextRate.isBreaking,
        );
        if (index == -1) {
          _rates = [..._rates, nextRate];
        } else {
          final updated = [..._rates];
          updated[index] = nextRate;
          _rates = updated;
        }
      },
    );
  }

  /// 根据项目标识和设备ID删除单价配置
  /// [projectKey] 项目唯一标识（联系人+工地）
  /// [deviceId] 设备ID
  Future<void> delete(
    String projectKey,
    int deviceId, {
    bool isBreaking = false,
  }) async {
    await writeAndPatchLocalState(
      write: () => _repository.delete(
        projectKey,
        deviceId,
        isBreaking: isBreaking,
      ),
      patch: (_) {
        _rates = _rates.where((item) {
          return !(
              item.projectKey == projectKey &&
              item.deviceId == deviceId &&
              item.isBreaking == isBreaking);
        }).toList();
      },
    );
  }
}
