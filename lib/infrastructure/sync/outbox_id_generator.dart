import 'dart:math';

/// sync_outbox 主键 id 生成器（R5.5）。
///
/// 旧实现用 `outbox-<microsecondsSinceEpoch>`：单条 save/delete/payment 风险低，
/// 但合并批次收款 / 结清簇 / ExternalWork 批量导入会在**同一个 transaction 内**
/// 连续入队多条 outbox，同微秒会主键碰撞。本抽象把 id 来源换成批量安全方案，
/// 并允许测试注入确定性序列。
abstract class OutboxIdGenerator {
  String generate();
}

/// 生产实现：`outbox-<128-bit 安全随机 hex>`。
///
/// 与项目既有约定一致（[ProjectId.create] / AppIdentityService 均用
/// `Random.secure()`）。128-bit 随机使同事务 / 同微秒 / 多 repo 实例连续生成的
/// 碰撞概率可忽略，且不依赖任何共享可变计数器来避免碰撞。
class SecureRandomOutboxIdGenerator implements OutboxIdGenerator {
  SecureRandomOutboxIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'outbox-$hex';
  }
}

/// 确定性序列生成器：`outbox-test-1` / `outbox-test-2` / …
///
/// 供测试断言具体 id，或验证批量入队的 id 唯一且有序。非随机、可控。
class SequenceOutboxIdGenerator implements OutboxIdGenerator {
  SequenceOutboxIdGenerator({String prefix = 'outbox-test-'}) : _prefix = prefix;

  final String _prefix;
  int _counter = 0;

  @override
  String generate() {
    _counter += 1;
    return '$_prefix$_counter';
  }
}
