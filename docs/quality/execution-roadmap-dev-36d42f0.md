# FleetLedger 质量优先执行路线图（基线 dev@36d42f0）

> 本文件是仓库内可执行版本，配套桌面文档
> `FleetLedger_执行步骤与切片计划_总结版.docx`。docx 是完整切片参考，本 .md
> 是落地执行的权威伴随：Phase 0 给足机器可校验细节，Phase 1–5 索引化。
>
> 来源：基于 `dev@36d42f0` 的只读复核（评分 6.5/10，适合作稳定开发基线，不适合
> 宣称完整商业化生产闭环）。配套 Codex prompt：`docs/quality/codex-prompts-p0.md`。

## 0′. 2026-06-24 状态刷新（分支收口后）

> 分支收口：发布主线已切到真主线 **`main = develop = ba52b60`**（与本文原基线
> `dev@36d42f0` 是两条不相交 root 的关系，详见记忆 `dev-branch-renamed-develop`）。
> 本文 Phase 0–5 的执行计划仍有效，但**多数 Phase 0–3 已在 ba52b60 落实**。按实测：

| 阶段 | 状态（ba52b60 实测） |
| --- | --- |
| Phase 0 远端门禁 | ✅ 完成（flutter.yml 全检查 + develop 触发 + arch-script 两遍隔离 + 双后端 job） |
| Phase 1 架构边界 | 🟡 features 直连 DB ✅ 收口并 guard；**patterns→data/models 15 文件未收（P1-S6/S7）** |
| Phase 2 质量债 | ✅ 日期校验 / i18n 展示层 / sync 限流 / FIX-DST-B；🟡 backup 后端结构化日志仍稀疏 |
| Phase 3 维护性 | ✅ 大文件拆分完成 |
| Phase 4 生产闭环 | ⏳ 全部代码就绪、未部署：live sync 硬阻断+2 deferred、driver entry 骨架、app-update launcher=null、IAP 待 sandbox smoke |
| Phase 5 发布准入 | ⏳ 未开始（真机矩阵 / 线上 smoke / runbook / rollback / secret rotation） |

**进行中欠账**（见 `docs/operations/tech-debt.md`）：patterns→data/models（P1-S6/S7）、
结算 snapshot 双份、S4b/S5b 领域层文案分离。下方原文按 `dev@36d42f0` 保留作历史参照。

---

## 0. 复核基线（repo-verified, 2026-06-22）

| 项 | 状态 |
| --- | --- |
| 基线 | `dev@36d42f0`；工作区干净 |
| 本地门禁 | `check_fast` / `check_architecture` / `check_full` 全绿；Flutter 测试 `+2272 ~3` |
| 后端单测 | cloud_sync_backend 21、cloud_backup_backend 30，全绿 |
| 远端门禁 | ~~**脱节**~~ → **2026-06-24 已修复**（见 §0′）：`flutter.yml` 全检查接回、两遍隔离 arch-script、`develop` 触发 |
| 阻断生产声明 | live sync（hard-gate + delete-meta/terminal-failed deferred）、driver entry（纯领域骨架）、native update（`inAppUpdateLauncher: null`，仅 URL fallback）、IAP 服务端校验（配置门控，未做 sandbox smoke；已 fail-closed） |

## 1. 总原则

- 一个切片 = 一个可单独评审、可单独回滚、可独立验收的提交/PR。
- 高风险切片：先写行为锁定测试（characterization tests）→ 再迁移接口/实现 → 最后打开 guard。
- **测试通过不等于生产可用**；fake/mock/test-only/有 fallback 都不算真实能力。
- 阶段顺序不可逆跨越：Phase 0/1 未达标前，不碰 Phase 4 的功能实现。

## 2. 阶段总览

| 阶段 | 主题 | 核心目标 |
| --- | --- | --- |
| Phase 0 | 基线冻结与远端门禁恢复 | 让本地全绿变成 CI 强制门禁（**当前执行批次**） |
| Phase 1 | 架构边界收口 | 消除 features 直连 DB、patterns→data/models 漂移，并由 guard 在 CI 守住 |
| Phase 2 | 关键质量债修复 | 日期边界、i18n、后端限流/日志硬化 |
| Phase 3 | 维护性治理 | 拆大文件 + 两个后端 app.py，行为不变 |
| Phase 4 | 生产能力闭环 | live sync / driver entry / app update / IAP 逐条上线验证 |
| Phase 5 | 发布准入 | 真机矩阵、线上 smoke、runbook、rollback、secret rotation |

Phase 1–5 的完整切片表见 docx 第 5–11 章；本 .md 不重复 22 张表，只在执行到对应
阶段时再展开为同样格式的 prompt 批次。

## 3. 基础验证命令（每个切片收口必跑其相关子集）

```bash
git status --short
bash tools/agent/check_fast.sh           # analyze + custom_lint + diff check
bash tools/check_architecture.sh         # 架构边界守卫
bash tools/agent/check_full.sh           # analyze + custom_lint + 全量 flutter test
cd server/cloud_sync_backend   && python3 -m unittest discover -s tests
cd server/cloud_backup_backend && python3 -m unittest discover -s tests
# 诊断（P0-S6）：严格 ResourceWarning
cd server/cloud_sync_backend   && python3 -W error::ResourceWarning -m unittest discover -s tests
cd server/cloud_backup_backend && python3 -W error::ResourceWarning -m unittest discover -s tests
```

---

## 4. Phase 0：基线冻结与远端门禁恢复（当前执行批次）

目标：把当前已经全绿的本地质量基线，真正变成远端 CI 的强制基线。

### 4.1 目标 CI 拓扑（执行细化）

- **触发与并发**：`on: push / pull_request` 覆盖 `[main, master, dev]`；新增
  `concurrency`（按 `${{ github.workflow }}-${{ github.ref }}` 取消同分支旧运行）。
- **Job 拓扑（两个并行 job）**：
  - `flutter-verify`（ubuntu-latest）：`subosito/flutter-action@v2` 装 Flutter
    `3.38.5` + 缓存 pub → `flutter pub get` → `flutter analyze` →
    `bash tools/run_custom_lint_isolated.sh` → `bash tools/check_architecture.sh`
    → `flutter test`。
  - `backend-verify`（ubuntu-latest）：`actions/setup-python@v5`（3.11+）→
    `python -m unittest discover -s tests`（cloud_sync_backend 与
    cloud_backup_backend 各一步）。
- **关键约束**：后端 job **不能**复用 Flutter job 环境，必须独立 `setup-python`，
  否则 runner 上没有 Python 解释器。
- **保留**现有 `Verify production IAP dart defines` 步骤（带
  `--dart-define-from-file=dart_defines/production.json`）。

### 4.2 本地等价验收（因无法在本机触发 GitHub Actions）

每个 CI 切片合并前必须：

1. 在本地跑通该切片 job 对应命令（见 §3），全绿；
2. 校验 workflow YAML 合法（本机 python3 无 PyYAML 且 PEP 668 受管，禁直接 pip；
   用 macOS 自带系统 ruby，零安装）：
   ```bash
   ruby -ryaml -e 'YAML.load_file(".github/workflows/flutter.yml"); puts "yaml OK"'
   ```
   （装了 `actionlint` 更佳。）

只有「本地等价命令全绿 + YAML 合法」才算该切片完成。

### 4.3 切片表

| 切片 | 风险 | 名称 | 执行范围 | 机器可校验验收 |
| --- | --- | --- | --- | --- |
| P0-S0 | 低 | 建立基线证据档案 | 新增 `docs/quality/baseline-dev-36d42f0.md`，记录 commit、测试结果、阻断能力、风险 | 文件存在；不夸大生产能力；`check_fast` 通过 |
| P0-S1 | 低 | 恢复 dev 分支 CI 触发 + concurrency | workflow `on.push`/`on.pull_request` 加 `dev`；加 `concurrency` 段 | YAML `safe_load` 通过；`on` 含 `dev`；存在 `concurrency:` |
| P0-S2 | 中低 | 恢复 custom_lint | 接回 `bash tools/run_custom_lint_isolated.sh`；删除误导性注释 | 本地 custom_lint 绿；workflow 含该步；无 “不存在的检查” 注释 |
| P0-S3 | 中 | 恢复 architecture guard | 接回 `bash tools/check_architecture.sh`；本切片不扩规则 | 本地 `check_architecture` 绿；workflow 含该步 |
| P0-S4 | 中 | 恢复 Flutter full test | workflow 跑 `flutter test`（全量，非单文件） | 本地 `flutter test` 绿；workflow 含全量 test 步 |
| P0-S5 | 中 | 接入后端 unittest | 新增 `backend-verify` job（独立 setup-python）跑两套 unittest | 本地两套 unittest 各 21 / 30 绿；workflow 含 `setup-python` + 两步 unittest |
| P0-S6 | 中 | ResourceWarning 诊断 | 跑 `-W error::ResourceWarning`；先诊断再决定是否阻断 CI | 严格模式有明确结论；若告警，记入 `docs/operations/tech-debt.md` 并给修复建议 |

### 4.4 退出标准

dev PR 会跑 CI；CI 包含 analyze、custom_lint、architecture guard、Flutter full
test、两个后端 unittest；workflow YAML 通过 `yaml.safe_load`；后端 job 已独立
`setup-python`；`concurrency` 生效；本地 `check_fast`/`check_full`/`check_architecture`
保持全绿。

### 4.5 回滚触发

任一新加 job 在首个 dev PR 上 >15 分钟未结束或出现非确定性失败，立即 `git revert`
该切片的 workflow 改动回到上一个绿色 workflow，再单独排查，不阻塞其它切片。

### 4.6 P0-S4 前置：DST 月度分摊修复（执行中发现）

P0-S4 恢复全量 `flutter test` 时揪出一个**既有真实 DST 钱分摊 bug**：
`timing_monthly_income/expense_service` 把日历日物化成本地 `DateTime` 做
`.difference().inDays`，跨夏令时少算一天，full test 在本机 `America/Los_Angeles`
确定性红（GitHub runner 默认 UTC 会 false-green）。
- 已修 `dc0dbf4`（统一 `DateTime.utc`，双时区全量绿，人工审计通过）→ **S4 前置满足**。
- 升级中 `FIX-DST-B`：日数差迁移到 `YmdDate` 整数序日。详见
  `docs/quality/codex-prompts-p0.md` §F 与规范 `docs/architecture/date-timezone-rules.md`。

---

## 5. Phase 1–5 索引（执行到时再展开为 prompt 批次）

- **Phase 1（架构边界）**：P1-S0 违规清单 → P1-S1/S2 sync conflict reader 行为锁定 +
  抽接口 → P1-S3/S4 DB 实现移出 feature 层 → P1-S5 guard 禁 features 直连 DB →
  P1-S6/S7 清理 + guard 禁 patterns→data/models。高风险切片先测后改。
- **Phase 2（质量债）**：P2-S1 `TimingRecord.fromMap` 日期校验；P2-S2..S6 i18n（清单
  → external_work → timing → device → 扩 CJK guard）；P2-B1..B4 sync backend 限流 +
  backup backend 结构化日志 + print 兜底收口。
- **Phase 3（维护性）**：拆两个后端 `app.py`、`sync_manager.dart`、`account_page.dart`、
  `device_page.dart`、`backup_validator.dart`，行为不变，characterization tests 护航。
- **Phase 4（生产闭环）**：4A live sync（tombstone 生命周期 + terminal-failed reset +
  端到端 smoke）；4B driver entry（状态机 → schema → 邀请闭环 → 外部入口 → 审批 →
  smoke）；4C app update native launcher；4D IAP sandbox/prod 准入。
- **Phase 5（发布准入）**：真机矩阵、线上 smoke checklist、runbook/rollback/secret rotation。

详见 docx 第 5–11、13 章。

## 6. 暂缓事项（硬性）

- CI 补齐前继续堆大功能。
- driver entry 未闭环就宣称「工作填报链接已完成」。
- delete-meta / terminal-failed deferred 未收口就宣称实时云同步生产可用。
- 未跑真机矩阵就宣称 HarmonyOS / 多端适配完成。
- 未配 `SubscriptionConfig` + sandbox smoke 就开启变现。
- 未注入真实 launcher 前宣称 native 应用内更新能力。
