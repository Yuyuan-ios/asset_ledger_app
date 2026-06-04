import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../core/utils/base_store.dart';
import '../use_cases/account_payment_write_use_case.dart';

/// 收款记录状态管理类
/// 负责收款记录的加载、新增、编辑、删除等操作，继承自基础状态管理类 BaseStore
/// 封装了与收款记录相关的所有业务逻辑和状态维护
class AccountPaymentStore extends BaseStore {
  /// [writeUseCase] 注入时（生产路径），单条收款的 create/update/delete 走事务化
  /// 入口并同事务入队 sync_outbox + entity_sync_meta（R5.3）。未注入时回退到旧的
  /// 直接 repository 写（不入队），保持既有测试 / 早期路径兼容。
  AccountPaymentStore(
    this._repository, {
    AccountPaymentWriteUseCase? writeUseCase,
  }) : _writeUseCase = writeUseCase;

  final AccountPaymentRepository _repository;
  final AccountPaymentWriteUseCase? _writeUseCase;

  /// 收款记录列表（私有变量）
  /// 使用下划线标记为私有，通过 get 方法对外暴露，保证数据不可直接修改
  List<AccountPayment> _records = const [];

  Future<void> _reload() async {
    _records = await _repository.listAll();
  }

  void _sortRecords() {
    _records = [..._records]
      ..sort((a, b) {
        final byDate = b.ymd.compareTo(a.ymd);
        if (byDate != 0) return byDate;
        final byCreatedAt = (b.createdAt ?? '').compareTo(a.createdAt ?? '');
        if (byCreatedAt != 0) return byCreatedAt;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
  }

  /// 对外提供的收款记录列表（只读）
  /// 外部只能读取，不能直接修改，确保数据的安全性
  List<AccountPayment> get records => _records;

  /// 加载所有收款记录
  /// 从仓库层获取完整的收款记录列表并更新本地状态
  Future<void> loadAll() async {
    // 调用 BaseStore 的 run 方法，统一处理异步操作的异常和加载状态
    await run(() async {
      // 从数据仓库获取所有收款记录
      await _reload();
    });
  }

  /// 保存收款记录（新增/编辑）
  /// 根据是否有 id 来判断是新增还是编辑操作
  /// [p] 要保存的收款记录实体
  Future<void> save(AccountPayment p) async {
    final payment = p.id == null && p.createdAt == null
        ? p.copyWith(createdAt: DateTime.now().toUtc().toIso8601String())
        : p;
    await writeAndPatchLocalState(
      write: () async {
        final writeUseCase = _writeUseCase;
        if (payment.id == null) {
          return writeUseCase != null
              ? await writeUseCase.create(payment)
              : await _repository.insert(payment);
        }
        if (writeUseCase != null) {
          await writeUseCase.update(payment);
        } else {
          await _repository.update(payment);
        }
        return payment.id!;
      },
      patch: (paymentId) {
        final next = payment.copyWith(id: paymentId);
        final index = _records.indexWhere((item) => item.id == paymentId);
        if (index == -1) {
          _records = [..._records, next];
        } else {
          final updated = [..._records];
          updated[index] = next;
          _records = updated;
        }
        _sortRecords();
      },
    );
  }

  /// 根据 ID 删除收款记录
  /// [id] 要删除的收款记录 ID
  Future<void> deleteById(int id) async {
    await writeAndPatchLocalState(
      write: () async {
        final writeUseCase = _writeUseCase;
        if (writeUseCase != null) {
          await writeUseCase.deleteById(id);
        } else {
          await _repository.deleteById(id);
        }
      },
      patch: (_) {
        _records = _records.where((item) => item.id != id).toList();
      },
    );
  }
}
