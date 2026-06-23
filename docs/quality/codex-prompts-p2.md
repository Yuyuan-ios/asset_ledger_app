# Codex 执行 Prompt — Phase 2（关键质量债，基线 dev = 1e38800）

> 配套：`docs/quality/execution-roadmap-dev-36d42f0.md`、`docs/architecture/date-timezone-rules.md`、
> `docs/product/ui-copywriting.md`、`docs/operations/tech-debt.md`。遵循 `docs/agent/prompt-style.md`。
> Phase 1 核心（features→DB）已完成并合入 dev；P1-S6/S7（patterns→data/models）暂缓。

## A. 授权与硬限制（执行前必读，只写一次）

**用户已授权自动连跑整条 Phase 2（覆盖 codex-execution-contract 的 no-auto-advance）：**

- ✅ 顺序自动连跑：**P2-S1 → P2-B1 → P2-B2 → P2-B3 → P2-S2 → P2-S3 → P2-S4 → P2-S5 → P2-S6**。
  每切片实现完成且验证全绿 → 自动 commit → 进入下一个。收尾出一份报告交人工审计。
- ✅ 分支：开工 `git switch -c feature/p2-quality-debt`（基于 dev=1e38800）。每切片一 commit，
  结尾加 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。

**硬限制（全程有效）：**

- ❌ 不 push / merge / release。
- 🛑 任一切片验证红灯 / GitNexus 影响 HIGH·CRITICAL / 需产品决策（文案口径、限流阈值、
  数据合法性策略）→ **立即停止**，保留现场，报告，等人工。
- ❌ 不改 DB schema/migration；不加依赖（限流/日志用标准库实现）；不动 `$HOME/.agents`；不提交密钥。
- ❌ i18n 切片：**只抽用户可见 UI 串**，绝不抽内部/调试/key/SQL 串；**展示中文文案保持逐字不变**；
  迁移涉及 context 的组件必修测试 harness（见 memory 教训）。
- **GitNexus（CLAUDE.md，针对 Dart）**：改 Dart 符号前 `gitnexus_impact`、提交前 `gitnexus_detect_changes`。
  **后端为 Python，不在索引内** → 用 unittest（含严格 ResourceWarning 复跑）验证。
- **computer use**：Phase 2 后端验证均本地 `python -m unittest`，**不需要远程服务器**。

## B. 全局前置（只写一次）

1. 仓库 `/Users/yu/Flutter_Projects/fleet_ledger_app`，dev=1e38800，工作区干净。
2. 必读：`docs/architecture/date-timezone-rules.md`（日期）、`docs/product/ui-copywriting.md`（文案）、
   `server/cloud_sync_backend/app.py` 与 `server/cloud_backup_backend/app.py`（后端现状）。
3. 验证命令：`bash tools/agent/check_full.sh`、`bash tools/check_architecture.sh`、
   两后端 `python3 -m unittest discover -s tests`（必要时 `-W error::ResourceWarning`）。
   注：本机 custom_lint 偶发 pub.dev TLS 网络失败，`flutter analyze` 清白即可视为静态分析通过。

## C. 自动连跑循环

```
对 slice in [S1, B1, B2, B3, S2, S3, S4, S5, S6]:
  1. 实现（含新增测试；后端切片实现+测试同片绿；i18n 切片保持展示文案不变）
  2. 跑该切片验证命令（Dart 切片必跑 check_full；后端切片跑对应 unittest）
  3. 全绿 → commit → 下一个；红灯/HIGH/需产品决策 → 停止并报告
S6 后跑收口（check_full + check_architecture + 两后端 unittest）→ 出报告，停止，等人工。
```

---

## D. 切片 Prompt

### P2-S1 — TimingRecord.fromMap 日期校验

- **目标**：`fromMap` 用 `YmdDate` 校验 `start_date`，非法日期不再静默进入领域层（date-timezone-rules）。
- **范围**：`lib/data/models/timing_record.dart` + `test/`。
- **改法**：`lib/data/models/timing_record.dart:215` `startDate: m['start_date'] as int` →
  先取 int，再用 `YmdDate.fromInt(...)` 校验；合法则放行原值，非法（null/负/0/越界如 20261332）
  抛 `FormatException`/`ArgumentError`（fail-loud，不静默）。
- **限制**：**合法旧数据必须照常加载**（只拦真正非法值）；不改其它字段解析；不改写入路径。
- **GitNexus**：`gitnexus_impact` on `TimingRecord.fromMap`（可能 HIGH=广泛使用）；HIGH 已知可继续，
  但若 detect 显示触及写入/序列化语义而非仅读校验 → 停下报告。
- **验证**：新测试（合法 yyyymmdd 正常构造；非法值抛异常）；`bash tools/agent/check_full.sh` 绿
  （若全量里有 fixture 用了非法 start_date 而现在抛错 → 停下报告，交人工决定 fixture 修正）。
- **commit**：`fix(timing): validate start_date as YmdDate in fromMap`

### P2-B1 — sync backend 逐用户限流（实现 + 测试同片）

- **目标**：`cloud_sync_backend` 加逐用户滑动窗口限流（参照 `cloud_backup_backend` 既有
  `SlidingWindowRateLimiter`）；鉴权后按 user/account bucket 限流，超限 429。
- **范围**：`server/cloud_sync_backend/app.py` + `server/cloud_sync_backend/tests/`。
- **改法**：复用/移植 backup 的 `SlidingWindowRateLimiter`；在鉴权后、处理前 check；
  超限抛 `HttpError(429, "rate_limited", ...)`。**413 batch_too_large 优先级**：批量过大仍先返回 413。
- **限制**：不改同步业务逻辑/响应结构（429 之外）；阈值若需产品判断 → 取保守默认并在报告里标注待确认，
  不擅自定死“正确”阈值。现有 21 测试必须仍绿（如限流影响既有用例，调测试夹具而非放宽业务）。
- **验证**：新测试（超限 429、不同 user 隔离、匿名 bucket、413 优先于 429）；
  `cd server/cloud_sync_backend && python3 -m unittest discover -s tests`（含 `-W error::ResourceWarning`）全绿。
- **commit**：`feat(sync-server): add per-user sliding-window rate limiting`

### P2-B2 — backup backend 结构化 logging

- **目标**：`cloud_backup_backend` 引入结构化 logging，替换 `print(...internal_error...)` 兜底，补 request_id 与敏感字段脱敏。
- **范围**：`server/cloud_backup_backend/app.py` + `server/cloud_backup_backend/tests/`。
- **改法**：`import logging` + `LOGGER`（参照 sync backend 的 `configure_logging`）；错误路径
  `logger.exception(...)`；日志带 request_id；token/JWT/密钥等敏感字段**不得**进日志。
- **限制**：客户端响应不变；不改限流/鉴权逻辑；启动横幅 print 可保留。
- **验证**：新测试（错误路径产生结构化日志、敏感字段不落日志）；30 测试仍绿
  （`-W error::ResourceWarning` 仍无告警）。
- **commit**：`feat(backup-server): structured logging with request_id and redaction`

### P2-B3 — sync backend print 兜底收口

- **目标**：sync backend 已有 logging 基础上，把 `print(...internal_error...)` 兜底换成 `logger.exception(...)`。
- **范围**：`server/cloud_sync_backend/app.py`（+ 必要测试）。
- **限制**：客户端响应不变；日志不泄密；启动横幅 print 可留。
- **验证**：`cd server/cloud_sync_backend && python3 -m unittest discover -s tests` 绿。
- **commit**：`refactor(sync-server): replace print fallback with logger.exception`

### P2-S2 — i18n 清单（只盘点）

- **目标**：盘点 external_work / timing / device 的用户可见硬编码中文，作后续 key 化索引。
- **范围**：新增 `docs/quality/p2-i18n-inventory.md`。
- **内容**：逐文件列出用户可见中文串（`Text('…')`、`title/label/hint/tooltip/snackbar/dialog` 等），
  标注模块；明确排除内部/调试/日志/key/SQL 串与已 key 化项。
- **验证**：文件存在；`check_fast` 绿。
- **commit**：`docs(quality): inventory Phase 2 i18n strings`

### P2-S3 / P2-S4 / P2-S5 — external_work / timing / device i18n

- **目标**：把对应模块的用户可见中文按清单 key 化（ARB：`lib/l10n/app_zh.arb` + `app_en.arb`），
  组件改用 `AppLocalizations`；**中文展示逐字不变**，英文给合理 fallback。
- **范围**：对应 `lib/features/<area>/**`（+ 相关 `lib/patterns/<area>`）、`lib/l10n/*.arb`、必要测试 harness。
- **改法**：每批 1–3 文件；加 key → 重新生成 l10n（`flutter gen-l10n` 或构建）→ 替换硬编码 →
  涉及 context 的 widget 测试若缺 `MaterialApp`/localizations harness 必须补齐。
- **限制**：只抽用户可见串；不改文案中文字面；不改业务逻辑；遵循 `docs/product/ui-copywriting.md`
  （如“外协项目”等既定口径不得擅改）。
- **验证**：`bash tools/agent/check_full.sh` 绿（widget 测试匹配的中文文案不变 → 仍绿）；
  对应模块用户可见硬编码中文清零或入豁免清单。
- **commit**：`i18n(<area>): key-ize user-facing strings`（每模块一 commit，可再分批）

### P2-S6 — 扩 CJK guard

- **目标**：扩 `tools/check_architecture.sh`（或既有 CJK 检查），对 view/widgets/patterns 阻断**新增**
  用户可见硬编码中文；合理例外有 allowlist。
- **范围**：`tools/check_architecture.sh` + `test/tools/check_architecture_failure_behavior_test.dart`。
- **限制**：不误杀注释/已豁免项；规则清晰可维护。
- **验证**：`bash tools/check_architecture.sh` 绿；failure-behavior 测试（故意新增硬编码中文→非零退出）通过；`check_full` 绿。
- **commit**：`build(arch): guard against new hardcoded CJK in UI`

## E. 最终精简总结报告格式

```
# Phase 2 执行总结（feature/p2-quality-debt）
- 仓库/分支 / 起始 HEAD(1e38800) / 结束 HEAD
- 切片结果表：| 切片 | 状态(绿/停) | commit | 关键验证 | GitNexus/unittest |
- P2-S1：非法 start_date 是否 fail-loud + 合法数据照常 + full gate 绿
- 后端：sync 限流(429/隔离/413优先) + backup 结构化日志(脱敏) + sync print 收口；21/30 仍绿，严格 ResourceWarning 无告警
- i18n：各模块用户可见中文是否清零/豁免，展示文案是否逐字不变，widget 测试是否绿，CJK guard 是否生效
- 收口：check_full / check_architecture / 后端 21·30 = 绿/红
- 是否改 lib / test / server / schema / pubspec / 密钥；是否 commit（逐切片）/ 是否 push（否）
- 风险 / 遗留（含待确认的限流阈值、i18n 豁免项）
```

报告精简、结构化；**不** push/merge；收尾停下等人工审计。
