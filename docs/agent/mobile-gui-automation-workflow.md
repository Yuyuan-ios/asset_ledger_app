# Mobile GUI Automation Workflow

## 1. Purpose

This document defines the mobile office GUI automation workflow for Fleet
Ledger agent work.

- The home MacBook is the long-running execution machine.
- The user reviews work from Telegram while away from the computer.
- OpenClaw connects ChatGPT and Codex through GUI automation.
- OpenClaw / MiniMax is not the final decision maker.
- ChatGPT is the prompt reviewer and planning brain.
- Codex is the executor.
- Telegram is the human review surface.

The goal is to mobile-enable the current desktop ChatGPT to prompt to Codex
workflow. It is not to let OpenClaw write code directly.

## 2. System Roles

### User / Telegram Reviewer

- Provides the overall goal or stage task.
- Reviews each step.
- Chooses approve, revise, stop, or next.
- Does not need to manually copy and paste prompts.
- Keeps final approval authority.

### OpenClaw

- Acts as the mobile office orchestrator.
- Reads repository docs.
- Manages stage state.
- Sends MiniMax DRAFT output to ChatGPT through GUI automation.
- Sends ChatGPT FINAL output back to Telegram.
- Hands FINAL to Codex only after user approval.
- Reads the Codex report and sends a Telegram summary.
- Does not directly write business code.
- Does not bypass ChatGPT.
- Does not bypass user approval.

### MiniMax

- Acts as the DRAFT generation brain behind OpenClaw.
- Generates only `DRAFT_PROMPT_PACKAGE`.
- Does not generate `FINAL_CODEX_PROMPT`.
- Does not call Codex directly.
- Does not decide push, merge, or release.

### ChatGPT

- Reviews DRAFT packages.
- Splits stages when needed.
- Narrows scope.
- Strengthens forbidden changes and validation.
- Generates `FINAL_CODEX_PROMPT`.
- Uses Codex reports to produce next-stage recommendations.

### Codex

- Executes only `FINAL_CODEX_PROMPT`.
- Runs validation.
- Outputs execution reports.
- Does not automatically push, merge, release, or publish.
- Does not execute DRAFT prompts.

## 3. End-to-End Loop

```text
Telegram /draft <task>
-> OpenClaw / MiniMax generates DRAFT_PROMPT_PACKAGE
-> OpenClaw sends DRAFT to ChatGPT through GUI automation
-> ChatGPT outputs FINAL_CODEX_PROMPT
-> OpenClaw sends Telegram review card
-> User chooses /approve, /revise, or /stop
-> If approved, OpenClaw hands FINAL to Codex
-> Codex executes and outputs report
-> OpenClaw summarizes report to Telegram
-> User chooses /next, /revise, or /stop
-> If next, OpenClaw sends the report to ChatGPT for the next-stage prompt flow
```

OpenClaw must not automatically move from one step to the next when an approval
gate is required.

## 3.1 Long-Goal Loop

The mobile office loop can carry long goals, but the first version must advance
by explicit stages.

- A long goal starts with planning, not implementation.
- Each stage still goes through DRAFT -> ChatGPT FINAL -> Telegram approve ->
  Codex execute.
- OpenClaw may suggest next after a stage completes, but must not execute next
  automatically.
- Codex tests passing does not automatically start the next stage.
- Long-goal state must be summarized clearly enough for Telegram review and
  later replay.
- Use `docs/agent/long-goal-automation-protocol.md` for multi-stage goals.

## 4. Mobile Approval Gates

### Gate 1: DRAFT Generated

- OpenClaw / MiniMax can generate only DRAFT.
- DRAFT must be handed to ChatGPT for review.
- DRAFT must not be given to Codex.

### Gate 2: FINAL Generated

- ChatGPT output must be clearly marked as `FINAL_CODEX_PROMPT` or an
  equivalent explicit final marker.
- OpenClaw must send the FINAL summary to Telegram for user confirmation.
- OpenClaw must not hand FINAL to Codex before user approval.

### Gate 3: Codex Execution

- Codex may execute only after the user approves the current FINAL.
- Approval applies only to the current FINAL.
- Approval does not grant long-term authorization.

### Gate 4: Report Review

- Codex reports must be sent to Telegram.
- The user must choose next, revise, or stop.
- OpenClaw must not automatically start the next stage.

## 5. Telegram Command Semantics

Use `docs/agent/telegram-review-contract.md` as the source of truth. In short:

- `/status` reports dev branch status and does not modify code.
- `/draft <task>` generates DRAFT and waits for ChatGPT review.
- `/review` reviews a draft or Codex report and does not modify code.
- `/approve` allows the current ChatGPT-reviewed FINAL to be executed by
  Codex.
- `/revise` requests a regenerated or changed DRAFT.
- `/stop` stops automatic progression.
- `/next` asks for next-stage recommendations.

`/approve` does not mean push, merge, release, publish, or long-term
authorization. `/next` does not execute the next stage. `/stop` stops automatic
progression until the user explicitly restarts it.

## 6. GUI Automation Policy

- GUI automation is only for passing information, reading output, and
  triggering approved actions.
- GUI automation must not bypass Telegram approval gates.
- GUI automation must not read, expose, or log API keys, tokens, auth files, or
  private configuration.
- GUI automation must not click execution, commit, push, merge, release, or
  publish controls before approval.
- If GUI automation sees a popup, expired login, permission request, captcha,
  model anomaly, or stuck Codex session, it must stop and request user action.
- GUI automation must keep auditable log summaries without recording secrets.

## 7. Failure And Stop Policy

OpenClaw must stop and ask for user confirmation when any of these happen:

- ChatGPT output is not `FINAL_CODEX_PROMPT` or an equivalent final marker.
- Codex report lacks validation results.
- Codex fails.
- The worktree is dirty and the task did not allow continuing.
- Current branch is not `develop`.
- Current repository path is not `/Users/yu/Flutter_Projects/fleet_ledger_app`.
- GUI automation cannot confirm page state.
- ChatGPT or Codex login expires.
- An API key, token, auth file, or private config appears.
- The task asks to push, merge, release, or publish.
- The user sends `/stop`.

## 8. Safety Policy

- Do not store real MiniMax API keys, Telegram tokens, OpenClaw private config,
  Codex auth, or other secrets in the repository.
- Do not send secrets to ChatGPT.
- Do not send secrets to Telegram.
- Do not write secrets into logs.
- Do not write secrets into Codex prompts.
- Sensitive configuration must stay in secure local storage or environment
  variables. Repository docs may contain placeholder instructions only.

## 9. Default Baseline

- Default repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Default branch: `develop`
- Default: do not use the old audit worktree.
- Default: do not push.
- Default: do not merge.
- Default: do not release or publish.
- Default: do not modify business code unless the approved FINAL prompt
  explicitly scopes that work.

Before every task, verify the actual path, branch, HEAD, and git status.

## 10. First Real Dry Run

The first real mobile office dry run should be low risk:

- Read-only audit.
- Prompt review.
- Documentation consistency check.
- No file modification.
- No push, merge, release, or publishing.
