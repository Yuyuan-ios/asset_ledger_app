# 分层边界

本文件记录当前仓库的基础架构边界，用于 agent 判断改动范围。

## feature

- 承载具体业务功能、页面流程和用例编排。
- 适合放置与单一功能强相关的 command、adapter、view model 或页面逻辑。

## patterns

- 承载跨功能复用的交互、状态或展示模式。
- 不应沉淀具体业务规则，除非该规则本身就是通用模式的一部分。
- **允许的依赖**：可只读依赖 `data/models` 的 domain 值对象（如 `Device`、
  `TimingRecord`）用于展示与类型签名。
- **禁止的依赖**：不得依赖 `repositories` / `data/db` / `infrastructure` /
  `data/services` / `use_cases`（持久化、事务、基础设施接线一律走 feature 层注入）。
  由 `tools/check_architecture.sh` 强制。
- 注：早期 roadmap（P1-S6/S7）曾设想禁 patterns→data/models，2026-06-24 评估后
  正式化为「允许只读 domain 值对象」——data/models 是稳定值对象，patterns 直接用于
  展示不构成有害耦合；真正有害的 repositories/db/infra 依赖已被 guard 拦住。

## data

- 承载数据库 schema、migration、repository、model 和持久化访问。
- 数据结构变化需要同时关注 migration、备份恢复和测试。

## services

- 承载跨 feature 的业务服务、导入导出、计算或系统能力。
- 服务层应保持可测试，避免直接绑定具体 UI。

## stores

- 承载状态保存、派发和缓存。
- stores 可以协调数据读取和状态变化，但不应吞掉需要复用的业务规则。

## providers

- 承载依赖注入、状态暴露和对象装配。
- providers 不应成为复杂业务逻辑的主要落点。

## 待确认

- 各目录下已有例外结构待后续逐项归档。
