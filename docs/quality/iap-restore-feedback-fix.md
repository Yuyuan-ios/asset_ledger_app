# IAP「恢复购买无反应」修复 + 最终上线准备

> 状态：分析完成、IAP 线已整合进 `develop`（merge `7b5a49f`）。待办：① 恢复购买显式反馈修复（codex 执行 + 真机验证）② 一个独立的上线门禁阻断（`5a2f173` db 测试，见 §7）。
> 作者：Claude（分析/整合），执行交 codex。日期：2026-06-25。

---

## 1. 现象

- 账户中心（`AccountCenterPage`）点击「恢复购买」**没有任何可见反应**。
- 历史对比：在 `7438667`（bound restore timeout + pending state）那一版，点击恢复购买能显示错误文案「订阅服务端未返回有效授权」。到 `6f627af`（reuse signed transaction token for restore）后变成"无反应"。

## 2. 根因分析（静态分析，高置信度）

恢复购买的**唯一可见反馈通道**是账户状态卡片的副标题文字，由
[`_subscriptionEntitlementLabel`](../../lib/features/device/view/device_account_status.dart) 渲染，优先级为：

1. `subscription.errorMessage` 非空 → 显示该错误文案；
2. 否则 `isRestoring / isPurchasing / pending` → 显示「处理中」（`deviceUpgradeTransactionPending`）；
3. 否则 `allowsProFeatures` → 「Pro」，否则 → 「免费版」。

`SubscriptionService.restorePurchases()`（[subscription_service.dart](../../lib/data/services/subscription_service.dart)）流程：
先 `_setSnapshot(pending, isRestoring:true)` → 读 appAccountToken → `storeGateway.restorePurchases()`（带超时，超时返回空列表）→ `_handleRestorePurchaseUpdates`；若未恢复到任何订阅 → `fetchCurrentEntitlement()` → `_applyVerificationResult`。

**回归机制**：
- `7438667` 版：重装后本地 `appAccountToken` 是新 UUID，与历史交易 JWS 内的旧 token 不一致 → 后端 `verificationFailed` → reason「订阅服务端未返回有效授权」→ `errorMessage` 被置 → 副标题**显示错误**（用户看得到反馈）。
- `6f627af` 版：verify 改为优先从 StoreKit `serverVerificationData`（JWS payload）里读取交易自带的 `appAccountToken` 再请求后端，token 对齐 → **不再触发 token 不一致的 `verificationFailed`**。当恢复路径没有可激活的订阅时，回落到 `fetchCurrentEntitlement`（用本地 token，无交易），结果**无 errorMessage** → 副标题从「处理中」很快回到「免费版」。由于点击前后都是「免费版」，且没有任何 toast/dialog/snackbar，用户**感知为"无反应"**。

**结论**：这不是按钮坏了，而是"反馈被并入副标题文字、且这次没有错误可显示" → 没有任何显式提示。`6f627af` 本身是正确修复（消除了 token 不一致误报）。

**静态分析无法判定、需真机 + 后端日志确认的点**：用户的 Sandbox 账号是否真的存在一笔"应被恢复并激活 Pro"的订阅。
- 若有，而恢复返回空 → 说明 StoreKit restore 未投递 restored purchases / 超时过短 → 功能缺口；
- 若无，则"无反应→免费版"其实是正确行为，只是 UX 不可见。

> 本轮修复采用的策略（用户已确认）：**让恢复结果显式、不可错过**。屏幕直接显示结局（含 reason 文案），从而既根治"无反应"观感，又把"是否检测到购买"这一信息暴露在屏幕上，充当真机诊断面。本轮不单独加客户端诊断日志、不改后端代码。

## 3. 本次已完成：IAP 线整合进 develop

- IAP 全部代码 + 文档原本只在游离链 `6f627af`（基于 `38bb83d`），`develop` 领先 20 个 commit 且从未收到 IAP 工作。
- 两条线**改动文件零重叠**（dry-run merge 确认无冲突），已 `--no-ff` 合并进 `develop`（merge commit `7b5a49f`）。
- 整合后 IAP 自身验证全绿：IAP Dart 测试 44 项通过；IAP 后端 Python 测试 38 项通过；`custom_lint` 无新增问题。
- 唯一遗留红：`develop` 自带的 `5a2f173` db 测试断裂（与 IAP 无关，见 §7）。

## 4. 修复方案（交 codex 执行）

目标：恢复购买结束时，**在用户当前可见的页面**弹出一条明确、本地化、不可错过的结果提示；同时恢复进行中禁用入口并转圈。**不改后端、不改 `6f627af` 的 token 对齐逻辑。**

### 4.1 结果模型
在 `subscription_service.dart` 新增结果枚举/值对象（建议 `enum SubscriptionRestoreOutcome { restoredPro, restoredMax, noActivePurchase, failed, unavailable }` + 可选 `reason`），由 `restorePurchases()` 在结束时**根据最终 snapshot 派生**返回：
- 最终 `allowsMaxFeatures` → `restoredMax`；
- 否则 `allowsProFeatures` → `restoredPro`；
- 否则 `errorMessage` 非空 → `failed`（reason = errorMessage，已是本地化文案，如「订阅服务端未返回有效授权」）/或 `unavailable`（如 reason 含"暂不可用/同步请求失败"）；
- 否则 → `noActivePurchase`（未发现可恢复购买）。

`restorePurchases()` 由 `Future<void>` 改为 `Future<SubscriptionRestoreOutcome>`；保持现有 notifier/副标题（pending、错误文案）行为不变（**additive**）。

### 4.2 入口签名 + 反馈位置（关键）
- `SubscriptionController.restorePurchases()` 透传返回 `Future<SubscriptionRestoreOutcome>`。
- **恢复是从 `AccountCenterPage`（被 push 的路由）触发的，handler `_restorePurchases` 却在 `device_page.dart`。** 若在 device_page 的 context 弹 SnackBar，会落在被遮挡的下层页面 → 看不见。所以：
  - `AccountCenterPage.onRestorePurchases` 类型改为 `Future<SubscriptionRestoreOutcome> Function()`；
  - 账户中心的「恢复购买」tile `onTap` 里 `await onRestorePurchases()`，再用**账户中心自己的 context**（`ScaffoldMessenger.of(context)`）弹本地化 SnackBar（或居中 dialog）。
  - `upgrade_page.dart` 的恢复入口同样在本页 context 展示结果。
- 恢复进行中：账户中心 tile 与升级页恢复按钮在 `snapshot.isRestoring` 时禁用并显示转圈（账户中心 tile 当前是无条件可点，需补 busy 态）。

### 4.3 文案（新增 l10n key，zh + en，跑 `flutter gen-l10n`）
| key | zh | en |
|---|---|---|
| `deviceRestoreResultRestoredPro` | 已恢复 Pro 订阅 | Pro subscription restored |
| `deviceRestoreResultRestoredMax` | 已恢复 Max 订阅 | Max subscription restored |
| `deviceRestoreResultNoPurchase` | 未发现可恢复的购买 | No purchases to restore |
| `deviceRestoreResultFailed`(reason) | 恢复失败：{reason} | Restore failed: {reason} |
| `deviceRestoreResultUnavailable`(reason) | 订阅服务暂不可用：{reason} | Subscription service unavailable: {reason} |

（文案可微调；保持中英一致、reason 占位用 ICU placeholder。）

### 4.4 测试
- 单元：`restorePurchases()` 在五种 snapshot 终态下返回正确 outcome（扩 `subscription_service_test.dart`，复用已有 fake gateway / repository）。
- Widget：账户中心点击恢复购买后，针对每种 outcome 断言出现对应 SnackBar 文案；并断言 `isRestoring` 时入口禁用（扩 `device_account_center_page_test.dart`）。
- 全绿门禁见 §6 与 §8。

## 5. CODEX PROMPT（自包含，可直接投喂）

```
你在 fleet_ledger_app（Flutter）develop 分支上工作。任务：修复"账户中心点击恢复购买无任何反应"，做法是让恢复购买的结果显式、不可错过。不要改后端，不要改 6f627af 的 JWS appAccountToken 对齐逻辑。

背景（务必先读）：docs/quality/iap-restore-feedback-fix.md。根因：恢复反馈只并入账户状态副标题文字；6f627af 对齐 token 后不再有 token 不一致错误，恢复无可激活订阅时副标题静默回到"免费版"，没有任何 toast/dialog → 用户感知"无反应"。

实现要求：
1. lib/data/services/subscription_service.dart：
   - 新增 enum SubscriptionRestoreOutcome { restoredPro, restoredMax, noActivePurchase, failed, unavailable }，可携带 String? reason（用值对象包一层亦可）。
   - restorePurchases() 由 Future<void> 改为 Future<SubscriptionRestoreOutcome>，在方法结束时按最终 snapshot 派生 outcome：allowsMaxFeatures→restoredMax；allowsProFeatures→restoredPro；errorMessage 非空→failed/unavailable(reason=errorMessage)；否则→noActivePurchase。
   - 保持现有 notifier/副标题（pending、错误文案、isRestoring）行为完全不变（additive）。catch 分支也要返回 outcome（failed，reason=已有错误文案）。
2. lib/features/device/application/controllers/subscription_controller.dart：restorePurchases() 透传返回 Future<SubscriptionRestoreOutcome>。
3. lib/features/device/view/device_account_center_page.dart：
   - onRestorePurchases 类型改 Future<SubscriptionRestoreOutcome> Function()。
   - 「恢复购买」tile：onTap 里 await 结果，用本页 ScaffoldMessenger.of(context) 弹本地化 SnackBar；恢复进行中（subscription.isRestoring）禁用该 tile 并显示转圈（loading）。注意必须用账户中心自己的 context（它是被 push 的页面），不能用 device_page 的 context，否则 SnackBar 落在被遮挡的下层页看不见。
4. lib/features/device/view/device_page.dart + upgrade_page.dart：_restorePurchases 透传返回值；升级页恢复入口也在本页 context 展示同样的结果反馈。
5. l10n：在 lib/l10n/app_zh.arb 与 app_en.arb 新增（见 doc §4.3 的 5 个 key，failed/unavailable 带 {reason} ICU 占位），运行 flutter gen-l10n。
6. 测试：
   - 扩 test/data/services/subscription_service_test.dart：五种终态各断言 restorePurchases() 返回正确 outcome。
   - 扩 test/features/device/view/device_account_center_page_test.dart：每种 outcome 点击恢复后断言对应 SnackBar 文案出现；断言 isRestoring 时 tile 禁用。

门禁（注意 develop 当前有一处与本任务无关的预存 analyze 红：5a2f173 的 db migration 测试引用了已删方法，见 doc §7；先不要去碰它）：
- flutter analyze lib test/data/services test/features/device test/features/upgrade_page_iap_define_test.dart  → 0 issue（限定到 IAP 相关路径，绕开预存的 db 测试红）
- dart run custom_lint  → 无新增
- flutter test --no-pub test/data/services/subscription_service_test.dart test/features/device/view/device_account_center_page_test.dart test/features/upgrade_page_iap_define_test.dart  → 全绿
- 改完不要提交，等人工审计 + 真机验证后再决定合并。
```

## 6. 真机测试步骤（订阅闭环）

前置：`develop`（含本修复）构建 release 装到 iPhone；登录测试账号；准备 Sandbox 测试账号。

1. **恢复购买—显式结果**：账户中心 → 恢复购买。期望：进行中 tile 转圈/禁用；结束弹出 SnackBar，文案为 {已恢复 Pro/Max | 未发现可恢复的购买 | 恢复失败：<reason> | 订阅服务暂不可用：<reason>} 之一。**绝不再无反应。**
2. **购买闭环**：升级页 → 购买 Pro（Sandbox）→ 完成后账户状态变 Pro，云端备份解锁。
3. **重装后恢复**：删除 App 重装 → 登录同账号 → 恢复购买 → 期望 `restoredPro/Max`（验证 `6f627af` JWS token 对齐生效）。
4. **后端日志对照**（如某步结果异常）：用 computer-use 登到 ECS，看 `fleet-ledger-iap` 的脱敏诊断日志（`e147e3b`）里的 reason / status，与屏幕结果对照。典型可见 reason 例：`transaction appAccountToken does not match request`（若仍出现，说明 token 仍未对齐）。
5. 若步骤 1 在"确有 Sandbox 订阅"的情况下仍报"未发现可恢复的购买" → 转入功能缺口排查（StoreKit restore 投递 / `_restoreGatewayTimeout` 时长），单独立项。

## 7. 独立上线门禁阻断：`5a2f173` db 测试断裂（与 IAP 无关）

`develop` 顶部 commit `5a2f173 feat(db): allow duplicate active legacy keys` 把
`DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness` 改名为
`dropActiveScopedLegacyProjectKeyUniqueness`（v54 删除 partial unique index），但**遗留 7 处旧名引用**：
- `test/data/db/migrations/migration_021_upgrade_path_test.dart`（6 处）
- `test/data/services/project_resolver_sqflite_test.dart`（1 处）

后果：`flutter analyze`（test 范围）报 7 个 `undefined_method`，相关测试无法编译 → `check_full` 红。`lib` 生产代码干净，**不影响真机 build / `flutter run`**，只挡全量测试门禁。

**为什么不顺手修**：不是机械改名。`Migration021.ensureActiveScopedLegacyProjectKeyUniqueness` 仍**创建**索引并对旧库做表重建，而 `Migration054` 是**删除**索引、`ProjectSchema` 不再创建；这些 upgrade-path 测试断言的是旧的"重建 + 建索引"语义。正确修法取决于 v54 之后这些迁移测试应断言什么（是否仍重建旧列级 UNIQUE 表、是否改断言 duplicates 允许），属 db 迁移设计判断，应由清楚 v54 意图的人单独处理。

**建议**：单开一个聚焦任务（`fix(db): realign v54 drop-uniqueness tests`），把 7 处引用与断言改到 v54 语义，跑 `flutter analyze lib test` + 相关迁移测试转绿。上线前必须清掉。

## 8. 最终上线准备清单

- [x] IAP 线整合进 `develop`（merge `7b5a49f`，零冲突，IAP 测试全绿）
- [ ] 恢复购买显式反馈修复（§5 codex prompt）→ 人工审计
- [ ] **真机验证订阅闭环**（§6 全部步骤通过）
- [ ] 清除 `5a2f173` db 测试断裂（§7）→ 全量 `bash tools/agent/check_full.sh` 转绿
- [ ] 上线运维闸（见 `docs/quality/codex-prompts-p4.md` 的 go-live checklist）：App Store Connect 密钥就位、`fleet-ledger-iap` 部署且 nginx 路由（`/fleet-ledger/iap/{healthz,apple/verify-purchase,apple/current-entitlement}`）通、Sandbox Pro/Max smoke
- [ ] `develop` → `main` FF 发布
