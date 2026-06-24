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

> 来源：`dev@36d42f0` 只读复核（2026-06-22）。
> **2026-06-24 刷新**：分支收口后，发布主线已切到真主线 `main = develop = ba52b60`
> （详见记忆 `dev-branch-renamed-develop`）。下列状态按 **ba52b60 实测**更新——
> 原 dev@36d42f0 上标"待处理"的 Phase 0–3 多数已在该线落实。完整路线见
> `docs/quality/execution-roadmap-dev-36d42f0.md`。

## DST 月度分摊 bug（日历日被当本地墙钟）

- 状态：✅ 已完成（ba52b60）
- 来源：P0-S4 恢复全量 `flutter test` 时揪出
- 影响范围：`TimingMonthlyIncomeService` / `TimingMonthlyExpenseService` 月度分摊；DST 时区用户
- 证据：服务已统一 `DateTime.utc`（3 处）并迁 `YmdDate.fromInt` 整数序日
  （`timing_monthly_income_service.dart:402-404`）；"keeps april income … under realtime rules"
  在本机 `America/Los_Angeles` 绿
- 备注：FIX-DST-B（整数序日）已落地。后续若审计其它本地 `DateTime(y,m,d)` 日算术另开条目
- 规范：`docs/architecture/date-timezone-rules.md`

## CI 与本地门禁脱节

- 状态：✅ 已完成（ba52b60，commit `ba52b60`）
- 证据：`.github/workflows/flutter.yml` 已接回 analyze + custom_lint + check_architecture +
  全量 test（两遍跑，隔离 `arch-script` 避免 `__arch_probe_*` 竞争）+ 双后端 unittest；
  触发分支含 `develop`；`concurrency` 生效
- 备注：本地 `check_full.sh` 同样两遍跑；详见记忆 `dev-branch-renamed-develop`

## 架构守卫：features 直连 DB

- 状态：✅ 已完成（ba52b60）
- 证据：`tools/check_architecture.sh:336,340` 已守 features→`package:sqflite` 与直接
  `AppDatabase` 使用；`lib/features/**` 直连 `AppDatabase.database` 残留 = 0

## 架构守卫：patterns→data/models（P1-S6/S7）

- 状态：✅ 已完成（2026-06-24 决策：formalize-allow）
- 来源：dev@36d42f0 复核；ba52b60 复验
- 决策：patterns 可只读依赖 `data/models` 的 domain 值对象（展示用），不视为违规；
  真正有害的 repositories/db/infrastructure/data/services/use_cases 依赖已被 guard 拦住
- 证据：`docs/architecture/layers.md`「patterns」节已明确允许/禁止依赖；
  `tools/check_architecture.sh` 注释记录该决策（patterns 全局基础设施依赖禁用块）
- 备注：roadmap P1-S7「guard 禁 patterns→data/models」原意被该决策替代——
  data/models 是稳定值对象，patterns 直接展示不构成有害耦合

## 结算 snapshot 双份逻辑（analyzer / service）

- 状态：✅ 已完成（2026-06-24）
- 来源：P1-S5 架构边界收口
- 影响范围：计时保存 preview / commit 结清撤销判断
- 处理：snapshot 构建收敛到 `ProjectSettlementImpactService` 单一来源——
  `evaluate`（commit，事务 executor）与新增 static `evaluateFromRepositories`
  （preview，repository；feature 层不持 executor 故走 repo 版，不违反 features→AppDatabase
  守卫）共用私有 `_snapshot` 构建点；analyzer 的 `_evaluateSettlementImpact` 改为委托。
  revoke 决策本就单源于 `ProjectSettlementImpactSnapshot.shouldRevokeSettlement`
- 证据：142 等价测试绿（analyzer / impact service / save_with_impact / 结清 use_case）
- 负责人：—

## i18n 展示层硬编码中文

- 状态：✅ 已完成（展示层，ba52b60）
- 证据：`'外协项目详情'` 等已 key 化入 `lib/l10n/app_zh.arb`
  （`externalWorkDetailSheetTitle`）；timing/device/external_work view 层 + CJK guard 已收
- 备注：**反馈层/领域层**文案（错误码→UI、save 路径 userMessage/warnings）未 key 化，
  单列为 S4b/S5b

## timing save-operation 领域层文案分离（S4b）

- 状态：⏳ 待处理（曾暂缓，2026-06-24 用户决定处理）
- 来源：Phase 2 i18n 人工诊断
- 影响范围：`lib/features/timing/operations/**`、`use_cases/**`、`application/**`
- 证据：`SaveTimingRecordOperationCommand` / analyzer / redactor 等保存链路生成
  `userMessage`、warnings、title、summary 等用户可见文案，埋在领域层；GitNexus 标 CRITICAL
- 建议处理：先定义领域错误/预览摘要 code 与 UI copy mapper，再迁移保存预览/确认/执行文案
- 负责人：待确认

## device 领域/application 层文案分离（S5b）

- 状态：⏳ 待处理（曾暂缓，2026-06-24 用户决定处理）
- 来源：Phase 2 device view-layer i18n
- 影响范围：`lib/features/device/domain/**`、`lib/features/device/application/**`
- 证据：`lifecycle_payback_calculator.dart` 仍直接生成 `statusText/resultText`；
  `cloud_backup_controller.dart`、`local_backup_controller.dart`、`device_action_controller.dart`、
  `device_avatar_policy.dart` 仍含可能展示给用户的中文错误/反馈文案
- 建议处理：领域/application 返回 code 或结构化状态，由 device view 层统一映射 `AppLocalizations`
- 负责人：待确认

## 后端生产化非对称（sync 限流 ✓ / backup 结构化日志 仍稀疏）

- 状态：🟡 部分完成（ba52b60）
- 证据：sync 后端已加逐用户限流配置（`server/cloud_sync_backend/config.py:144` rate_limit_*）；
  backup 后端已有 `SlidingWindowRateLimiter`，但结构化 logging 仍稀疏（仅 ~2 处 logging 引用，
  仍有 print 兜底）
- 建议处理：给 backup 后端补结构化 logging + 敏感字段脱敏；统一异常→结构化错误
- 负责人：待确认

## 后端 sqlite 连接未显式关闭（ResourceWarning）

- 状态：✅ 已完成（Debt-0）
- 证据：P0-S6 严格 ResourceWarning 诊断后收口

## 大文件维护性

- 状态：✅ 已完成（Phase 3，ba52b60）
- 证据：`account_page.dart` 1208→217、`device_page.dart`、`backup_validator.dart`、
  `sync_manager.dart`、两后端 `app.py` 等已拆，行为不变（characterization 护航）

## 四条能力生产闭环（live sync / driver entry / native update / IAP）

- 状态：⏳ 待处理（Phase 4，代码就绪、缺部署/smoke）
- 影响范围：对外商业化声明
- 证据（ba52b60 实测）：
  - **live sync**：`sync_live_readiness_gate.dart:34` 硬阻断 `real-cloud-transport-not-configured`
    + 2 deferred（`delete-meta-lifecycle-deferred`、`terminal-failed-admin-reset-deferred`）
  - **driver entry**：`driver_entry_submission_workflow.dart` 纯领域骨架（无 concrete 实现/无表/无入口）
  - **native update**：`app_providers.dart:39`、`app_update_providers.dart:84` `inAppUpdateLauncher: null`
  - **IAP**：`subscription_verification_repository_factory.dart` 配置门控、fail-closed，
    `iap_verification_backend` 已提交；缺 Apple 密钥 + 部署 + sandbox smoke
- 建议处理：Phase 4 逐条真机/线上 smoke 留证；Phase 5 发布准入
- 负责人：待确认
