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
| `next-stage-planning` | `docs/operations/active/README.md`, related active-stage docs, and `docs/agent/long-goal-automation-protocol.md` when multi-stage |
| `telegram-review-contract` | `docs/agent/telegram-review-contract.md` |
| `codex-execution-contract` | `docs/agent/codex-execution-contract.md` |
| `openclaw-minimax-orchestration` | `docs/agent/openclaw-minimax-orchestration.md` |
| `mobile-gui-automation-workflow` | `docs/agent/mobile-gui-automation-workflow.md` |
| `long-goal-plan` | `docs/agent/templates/long-goal-plan.md` |
| `stage-execution` | `docs/agent/long-goal-automation-protocol.md` |
| `stage-report-review` | `references/report-checklist.md` |

## Routing Notes

- If a task touches multiple types, split it into smaller stages.
- High-risk types should usually start as `readonly-audit`.
- Do not turn `report-review` or `next-stage-planning` into code execution
  unless the user explicitly approves the next implementation stage.
- For `mobile-gui-automation-workflow`, verify that GUI automation does not
  bypass Telegram approval gates and stops when page state is uncertain.
- For `long-goal-plan`, do not generate an implementation prompt until
  ChatGPT produces `FINAL_STAGE_PLAN` and the user approves it.
- For `stage-execution`, execute one approved stage only.
- For `stage-report-review`, decide next, revise, retry, or stop from the
  Codex report; do not execute next automatically.
