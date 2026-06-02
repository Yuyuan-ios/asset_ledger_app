# Agent 工作入口

本目录记录 agent 在本仓库中的工作方式。任务开始时先读根目录
`AGENTS.md`，再按任务领域读取对应的产品、架构、验证或模板文档。

## 基本原则

- 只读取与当前任务有关的文档，不把一次任务扩展成全仓库重构。
- 审计任务保持只读；实现任务只改目标范围内的文件。
- 未明确要求时，不主动提交、不 push、不引入依赖、不改业务代码以外的范围。
- 不确定的产品细节写作 `待确认`，不要补造规则。

## 常用命令

从仓库根目录运行：

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_fast.sh
tools/agent/check_full.sh
```

- 快速检查：`tools/agent/check_fast.sh`
- 全量检查：`tools/agent/check_full.sh`
- 项目状态：`tools/agent/project_status.sh`
- Diff 摘要：`tools/agent/summarize_diff.sh`

## 相关文档

- 标准流程：`docs/agent/workflow.md`
- Prompt 规范：`docs/agent/prompt-style.md`
- 产品规则：`docs/product/`
- 架构规则：`docs/architecture/`
- 阶段记录与技术债：`docs/operations/`
