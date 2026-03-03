import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../core/utils/base_store.dart';

/// 收款记录状态管理类
/// 负责收款记录的加载、新增、编辑、删除等操作，继承自基础状态管理类 BaseStore
/// 封装了与收款记录相关的所有业务逻辑和状态维护
class AccountPaymentStore extends BaseStore {
  AccountPaymentStore(this._repository);

  final AccountPaymentRepository _repository;

  /// 收款记录列表（私有变量）
  /// 使用下划线标记为私有，通过 get 方法对外暴露，保证数据不可直接修改
  List<AccountPayment> _records = const [];

  Future<void> _reload() async {
    _records = await _repository.listAll();
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
    await run(() async {
      // 无 id 表示新增记录
      if (p.id == null) {
        await _repository.insert(p);
      } else {
        // 有 id 表示编辑已有记录
        await _repository.update(p);
      }
      // 保存后重新加载最新的记录列表，保证状态同步
      await _reload();
    });
  }

  /// 根据 ID 删除收款记录
  /// [id] 要删除的收款记录 ID
  Future<void> deleteById(int id) async {
    await run(() async {
      // 调用仓库层删除指定 ID 的记录
      await _repository.deleteById(id);
      // 删除后重新加载最新的记录列表，保证状态同步
      await _reload();
    });
  }
}
