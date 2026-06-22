# Codex 执行 Prompt — Phase 0（远端门禁恢复，基线 dev@36d42f0）

> 配套路线图：`docs/quality/execution-roadmap-dev-36d42f0.md`。
> 本文件每个小节是一个 **FINAL_CODEX_PROMPT**，按 P0-S0 → P0-S6 顺序执行。
> 写作遵循 `docs/agent/prompt-style.md`（目标 / 范围 / 限制 / 验证 / 最终报告）。

---

## A. 本批次授权与硬限制（Codex 执行前必读，只写一次）

**用户已显式授权（覆盖 `docs/agent/codex-execution-contract.md` 的相应条款，仅限本 P0 批次）：**

- ✅ **P0 内自动连跑**：P0-S0 → P0-S6 逐切片执行；每切片完成且其验证命令全绿后，
  **自动提交并进入下一个切片**，无需等待人工点头。此授权**仅覆盖 contract §1/§4 的
  “不自动进入下一阶段 / 测试通过不授权下一阶段”**，且**仅限 P0-S0..S6**。
- ✅ **分支与提交**：执行前新建并切到分支 `feature/p0-ci-restore`（基于当前 `dev`）。
  **每个切片一个 commit**（信息见各切片末尾），commit message 末尾加
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。

**以下硬限制仍然全部有效，不得逾越：**

- ❌ 不 `push`、不 `merge`、不 `release`、不发布。
- ❌ 不扩大范围；不为了让测试过去改无关模块；不动 `lib/` 业务逻辑、UI、DB schema/migration、
  测试断言（P0 全是 CI/文档改动，不应触碰这些）。
- ❌ 不改 `$HOME/.agents`；不提交密钥/私有配置；不新增依赖。
- 🛑 **任一切片的验证命令红灯、或出现需要产品决策的问题：立即停止，不再自动前进，
  保留现场，在最终报告里说明，等待人工。**
- 🛑 若执行时实际 git 状态与本文件假设冲突（不是 `dev`、工作区不干净），先停下报告。

**后端验证 / computer use：**
P0 全部切片的后端校验都在本地（`python -m unittest`）或 CI 内完成，**不需要远程服务器**。
仅当后续 Phase 4 smoke 切片确需访问真实后端时，才使用 computer use 在用户**已登录的
远程服务器**上操作。P0 阶段不触发 computer use。

---

## B. 全局前置（只写一次，不在每个切片重复）

1. 仓库：`/Users/yu/Flutter_Projects/fleet_ledger_app`，起始分支 `dev`。本计划文档
   （roadmap / 本 prompt / tech-debt / AGENTS）**已提交在 `dev`**，工作区应为干净。
   - 先 `git status --short` + `git rev-parse --short HEAD` 确认：工作区干净；HEAD 为
     dev 当前 tip（计划 docs 提交，位于 `36d42f0` 之上，代码层等价 36d42f0）。
   - 若工作区含**任何未提交改动**：停下报告，不自动前进。
2. 建分支：`git switch -c feature/p0-ci-restore`（基于 dev tip）。
3. 必读：`AGENTS.md`、`docs/quality/execution-roadmap-dev-36d42f0.md`、
   `.github/workflows/flutter.yml`、`tools/agent/check_fast.sh`、`tools/check_architecture.sh`、
   `tools/run_custom_lint_isolated.sh`。
4. 目标 CI 拓扑见路线图 §4.1：两个并行 job —— `flutter-verify`（Flutter）与
   `backend-verify`（独立 `setup-python`）。后端 job 必须独立装 Python。
5. **本地等价验收**：CI 无法在本机真触发，故每个 CI 切片必须 (a) 本地跑通对应命令，
   (b) `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/flutter.yml'))"` 校验 YAML。

---

## C. 自动连跑循环协议（每个切片都按此执行）

```
对 slice in [S0, S1, S2, S3, S4, S5, S6]:
    1. 实现该切片的范围内改动
    2. 跑该切片“验证”小节列出的全部命令
    3. 若全绿:
         - git add <范围内文件> && git commit（该切片 commit message）
         - 记录该切片结果，自动进入下一个切片
       若有红灯 / 需产品决策:
         - 停止，不再前进；保留现场；进入最终报告，标注失败切片与原因
    4. S6 完成后:跑一次完整收口(check_full + check_architecture + 两套后端 unittest)
                  并产出最终精简总结报告
```

---

## D. 切片 Prompt

### P0-S0 — 建立基线证据档案

- **目标**：把 `dev@36d42f0` 复核结论固化为后续 PR 的共同基线证据，不夸大生产能力。
- **范围**：仅新增 `docs/quality/baseline-dev-36d42f0.md`。
- **内容要求**（如实记录，不得改成“已生产闭环”）：
  - 基线：`dev@36d42f0`，工作区干净。
  - 复核评分 6.5/10：适合稳定开发基线，**不**适合宣称完整商业化生产闭环。
  - 本地门禁：`check_fast` / `check_architecture` / `check_full` 全绿；Flutter 测试 `+2272 ~3 skipped`。
  - 后端单测：cloud_sync_backend 21、cloud_backup_backend 30，全绿。
  - 远端门禁脱节：`flutter.yml` 仅 analyze + 单个 IAP define 测试；其余被注释；只在 main/master 触发。
  - 阻断生产声明的四条能力（如实写其当前真实状态）：
    live sync（hard-gate `real-cloud-transport-not-configured` + delete-meta/terminal-failed deferred）；
    driver entry（纯领域骨架，无 concrete 实现/无表/无 deep link）；
    native update（`inAppUpdateLauncher: null`，仅 URL fallback）；
    IAP 服务端校验（配置门控、未做 sandbox smoke，已 fail-closed）。
- **限制**：不改任何代码 / workflow / 测试；纯文档新增。
- **验证**：文件存在；`bash tools/agent/check_fast.sh` 通过。
- **commit**：`docs(quality): add dev@36d42f0 baseline evidence file`

### P0-S1 — 恢复 dev 触发 + concurrency

- **目标**：让 `dev` 的 push / PR 会触发 CI，并加并发取消。
- **范围**：仅 `.github/workflows/flutter.yml`。
- **改动**：`on.push.branches` 与 `on.pull_request.branches` 增加 `dev`；新增
  `concurrency` 段（`group: ${{ github.workflow }}-${{ github.ref }}`，`cancel-in-progress: true`）。
  本切片**不**新增检查步骤。
- **限制**：不改 job steps；不动其它 workflow。
- **验证**：`python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/flutter.yml')); assert 'dev' in d['on']['push']['branches'] and 'dev' in d['on']['pull_request']['branches'] and 'concurrency' in d"`。
- **commit**：`ci: trigger on dev branch and add concurrency cancel`

### P0-S2 — 恢复 custom_lint

- **目标**：把本地已有的 custom lint 接回 CI，并删除误导性注释。
- **范围**：仅 `.github/workflows/flutter.yml`。
- **改动**：在 `flutter-verify` 加一步 `run: bash tools/run_custom_lint_isolated.sh`；
  删除 “暂时注释掉不存在的检查和测试” 一类不实注释。
- **限制**：不改 lint 规则；不改 `analysis_options.yaml`。
- **验证**：本地 `bash tools/run_custom_lint_isolated.sh` 绿；YAML `safe_load` 通过；
  workflow 文本含 `run_custom_lint_isolated.sh`，且不再含 “不存在的检查” 注释。
- **commit**：`ci: restore custom_lint gate`

### P0-S3 — 恢复 architecture guard

- **目标**：让架构守卫成为 CI 必过项（不在本切片扩规则）。
- **范围**：仅 `.github/workflows/flutter.yml`。
- **改动**：在 `flutter-verify` 加一步 `run: bash tools/check_architecture.sh`。
- **限制**：**不**修改 `tools/check_architecture.sh` 规则（扩规则属 Phase 1）。
- **验证**：本地 `bash tools/check_architecture.sh` 输出 `Architecture boundary checks passed.`；
  YAML `safe_load` 通过；workflow 含 `check_architecture.sh`。
- **commit**：`ci: restore architecture boundary guard`

### P0-S4 — 恢复 Flutter 全量测试

- **目标**：CI 跑全量 Flutter 测试，不再只用单个 IAP 测试代替。
- **范围**：仅 `.github/workflows/flutter.yml`。
- **改动**：在 `flutter-verify` 加一步 `run: flutter test`（全量）。保留既有
  `Verify production IAP dart defines` 步骤。
- **限制**：不改任何测试文件；不加 `--no-pub` 之外的过滤导致漏跑。
- **验证**：本地 `flutter test` 全绿（`All tests passed!`）；YAML `safe_load` 通过；
  workflow 含全量 `flutter test` 步。
- **commit**：`ci: restore full flutter test suite`

### P0-S5 — 接入后端 unittest（独立 setup-python）

- **目标**：cloud_sync_backend 与 cloud_backup_backend 单测进入 CI。
- **范围**：仅 `.github/workflows/flutter.yml`。
- **改动**：新增并行 job `backend-verify`（ubuntu-latest）：`actions/setup-python@v5`
  （3.11+）→ 两步分别在两个后端目录 `python -m unittest discover -s tests`。
  **不得**把后端测试塞进 Flutter job（那里没有 Python 环境保证）。
- **限制**：不改任何 `server/**` 代码或测试。
- **验证**：本地
  `cd server/cloud_sync_backend && python3 -m unittest discover -s tests`（21 OK）、
  `cd server/cloud_backup_backend && python3 -m unittest discover -s tests`（30 OK）；
  YAML `safe_load` 通过；workflow 含 `setup-python` 与两步 unittest。
- **commit**：`ci: add backend unittest job with setup-python`

### P0-S6 — ResourceWarning 诊断（先诊断，不武断阻断）

- **目标**：用严格模式诊断后端是否有 ResourceWarning，再决定是否纳入 CI。
- **范围**：诊断为主；如发现告警，仅新增/更新 `docs/operations/tech-debt.md` 记录，
  **不**在本切片修后端代码。
- **改动**：
  - 跑严格模式（见验证）。
  - 若**无**告警：在 `docs/quality/baseline-dev-36d42f0.md` 注明“严格 ResourceWarning 通过”。
  - 若**有**告警：按 `tech-debt.md` 模板新增条目（状态/来源/影响/证据/建议/负责人=待确认），
    给出最小修复建议，**不**在本切片实施修复（留给独立 PR）。
- **限制**：不改 `server/**` 代码；不把不稳定的严格检查直接设为 CI 必过（先诊断结论）。
- **验证**：
  `cd server/cloud_sync_backend && python3 -W error::ResourceWarning -m unittest discover -s tests`；
  `cd server/cloud_backup_backend && python3 -W error::ResourceWarning -m unittest discover -s tests`；
  记录明确结论（通过 / 列出告警来源 file:line）。
- **commit**：`docs(quality): record ResourceWarning strict-mode diagnosis`

### P0 收口（S6 后自动执行一次）

```bash
bash tools/agent/check_full.sh
bash tools/check_architecture.sh
cd server/cloud_sync_backend   && python3 -m unittest discover -s tests
cd server/cloud_backup_backend && python3 -m unittest discover -s tests
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/flutter.yml'))"
git log --oneline dev..feature/p0-ci-restore
```

---

## E. 最终精简总结报告格式（Codex 交付，供人工审计）

```
# P0 执行总结（feature/p0-ci-restore）

- 仓库 / 分支：/Users/yu/Flutter_Projects/fleet_ledger_app / feature/p0-ci-restore
- 起始 HEAD：<dev tip = 36d42f0 + 计划 docs 提交>    结束 HEAD：<sha>
- 切片结果表：
  | 切片 | 状态(绿/停) | commit | 关键验证输出 |
  | P0-S0 | ... | <sha> | check_fast 通过 |
  | ...   | ... |  ...  | ... |
- ResourceWarning 诊断结论：<通过 / 告警 file:line + 建议>
- 收口验证：check_full=<绿/红>；check_architecture=<绿/红>；后端 21/30=<绿/红>；YAML 合法=<是/否>
- 是否改了 lib/ 业务代码：否（应为否）
- 是否改了 test/：否（应为否）
- 是否改了 DB schema/migration：否（应为否）
- 是否改了 pubspec.yaml：否（应为否）
- 是否 commit：是（逐切片）   是否 push：否
- 风险 / 遗留：<...>
- 是否安全在群里转述（无密钥）：是
- 建议下一步：人工审计本批次 → 决定是否 FF 合回 dev → 再排 Phase 1
```

报告必须精简、结构化；**不**自动进入 Phase 1，**不** push/merge。
