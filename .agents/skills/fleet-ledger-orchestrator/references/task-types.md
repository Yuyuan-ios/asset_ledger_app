# Task Types

Use task type to select the right repository template and review depth.

| Task type | Use |
| --- | --- |
| `readonly-audit` | `docs/agent/templates/readonly-audit.md` |
| `implementation` | `docs/agent/templates/implementation-task.md` |
| `merge-review` | `docs/agent/templates/merge-review.md` |
| `ui-polish` | `docs/agent/templates/ui-polish.md` |
| `migration-change` | `docs/agent/templates/migration-change.md` |
| `report-review` | `references/report-checklist.md` |
| `prompt-review` | `references/chatgpt-review-gateway.md` |
| `next-stage-planning` | `docs/operations/active/README.md` and related active-stage docs |
| `telegram-review-contract` | `docs/agent/telegram-review-contract.md` |
| `codex-execution-contract` | `docs/agent/codex-execution-contract.md` |
| `openclaw-minimax-orchestration` | `docs/agent/openclaw-minimax-orchestration.md` |

## Routing Notes

- If a task touches multiple types, split it into smaller stages.
- High-risk types should usually start as `readonly-audit`.
- Do not turn `report-review` or `next-stage-planning` into code execution
  unless the user explicitly approves the next implementation stage.
