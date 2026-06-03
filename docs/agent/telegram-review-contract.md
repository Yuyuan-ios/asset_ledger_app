# Telegram Review Contract

## 1. Purpose

Telegram is the human review surface for this repository workflow. It is not an
automatic publishing, merge, push, or release entry point.

Telegram is also the primary approval surface when the user is working away
from the home MacBook. Messages must stay short enough for mobile review while
still naming risk, scope, forbidden changes, and validation.

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
- Must be bound to the current FINAL prompt summary or task id.
- In a long-goal loop, approves only the current stage FINAL prompt.
- Does not mean push.
- Does not mean merge.
- Does not mean release or publish.
- Does not permit scope expansion.
- Does not permit bypassing forbidden changes.
- Does not authorize later steps.

### `/revise`

- Requests a regenerated or modified DRAFT.
- Does not execute Codex.

### `/stop`

- Stops the current automatic progression.
- In a long-goal loop, stops the whole long-goal loop.
- Future work must be explicitly restarted by the user.
- OpenClaw / MiniMax must not keep generating execution prompts for the stopped
  task.

### `/next`

- Generates next-stage suggestions from the current docs and Codex report.
- In a long-goal loop, requests the next-stage DRAFT only.
- Does not directly execute the next stage.
- Does not automatically call Codex.
- Does not grant approval for the next stage.

### `/retry`

- Retries the current failed stage only.
- Must not expand scope.
- Must not skip ChatGPT review if the retry prompt changes.
- Must not advance to the next stage.

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

## 5. Long-Goal Cards

Long-goal Telegram cards are defined in
`docs/agent/long-goal-automation-protocol.md`. The required card types are:

- Goal intake card.
- Stage plan review card.
- Stage approval card.
- Stage result card.
- Failure card.
- Human decision card.

## 6. Approval Semantics

- `/approve` applies only to the current `FINAL_CODEX_PROMPT`.
- `/approve` must be tied to the current FINAL prompt summary or task id.
- `/approve stage` applies only to the current stage FINAL prompt.
- `/approve` does not create long-term authorization.
- `/approve` does not allow automatic push, merge, release, or publishing.
- `/approve` does not allow OpenClaw / MiniMax to bypass ChatGPT.
- `/approve` does not allow Codex to modify files outside the listed scope.
- `/approve` does not override forbidden changes.
- Every button or command is single-use for the current reviewed item.
- `/next` requests next-stage suggestions only; it does not execute the next
  stage.
- `/retry` retries only the current stage and must not broaden scope.
- `/stop` stops the whole long-goal loop.
