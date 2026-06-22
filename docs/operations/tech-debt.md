# 技术债清单

本文件用于记录已确认但不属于当前任务范围的问题。不要编造不存在的问题。

## 记录模板

```markdown
## <标题>

- 状态：待处理 / 处理中 / 已完成
- 来源：<任务、审计、issue 或 commit>
- 影响范围：<模块或用户场景>
- 证据：<文件、函数、测试或复现步骤>
- 建议处理：<下一步>
- 负责人：待确认
```

## 当前条目

> 来源：`dev@36d42f0` 只读复核（2026-06-22）。完整执行路线见
> `docs/quality/execution-roadmap-dev-36d42f0.md`，P0 prompt 见
> `docs/quality/codex-prompts-p0.md`。

## DST 月度分摊 bug（日历日被当本地墙钟）

- 状态：部分已修（`dc0dbf4` 过渡形态，双时区全量绿）；升级中（FIX-DST-B 整数序日）
- 来源：P0-S4 恢复全量 `flutter test` 时揪出
- 影响范围：`TimingMonthlyIncomeService` / `TimingMonthlyExpenseService` 的月度收入/支出分摊；
  DST 时区用户、作业分段跨 DST 边界时算错一天占比；GitHub runner（UTC）会 false-green
- 证据：原 `.difference(start).inDays` 用本地 `DateTime`；`timing_monthly_income_service_test.dart`
  "keeps april income … under realtime rules" 本机 `America/Los_Angeles` 红、`TZ=UTC` 绿
- 建议处理：① `dc0dbf4` 已统一 `DateTime.utc`；② FIX-DST-B 迁移到 `YmdDate.toEpochDay()`
  整数序日；③ 后续审计其它 `dateFromYmd(...).difference()` / 本地 `DateTime(y,m,d)` 日算术
- 规范：`docs/architecture/date-timezone-rules.md`
- 负责人：待确认

## CI 与本地门禁脱节

- 状态：处理中（Phase 0）
- 来源：dev@36d42f0 复核
- 影响范围：远端回归防线/全仓
- 证据：`.github/workflows/flutter.yml:32-38` custom_lint / `check_architecture.sh` /
  全量 `flutter test` 被注释，仅跑 analyze + 单个 IAP define 测试；只在 `main/master` 触发
- 建议处理：Phase 0 切片 P0-S1..S6 恢复
- 负责人：待确认

## 架构守卫覆盖缺口（features 直连 DB / patterns→data/models）

- 状态：待处理（Phase 1）
- 来源：dev@36d42f0 复核
- 影响范围：分层边界长期漂移
- 证据：`lib/features/sync/sync_conflict_review_controller.dart:64` `AppDatabase.database` 裸 SQL；
  `lib/features/timing/operations/save_timing_record_operation_analyzer.dart` 直引 `AppDatabase`；
  15 个 `lib/patterns/**` 文件直接 import `data/models`（guard 未覆盖此两类）
- 建议处理：Phase 1 先写行为锁定测试 → 迁移 → 扩 guard
- 负责人：待确认

## TimingRecord.fromMap 日期不变量未贯穿持久化边界

- 状态：待处理（Phase 2）
- 来源：dev@36d42f0 复核
- 影响范围：领域日期合法性
- 证据：`lib/data/models/timing_record.dart:215` `startDate: m['start_date'] as int` 裸转，
  读路径不经 `YmdDate` 校验
- 建议处理：Phase 2 P2-S1 用 YmdDate/等价 parser 校验
- 负责人：待确认

## i18n 残留（用户可见硬编码中文 + external_work 未 key 化）

- 状态：待处理（Phase 2）
- 来源：dev@36d42f0 复核
- 影响范围：i18n/UX
- 证据：约 54 处面向用户硬编码中文集中在 timing/device/external_work，
  如 `lib/features/timing/view/timing_page.dart:723` `'外协项目详情'`；CJK guard 非全域
- 建议处理：Phase 2 P2-S2..S6 分模块 key 化 + 扩 CJK guard
- 负责人：待确认

## 后端生产化非对称（sync 缺限流 / backup 缺结构化日志）

- 状态：待处理（Phase 2/3）
- 来源：dev@36d42f0 复核
- 影响范围：后端可靠性/可观测性
- 证据：`server/cloud_sync_backend/app.py` 有 logging 但无逐用户限流（仅 413 批量上限，
  见 `:845`），print 兜底 `:952,992`；`server/cloud_backup_backend/app.py` 有
  `SlidingWindowRateLimiter`（`:448,719`）但零 logging，print 兜底 `:952,999`；
  两者均 `ThreadingHTTPServer` 每请求一线程无池化
- 建议处理：Phase 2 后端硬化（P2-B1..B4）+ Phase 3 拆 app.py
- 负责人：待确认

## 后端 sqlite 连接未显式关闭（ResourceWarning）

- 状态：已完成（Debt-0）
- 来源：P0-S6 严格 ResourceWarning 诊断
- 影响范围：`server/cloud_sync_backend` / `server/cloud_backup_backend` 资源句柄
- 证据：两后端 `python3 -W error::ResourceWarning -m unittest discover -s tests` 均报
  `ResourceWarning: unclosed database`；告警在 GC finalize 阶段触发，进程 exit=0 不致命；
  根因：`with self._connect() as conn` 是事务 CM 不关闭连接
- 建议处理：改 `contextlib.closing(self._connect())` 或 try/finally `conn.close()`；
  修复后可考虑把严格 ResourceWarning 纳入后端 CI
- 负责人：待确认

## 大文件维护性

- 状态：待处理（Phase 3）
- 来源：dev@36d42f0 复核
- 影响范围：可维护性
- 证据：`account_page.dart`(1208)、`device_page.dart`(1164)、`backup_validator.dart`(965)、
  `timing_page.dart`(907)、`sync_manager.dart`(865)、两个后端 `app.py`(1022/1016)
- 建议处理：Phase 3 行为不变拆分，characterization tests 护航
- 负责人：待确认

## 四条能力生产闭环（live sync / driver entry / native update / IAP）

- 状态：待处理（Phase 4，冻结中）
- 来源：dev@36d42f0 复核
- 影响范围：对外商业化声明
- 证据：`sync_live_readiness_gate.dart:34` 硬阻断 + `sync_repositories.dart:367` delete-meta no-op；
  `driver_entry_submission_workflow.dart` 纯领域骨架（无 concrete 实现/无表/无 deep link）；
  `app_update_providers.dart:84` `inAppUpdateLauncher: null`；
  `subscription_verification_repository_factory.dart:22-26` 配置门控、未做 sandbox smoke（已 fail-closed）
- 建议处理：Phase 0/1 达标后才进 Phase 4，逐条真机/线上 smoke 留证
- 负责人：待确认
