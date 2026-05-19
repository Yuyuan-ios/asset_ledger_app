import '../../../../data/repositories/account_payment_repository.dart';
import '../../../../data/services/account_project_merge_service.dart';
import '../../domain/entities/account_entities.dart';
import '../../model/account_project_payment_display_vm.dart';
import '../../model/account_view_model.dart';
import '../../state/account_payment_store.dart';
import '../../state/account_store.dart';
import '../../state/project_rate_store.dart';
import '../../use_cases/create_merged_payment_use_case.dart';
import '../../use_cases/delete_merged_payment_batch_use_case.dart';
import '../../use_cases/project_settlement_use_case.dart';
import '../../use_cases/update_merged_payment_batch_use_case.dart';
import '../../../device/state/device_store.dart';
import '../../../timing/state/timing_store.dart';

class AccountActionController {
  const AccountActionController({
    required AccountPaymentRepository paymentRepository,
    required AccountProjectMergeService mergeService,
    required ProjectSettlementUseCase settlementUseCase,
  }) : _paymentRepository = paymentRepository,
       _mergeService = mergeService,
       _settlementUseCase = settlementUseCase;

  final AccountPaymentRepository _paymentRepository;
  final AccountProjectMergeService _mergeService;
  final ProjectSettlementUseCase _settlementUseCase;

  Future<void> createMergedPayment({
    required AccountProjectVM project,
    required AccountPayment payment,
    required TimingStore timingStore,
    required DeviceStore deviceStore,
    required AccountPaymentStore paymentStore,
    required ProjectRateStore rateStore,
    required AccountStore accountStore,
  }) async {
    final memberProjects = memberProjectsForMerged(
      project: project,
      timingStore: timingStore,
      deviceStore: deviceStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
    );
    await CreateMergedPaymentUseCase(repository: _paymentRepository).execute(
      mergedProject: project,
      memberProjects: memberProjects,
      ymd: payment.ymd,
      amount: payment.amount,
      note: payment.note,
    );
    await Future.wait([paymentStore.loadAll(), accountStore.loadAll()]);
  }

  Future<void> updateMergedPaymentBatch({
    required AccountProjectVM project,
    required AccountProjectPaymentDisplayVM paymentItem,
    required AccountPayment payment,
    required TimingStore timingStore,
    required DeviceStore deviceStore,
    required AccountPaymentStore paymentStore,
    required ProjectRateStore rateStore,
    required AccountStore accountStore,
  }) async {
    final batchId = paymentItem.mergeBatchId;
    if (batchId == null || batchId.trim().isEmpty) return;
    final memberProjects = memberProjectsForMerged(
      project: project,
      timingStore: timingStore,
      deviceStore: deviceStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
    );
    await UpdateMergedPaymentBatchUseCase(
      repository: _paymentRepository,
    ).execute(
      mergedProject: project,
      memberProjects: memberProjects,
      mergeBatchId: batchId,
      ymd: payment.ymd,
      amount: payment.amount,
      note: payment.note,
    );
    await Future.wait([paymentStore.loadAll(), accountStore.loadAll()]);
  }

  Future<void> deleteMergedPaymentBatch({
    required String mergeBatchId,
    required AccountPaymentStore paymentStore,
    required AccountStore accountStore,
  }) async {
    await DeleteMergedPaymentBatchUseCase(
      repository: _paymentRepository,
    ).execute(mergeBatchId: mergeBatchId);
    await Future.wait([paymentStore.loadAll(), accountStore.loadAll()]);
  }

  Future<void> dissolveMergeGroup({
    required int groupId,
    required AccountStore accountStore,
  }) async {
    await _mergeService.dissolveMergeGroup(groupId);
    await accountStore.loadAll();
  }

  Future<void> createMergeGroup({
    required String contact,
    required List<String> projectIds,
    required List<String> projectKeys,
    required AccountStore accountStore,
  }) async {
    await _mergeService.createMergeGroup(
      contact: contact,
      projectIds: projectIds,
      projectKeys: projectKeys,
    );
    await accountStore.loadAll();
  }

  Future<ProjectSettlementResult> settleProject({
    required AccountProjectVM project,
    required double paymentAmount,
    required double writeOffAmount,
    required ProjectWriteOffReason? writeOffReason,
    required int ymd,
    required String? note,
    required AccountPaymentStore paymentStore,
    required AccountStore accountStore,
  }) async {
    final settlement = await _settlementUseCase.execute(
      projectId: project.effectiveProjectId,
      projectKey: project.projectKey,
      receivable: project.receivable,
      paymentAmount: paymentAmount,
      writeOffAmount: writeOffAmount,
      writeOffReason: writeOffReason,
      ymd: ymd,
      note: note,
    );
    await Future.wait([paymentStore.loadAll(), accountStore.loadAll()]);
    return settlement;
  }

  Future<DeleteProjectWriteOffResult> deleteWriteOff({
    required AccountProjectVM project,
    required ProjectWriteOff writeOff,
    required AccountStore accountStore,
  }) async {
    final result = await _settlementUseCase.deleteWriteOff(
      projectId: project.effectiveProjectId,
      writeOffId: writeOff.id,
      receivable: project.receivable,
    );
    await accountStore.loadAll();
    return result;
  }

  List<AccountProjectVM> memberProjectsForMerged({
    required AccountProjectVM project,
    required TimingStore timingStore,
    required DeviceStore deviceStore,
    required AccountPaymentStore paymentStore,
    required ProjectRateStore rateStore,
    required AccountStore accountStore,
  }) {
    final normalComputed = accountStore.compute(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
      activeMergeGroups: const [],
    );

    final memberKeys = project.memberProjectKeys.toSet();
    return normalComputed.projects.where((item) {
      return memberKeys.contains(item.projectKey);
    }).toList();
  }

  String friendlyMergedPaymentError(Object error) {
    final message = error.toString();
    if (message.contains('不存在或已被删除')) {
      return '这笔合并收款不存在或已被删除，请刷新后重试。';
    }
    if (message.contains('合并状态已变化')) {
      return '合并状态已变化，请重新打开项目详情后再操作。';
    }
    if (message.contains('超出剩余应收')) {
      final index = message.indexOf('超出剩余应收');
      return index < 0 ? '超出剩余应收' : message.substring(index);
    }
    return '操作失败，请稍后重试。';
  }

  String friendlyWriteOffError(Object error) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) {
      return error.message?.toString() ?? '输入不合法';
    }
    return '操作失败，请稍后重试。';
  }
}
