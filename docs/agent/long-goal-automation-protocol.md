# Long Goal Automation Protocol

## 1. Purpose

This document defines how long goals move through OpenClaw / MiniMax,
ChatGPT, Codex, and Telegram in small controlled stages.

- The goal is not to let OpenClaw write code directly.
- OpenClaw orchestrates ChatGPT and Codex.
- The user keeps stage approval authority in Telegram.
- Long goals must be split into small stages.
- Every stage needs clear scope, validation, stop conditions, and final report
  format.
- The first version does not allow unlimited auto-next.
- Each stage completion waits for user `next` by default.
- Low-risk docs-only or read-only audit stages may suggest next, but still
  require user confirmation.

## 2. Roles

### User / Telegram Reviewer

- Provides the overall goal.
- Reviews the full stage plan.
- Approves the current stage FINAL prompt.
- Chooses next, revise, retry, or stop.
- Handles product decisions, risk confirmations, and failure confirmations.

### OpenClaw

- Acts as the mobile office orchestrator.
- Maintains current long-goal state.
- Reads repository docs.
- Calls MiniMax to generate DRAFT output.
- Sends DRAFT to ChatGPT through GUI automation.
- Sends ChatGPT FINAL output to Telegram for user confirmation.
- Hands FINAL to Codex only after user approval.
- Reads Codex reports and sends Telegram summaries.
- Does not directly write business code.
- Does not bypass ChatGPT.
- Does not bypass user approval gates.

### MiniMax

- Generates `DRAFT_PROMPT_PACKAGE`.
- Generates `DRAFT_STAGE_PLAN`.
- Generates draft next-stage suggestions.
- Does not generate `FINAL_STAGE_PLAN`.
- Does not generate `FINAL_CODEX_PROMPT`.
- Does not directly call Codex.

### ChatGPT

- Reviews DRAFT output.
- Splits long goals into staged plans.
- Outputs `FINAL_STAGE_PLAN`.
- Narrows the current stage scope.
- Strengthens forbidden changes and validation.
- Uses Codex reports to decide the next-stage prompt.
- Outputs `FINAL_CODEX_PROMPT`.

### Codex

- Executes only `FINAL_CODEX_PROMPT`.
- Executes one stage at a time.
- Runs validation after execution.
- Outputs an execution report.
- Does not automatically push, merge, release, or publish.
- Does not automatically enter the next stage.

## 3. Long Goal Lifecycle

### A. Goal Intake

- The user sends an overall goal in Telegram, for example: "implement date
  picker functionality".
- OpenClaw creates `GOAL_INTAKE_SUMMARY`.
- OpenClaw must not send the goal directly to Codex.

### B. Planning

- OpenClaw / MiniMax generates `DRAFT_STAGE_PLAN`.
- ChatGPT reviews the DRAFT and outputs `FINAL_STAGE_PLAN`.
- `FINAL_STAGE_PLAN` must be sent to Telegram for user confirmation.
- Only after user approval may the workflow enter Stage 1.

### C. Stage Execution

- OpenClaw / MiniMax generates `DRAFT_PROMPT_PACKAGE` for the current stage.
- ChatGPT reviews it into `FINAL_CODEX_PROMPT`.
- The user approves the current stage.
- Codex executes the current stage only.
- Codex runs validation.
- OpenClaw summarizes the Codex report to Telegram.

### D. Stage Result Decision

- If validation passes and no human decision point remains, OpenClaw sends a
  next suggestion card.
- If validation fails, OpenClaw sends a failure card and waits for user revise,
  retry, or stop.
- If a product decision is needed, OpenClaw sends a human decision card.
- If scope expands beyond the approved stage, OpenClaw stops and asks ChatGPT to
  narrow the next prompt.
- If the user chooses next, OpenClaw starts the next-stage DRAFT flow.
- If the user chooses stop, OpenClaw stops the long-goal loop.

### E. Completion

- After all stages are complete, OpenClaw creates a final summary.
- The final summary must include changed files, commits, validation results,
  remaining issues, and whether anything was pushed.
- Default behavior is no push.

## 4. Stage Plan Format

FINAL_STAGE_PLAN

Goal:
<overall goal>

Baseline:
- Repository:
- Branch:
- HEAD:
- Status:

Assumptions:
- <assumption>

Out of scope:
- <what will not be done>

Stages:
1. Stage name:
   Goal:
   Scope:
   Files likely involved:
   Forbidden changes:
   Validation:
   Human approval needed before execution:
   Auto-next allowed after success:
   Stop conditions:

2. Stage name:
   Goal:
   Scope:
   Files likely involved:
   Forbidden changes:
   Validation:
   Human approval needed before execution:
   Auto-next allowed after success:
   Stop conditions:

Global forbidden changes:
- No automatic push.
- No automatic merge.
- No automatic release or publish.
- Do not modify business modules outside listed scope.
- Do not read or output secrets.

Completion criteria:
- <what counts as done>

## 5. Stage Execution Rules

- Codex executes one stage per run.
- Each stage must have `FINAL_CODEX_PROMPT`.
- Each stage must have validation commands.
- Each stage must have forbidden changes.
- Each stage must have final report format.
- Codex failures must not trigger broad automatic fixes.
- Test failures must be reported before user chooses retry, revise, or stop.
- Low-risk docs-only stages may suggest auto-next, but the first version still
  requires user confirmation.
- High-risk areas require manual approval for every stage, including DB schema,
  migrations, finance, external work, settlement, write-off, statistics,
  subscriptions, and data recovery.

## 6. Telegram Long-Goal Cards

Goal intake card:

Task:
Type:
Risk:
Proposed planning action:
Needs ChatGPT:
Buttons:
[Ask ChatGPT Plan] [Revise Goal] [Stop]

Stage plan review card:

Goal:
Stage count:
Risk:
Out of scope:
Stage list:
Recommended action:
Buttons:
[Approve Plan] [Revise Plan] [Stop]

Stage approval card:

Stage:
What Codex will do:
What Codex must not touch:
Validation:
Risk:
Auto-next after success:
Buttons:
[Approve Stage] [Revise Prompt] [Stop]

Stage result card:

Stage:
Result:
Validation:
Changed files:
Commit:
Risks:
Recommended next:
Buttons:
[Next] [Revise] [Retry] [Stop]

Failure card:

Stage:
Failure type:
Command failed:
Likely cause:
Recommended action:
Buttons:
[Ask ChatGPT Fix] [Retry] [Stop]

Human decision card:

Question:
Options:
Impact:
Recommended option:
Buttons:
[Choose A] [Choose B] [Ask ChatGPT] [Stop]

## 7. Auto-Next Policy

First version default:

- Unlimited auto-next is not allowed.
- Every code stage requires Telegram next after completion.
- Docs-only or read-only audit stages may suggest next, but the user must
  confirm.
- Codex tests passing does not automatically start the next stage.
- OpenClaw may prepare the next-stage DRAFT, but must not hand it to Codex
  unless the user approves.

Future optional enhancement:

- Allow auto-next only for low-risk docs or test-addition stages.
- Require a consecutive auto-stage limit, for example at most two automatic
  stages.
- Stop immediately on any failure.
- Require human confirmation after any business-code modification.

## 8. Stop Conditions

OpenClaw must stop and notify Telegram when any of these are true:

- Current repository path is wrong.
- Current branch is not `dev`.
- Git status is dirty and the current stage did not allow continuing.
- ChatGPT did not output `FINAL_CODEX_PROMPT`.
- Codex report lacks validation results.
- Codex modified forbidden changes.
- Codex failed.
- Tests failed.
- A product decision is needed.
- A DB migration is needed.
- The task touches high-risk finance, statistics, external work, settlement, or
  write-off rules.
- An API key, token, auth file, or private config appears.
- GUI automation state cannot be confirmed.
- The user sends `/stop`.

## 9. Date Picker Example

Overall goal:
Implement date picker functionality.

Recommended staged plan:

- Stage 0: readonly audit current date inputs, date formats, and relevant UI;
  no code changes.
- Stage 1: proposal for date picker entry point and interaction; no code
  changes.
- Stage 2: implement the smallest UI date picker control; do not change
  business storage.
- Stage 3: connect target page state; do not change DB schema.
- Stage 4: add widget or unit tests.
- Stage 5: polish and regression validation.

This is only an example and does not mean immediate execution. Before real
execution, ChatGPT must split the goal again from current code and current docs.
Every stage requires Telegram approval.

## 10. Safety And Secrets

- Do not store real MiniMax API keys, Telegram tokens, OpenClaw private config,
  Codex auth, or other secrets in the repository.
- Do not send secrets to ChatGPT.
- Do not send secrets to Telegram.
- Do not write secrets into logs.
- Do not write secrets into Codex prompts.
- Use placeholders only in repository docs.

