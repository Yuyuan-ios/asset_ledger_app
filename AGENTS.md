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
| Telegram review, Codex execution, orchestration contracts | `docs/agent/telegram-review-contract.md`, `docs/agent/codex-execution-contract.md`, `docs/agent/openclaw-minimax-orchestration.md` |
| Mobile GUI automation workflow | `docs/agent/mobile-gui-automation-workflow.md` |
| Long-goal multi-stage automation | `docs/agent/long-goal-automation-protocol.md`, `docs/agent/templates/long-goal-plan.md` |
| Prompt format for future agent tasks | `docs/agent/prompt-style.md` |
| Project identity, project title, contact/site | `docs/product/project-identity.md` |
| External work import/export and wording | `docs/product/external-work.md` |
| Settlement and write-off behavior | `docs/product/settlement-writeoff.md` |
| Statistics and financial wording | `docs/product/statistics.md` |
| Chinese UI copy rules | `docs/product/ui-copywriting.md` |
| Layer boundaries and architecture | `docs/architecture/layers.md` |
| Database migrations | `docs/architecture/database-migration-rules.md` |
| Date / timezone handling (civil date vs instant, DST-safe day math) | `docs/architecture/date-timezone-rules.md` |
| Test and verification commands | `docs/architecture/testing-rules.md` |
| Active or completed operation phases | `docs/operations/active/current-stage.md`, `docs/operations/active/README.md`, `docs/operations/completed/README.md` |
| Known technical debt | `docs/operations/tech-debt.md` |
| Quality-first execution roadmap (dev@36d42f0) | `docs/quality/execution-roadmap-dev-36d42f0.md`, `docs/quality/codex-prompts-p0.md`, `docs/quality/codex-prompts-p1.md`, `docs/quality/codex-prompts-p2.md`, `docs/quality/codex-prompts-p3.md`, `docs/quality/codex-prompts-p4.md` |

## Task Templates

- Read-only audit: `docs/agent/templates/readonly-audit.md`
- Implementation task: `docs/agent/templates/implementation-task.md`
- Merge review: `docs/agent/templates/merge-review.md`
- UI polish: `docs/agent/templates/ui-polish.md`
- Migration change: `docs/agent/templates/migration-change.md`
- Long-goal plan: `docs/agent/templates/long-goal-plan.md`

If a rule is not covered by these documents, mark it as `待确认` in the report
instead of inventing product behavior.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **asset_ledger_app** (22378 symbols, 58485 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/asset_ledger_app/context` | Codebase overview, check index freshness |
| `gitnexus://repo/asset_ledger_app/clusters` | All functional areas |
| `gitnexus://repo/asset_ledger_app/processes` | All execution flows |
| `gitnexus://repo/asset_ledger_app/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
