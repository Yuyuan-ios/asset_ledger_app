# Prompt Gateway Dry Run

## 1. Dry Run Purpose

This dry run validates whether the repository's Prompt Review Gateway can support
a realistic agent workflow without executing business changes.

The goals are:

- Verify that OpenClaw / MiniMax can only generate a DRAFT prompt.
- Verify that the ChatGPT review gate is clear enough to catch missing context,
  oversized scope, and weak validation.
- Verify that the FINAL prompt is safer, smaller, and more verifiable than the
  DRAFT.
- Verify what Telegram review should show before the user approves or stops the
  next action.

This dry run does not implement Stage D behavior and does not inspect or modify
operation-token or audit code.

## 2. Source User Request

> 请为阶段 D 的下一步 operation token / audit 相关任务生成一个 Codex prompt，但不要直接执行代码。

## 3. Relevant Documents That Should Be Read

OpenClaw / MiniMax should read these before generating the DRAFT:

- `AGENTS.md`
- `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
- `.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`
- `.agents/skills/fleet-ledger-orchestrator/references/prompt-rules.md`
- `.agents/skills/fleet-ledger-orchestrator/references/task-types.md`
- `docs/agent/prompt-review-gateway.md`
- `docs/agent/templates/implementation-task.md`
- `docs/architecture/testing-rules.md`
- `docs/operations/active/README.md`

Stage D active context:

- Stage D operation token / audit active-stage document: not available in current
  repository docs.
- Real Stage D acceptance criteria: requires user-provided stage context.
- Existing operation token / audit source files: should not be inspected during
  this dry run.

## 4. Simulated DRAFT_PROMPT_PACKAGE

```text
DRAFT_PROMPT_PACKAGE

Task:
Stage D operation token / audit next prompt

Task type:
implementation

Source request:
请为阶段 D 的下一步 operation token / audit 相关任务生成一个 Codex prompt，但不要直接执行代码。

Relevant docs read:
- AGENTS.md
- .agents/skills/fleet-ledger-orchestrator/SKILL.md
- .agents/skills/fleet-ledger-orchestrator/references/prompt-rules.md
- docs/agent/templates/implementation-task.md
- docs/architecture/testing-rules.md

Assumptions:
- Stage D is about operation token and audit infrastructure.
- The next useful task is probably to inspect current operation token / audit code
  and draft an implementation plan.
- Current branch/worktree does not need special handling.

Risks:
- Stage D context may be incomplete.
- The scope might be too broad if operation token and audit work are handled in
  the same prompt.
- Validation may need more than fast checks.

Draft Codex prompt:
You are in /Users/yu/Flutter_Projects/fleet_ledger_app. Generate a Codex prompt
for the next Stage D operation token / audit task. Read AGENTS.md and relevant
agent docs. Inspect operation token and audit-related code if needed. Produce a
prompt that can guide Codex to implement the next step. Do not push.

Validation:
- bash tools/agent/project_status.sh
- bash tools/agent/summarize_diff.sh

Questions for ChatGPT reviewer:
- Is this scope too broad?
- Should this be read-only before implementation?
- Which Stage D docs are missing?
- Should commit be allowed?
```

Known draft issues intentionally left for review:

- Scope is broad because it mixes operation token and audit.
- It depends on Stage D context that is not available in current repository docs.
- Validation is incomplete and does not include `check_fast`.
- Commit behavior is unclear.

## 5. ChatGPT Review Notes

ChatGPT should flag these issues:

- The draft lacks real Stage D active context. It should ask for or create a
  current-stage context entry before implementation work.
- The task scope is too large for execution. It combines operation token, audit,
  implementation planning, and source inspection.
- The safe next step is a read-only audit or prompt-drafting task, not code
  changes.
- The prompt must explicitly forbid UI, external-work, statistics, DB schema,
  migration, `lib/`, `test/`, and `pubspec.yaml` changes for this dry run.
- The prompt must require final report sections: files inspected, draft prompt
  produced, validation commands, business-code impact, `$HOME/.agents` impact,
  commit status, push status, and missing context.
- The prompt must distinguish "generate prompt" from "execute code". Codex should
  not implement operation token or audit behavior in this dry run.
- Commit must be explicitly forbidden unless the user later requests it.

## 6. Simulated FINAL_CODEX_PROMPT

```text
FINAL_CODEX_PROMPT

Reviewer verdict:
approved_after_revision

Changes made by ChatGPT:
- Changed the task type from implementation to readonly-audit / prompt-drafting.
- Removed permission to inspect or modify operation token / audit source code.
- Added explicit forbidden changes for UI, external-work, statistics, DB schema,
  migration, lib, test, and pubspec.yaml.
- Added required validation and final report sections.
- Made commit and push explicitly forbidden.
- Marked missing Stage D active context as a finding instead of inventing it.

Final Codex prompt:
You are in /Users/yu/Flutter_Projects/fleet_ledger_app executing a safe Prompt
Gateway dry-run task for Stage D operation token / audit planning.

Goal:
Produce a next-step Codex prompt draft for Stage D operation token / audit work,
but do not execute Stage D code changes. This is a read-only prompt-planning
task.

Context:
- Stage 1 repository Agent Harness was committed as 2a0d34c.
- Stage 2 Prompt Review Gateway + Fleet Ledger Orchestrator Skill was committed
  as 6cead73.
- OpenClaw / MiniMax may only generate DRAFT prompts.
- ChatGPT reviews DRAFT prompts and outputs FINAL Codex prompts.
- Codex executes only FINAL prompts after user approval.
- Telegram /approve does not mean push, merge, or release.

Scope:
- Inspect only repository documentation and harness files needed to draft the
  next Stage D prompt.
- Identify missing Stage D active context.
- Produce a DRAFT prompt for the next read-only Stage D context audit.
- Do not inspect operation token / audit source code during this dry run unless
  the user later provides a FINAL prompt explicitly allowing it.

Forbidden changes:
- Do not modify lib/.
- Do not modify test/.
- Do not modify pubspec.yaml.
- Do not modify database schema or migration files.
- Do not modify UI behavior, copywriting, statistics, external-work, settlement,
  write-off, or project-identity rules.
- Do not modify $HOME/.agents.
- Do not introduce dependencies.
- Do not run git add ., commit, push, merge, or release commands.
- Do not implement operation token / audit behavior.

Required files/docs to inspect:
- AGENTS.md
- docs/agent/prompt-review-gateway.md
- docs/agent/skills.md
- .agents/skills/fleet-ledger-orchestrator/SKILL.md
- .agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md
- .agents/skills/fleet-ledger-orchestrator/references/prompt-rules.md
- .agents/skills/fleet-ledger-orchestrator/references/task-types.md
- docs/agent/templates/readonly-audit.md
- docs/architecture/testing-rules.md
- docs/operations/active/README.md

Validation:
- bash tools/agent/project_status.sh
- bash tools/agent/summarize_diff.sh
- bash tools/agent/check_fast.sh

Final report format:
- Documents inspected.
- Generated Stage D next-step DRAFT prompt.
- Missing context and questions for the user.
- Validation commands and results.
- Whether business code was modified; expected answer: no.
- Whether $HOME/.agents was modified; expected answer: no.
- Whether commit was created; expected answer: no unless explicitly requested.
- Whether push was performed; expected answer: no.
```

## 7. Telegram Review Card

```text
Task: Stage D operation token / audit prompt dry run
Type: prompt-review / readonly-audit
Risk: Medium, because Stage D context is missing and operation/audit areas are sensitive.

What Codex would do:
- Read agent gateway docs and templates.
- Identify missing Stage D active context.
- Produce a safe next-step DRAFT prompt for a read-only Stage D context audit.
- Run project_status, summarize_diff, and check_fast.

What Codex must not touch:
- lib/
- test/
- pubspec.yaml
- DB schema / migrations
- UI, statistics, external-work, settlement/write-off, project-identity rules
- $HOME/.agents
- git push / merge / release

Validation:
- bash tools/agent/project_status.sh
- bash tools/agent/summarize_diff.sh
- bash tools/agent/check_fast.sh

Recommended action:
Revise Prompt if real Stage D context exists but was not supplied. Otherwise approve
only the read-only context-audit prompt.

Buttons:
[Approve] [Revise Prompt] [Stop]
```

## 8. Findings

- The existing skill is clear enough about the core gateway boundary:
  OpenClaw / MiniMax emits DRAFT, ChatGPT emits FINAL, Codex executes FINAL.
- The existing gateway docs are clear that Telegram `/approve` is not push,
  merge, or release permission.
- The current repository docs do not contain a dedicated active Stage D context
  document for operation token / audit next steps.
- A `docs/operations/active/current-stage.md` or a Stage-D-specific active doc
  would reduce ambiguity before future real work.
- OpenClaw / MiniMax should always emit the fixed `DRAFT_PROMPT_PACKAGE` format
  from the gateway reference.
- ChatGPT review gate is sufficient for this dry run; no Stage 2 doc change is
  required now.

## 9. Next Recommendation

- Submit this dry run document after review.
- Before real Stage D implementation work, add or supply active Stage D context,
  preferably `docs/operations/active/current-stage.md` or a Stage-D-specific
  active document.
- Then proceed to Stage 4: Telegram command contract, so `/draft`, `/review`,
  `/approve`, `/stop`, and `/next` have explicit request/response semantics.
