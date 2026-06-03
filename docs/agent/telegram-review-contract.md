# Telegram Review Contract

## 1. Purpose

Telegram is the human review surface for this repository workflow. It is not an
automatic publishing, merge, push, or release entry point.

The default execution baseline for Telegram-reviewed work is:

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Branch: `dev`

Every task must verify the current path, branch, HEAD, and dirty status before
reporting or execution.

## 2. Roles

- User: reviews status, approves a single final prompt, stops the flow, requests
  revisions, or asks for next-stage suggestions.
- OpenClaw / MiniMax: draft orchestrator. It produces
  `DRAFT_PROMPT_PACKAGE` only.
- ChatGPT: final prompt reviewer. It reviews, narrows, and converts DRAFT into
  `FINAL_CODEX_PROMPT`.
- Codex: executor. It executes only ChatGPT-reviewed FINAL prompts.

## 3. Commands

### `/status`

- Returns dev branch status, HEAD, dirty files, recent commits, and current
  active stage.
- Does not modify code.
- Does not call Codex for execution.

### `/draft <task>`

- OpenClaw / MiniMax generates `DRAFT_PROMPT_PACKAGE`.
- Does not hand work to Codex.
- Must wait for ChatGPT review before any execution.

### `/review`

- Reviews a Codex execution report or an OpenClaw / MiniMax draft.
- Outputs risks, missing context, whether ChatGPT secondary review is needed,
  and whether the task should stop or continue.
- Does not modify code.

### `/approve`

- Confirms that the current ChatGPT-reviewed `FINAL_CODEX_PROMPT` may be handed
  to Codex for execution.
- Does not mean push.
- Does not mean merge.
- Does not mean release or publish.
- Does not permit scope expansion.
- Does not permit bypassing forbidden changes.

### `/revise`

- Requests a regenerated or modified DRAFT.
- Does not execute Codex.

### `/stop`

- Stops the current automatic progression.
- Future work must be explicitly restarted by the user.
- OpenClaw / MiniMax must not keep generating execution prompts for the stopped
  task.

### `/next`

- Generates next-stage suggestions from the current docs and Codex report.
- Does not directly execute the next stage.
- Does not automatically call Codex.

## 4. Review Card Format

```text
Task:
<任务名>

Type:
<readonly-audit | implementation | ui-polish | migration-change | report-review | next-stage-planning | prompt-review>

Risk:
<low | medium | high>

Current baseline:
- Repository:
- Branch:
- HEAD:
- Status:

What Codex would do:
- <事项>

What Codex must not touch:
- <禁止范围>

Validation:
- <验证命令>

Needs ChatGPT review:
<yes/no>

Recommended action:
<Approve / Revise Prompt / Stop / Ask ChatGPT>

Buttons:
[Approve] [Revise Prompt] [Stop] [Ask ChatGPT]
```

## 5. Approval Semantics

- `/approve` applies only to the current `FINAL_CODEX_PROMPT`.
- `/approve` does not create long-term authorization.
- `/approve` does not allow automatic push, merge, release, or publishing.
- `/approve` does not allow OpenClaw / MiniMax to bypass ChatGPT.
- `/approve` does not allow Codex to modify files outside the listed scope.
- `/approve` does not override forbidden changes.
