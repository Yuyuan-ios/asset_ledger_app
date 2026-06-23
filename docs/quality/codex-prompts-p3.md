# Codex 执行 Prompt — Phase 3（维护性治理：拆大文件，行为不变）

> 配套：`docs/quality/execution-roadmap-dev-36d42f0.md`、`docs/architecture/layers.md`。遵循 `docs/agent/prompt-style.md`。
> 基线 dev = Phase 2 tip。原则：**行为不变，不混入新功能**；每个拆分只做机械迁移，不做语义优化。

## A. 授权与硬限制（执行前必读，只写一次）

**用户已授权自动连跑 P3-S1 → P3-S5（覆盖 codex-execution-contract 的 no-auto-advance）：**

- ✅ 顺序自动连跑：**S1（sync app.py）→ S2（backup app.py）→ S3（account_page）→ S4（device_page）→ S5（sync_manager）**。
  每切片全绿 → 自动 commit → 下一个。收尾出报告交人工审计。
- ✅ 分支：`git switch -c feature/p3-maintainability`（基于 dev=Phase 2 tip）。每切片一 commit，
  结尾加 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。
- 🛑 **S5 后强制 STOP，交人工审计。`backup_validator.dart`（S6）覆盖薄，须人工放行后单独做（characterization 先行）。**

**拆分切片的 gate（本批次规则，覆盖“HIGH→停”）：**

- 对**纯机械拆分（行为不变）**，**忽略 GitNexus HIGH**（大/中心文件的 HIGH 是中心度，不是风险）。
- 真正的停条件改为以下任一：
  (1) **公开 API / facade / 导出符号发生变化**（拆分应是内部重组：原文件留作 facade/barrel，对外签名不变）→ 停。
  (2) diff **不是机械搬迁**而动了业务逻辑/判断/顺序/异常处理 → 停。
  (3) 既有或新增 characterization 测试变红 → 停。
  (4) GitNexus `CRITICAL`，或触及 save/sync/settlement/backup **正确性语义** → 停下报告。
- 仍跑 `gitnexus_impact`/`gitnexus_detect_changes`（仅记录，不因 HIGH 停）。后端为 Python，用 unittest 验证。

**通用硬限制：** 不 push/merge/release；不改 DB schema/migration；不加依赖；不改测试断言（只在拆分要求时
新增/迁移测试，且不弱化断言）；不动 `$HOME/.agents`；不提交密钥；不用 computer use（后端本地 unittest 即可）。

## B. 全局前置（只写一次）

1. dev = Phase 2 tip，工作区干净。必读 `docs/architecture/layers.md`。
2. 验证命令：`bash tools/agent/check_full.sh`（卡 SDK cache 则跑等价四原子命令：analyze / run_custom_lint_isolated.sh /
   `flutter test --no-pub` / `git diff --check`）、`bash tools/check_architecture.sh`、两后端
   `python3 -m unittest discover -s tests`（含 `-W error::ResourceWarning`）。
3. **拆分通用顺序**：先确认既有测试锁住行为 → 抽纯函数/配置/helper 等低风险部分 → 再抽高风险部分 →
   原文件留作 facade。每切片结束跑对应验证；阶段收口跑 check_full。

## C. 自动连跑循环（S1 → S5）

```
对 slice in [S1, S2, S3, S4, S5]:
  1. 机械抽取（原文件保留为 facade/bootstrap；新建子模块/子 widget）
  2. 跑验证（Dart 切片必跑 check_full；后端切片跑对应 unittest）
  3. 公开 API 不变 + 测试全绿 + diff 机械 → commit → 下一个；否则停下报告
S5 后收口（check_full + check_architecture + 后端 26/33）→ 报告，停止，等人工。S6 待人工放行。
```

---

## D. 切片 Prompt

### P3-S1 — 拆 `server/cloud_sync_backend/app.py`（1108 行）

- **目标**：按职责拆模块，`app.py` 留作 bootstrap + 兼容 re-export。行为/HTTP 协议不变。
- **范围**：`server/cloud_sync_backend/`（新增模块文件）+ 必要时 `tests/`（仅调整 import）。
- **拆法（参考）**：`config.py`（env/常量）、`http_helpers.py`（json/error response、read body）、
  `auth.py`（Authenticator/introspection）、`rate_limit.py`（SlidingWindowRateLimiter）、
  `storage.py`（sqlite 仓库/连接，沿用 `with closing(...) as conn: with conn:` 事务）、
  `handlers.py`（请求处理）、`app.py`（HTTPServer 装配 + bootstrap）。
- **限制**：`from app import X` 必须仍可用（app.py re-export 已迁符号）→ 既有测试不改断言即绿；
  不改限流/鉴权/响应逻辑。
- **验证**：`cd server/cloud_sync_backend && python3 -W error::ResourceWarning -m unittest discover -s tests`（26 绿，无告警）。
- **commit**：`refactor(sync-server): split app.py into config/auth/storage/rate_limit/handlers modules`

### P3-S2 — 拆 `server/cloud_backup_backend/app.py`（1062 行）

- **目标**：同 S1 的拆法（含 `logging`/redaction 归入 `http_helpers`/`observability` 模块），`app.py` 留 bootstrap+re-export。
- **范围**：`server/cloud_backup_backend/`。
- **验证**：`python3 -W error::ResourceWarning -m unittest discover -s tests`（33 绿，敏感字段不入日志的测试仍绿）。
- **commit**：`refactor(backup-server): split app.py into focused modules`

### P3-S3 — 拆 `lib/features/account/view/account_page.dart`（1208 行）

- **目标**：抽 section widget，`account_page.dart` 留作组合。布局/状态/文案不变。
- **范围**：`lib/features/account/view/**`（新增 widgets 子文件）+ 必要测试 harness。
- **拆法（参考）**：header、subscription、backup/sync、settings、dialogs 各抽为独立 widget。
- **限制**：不改业务流/provider 接线/显示文案；纯 widget 抽取；公开入口 `AccountPage` 签名不变。
- **GitNexus**：impact 记录（预期 HIGH=中心 UI），不因 HIGH 停。
- **验证**：`bash tools/agent/check_full.sh` 绿（account_page 既有 4 个 widget/view 测试仍绿）。
- **commit**：`refactor(account): extract account_page sections into widgets`

### P3-S4 — 拆 `lib/features/device/view/device_page.dart`（1168 行）

- **目标**：同 S3 思路，抽 list/form/status/actions/dialogs/validation 子 widget。**不顺手改设备业务流**。
- **范围**：`lib/features/device/view/**`。
- **验证**：`check_full` 绿（device 既有 widget/l10n 测试 + migrated CJK guard 仍绿）。
- **commit**：`refactor(device): extract device_page sections into widgets`

### P3-S5 — 拆 `lib/infrastructure/sync/sync_manager.dart`（865 行）

- **目标**：`sync_manager` 保持 **facade**（公开方法签名不变）；把 push/pull/retry/conflict/terminal-failed
  抽为内部 coordinator/helper。同步行为不变。
- **范围**：`lib/infrastructure/sync/**`。
- **限制**：**这是 sync 正确性核心**——纯机械抽取，不改 push 顺序/ack-retry/outbox folding/conflict/readiness 逻辑；
  原 `SyncManager` 公开 API 与行为不变（由既有 readiness/outbox-folding/dry-run/push-gate 等专测护航）。
- **GitNexus**：impact 记录；若 detect 显示触及同步语义而非机械抽取 → 停下报告。
- **验证**：`check_full` 绿（全部 sync_manager 相关专测仍绿）；`check_architecture` 绿。
- **commit**：`refactor(sync): extract sync_manager coordinators behind facade`
- **→ 收口后 STOP，出报告，等人工审计。**

### P3-S6 — 拆 `backup_validator.dart`（965 行）（**需人工放行**）

- **状态**：覆盖薄（仅 1 处间接测试），**不在自动批**。人工审计 S1–S5 后再放行。
- **要求**：**characterization 先行**——先为 schema/version、金额(fen)/日期、引用完整性、错误聚合各类规则补测试
  并锁住当前行为，**再**按规则类拆分；备份校验错误信息与行为不变。
- 执行前重读本节并由人工确认。

## E. 最终精简总结报告格式

```
# Phase 3（S1–S5）执行总结（feature/p3-maintainability）
- 仓库/分支 / 起始 HEAD / 结束 HEAD
- 切片结果表：| 切片 | 状态(绿/停) | commit | 原文件→新结构 | 公开 API 不变? | 验证 |
- 后端：app.py 拆分后 from app import 仍可用、26/33 绿、严格 ResourceWarning 无告警
- UI：account_page/device_page 既有 widget 测试仍绿、显示不变
- sync_manager：facade 签名不变、sync 专测全绿
- 收口：check_full / check_architecture / 后端 = 绿/红
- 是否改 lib/test/server/schema/pubspec/密钥；是否 commit（逐切片）/ push（否）
- 风险/遗留；S6(backup_validator) 是否建议放行
```

报告精简、结构化；**不**自动进入 S6，**不** push/merge。
