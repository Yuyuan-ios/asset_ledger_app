# Codex 执行 Prompt — Debt-0 + Phase 1（架构边界收口，基线 dev = P0 tip）

> 配套：`docs/quality/execution-roadmap-dev-36d42f0.md`、`docs/architecture/layers.md`、
> `docs/architecture/date-timezone-rules.md`、`docs/operations/tech-debt.md`。
> 写作遵循 `docs/agent/prompt-style.md`（目标 / 范围 / 限制 / 验证 / 报告）。

## A. 本批次授权与硬限制（执行前必读，只写一次）

**用户已显式授权（覆盖 `docs/agent/codex-execution-contract.md` 的 no-auto-advance，仅限本批次 Debt-0 → P1-S5）：**

- ✅ **自动连跑 Debt-0 → P1-S0 → … → P1-S5**：每切片实现完成且验证全绿后自动 commit 并进入下一个。
- ✅ 分支：开工 `git switch -c feature/p1-arch-boundary`（基于当前 `dev` tip）。每切片一个 commit，
  message 见各切片末尾，结尾加 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。
- 🛑 **P1-S5 完成后强制 STOP，交人工审计。P1-S6 / P1-S7（patterns→data/models，15 文件）
  须人工放行后才执行**（高 churn、价值可议）。

**硬限制（全程有效）：**

- ❌ 不 push / merge / release / 发布。
- ❌ 任一切片验证红灯、或 GitNexus 影响分析 HIGH/CRITICAL、或遇需产品决策的问题 →
  **立即停止**，保留现场，报告，等人工。
- ❌ 重构切片必须**行为不变**：只做迁移/接线/抽接口，不改业务语义；若某切片的 diff 不是
  机械迁移而牵动逻辑 → 停下报告。DB 异常不得吞成静默成功。
- ❌ 不动 DB schema/migration（本批次不涉及）；不加依赖；不改 `$HOME/.agents`；不提交密钥。
- 🛑 git 实际状态与本文件假设冲突（不是 dev tip、worktree 不干净）→ 先停下报告。

**GitNexus（CLAUDE.md 强制，针对 Dart 符号）：** 改某 Dart 函数/类/方法前跑
`gitnexus_impact({target, direction:"upstream"})` 报告 blast radius；提交前 `gitnexus_detect_changes()`。
**Debt-0 是 Python 后端，不在 GitNexus（Dart）索引内** → 用严格 ResourceWarning + 单测验证替代符号影响分析。

**computer use / 后端：** 本批次后端验证均本地 `python -m unittest`，**不需要远程服务器，不用 computer use。**

## B. 全局前置（只写一次）

1. 仓库 `/Users/yu/Flutter_Projects/fleet_ledger_app`，起始分支 `dev`。先 `git status --short`（干净）、
   `git rev-parse --short HEAD`（dev tip）。本计划文档若未提交，带到 feature 分支在 P1-S0 一并提交。
2. 必读：`AGENTS.md`、`docs/architecture/layers.md`、`tools/check_architecture.sh`、
   `lib/features/sync/sync_conflict_review_controller.dart`、
   `lib/features/timing/operations/save_timing_record_operation_analyzer.dart`。
3. 验证命令集（按切片取相关子集）：`bash tools/agent/check_fast.sh`、
   `bash tools/agent/check_full.sh`、`bash tools/check_architecture.sh`、
   两后端 `python3 -m unittest discover -s tests`。

## C. 自动连跑循环（Debt-0 → S0 → S5）

```
对 slice in [Debt-0, S0, S1, S2, S3, S4, S5]:
  1. 实现范围内改动（高风险切片先写 characterization 测试再改实现）
  2. 跑该切片“验证”命令；重构切片必须跑 check_full
  3. 全绿 → commit → 自动进入下一个；红灯/HIGH 影响/需产品决策 → 停止并报告
S5 完成后：跑收口（check_full + check_architecture + 两后端单测）→ STOP，出报告，等人工。
S6/S7 不在自动范围，待人工放行。
```

---

## D. 切片 Prompt

### Debt-0 — 后端 sqlite 连接关闭（清 ResourceWarning）

- **目标**：消除两后端 `ResourceWarning: unclosed database`，**不改任何 API / 响应 / 事务行为**。
- **范围**：`server/cloud_sync_backend/app.py`、`server/cloud_backup_backend/app.py`（仅连接生命周期）。
- **修法**：把 `with self._connect() as conn:` 改为同时**关闭**且**保留事务**，例如
  ```python
  from contextlib import closing
  with closing(self._connect()) as conn:
      with conn:            # 保留原有 commit/rollback 事务语义
          ...
  ```
  ⚠️ **关键footgun**：原 `with self._connect() as conn:` 的 `with` 是 sqlite3 **事务** CM（成功 commit、
  异常 rollback），**不关闭连接**。只套 `closing` 而丢掉内层 `with conn:` 会**丢失隐式 commit → 写入不落库**。
  必须两者都保留。已显式 `finally: conn.close()` 的地方维持即可。
- **限制**：不改鉴权/限流/错误响应/print；不改测试断言；不动 Flutter 端。
- **验证**：两后端
  `python3 -W error::ResourceWarning -m unittest discover -s tests` **无 ResourceWarning 输出**且
  分别 21 / 30 通过（写入类用例必须仍绿，确认事务未丢）。
- **commit**：`fix(server): close sqlite connections to clear ResourceWarning`
- 修完更新 `docs/operations/tech-debt.md` 该条状态为「已修」。

### P1-S0 — 架构违规清单（只盘点不修）

- **目标**：登记 features→DB 直连 与 patterns→data/models 现存违规，作后续切片索引。
- **范围**：新增 `docs/quality/p1-arch-violations.md`。
- **内容**：① `lib/features/sync/sync_conflict_review_controller.dart` 的 `AppDatabase.database` + 裸 SQL；
  ② `lib/features/timing/operations/save_timing_record_operation_analyzer.dart` 直引 `AppDatabase`；
  ③ 15 个 `lib/patterns/**` import `data/models`（逐文件列出，并按 **A 展示字段 / B 业务判断 / C 序列化** 分类）。
- **限制**：不改任何 lib/test。
- **验证**：文件存在；`bash tools/agent/check_fast.sh` 通过。
- **commit**：`docs(quality): inventory Phase 1 architecture violations`

### P1-S1 — sync conflict reader 行为锁定（characterization）

- **目标**：为 `LocalTimingConflictSummaryReader` 增 characterization 测试，锁定空状态、排序、异常、
  字段缺失、remote 删除等现有行为，作为 S2/S3 迁移的安全网。
- **范围**：`test/` 新增；**不改 lib**。
- **验证**：新测试通过；`bash tools/agent/check_full.sh` 绿。
- **commit**：`test(sync): characterize LocalTimingConflictSummaryReader behavior`

### P1-S2 — controller 依赖 TimingConflictSummaryReader 接口

- **目标**：`SyncConflictReviewController` 依赖既有抽象 `TimingConflictSummaryReader`，由 provider 注入
  具体实现；controller 不再直接 new 具体 reader。
- **范围**：`lib/features/sync/sync_conflict_review_controller.dart` + provider 接线。
- **限制**：行为不变；**本切片不动 DB 访问本身**（留给 S3）。
- **GitNexus**：impact on `SyncConflictReviewController`。
- **验证**：S1 测试 + `check_full` 绿。
- **commit**：`refactor(sync): inject TimingConflictSummaryReader via interface`

### P1-S3 — DB reader 实现移出 feature 层

- **目标**：把 `LocalTimingConflictSummaryReader`（含 `AppDatabase.database` + 裸 SQL）从
  `lib/features/sync` 迁到 `lib/data` 或 `lib/infrastructure`；provider 注入新位置；
  `lib/features/sync` 不再出现 `AppDatabase.database`。
- **范围**：移动该类 + provider 接线 + import 调整。
- **限制**：行为不变（S1 测试护航）；纯位置迁移 + 接线，不改查询逻辑。
- **步骤**：复制到新位置 → provider 改注入 → 删旧 → `grep` 确认。
- **GitNexus**：impact on `LocalTimingConflictSummaryReader`。
- **验证**：`grep -rn "AppDatabase.database" lib/features/sync/` 为空；S1 测试 + `check_full` 绿。
- **commit**：`refactor(sync): move conflict summary DB reader out of feature layer`

### P1-S4 — 收敛 save_timing_record_operation_analyzer 的 DB 依赖（钱路径，高风险）

- **目标**：`save_timing_record_operation_analyzer` 不再直连 `AppDatabase`；改依赖一个 read-model 接口，
  data 层实现 adapter。
- **范围**：`lib/features/timing/operations/save_timing_record_operation_analyzer.dart` + 新接口 + data adapter + provider。
- **限制**：**这是保存（钱）路径，务必行为不变**——先写保存/更新/跨日期/异常 characterization 测试，
  再抽接口，再迁移；不改保存语义；DB 异常不得吞成静默成功。
- **GitNexus**：impact on analyzer 的 compute/analyze 方法；**若 HIGH/CRITICAL → 停下报告，不擅自继续**。
- **验证**：新增 analyzer characterization 测试 + `grep -rn "AppDatabase" lib/features/timing/operations/` 无直连
  + `check_full` 绿。
- **commit**：`refactor(timing): converge save analyzer DB access behind read-model interface`

### P1-S5 — guard 禁 features 直连 DB

- **目标**：扩 `tools/check_architecture.sh`，禁止 `lib/features/**` 依赖 `AppDatabase` / `data/db/` / `sqflite`；
  合法的 feature-domain repository **接口**不误杀。
- **范围**：`tools/check_architecture.sh` + `test/tools/check_architecture_failure_behavior_test.dart`（加“故意违规→脚本非零退出”行为测试）。
- **限制**：新规则不得误杀现有合法代码（确保 S3/S4 已清零后再开）。
- **验证**：`bash tools/check_architecture.sh` 绿；新增 failure-behavior 测试通过；`check_full` 绿。
- **commit**：`build(arch): guard against features depending on AppDatabase/db`
- **→ 收口后 STOP，出报告，等人工审计。**

### P1-S6 / P1-S7 — patterns→data/models（**需人工放行**）

- **状态**：S5 人工审计通过后再决定是否执行（15 文件、高 churn、价值可议）。
- **P1-S6**：按 S0 清单的 A/B/C 分类分批（每批 1–3 文件）把 `lib/patterns/**` 对 `data/models` 的依赖
  收敛（A 展示字段抽 view-model 字段、B 业务判断上移 feature 层、C 序列化移出 patterns）；行为不变。
- **P1-S7**：清零后扩 `tools/check_architecture.sh` 禁 `lib/patterns→data/models` + failure-behavior 测试。
- 执行前重读本节并由人工确认范围。

## E. 最终精简总结报告格式

```
# Debt-0 + Phase 1（S0–S5）执行总结（feature/p1-arch-boundary）
- 仓库/分支 / 起始 HEAD(dev tip) / 结束 HEAD
- 切片结果表：| 切片 | 状态(绿/停) | commit | 关键验证输出 | GitNexus 影响 |
- ResourceWarning：修复后严格模式是否无告警 + 21/30 是否仍绿（事务未丢）
- features→DB：grep 确认 sync / timing operations 已无 AppDatabase 直连
- 新 guard：是否生效 + failure-behavior 测试是否通过
- 收口：check_full / check_architecture / 后端 21·30 = 绿/红
- 是否改 lib / test / server / schema / pubspec / $HOME/.agents / 密钥
- 是否 commit（逐切片）/ 是否 push（否）
- 风险 / 遗留；S6/S7 是否建议执行
```

报告精简、结构化；**不**自动进入 S6/S7，**不** push/merge。
