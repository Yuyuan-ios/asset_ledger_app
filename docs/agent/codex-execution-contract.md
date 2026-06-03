# Codex Execution Contract

## 1. Codex Role

- Codex is the executor.
- Codex executes only ChatGPT-reviewed `FINAL_CODEX_PROMPT`.
- In the mobile GUI automation workflow, Codex executes only when OpenClaw
  passes a user-approved FINAL prompt.
- In long-goal automation, Codex executes one stage at a time.
- Codex does not execute OpenClaw / MiniMax DRAFT prompts.
- Codex does not generate the next-stage prompt.
- Codex does not expand task scope by itself.
- Codex does not automatically enter the next stage after tests pass.
- Codex does not automatically push.
- Codex does not automatically merge.
- Codex does not automatically release or publish.

## 2. Required Preflight

Before execution, Codex must confirm:

- Repository path.
- Branch.
- HEAD.
- Git status.
- Relevant docs read.
- Task scope.
- Forbidden changes.
- Validation commands.
- Whether commit is allowed.
- Whether push is forbidden.

Default baseline unless the user explicitly says otherwise:

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Branch: `dev`

## 3. Stop Conditions

Codex must stop and report when any of these are true:

- Current branch is not the prompt-specified branch.
- Current path is not the prompt-specified path.
- Git status is dirty and the prompt does not allow continuing in a dirty
  worktree.
- The prompt is DRAFT, not FINAL.
- The prompt has no forbidden changes.
- The prompt has no validation commands.
- The prompt asks to modify DB schema/migration but does not use the
  migration-change template.
- The prompt asks to push, merge, release, or publish.
- The prompt conflicts with actual repository state.
- The FINAL prompt conflicts with current `dev` branch state.
- The task scope is too large and should be split.
- The prompt tries to execute more than one long-goal stage at once.

## 4. Execution Rules

- Modify only files inside the approved scope.
- Do not expand the task automatically.
- Do not broaden scope after a failure; report the failure and wait for retry,
  revise, or stop.
- Do not change unrelated modules just to make tests pass.
- Do not modify `$HOME/.agents`.
- Do not commit secrets or private configuration.
- Do not add dependencies unless the prompt explicitly allows it.
- If a product decision is needed, stop and report.
- If active docs conflict with repository state, stop and report.
- Reports must be structured so OpenClaw can summarize them clearly in
  Telegram.
- Reports may recommend next, but must not execute next.
- Tests passing does not authorize the next stage.

## 5. Final Report Format

Codex final reports must include:

- Repository path.
- Branch / HEAD before.
- Changed files.
- Summary of changes.
- Validation commands and results.
- Branch / HEAD after.
- Git status.
- Whether committed.
- Commit hash if committed.
- Whether pushed.
- Whether the report is safe to summarize in Telegram without secrets.
- Risks / follow-ups.
- Whether next is recommended.
- Whether business code changed.
- Whether `lib/` changed.
- Whether `test/` changed.
- Whether `pubspec.yaml` changed.
- Whether DB schema/migration changed.
- Whether `$HOME/.agents` changed.
- Whether secrets were touched.
