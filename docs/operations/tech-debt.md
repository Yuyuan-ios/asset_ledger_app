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

- 状态：⏳ 待处理（2026-06-24 深度 scoping 完成，待专项实施）
- 来源：Phase 2 i18n 人工诊断
- 影响范围：`lib/features/timing/operations/**`（~88 中文串，含 command 20 / analyzer 21 /
  redactor 11 / use_case 10 / disambiguation 6）
- **架构发现（2026-06-24）**：用户真正看到的文案**不是** analyzer 的 raw warnings（那些含
  项目/财务 ID，被 `save_timing_record_preview_redactor.dart` **脱敏剥离**），而是 redactor 的
  `_safeWarnings`（'预览基于当前本地数据…'、'可能影响项目结构，需老板确认。'）/
  `_genericImpactItems`（title/description，**已带 `code: 'project_structure'`**）/
  `_redactionReasons`（3 条）。这些经 `core/operations` 通用框架（`OperationImpactItem`，
  含可选 `code` 字段）以 `List<String> warnings` 形态流到 UI；UI 最终渲染点在通用 operation
  框架里，不在 timing view 直引，需先定位。
- **设计**：① 给 safe warnings / redaction reasons 定 enum code；② `OperationImpactItem` 用已有
  `code` 做 key；③ 在通用 operation-preview 渲染点加 code→`AppLocalizations` mapper（embedded
  title/description 作 fallback）；④ ARB key；⑤ 改 `warnings: List<String>` → 结构化 code 贯穿
  command/redactor/service/adapter（~6 源文件）；⑥ 更新 5 个测试文件断言（改断 code 而非中文串）。
- **风险**：CRITICAL 保存路径 + 跨 ~10 文件类型变更；须逐片 + characterization 护航，勿大爆改。
- 既有可复用 code 模式：`SaveTimingRecordStaleReasonType`、`OperationImpactItem.code`
- **2026-06-24 渲染点排查（重大修正）**：timing_page 的唯一保存入口是
  `SaveTimingRecordWithImpactUseCase`（`timing_page.dart:507`），**operation 管线
  （analyzer/command/redactor/preview 那 88 串）DI 接了但 UI 不渲染、也无审计历史 UI 展示**
  → 这些串当前**并非用户可见**（疑为 sync/未来 token-aware confirm 的地基）。真正用户可见的
  保存/删除反馈来自共享核心工具 **`lib/core/utils/store_feedback.dart`**（`'已保存'/'已删除'/
  `'$action失败：…'`），被 timing/fuel/device/maintenance/account **8 个 caller** 调用
  （action 传中文 '保存'6/'删除'3/'更新'1）。timing 的外协确认弹窗已 `l10n.*`。
  **故 S4b 真正第一片应改 `store_feedback.dart`（enum action + code→UI mapper），而非 operation 管线。**
- **✅ 第一片已完成（2026-06-24）action-toast 路径**：`store_feedback.dart` 的
  `StoreActionFeedback` 改为 code 型（`StoreActionKind` + `isSuccess` + `failureType` +
  `failureDetail` + `successOverrideText`，core 不含展示中文）；新增 UI mapper
  `lib/components/feedback/store_action_feedback_l10n.dart` 映射到 `AppLocalizations`；
  13 个 ARB key（zh+en）；迁 **7 个 caller**（fuel/timing/device/maintenance/account ×2 dialog
  + payment dialog 的 save/delete/update/deactivate toast）。等价测试绿（mapper 输出与旧
  '已保存'/'X失败：…' 逐字一致）。
- **✅ 第二片已完成（2026-06-24）view_data「读取」路径**：`store_feedback.dart` 现**完全 code 化、零中文**——
  删除 `storeErrorMessage`/`firstStoreErrorMessage`（String 版），新增 code 型 `firstStoreActionFailure`
  + `StoreActionKind.read`。view_data builder（fuel/maintenance/account）的 `error` 字段改为
  `StoreActionFeedback?`，由各 view（account_page_content / fuel_page / maintenance_page）用 mapper 本地化；
  in-view 直读（timing_page / device_page ×2 / account_rate_edit_actions）也迁到 code+mapper。
  等价测试绿（含 read 失败映射 '读取失败：…'）。**store_feedback i18n 全部收口**。
- **本片剩余 follow-up**：operation 管线那 88 串当前不可见，待其真正接 UI（token-aware confirm /
  审计历史）时再 i18n。
- 负责人：待确认（剩余 follow-up 建议专项执行）

## device 领域/application 层文案分离（S5b）

- 状态：⏳ 待处理（曾暂缓，2026-06-24 用户决定处理）
- 来源：Phase 2 device view-layer i18n
- 影响范围：`lib/features/device/domain/**`、`lib/features/device/application/**`
- 证据（~19 串）：`lifecycle_payback_calculator.dart`(9)、`device_action_controller.dart`(4)、
  `local_backup_controller.dart`(3)、`cloud_backup_controller.dart`(2)、`device_avatar_policy.dart`(1)
- **2026-06-24 scoping（精确计划，复用 store_feedback 已验证的 code→UI mapper 模式）**：分两类
  - **A. application 层 message（device_action / local_backup / cloud_backup controller）**：方法把
    `Future<String>`（中文）改返回**已有的 code/enum**（如 `device_action_controller.openRateApp`→`bool`、
    `openSupportEntry`→`SupportFeedbackOpenResult`；backup controller 的 restore-blocked reason→enum）；
    caller 在 view 层映射 `AppLocalizations` + ARB key。**坑：device_page_actions 的 static action 方法
    （openRateApp/openSupportPage）只收 `toast`/`isMounted`、无 l10n**，需把 l10n 穿透进这些 static 方法
    及其 caller（与 view_data 那次同型）。
  - **B. lifecycle_payback_calculator（最复杂）**：`LifecyclePaybackResult.statusText/resultText`
    含**插值金额/百分比**（'已回本 95.5%'、'预计盈余 ¥X'、'还差 ¥X 回本'），被 **5 个 device view**
    （lifecycle_payback_card / device_business_ledger_section / device_page / device_page_sections /
    lifecycle_amount_sheet）消费。改法：calculator 返回 **status code + 原始 paybackRate/profitFen**，
    各 view 用 ICU placeholder（百分比/金额）本地化。result 类型变更 ripple 到 5 view。
- **✅ S5b-A 部分完成（2026-06-24，3/4）**：`device_action_controller`（openRateApp→`bool`、
  openSupportEntry→新 `SupportEntryOutcome` enum，避免 view 直依赖 data 层 `SupportFeedbackOpenResult`，
  view 层 device_page_actions 映射 l10n）、`local_backup_controller.restoreBlockReason`→`RestoreBlockReason`
  enum（device_backup_dialogs 映射）、`device_avatar_policy` 抛 typed `CustomAvatarNotAllowedException`
  （device_editor_dialog catch→l10n）。ARB(zh+en) + check_full 绿。**剩 `cloud_backup_controller`（已全 trace，确认是 ~6 文件 sprawl，未做）**：3 处硬编码中文
  （`_defaultEntitlementRequiredMessage`、`unavailableMessage` 兜底 '云端备份服务暂未配置'、
  `device_fleet_providers.dart:114` 同串兜底）经**两个不同 result 字段**流向 UI——
  ① `errorMessage`（带 `errorCode` `cloud_backup_requires_pro`/`cloud_backup_not_configured`）在
  device_backup_dialogs **upload(:115)/list(:145)** 以 `result.errorMessage ?? l10n.fallback` 显示；
  ② **`BackupRestoreResult.message`** 在 `_showRestoreFailureDialog(:733)` 以 `'${result.message}…'` 显示，
  而该 dialog **本地+云端 restore 共用**——直接 null 掉云端 message 会破坏本地恢复路径，须分辨来源。
  另 `unavailableMessage` 直读 2 处（device_page:347、device_backup_dialogs:26）经 **nullable 参数链**
  穿 `device_account_center_page`（:43 nullable / :161 non-null / :118 `?? 兜底` / :256）。`availability.message`
  是 server `disabledMessage`（nullable）+ 构造期中文兜底。**clean 做法**：codes 公开 + 移除 controller/providers
  中文 + result 对结构化 code 不带中文 + 各展示点 errorCode→l10n（含共用 restore dialog 按来源分辨）+
  nullable 参数链补 l10n 兜底。涉及备份/恢复数据路径，须独立专项 + 充分回归，勿在长会话尾巴做。
- **风险/建议**：B（lifecycle ICU 金额，跨 5 view）+ cloud_backup（result errorMessage 流）建议**独立专项**做，
  勿在长会话尾巴大爆改。
- 负责人：待确认（建议专项 session）

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
