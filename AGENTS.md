# Agent Entry

This file is a short index for Codex, OpenClaw, Claude Code, and other agents.
Do not expand it into a product encyclopedia. Read the specific document for the
rule area you are touching.

## Code Intelligence

- This project is indexed by GitNexus as `asset_ledger_app`.
- Before editing a function, class, or method, run impact analysis and report the blast radius.
- Before committing code changes, run change detection if GitNexus tools are available.
- If the GitNexus index is stale, run `npx gitnexus analyze`.
- Docs-only and script-only tasks that do not edit code symbols do not need symbol impact analysis.

## Read First

| When the task touches | Read |
| --- | --- |
| Agent workflow, reports, and commits | `docs/agent/index.md`, `docs/agent/workflow.md` |
| Prompt review gateway and project skill | `docs/agent/prompt-review-gateway.md`, `.agents/skills/fleet-ledger-orchestrator/SKILL.md` |
| Prompt format for future agent tasks | `docs/agent/prompt-style.md` |
| Project identity, project title, contact/site | `docs/product/project-identity.md` |
| External work import/export and wording | `docs/product/external-work.md` |
| Settlement and write-off behavior | `docs/product/settlement-writeoff.md` |
| Statistics and financial wording | `docs/product/statistics.md` |
| Chinese UI copy rules | `docs/product/ui-copywriting.md` |
| Layer boundaries and architecture | `docs/architecture/layers.md` |
| Database migrations | `docs/architecture/database-migration-rules.md` |
| Test and verification commands | `docs/architecture/testing-rules.md` |
| Active or completed operation phases | `docs/operations/active/current-stage.md`, `docs/operations/active/README.md`, `docs/operations/completed/README.md` |
| Known technical debt | `docs/operations/tech-debt.md` |

## Task Templates

- Read-only audit: `docs/agent/templates/readonly-audit.md`
- Implementation task: `docs/agent/templates/implementation-task.md`
- Merge review: `docs/agent/templates/merge-review.md`
- UI polish: `docs/agent/templates/ui-polish.md`
- Migration change: `docs/agent/templates/migration-change.md`

If a rule is not covered by these documents, mark it as `待确认` in the report
instead of inventing product behavior.
