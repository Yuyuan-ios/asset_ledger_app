import '../../../data/models/account_payment.dart';
import '../../../data/models/account_project_merge_group_with_members.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/project_write_off.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/project_write_off_repository.dart';
import '../../../data/services/account_project_merge_service.dart';
import '../../../core/utils/base_store.dart';
import '../model/account_view_model.dart';
import '../use_cases/compute_account_summary_use_case.dart';

/// AccountStore（聚合/派生 Store）
///
/// 设计目标：
/// - 只做“原始数据 + 合并组只读状态 -> UI VM”的转换（可复用、可测试）
/// - 不做 CRUD（CRUD 放在 AccountPaymentStore / 后续合并管理入口）
///
/// 输入：timingRecords / devices / rates / payments / activeMergeGroups
/// 输出：AccountComputed（项目列表 VM + 总览）
///
/// 口径：
/// - 项目聚合：使用 AccountService.buildProjects
/// - 金额计算：使用 AccountService.calcMoney
/// - 项目日期：统一使用 agg.minYmd（项目最早计时日期）
/// - 排序：minYmd DESC（越晚越靠前，越早越靠后）
///
class AccountStore extends BaseStore {
  AccountStore({
    AccountProjectMergeService? mergeService,
    ProjectWriteOffRepository? writeOffRepository,
    ComputeAccountSummaryUseCase? computeAccountSummaryUseCase,
  }) : _mergeService = mergeService,
       _writeOffRepository = writeOffRepository,
       _computeAccountSummaryUseCase =
           computeAccountSummaryUseCase ?? const ComputeAccountSummaryUseCase();

  final AccountProjectMergeService? _mergeService;
  final ProjectWriteOffRepository? _writeOffRepository;
  final ComputeAccountSummaryUseCase _computeAccountSummaryUseCase;
  List<AccountProjectMergeGroupWithMembers> _activeMergeGroups = const [];
  List<ProjectWriteOff> _writeOffs = const [];

  List<AccountProjectMergeGroupWithMembers> get activeMergeGroups =>
      List.unmodifiable(_activeMergeGroups);

  List<ProjectWriteOff> get writeOffs => List.unmodifiable(_writeOffs);

  Future<void> loadAll() async {
    await run(() async {
      final mergeService = _mergeService;
      _activeMergeGroups = mergeService == null
          ? const []
          : await mergeService.getActiveMergeGroupsWithMembers();

      final writeOffRepository = _writeOffRepository;
      _writeOffs = writeOffRepository == null
          ? const []
          : await writeOffRepository.listAll();
    });
  }

  // =====================================================================
  // ============================== A) 聚合计算 ==============================
  // =====================================================================

  AccountComputed compute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<AccountProjectMergeGroupWithMembers>? activeMergeGroups,
    List<ProjectWriteOff>? writeOffs,
  }) {
    return _computeAccountSummaryUseCase.execute(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
      payments: payments,
      writeOffs: writeOffs ?? _writeOffs,
      activeMergeGroups: activeMergeGroups ?? _activeMergeGroups,
    );
  }
}
